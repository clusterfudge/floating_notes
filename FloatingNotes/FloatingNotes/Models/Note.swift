import Foundation

/// Represents a single note in Floating Notes
struct Note: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var content: String
    var created_at: Date
    var updated_at: Date
    var pinned: Bool
    var color: String?
    var archived: Bool
    var section: String?

    /// Creates a new note with default values
    init(
        id: String = UUID().uuidString,
        title: String = "",
        content: String = "",
        created_at: Date = Date(),
        updated_at: Date = Date(),
        pinned: Bool = false,
        color: String? = nil,
        archived: Bool = false,
        section: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.created_at = created_at
        self.updated_at = updated_at
        self.pinned = pinned
        self.color = color
        self.archived = archived
        self.section = section
    }

    /// The display name for the note (title or first line of content)
    var displayName: String {
        if !title.isEmpty {
            return title
        }

        let firstLine = content.components(separatedBy: .newlines).first ?? ""
        if firstLine.isEmpty {
            return "Untitled Note"
        }

        // Strip markdown heading prefix if present
        let stripped = firstLine.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
        return stripped.isEmpty ? "Untitled Note" : stripped
    }

    /// Parse section from metadata footer in content
    /// Format: <!-- section: SectionName -->
    mutating func parseMetadata() {
        let pattern = "<!--\\s*section:\\s*(.+?)\\s*-->"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            section = String(content[range]).trimmingCharacters(in: .whitespaces)
        }
    }

    /// Updates the note with new content and refreshes metadata
    mutating func updateContent(_ newContent: String) {
        content = newContent
        updated_at = Date()
        parseMetadata()
    }

    /// Returns a preview of the note content (first 100 characters)
    var preview: String {
        let stripped = content.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
        let lines = stripped.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let preview = lines.prefix(2).joined(separator: " ")
        if preview.count > 100 {
            return String(preview.prefix(100)) + "..."
        }
        return preview
    }
}

/// Index entry for the web viewer
struct NoteIndexEntry: Codable {
    let id: String
    let title: String
    let preview: String
    let created_at: Date
    let updated_at: Date
    let pinned: Bool
    let section: String?

    init(from note: Note) {
        self.id = note.id
        self.title = note.displayName
        self.preview = note.preview
        self.created_at = note.created_at
        self.updated_at = note.updated_at
        self.pinned = note.pinned
        self.section = note.section
    }
}

/// Available note colors
enum NoteColor: String, CaseIterable, Codable {
    case none = ""
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"

    var displayName: String {
        switch self {
        case .none: return "None"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        }
    }

    #if canImport(SwiftUI)
    import SwiftUI

    var swiftUIColor: Color {
        switch self {
        case .none: return .clear
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
    #endif
}
