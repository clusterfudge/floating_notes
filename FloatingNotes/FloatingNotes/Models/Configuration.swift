import Foundation

/// Sync provider type
enum SyncProviderType: String, Codable, CaseIterable {
    case none
    case folder

    var displayName: String {
        switch self {
        case .none: return "Local Only"
        case .folder: return "Folder Sync"
        }
    }
}

/// Sync status
enum SyncStatus: Equatable {
    case synced
    case syncing
    case error(String)
    case disabled

    var displayText: String {
        switch self {
        case .synced: return "Synced"
        case .syncing: return "Syncing..."
        case .error(let message): return "Error: \(message)"
        case .disabled: return "Sync disabled"
        }
    }

    var isHealthy: Bool {
        switch self {
        case .synced, .syncing, .disabled: return true
        case .error: return false
        }
    }
}

/// Cloud location type for sync folder
enum CloudLocation: Equatable {
    case iCloud(URL)
    case dropbox(URL)
    case iCloudDocuments(URL)
    case custom(URL)

    var displayName: String {
        switch self {
        case .iCloud: return "iCloud Drive"
        case .dropbox: return "Dropbox"
        case .iCloudDocuments: return "Documents (iCloud)"
        case .custom: return "Custom Folder"
        }
    }

    var url: URL {
        switch self {
        case .iCloud(let url), .dropbox(let url), .iCloudDocuments(let url), .custom(let url):
            return url
        }
    }

    var description: String {
        switch self {
        case .iCloud:
            return "Syncs automatically across all your Apple devices"
        case .dropbox:
            return "Syncs to Dropbox-connected devices"
        case .iCloudDocuments:
            return "Your Documents folder is synced to iCloud"
        case .custom:
            return "Choose any folder (can still be cloud-synced)"
        }
    }
}

/// Sync configuration
struct SyncConfig: Codable, Equatable {
    var provider: SyncProviderType
    var folderPath: String?
    var publishHookPath: String?
    var publishBaseURL: String?
    var filterSecrets: Bool

    init(
        provider: SyncProviderType = .none,
        folderPath: String? = nil,
        publishHookPath: String? = nil,
        publishBaseURL: String? = nil,
        filterSecrets: Bool = true
    ) {
        self.provider = provider
        self.folderPath = folderPath
        self.publishHookPath = publishHookPath
        self.publishBaseURL = publishBaseURL
        self.filterSecrets = filterSecrets
    }
}

/// Window state for persistence
struct WindowState: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var sidebarWidth: Double

    init(
        x: Double = 100,
        y: Double = 100,
        width: Double = 900,
        height: Double = 600,
        sidebarWidth: Double = 250
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.sidebarWidth = sidebarWidth
    }
}

/// Application configuration
struct AppConfiguration: Codable {
    var sync: SyncConfig
    var windowState: WindowState
    var hasCompletedOnboarding: Bool
    var selectedNoteId: String?
    var showArchived: Bool
    var sortOrder: NoteSortOrder
    var lastSyncDate: Date?

    init(
        sync: SyncConfig = SyncConfig(),
        windowState: WindowState = WindowState(),
        hasCompletedOnboarding: Bool = false,
        selectedNoteId: String? = nil,
        showArchived: Bool = false,
        sortOrder: NoteSortOrder = .updatedAt,
        lastSyncDate: Date? = nil
    ) {
        self.sync = sync
        self.windowState = windowState
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.selectedNoteId = selectedNoteId
        self.showArchived = showArchived
        self.sortOrder = sortOrder
        self.lastSyncDate = lastSyncDate
    }

    /// Default configuration
    static let `default` = AppConfiguration()
}

/// Note sort order
enum NoteSortOrder: String, Codable, CaseIterable {
    case updatedAt = "updated_at"
    case createdAt = "created_at"
    case title = "title"

    var displayName: String {
        switch self {
        case .updatedAt: return "Last Modified"
        case .createdAt: return "Date Created"
        case .title: return "Title"
        }
    }
}

/// Configuration manager for loading/saving app config
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()

    @Published var config: AppConfiguration

    private let configURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("FloatingNotes", isDirectory: true)
        configURL = appFolder.appendingPathComponent("config.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        // Load config or use default
        if let data = try? Data(contentsOf: configURL),
           let loaded = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            config = loaded
        } else {
            config = .default
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: configURL)
        } catch {
            print("Failed to save config: \(error)")
        }
    }

    func updateSync(_ sync: SyncConfig) {
        config.sync = sync
        save()
    }

    func updateWindowState(_ state: WindowState) {
        config.windowState = state
        save()
    }

    func completeOnboarding() {
        config.hasCompletedOnboarding = true
        save()
    }

    func setSelectedNote(_ noteId: String?) {
        config.selectedNoteId = noteId
        save()
    }
}
