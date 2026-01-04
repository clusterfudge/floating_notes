import Foundation

/// Events that can be sent to the publish hook
enum PublishEvent: Encodable {
    case noteUpdated(noteId: String, notePath: String)
    case noteDeleted(noteId: String)
    case imageUploaded(localPath: String, hash: String)
    case syncAll(syncFolder: String)
    case generateHtml(outputPath: String, indexPath: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case noteId = "note_id"
        case notePath = "note_path"
        case localPath = "local_path"
        case hash
        case syncFolder = "sync_folder"
        case outputPath = "output_path"
        case indexPath = "index_path"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .noteUpdated(let noteId, let notePath):
            try container.encode("note_updated", forKey: .type)
            try container.encode(noteId, forKey: .noteId)
            try container.encode(notePath, forKey: .notePath)

        case .noteDeleted(let noteId):
            try container.encode("note_deleted", forKey: .type)
            try container.encode(noteId, forKey: .noteId)

        case .imageUploaded(let localPath, let hash):
            try container.encode("image_uploaded", forKey: .type)
            try container.encode(localPath, forKey: .localPath)
            try container.encode(hash, forKey: .hash)

        case .syncAll(let syncFolder):
            try container.encode("sync_all", forKey: .type)
            try container.encode(syncFolder, forKey: .syncFolder)

        case .generateHtml(let outputPath, let indexPath):
            try container.encode("generate_html", forKey: .type)
            try container.encode(outputPath, forKey: .outputPath)
            try container.encode(indexPath, forKey: .indexPath)
        }
    }
}

/// Manages calling user-provided publish hook scripts
class PublishHook {
    let scriptPath: URL
    let baseURL: String?

    private let encoder: JSONEncoder

    init(scriptPath: URL, baseURL: String? = nil) {
        self.scriptPath = scriptPath
        self.baseURL = baseURL

        encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
    }

    /// Called when a note is updated
    func noteUpdated(noteId: String, notePath: URL) async throws {
        let event = PublishEvent.noteUpdated(noteId: noteId, notePath: notePath.path)
        _ = try await runScript(event: event)
    }

    /// Called when a note is deleted
    func noteDeleted(noteId: String) async throws {
        let event = PublishEvent.noteDeleted(noteId: noteId)
        _ = try await runScript(event: event)
    }

    /// Called when an image is uploaded. Returns the public URL if the hook provides one.
    func imageUploaded(localPath: URL, hash: String) async throws -> URL? {
        let event = PublishEvent.imageUploaded(localPath: localPath.path, hash: hash)
        let output = try await runScript(event: event)

        // Script can return a public URL
        if let urlString = output?.trimmingCharacters(in: .whitespacesAndNewlines),
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            return url
        }
        return nil
    }

    /// Called to sync all notes
    func syncAll(syncFolder: URL) async throws {
        let event = PublishEvent.syncAll(syncFolder: syncFolder.path)
        _ = try await runScript(event: event)
    }

    /// Called to generate HTML viewer
    func generateHtml(outputPath: URL, indexPath: URL) async throws {
        let event = PublishEvent.generateHtml(outputPath: outputPath.path, indexPath: indexPath.path)
        _ = try await runScript(event: event)
    }

    /// Run the hook script with the given event
    private func runScript(event: PublishEvent) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/bash")
                    process.arguments = [scriptPath.path]

                    let inputPipe = Pipe()
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()

                    process.standardInput = inputPipe
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe

                    try process.run()

                    // Send event JSON to stdin
                    let eventData = try encoder.encode(event)
                    inputPipe.fileHandleForWriting.write(eventData)
                    inputPipe.fileHandleForWriting.closeFile()

                    process.waitUntilExit()

                    if process.terminationStatus != 0 {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: SyncError.hookFailed(errorMessage))
                        return
                    }

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Verify the hook script exists and is executable
    func verify() -> Bool {
        let fileManager = FileManager.default
        return fileManager.isExecutableFile(atPath: scriptPath.path)
    }
}

/// Factory for creating publish hooks from configuration
struct PublishHookFactory {
    static func create(from config: SyncConfig) -> PublishHook? {
        guard let hookPath = config.publishHookPath else { return nil }

        let scriptURL = URL(fileURLWithPath: hookPath)
        return PublishHook(scriptPath: scriptURL, baseURL: config.publishBaseURL)
    }
}
