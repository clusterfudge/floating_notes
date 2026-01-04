import Foundation
import CryptoKit

#if canImport(AppKit)
import AppKit
#endif

/// Handles image storage and management
class ImageHandler {
    static let shared = ImageHandler()

    private let fileManager = FileManager.default
    private let imagesDirectory: URL

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("FloatingNotes", isDirectory: true)
        imagesDirectory = appFolder.appendingPathComponent("images", isDirectory: true)

        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    /// Save image data and return the local file URL
    func saveImage(data: Data, preferredExtension: String = "png") -> URL? {
        // Generate content hash for filename
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16)

        let filename = "\(hashString).\(preferredExtension)"
        let fileURL = imagesDirectory.appendingPathComponent(filename)

        // Skip if file already exists
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    #if canImport(AppKit)
    /// Save an NSImage and return the local file URL
    func saveImage(_ image: NSImage) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        return saveImage(data: pngData, preferredExtension: "png")
    }

    /// Get image from pasteboard
    func imageFromPasteboard() -> (NSImage, URL?)? {
        let pasteboard = NSPasteboard.general

        // Check for image data
        if let image = NSImage(pasteboard: pasteboard) {
            if let url = saveImage(image) {
                return (image, url)
            }
        }

        // Check for file URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let fileURL = urls.first,
           let image = NSImage(contentsOf: fileURL) {
            // Copy the file to our images directory
            if let data = try? Data(contentsOf: fileURL) {
                let ext = fileURL.pathExtension.isEmpty ? "png" : fileURL.pathExtension
                if let localURL = saveImage(data: data, preferredExtension: ext) {
                    return (image, localURL)
                }
            }
        }

        return nil
    }
    #endif

    /// Generate markdown for an image
    func markdownForImage(url: URL, altText: String = "") -> String {
        return "![\(altText)](file://\(url.path))"
    }

    /// Delete an image by filename
    func deleteImage(filename: String) {
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Get all images in the images directory
    func allImages() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "heic"]
        return files.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
    }

    /// Clean up orphaned images (not referenced in any note)
    func cleanupOrphanedImages(notes: [Note]) {
        let allImageFiles = allImages()

        for imageURL in allImageFiles {
            let filename = imageURL.lastPathComponent
            let isReferenced = notes.contains { note in
                note.content.contains(filename)
            }

            if !isReferenced {
                try? fileManager.removeItem(at: imageURL)
            }
        }
    }
}

/// Image context for URL resolution
enum ImageContext {
    case editor
    case webViewer
}

/// Resolve image URL based on context
func resolveImageURL(_ localPath: String, for context: ImageContext, baseURL: String? = nil) -> String {
    switch context {
    case .editor:
        // Always use local file for editing
        return "file://\(localPath)"
    case .webViewer:
        // Use publish hook's base URL if available
        if let baseURL = baseURL {
            let filename = URL(fileURLWithPath: localPath).lastPathComponent
            return "\(baseURL)/images/\(filename)"
        }
        // Fall back to relative path
        let filename = URL(fileURLWithPath: localPath).lastPathComponent
        return "images/\(filename)"
    }
}
