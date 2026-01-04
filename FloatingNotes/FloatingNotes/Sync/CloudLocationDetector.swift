import Foundation

/// Detects available cloud sync locations
struct CloudLocationDetector {
    private static let fileManager = FileManager.default

    /// Detect all available cloud sync locations
    static func detectAvailableLocations() -> [CloudLocation] {
        var locations: [CloudLocation] = []

        // iCloud Drive (most reliable)
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/FloatingNotes") {
            locations.append(.iCloud(iCloudURL))
        }

        // Alternative iCloud path (Mobile Documents)
        let mobileDocuments = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/FloatingNotes")
        if fileManager.fileExists(atPath: mobileDocuments.deletingLastPathComponent().path) {
            // Only add if we didn't already add iCloud
            if !locations.contains(where: {
                if case .iCloud = $0 { return true }
                return false
            }) {
                locations.append(.iCloud(mobileDocuments))
            }
        }

        // Dropbox
        let dropboxURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Dropbox/FloatingNotes")
        if fileManager.fileExists(atPath: dropboxURL.deletingLastPathComponent().path) {
            locations.append(.dropbox(dropboxURL))
        }

        // iCloud Documents folder (if enabled)
        let documentsURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/FloatingNotes")
        if isICloudSynced(documentsURL.deletingLastPathComponent()) {
            locations.append(.iCloudDocuments(documentsURL))
        }

        return locations
    }

    /// Check if a folder is synced via iCloud
    private static func isICloudSynced(_ url: URL) -> Bool {
        // Check for .icloud files or iCloud extended attributes
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isUbiquitousItemKey])
            return resourceValues.isUbiquitousItem ?? false
        } catch {
            // Fallback: check for .icloud files in the directory
            if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                return contents.contains { $0.lastPathComponent.hasPrefix(".") && $0.lastPathComponent.hasSuffix(".icloud") }
            }
            return false
        }
    }

    /// Get the recommended sync location
    static func recommendedLocation() -> CloudLocation? {
        let locations = detectAvailableLocations()

        // Prefer iCloud Drive
        if let iCloud = locations.first(where: {
            if case .iCloud = $0 { return true }
            return false
        }) {
            return iCloud
        }

        // Then Dropbox
        if let dropbox = locations.first(where: {
            if case .dropbox = $0 { return true }
            return false
        }) {
            return dropbox
        }

        // Then iCloud Documents
        if let iCloudDocs = locations.first(where: {
            if case .iCloudDocuments = $0 { return true }
            return false
        }) {
            return iCloudDocs
        }

        return nil
    }

    /// Ensure the sync folder exists
    static func ensureSyncFolder(at location: CloudLocation) throws {
        let url = location.url
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }

        // Create subdirectories
        let notesDir = url.appendingPathComponent("notes", isDirectory: true)
        let imagesDir = url.appendingPathComponent("images", isDirectory: true)

        if !fileManager.fileExists(atPath: notesDir.path) {
            try fileManager.createDirectory(at: notesDir, withIntermediateDirectories: true)
        }

        if !fileManager.fileExists(atPath: imagesDir.path) {
            try fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }
    }

    /// Get a human-readable path for display
    static func displayPath(for location: CloudLocation) -> String {
        let url = location.url
        let home = fileManager.homeDirectoryForCurrentUser.path

        var path = url.path
        if path.hasPrefix(home) {
            path = "~" + path.dropFirst(home.count)
        }

        return path
    }
}
