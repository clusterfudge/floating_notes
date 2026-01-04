import Foundation

/// Syncs notes to a designated folder (iCloud Drive, Dropbox, or any synced location)
class FolderSyncProvider: SyncProvider {
    let syncFolderURL: URL
    private let notesFolder: URL
    private let imagesFolder: URL
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let secretFilter: SecretFilter

    var publishHook: PublishHook?

    private(set) var isEnabled: Bool = true
    private(set) var status: SyncStatus = .synced

    init(syncFolderURL: URL, publishHook: PublishHook? = nil) {
        self.syncFolderURL = syncFolderURL
        self.notesFolder = syncFolderURL.appendingPathComponent("notes", isDirectory: true)
        self.imagesFolder = syncFolderURL.appendingPathComponent("images", isDirectory: true)
        self.publishHook = publishHook
        self.secretFilter = SecretFilter()

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        // Create directories
        try? fileManager.createDirectory(at: notesFolder, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
    }

    func syncNote(_ note: Note) async throws {
        guard isEnabled else { return }

        // Apply secret filter if configured
        let sanitized = secretFilter.filter(note)

        // Write to sync folder
        let noteURL = notesFolder.appendingPathComponent("\(note.id).json")
        do {
            let data = try encoder.encode(sanitized)
            try data.write(to: noteURL, options: .atomic)
        } catch {
            throw SyncError.writeFailed(noteURL, error)
        }

        // Trigger publish hook if configured
        if let hook = publishHook {
            try await hook.noteUpdated(noteId: note.id, notePath: noteURL)
        }

        // Update index
        try await updateIndex()
    }

    func deleteNote(_ noteId: String) async throws {
        guard isEnabled else { return }

        let noteURL = notesFolder.appendingPathComponent("\(noteId).json")

        if fileManager.fileExists(atPath: noteURL.path) {
            do {
                try fileManager.removeItem(at: noteURL)
            } catch {
                throw SyncError.deleteFailed(noteURL, error)
            }
        }

        // Trigger publish hook
        if let hook = publishHook {
            try await hook.noteDeleted(noteId: noteId)
        }

        // Update index
        try await updateIndex()
    }

    func syncImage(_ localPath: URL, hash: String) async throws -> URL {
        guard isEnabled else { return localPath }

        let ext = localPath.pathExtension
        let destURL = imagesFolder.appendingPathComponent("\(hash).\(ext)")

        // Skip if already exists
        if !fileManager.fileExists(atPath: destURL.path) {
            do {
                try fileManager.copyItem(at: localPath, to: destURL)
            } catch {
                throw SyncError.writeFailed(destURL, error)
            }
        }

        // Trigger publish hook and get public URL if available
        if let hook = publishHook {
            if let publicURL = try await hook.imageUploaded(localPath: destURL, hash: hash) {
                return publicURL
            }
        }

        return destURL
    }

    func syncAll() async throws {
        guard isEnabled else { return }

        status = .syncing

        // Trigger full sync via publish hook
        if let hook = publishHook {
            try await hook.syncAll(syncFolder: syncFolderURL)
        }

        status = .synced
    }

    /// Update the index.json file for web viewer
    private func updateIndex() async throws {
        // Load all notes from sync folder
        guard let files = try? fileManager.contentsOfDirectory(at: notesFolder, includingPropertiesForKeys: nil) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let notes: [Note] = files.compactMap { url -> Note? in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Note.self, from: data)
        }

        // Create index entries
        let indexEntries = notes.map { NoteIndexEntry(from: $0) }
            .sorted { $0.updated_at > $1.updated_at }

        // Write index
        let indexURL = syncFolderURL.appendingPathComponent("index.json")
        let indexData = try encoder.encode(indexEntries)
        try indexData.write(to: indexURL, options: .atomic)
    }

    /// Verify sync folder is accessible
    func verifyAccess() -> Bool {
        return fileManager.isWritableFile(atPath: syncFolderURL.path)
    }
}
