import Foundation

/// Protocol for sync providers
protocol SyncProvider {
    var isEnabled: Bool { get }
    var status: SyncStatus { get }

    func syncNote(_ note: Note) async throws
    func deleteNote(_ noteId: String) async throws
    func syncImage(_ localPath: URL, hash: String) async throws -> URL
    func syncAll() async throws
}

/// No-op provider for users who don't want sync
class LocalOnlySyncProvider: SyncProvider {
    var isEnabled: Bool { false }
    var status: SyncStatus { .disabled }

    func syncNote(_ note: Note) async throws {
        // No-op
    }

    func deleteNote(_ noteId: String) async throws {
        // No-op
    }

    func syncImage(_ localPath: URL, hash: String) async throws -> URL {
        return localPath
    }

    func syncAll() async throws {
        // No-op
    }
}

/// Errors that can occur during sync
enum SyncError: LocalizedError {
    case folderNotConfigured
    case folderNotAccessible(URL)
    case writeFailed(URL, Error)
    case deleteFailed(URL, Error)
    case hookFailed(String)

    var errorDescription: String? {
        switch self {
        case .folderNotConfigured:
            return "Sync folder is not configured"
        case .folderNotAccessible(let url):
            return "Cannot access sync folder: \(url.path)"
        case .writeFailed(let url, let error):
            return "Failed to write to \(url.lastPathComponent): \(error.localizedDescription)"
        case .deleteFailed(let url, let error):
            return "Failed to delete \(url.lastPathComponent): \(error.localizedDescription)"
        case .hookFailed(let message):
            return "Publish hook failed: \(message)"
        }
    }
}
