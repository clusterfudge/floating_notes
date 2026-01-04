import Foundation
import Combine

/// Main storage and state management for notes
@MainActor
class NoteStore: ObservableObject {
    static let shared = NoteStore()

    @Published var notes: [Note] = []
    @Published var templates: [Template] = []
    @Published var selectedNoteId: String?
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var syncStatus: SyncStatus = .disabled

    private let notesDirectory: URL
    private let templatesDirectory: URL
    private let imagesDirectory: URL
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    var syncProvider: SyncProvider?
    private var autoSaveTask: Task<Void, Never>?
    private var pendingSaves: Set<String> = []

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("FloatingNotes", isDirectory: true)

        notesDirectory = appFolder.appendingPathComponent("notes", isDirectory: true)
        templatesDirectory = appFolder.appendingPathComponent("templates", isDirectory: true)
        imagesDirectory = appFolder.appendingPathComponent("images", isDirectory: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Create directories
        try? fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        // Load notes and templates
        loadNotes()
        loadTemplates()
    }

    // MARK: - Notes CRUD

    /// Load all notes from disk
    func loadNotes() {
        isLoading = true
        defer { isLoading = false }

        guard let files = try? fileManager.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        notes = files.compactMap { url -> Note? in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Note.self, from: data)
        }

        // Parse metadata for each note
        for i in notes.indices {
            notes[i].parseMetadata()
        }

        // Sort by updated_at descending
        notes.sort { $0.updated_at > $1.updated_at }
    }

    /// Save a note to disk
    func saveNote(_ note: Note) async {
        // Update in-memory
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.insert(note, at: 0)
        }

        // Save to disk
        let noteURL = notesDirectory.appendingPathComponent("\(note.id).json")
        do {
            let data = try encoder.encode(note)
            try data.write(to: noteURL, options: .atomic)

            // Sync if enabled
            if let provider = syncProvider, provider.isEnabled {
                try await provider.syncNote(note)
            }
        } catch {
            print("Failed to save note: \(error)")
        }
    }

    /// Create a new note
    func createNote(from template: Template? = nil) -> Note {
        var note = Note()

        if let template = template {
            #if canImport(AppKit)
            let clipboard = NSPasteboard.general.string(forType: .string)
            #else
            let clipboard: String? = nil
            #endif
            note.content = template.expand(clipboard: clipboard)
        }

        notes.insert(note, at: 0)
        selectedNoteId = note.id

        Task {
            await saveNote(note)
        }

        return note
    }

    /// Delete a note
    func deleteNote(_ noteId: String) async {
        notes.removeAll { $0.id == noteId }

        let noteURL = notesDirectory.appendingPathComponent("\(noteId).json")
        try? fileManager.removeItem(at: noteURL)

        if selectedNoteId == noteId {
            selectedNoteId = notes.first?.id
        }

        // Sync deletion
        if let provider = syncProvider, provider.isEnabled {
            try? await provider.deleteNote(noteId)
        }
    }

    /// Toggle note pinned state
    func togglePinned(_ noteId: String) async {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[index].pinned.toggle()
        notes[index].updated_at = Date()
        await saveNote(notes[index])
    }

    /// Toggle note archived state
    func toggleArchived(_ noteId: String) async {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[index].archived.toggle()
        notes[index].updated_at = Date()
        await saveNote(notes[index])
    }

    /// Set note color
    func setNoteColor(_ noteId: String, color: String?) async {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[index].color = color
        notes[index].updated_at = Date()
        await saveNote(notes[index])
    }

    // MARK: - Templates CRUD

    /// Load all templates from disk
    func loadTemplates() {
        guard let files = try? fileManager.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: nil) else {
            templates = Template.builtIn
            return
        }

        var loadedTemplates = files.compactMap { url -> Template? in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Template.self, from: data)
        }

        // Add built-in templates if not present
        for builtIn in Template.builtIn {
            if !loadedTemplates.contains(where: { $0.id == builtIn.id }) {
                loadedTemplates.append(builtIn)
            }
        }

        templates = loadedTemplates.sorted { $0.name < $1.name }
    }

    /// Save a template to disk
    func saveTemplate(_ template: Template) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }

        let templateURL = templatesDirectory.appendingPathComponent("\(template.id).json")
        do {
            let data = try encoder.encode(template)
            try data.write(to: templateURL, options: .atomic)
        } catch {
            print("Failed to save template: \(error)")
        }
    }

    /// Delete a template
    func deleteTemplate(_ templateId: String) {
        templates.removeAll { $0.id == templateId }
        let templateURL = templatesDirectory.appendingPathComponent("\(templateId).json")
        try? fileManager.removeItem(at: templateURL)
    }

    // MARK: - Filtering & Sorting

    /// Get selected note
    var selectedNote: Note? {
        notes.first { $0.id == selectedNoteId }
    }

    /// Get filtered notes based on search text and archive state
    func filteredNotes(showArchived: Bool) -> [Note] {
        var result = notes

        // Filter archived
        if !showArchived {
            result = result.filter { !$0.archived }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            result = result.filter {
                $0.displayName.lowercased().contains(searchLower) ||
                $0.content.lowercased().contains(searchLower)
            }
        }

        return result
    }

    /// Get notes grouped by section
    func groupedNotes(showArchived: Bool) -> [(section: String, notes: [Note])] {
        let filtered = filteredNotes(showArchived: showArchived)

        // Group pinned notes first
        let pinned = filtered.filter { $0.pinned }
        let unpinned = filtered.filter { !$0.pinned }

        // Group by section
        var sectionDict: [String: [Note]] = [:]
        for note in unpinned {
            let section = note.section ?? "Notes"
            sectionDict[section, default: []].append(note)
        }

        var result: [(String, [Note])] = []

        if !pinned.isEmpty {
            result.append(("Pinned", pinned))
        }

        // Sort sections alphabetically, but keep "Notes" last
        let sortedSections = sectionDict.keys.sorted { a, b in
            if a == "Notes" { return false }
            if b == "Notes" { return true }
            return a < b
        }

        for section in sortedSections {
            if let notes = sectionDict[section] {
                result.append((section, notes))
            }
        }

        return result
    }

    /// Get recent notes (last 5 modified)
    var recentNotes: [Note] {
        Array(notes.filter { !$0.archived }.prefix(5))
    }

    // MARK: - Sync

    /// Configure sync provider
    func configureSyncProvider(_ provider: SyncProvider?) {
        self.syncProvider = provider
        if let provider = provider {
            syncStatus = provider.isEnabled ? .synced : .disabled
        } else {
            syncStatus = .disabled
        }
    }

    /// Sync all notes
    func syncAll() async {
        guard let provider = syncProvider, provider.isEnabled else { return }

        syncStatus = .syncing
        do {
            try await provider.syncAll()
            syncStatus = .synced
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Images

    /// Get images directory URL
    var imagesDirectoryURL: URL {
        imagesDirectory
    }

    /// Get path for an image with given hash
    func imagePath(hash: String, ext: String) -> URL {
        imagesDirectory.appendingPathComponent("\(hash).\(ext)")
    }
}

#if canImport(AppKit)
import AppKit
#endif
