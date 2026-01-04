import Foundation

/// Represents a note template with variable substitution
struct Template: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var content: String
    var created_at: Date
    var updated_at: Date

    /// Creates a new template
    init(
        id: String = UUID().uuidString,
        name: String = "",
        content: String = "",
        created_at: Date = Date(),
        updated_at: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.created_at = created_at
        self.updated_at = updated_at
    }

    /// Available template variables
    enum Variable: String, CaseIterable {
        case date = "{{date}}"
        case time = "{{time}}"
        case datetime = "{{datetime}}"
        case isoDate = "{{iso_date}}"
        case year = "{{year}}"
        case month = "{{month}}"
        case day = "{{day}}"
        case weekday = "{{weekday}}"
        case uuid = "{{uuid}}"
        case clipboard = "{{clipboard}}"

        var description: String {
            switch self {
            case .date: return "Current date (e.g., January 4, 2026)"
            case .time: return "Current time (e.g., 2:30 PM)"
            case .datetime: return "Current date and time"
            case .isoDate: return "ISO 8601 date (e.g., 2026-01-04)"
            case .year: return "Current year"
            case .month: return "Current month name"
            case .day: return "Current day of month"
            case .weekday: return "Current day of week"
            case .uuid: return "Unique identifier"
            case .clipboard: return "Clipboard contents"
            }
        }
    }

    /// Expands template variables in the content
    func expand(clipboard: String? = nil) -> String {
        var result = content
        let now = Date()
        let dateFormatter = DateFormatter()

        // Date
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        result = result.replacingOccurrences(of: Variable.date.rawValue, with: dateFormatter.string(from: now))

        // Time
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        result = result.replacingOccurrences(of: Variable.time.rawValue, with: dateFormatter.string(from: now))

        // DateTime
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        result = result.replacingOccurrences(of: Variable.datetime.rawValue, with: dateFormatter.string(from: now))

        // ISO Date
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        result = result.replacingOccurrences(of: Variable.isoDate.rawValue, with: isoFormatter.string(from: now))

        // Year
        let calendar = Calendar.current
        result = result.replacingOccurrences(of: Variable.year.rawValue, with: String(calendar.component(.year, from: now)))

        // Month
        dateFormatter.dateFormat = "MMMM"
        result = result.replacingOccurrences(of: Variable.month.rawValue, with: dateFormatter.string(from: now))

        // Day
        result = result.replacingOccurrences(of: Variable.day.rawValue, with: String(calendar.component(.day, from: now)))

        // Weekday
        dateFormatter.dateFormat = "EEEE"
        result = result.replacingOccurrences(of: Variable.weekday.rawValue, with: dateFormatter.string(from: now))

        // UUID
        result = result.replacingOccurrences(of: Variable.uuid.rawValue, with: UUID().uuidString)

        // Clipboard
        if let clipboardContent = clipboard {
            result = result.replacingOccurrences(of: Variable.clipboard.rawValue, with: clipboardContent)
        } else {
            result = result.replacingOccurrences(of: Variable.clipboard.rawValue, with: "")
        }

        return result
    }
}

/// Built-in templates
extension Template {
    static let builtIn: [Template] = [
        Template(
            id: "meeting-notes",
            name: "Meeting Notes",
            content: """
            # Meeting Notes - {{date}}

            ## Attendees
            -

            ## Agenda
            -

            ## Discussion
            -

            ## Action Items
            - [ ]

            ## Next Steps
            -

            <!-- section: Meetings -->
            """
        ),
        Template(
            id: "daily-standup",
            name: "Daily Standup",
            content: """
            # Standup - {{weekday}}, {{date}}

            ## Yesterday
            -

            ## Today
            -

            ## Blockers
            -

            <!-- section: Standups -->
            """
        ),
        Template(
            id: "todo-list",
            name: "Todo List",
            content: """
            # Tasks - {{date}}

            ## High Priority
            - [ ]

            ## Normal Priority
            - [ ]

            ## Completed
            - [x]

            <!-- section: Tasks -->
            """
        ),
        Template(
            id: "journal-entry",
            name: "Journal Entry",
            content: """
            # {{date}}

            ## How am I feeling?


            ## What happened today?


            ## What am I grateful for?
            -

            ## Tomorrow's priorities
            -

            <!-- section: Journal -->
            """
        ),
        Template(
            id: "project-idea",
            name: "Project Idea",
            content: """
            # Project: [Name]

            ## Problem
            What problem does this solve?

            ## Solution
            How does this solve it?

            ## Key Features
            -

            ## Technical Notes
            -

            ## Next Steps
            - [ ]

            <!-- section: Ideas -->
            """
        )
    ]
}
