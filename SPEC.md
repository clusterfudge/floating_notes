Floating Notes - Portable Design Document

 Overview

 This document describes a portable version of Floating Notes that can be used outside the Anthropic monorepo. The key changes are:

 1. Local-first storage with optional file-system based sync (iCloud, Dropbox, etc.)
 2. Pluggable publish hooks for optional web publishing via user-provided scripts
 3. No Anthropic-specific dependencies (no ff, no internal S3 buckets)

 ---
 Architecture

 Current vs Portable
 ┌────────────────┬─────────────────────┬───────────────────────────────────┐
 │     Aspect     │ Current (Anthropic) │             Portable              │
 ├────────────────┼─────────────────────┼───────────────────────────────────┤
 │ Storage        │ Local + S3 sync     │ Local + optional folder sync      │
 ├────────────────┼─────────────────────┼───────────────────────────────────┤
 │ Sync mechanism │ ff CLI to S3        │ File-system sync (iCloud/Dropbox) │
 ├────────────────┼─────────────────────┼───────────────────────────────────┤
 │ Publishing     │ S3-serve + go links │ Optional hook script              │
 ├────────────────┼─────────────────────┼───────────────────────────────────┤
 │ Image hosting  │ S3 bucket           │ Local + optional hook             │
 ├────────────────┼─────────────────────┼───────────────────────────────────┤
 │ Web viewer     │ Auto-generated HTML │ Optional static site generation   │
 └────────────────┴─────────────────────┴───────────────────────────────────┘
 Storage Architecture

 ~/Library/Application Support/FloatingNotes/
 ├── notes/
 │   ├── <uuid>.json         # Individual note files
 │   └── ...
 ├── templates/
 │   ├── <uuid>.json         # Note templates
 │   └── ...
 ├── images/
 │   └── <hash>.<ext>        # Locally stored images
 ├── config.json             # App configuration
 └── hooks/
     └── (symlinks to user scripts)

 # Sync folder - auto-detected cloud locations or user choice:
 ~/Library/Mobile Documents/com~apple~CloudDocs/FloatingNotes/  # iCloud Drive (preferred)
 ~/Dropbox/FloatingNotes/                                        # Dropbox
 ~/Documents/FloatingNotes/                                      # If iCloud Documents enabled
 ├── notes/
 │   └── <uuid>.json          # Synced notes
 ├── images/
 │   └── <hash>.<ext>         # Synced images
 └── index.json               # Note index for web viewer

 Cloud Folder Detection

 On first launch, detect available cloud sync locations:

 struct CloudLocationDetector {
     static func detectAvailableLocations() -> [CloudLocation] {
         var locations: [CloudLocation] = []

         // iCloud Drive (most reliable)
         let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
             .appendingPathComponent("Documents/FloatingNotes")
         if let url = iCloudURL {
             locations.append(.iCloud(url))
         }

         // Dropbox
         let dropboxURL = FileManager.default.homeDirectoryForCurrentUser
             .appendingPathComponent("Dropbox/FloatingNotes")
         if FileManager.default.fileExists(atPath: dropboxURL.deletingLastPathComponent().path) {
             locations.append(.dropbox(dropboxURL))
         }

         // iCloud Documents folder (if enabled)
         let documentsURL = FileManager.default.homeDirectoryForCurrentUser
             .appendingPathComponent("Documents/FloatingNotes")
         // Check if Documents is synced via extended attributes or .icloud files
         if isICloudSynced(documentsURL.deletingLastPathComponent()) {
             locations.append(.iCloudDocuments(documentsURL))
         }

         return locations
     }
 }

 enum CloudLocation {
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
 }

 ---
 Core Components (Unchanged)

 These components remain largely unchanged from the current implementation:

 1. Note Model

 struct Note: Codable, Identifiable {
     let id: String
     var title: String
     var content: String
     var created_at: Date
     var updated_at: Date
     var pinned: Bool
     var color: String?
     var archived: Bool
     var section: String?
 }

 2. UI Components

 - ContentView - Main split-pane layout
 - SidebarView - Note list grouped by sections
 - EditorView - Markdown text editor with auto-save
 - CommandPaletteWindow - Quick actions (Cmd+K)
 - EmojiCompletionWindow - Emoji shortcode autocomplete
 - TemplatePickerWindow - Note template selection

 3. Features to Keep

 - All keyboard shortcuts and customization
 - Template system with variable substitution
 - Emoji shortcode completion
 - Sections via metadata footer parsing
 - Recents, pinned notes, archive
 - Window state persistence
 - Secret filtering (for privacy before any publishing)

 ---
 New: Sync Layer Architecture

 SyncProvider Protocol

 protocol SyncProvider {
     var isEnabled: Bool { get }
     var status: SyncStatus { get }

     func syncNote(_ note: Note) async throws
     func deleteNote(_ noteId: String) async throws
     func syncImage(_ localPath: URL, hash: String) async throws -> URL
     func syncAll() async throws
 }

 1. LocalOnlySyncProvider (Default)

 No-op provider for users who don't want sync.

 class LocalOnlySyncProvider: SyncProvider {
     var isEnabled: Bool { false }
     var status: SyncStatus { .synced }

     // All methods are no-ops
 }

 2. FolderSyncProvider (iCloud/Dropbox)

 Syncs notes to a designated folder that can be in iCloud Drive, Dropbox, or any synced location.

 class FolderSyncProvider: SyncProvider {
     let syncFolderURL: URL  // e.g., ~/FloatingNotes or ~/Library/Mobile Documents/...

     func syncNote(_ note: Note) async throws {
         // 1. Apply secret filter
         let sanitized = SecretFilter.filter(note)

         // 2. Write to sync folder
         let noteURL = syncFolderURL.appendingPathComponent("notes/\(note.id).json")
         try encoder.encode(sanitized).write(to: noteURL)

         // 3. Trigger publish hook if configured
         await publishHook?.noteUpdated(note.id)
     }

     func syncImage(_ localPath: URL, hash: String) async throws -> URL {
         let destURL = syncFolderURL.appendingPathComponent("images/\(hash).\(ext)")
         try FileManager.default.copyItem(at: localPath, to: destURL)
         return destURL  // Return local path; publish hook can replace
     }
 }

 Configuration

 struct SyncConfig: Codable {
     var provider: SyncProviderType  // .none, .folder
     var folderPath: String?         // For folder sync
     var publishHookPath: String?    // Optional publish script
     var publishBaseURL: String?     // Base URL for published notes (for link generation)
 }

 enum SyncProviderType: String, Codable {
     case none
     case folder
 }

 ---
 New: Publish Hook System

 Overview

 Publishing is completely decoupled from sync. Users who want to publish their notes to the web can provide a hook script that gets called when notes change.

 Hook Interface

 The app calls a user-provided script with JSON on stdin:

 #!/bin/bash
 # ~/.config/floating-notes/publish-hook.sh

 # Read event JSON from stdin
 event=$(cat)
 event_type=$(echo "$event" | jq -r '.type')

 case "$event_type" in
   "note_updated")
     note_id=$(echo "$event" | jq -r '.note_id')
     note_path=$(echo "$event" | jq -r '.note_path')
     # Upload to your hosting...
     ;;
   "note_deleted")
     note_id=$(echo "$event" | jq -r '.note_id')
     # Delete from your hosting...
     ;;
   "image_uploaded")
     local_path=$(echo "$event" | jq -r '.local_path')
     hash=$(echo "$event" | jq -r '.hash')
     # Upload image, echo public URL to stdout
     ;;
   "sync_all")
     sync_folder=$(echo "$event" | jq -r '.sync_folder')
     # Regenerate everything...
     ;;
   "generate_html")
     output_path=$(echo "$event" | jq -r '.output_path')
     # Generate web viewer...
     ;;
 esac

 Event Types
 ┌────────────────┬───────────────────────────┬──────────────────────┐
 │     Event      │          Payload          │  Expected Response   │
 ├────────────────┼───────────────────────────┼──────────────────────┤
 │ note_updated   │ {note_id, note_path}      │ Exit code 0          │
 ├────────────────┼───────────────────────────┼──────────────────────┤
 │ note_deleted   │ {note_id}                 │ Exit code 0          │
 ├────────────────┼───────────────────────────┼──────────────────────┤
 │ image_uploaded │ {local_path, hash}        │ Public URL on stdout │
 ├────────────────┼───────────────────────────┼──────────────────────┤
 │ sync_all       │ {sync_folder}             │ Exit code 0          │
 ├────────────────┼───────────────────────────┼──────────────────────┤
 │ generate_html  │ {output_path, index_path} │ Exit code 0          │
 └────────────────┴───────────────────────────┴──────────────────────┘
 PublishHook Class

 class PublishHook {
     let scriptPath: URL
     let baseURL: String?

     func noteUpdated(_ noteId: String) async throws {
         let event = PublishEvent.noteUpdated(noteId: noteId, notePath: notePath(noteId))
         try await runScript(event: event)
     }

     func imageUploaded(localPath: URL, hash: String) async throws -> URL? {
         let event = PublishEvent.imageUploaded(localPath: localPath, hash: hash)
         let output = try await runScript(event: event)

         // Script can return a public URL
         if let urlString = output?.trimmingCharacters(in: .whitespacesAndNewlines),
            let url = URL(string: urlString) {
             return url
         }
         return nil
     }

     private func runScript(event: PublishEvent) async throws -> String? {
         let process = Process()
         process.executableURL = URL(fileURLWithPath: "/bin/bash")
         process.arguments = [scriptPath.path]

         let inputPipe = Pipe()
         let outputPipe = Pipe()
         process.standardInput = inputPipe
         process.standardOutput = outputPipe

         try process.run()

         let eventData = try encoder.encode(event)
         inputPipe.fileHandleForWriting.write(eventData)
         inputPipe.fileHandleForWriting.closeFile()

         process.waitUntilExit()

         let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
         return String(data: outputData, encoding: .utf8)
     }
 }

 ---
 Image Handling

 Current Behavior

 - Paste image → Upload to S3 → Insert markdown with S3 URL

 New Behavior

 1. Paste image → Save to local images/ folder with content hash
 2. Insert markdown with local file reference: ![](file:///.../images/abc123.png)
 3. If folder sync enabled → Copy to sync folder
 4. If publish hook configured → Call hook, get public URL, update markdown

 Image URL Resolution

 func resolveImageURL(_ localPath: String, for context: ImageContext) -> String {
     switch context {
     case .editor:
         // Always use local file for editing
         return "file://\(localPath)"
     case .webViewer:
         // Use publish hook's base URL if available
         if let baseURL = config.publishBaseURL {
             let hash = URL(fileURLWithPath: localPath).lastPathComponent
             return "\(baseURL)/images/\(hash)"
         }
         // Fall back to relative path
         return "images/\(hash)"
     }
 }

 ---
 Web Viewer

 Built-in HTTP Server for Local Preview

 Include a lightweight HTTP server for previewing the web viewer locally:

 class LocalPreviewServer {
     private var server: NWListener?
     private let port: UInt16 = 8765

     var isRunning: Bool { server != nil }
     var url: URL { URL(string: "http://localhost:\(port)")! }

     func start(servingFolder: URL) throws {
         let parameters = NWParameters.tcp
         server = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

         server?.newConnectionHandler = { [weak self] connection in
             self?.handleConnection(connection, rootFolder: servingFolder)
         }

         server?.start(queue: .global())
     }

     func stop() {
         server?.cancel()
         server = nil
     }

     private func handleConnection(_ connection: NWConnection, rootFolder: URL) {
         // Simple HTTP/1.1 file server
         // Serves index.html, notes/*.json, images/*, and static assets
         // Returns appropriate Content-Type headers
         // CORS headers for local development
     }
 }

 Menu Bar Integration

 // In app menu
 Menu("Web Viewer") {
     Button("Start Local Preview") {
         previewServer.start(servingFolder: syncFolder)
         NSWorkspace.shared.open(previewServer.url)
     }
     .disabled(previewServer.isRunning)

     Button("Stop Local Preview") {
         previewServer.stop()
     }
     .disabled(!previewServer.isRunning)

     Divider()

     Button("Generate Standalone HTML...") {
         // Save panel to choose output location
         generateStandaloneViewer()
     }

     Button("Open Sync Folder in Finder") {
         NSWorkspace.shared.open(syncFolder)
     }
 }

 Bundled HTML Template

 The HTML viewer is bundled with the app but generated on-demand:

 func generateWebViewer(to outputPath: URL) throws {
     // Load bundled template
     let template = Bundle.main.url(forResource: "viewer", withExtension: "html")!

     // Generate index.json
     let index = notes.map { NoteIndexEntry(id: $0.id, title: $0.displayName, ...) }
     let indexPath = outputPath.deletingLastPathComponent().appendingPathComponent("index.json")
     try encoder.encode(index).write(to: indexPath)

     // Copy template (it loads index.json at runtime)
     try FileManager.default.copyItem(at: template, to: outputPath)
 }

 Self-Contained Option

 For users without a publish hook, generate a single HTML file with embedded notes:

 func generateStandaloneViewer(to outputPath: URL) throws {
     var html = baseTemplate

     // Embed notes as JSON (with images as base64 data URLs)
     let notesJSON = try encoder.encode(notes)
     html = html.replacingOccurrences(
         of: "<!-- NOTES_DATA -->",
         with: "<script>const NOTES_DATA = \(String(data: notesJSON, encoding: .utf8)!);</script>"
     )

     try html.write(to: outputPath, atomically: true, encoding: .utf8)
 }

 ---
 Configuration UI

 First Launch: Sync Setup

 ┌─────────────────────────────────────────────────────────┐
 │ Welcome to Floating Notes                               │
 ├─────────────────────────────────────────────────────────┤
 │                                                         │
 │ Where would you like to sync your notes?                │
 │                                                         │
 │   ◉ iCloud Drive (Recommended)                          │
 │     ~/Library/Mobile Documents/.../FloatingNotes        │
 │     Syncs automatically across all your Apple devices   │
 │                                                         │
 │   ○ Dropbox                                             │
 │     ~/Dropbox/FloatingNotes                             │
 │     Syncs to Dropbox-connected devices                  │
 │                                                         │
 │   ○ Documents (iCloud synced)                           │
 │     ~/Documents/FloatingNotes                           │
 │     Your Documents folder is synced to iCloud           │
 │                                                         │
 │   ○ Custom folder...                                    │
 │     Choose any folder (can still be cloud-synced)       │
 │                                                         │
 │   ○ Local only (no sync)                                │
 │     Notes stay on this Mac only                         │
 │                                                         │
 │                           [Continue]                    │
 └─────────────────────────────────────────────────────────┘

 Settings Window

 ┌─────────────────────────────────────────────────────┐
 │ Floating Notes Settings                             │
 ├─────────────────────────────────────────────────────┤
 │                                                     │
 │ Sync                                                │
 │ ┌─────────────────────────────────────────────────┐ │
 │ │ Sync location: iCloud Drive             [Change]│ │
 │ │ ~/Library/Mobile Documents/.../FloatingNotes    │ │
 │ │                                                 │ │
 │ │ Status: ● Synced (23 notes)                     │ │
 │ └─────────────────────────────────────────────────┘ │
 │                                                     │
 │ Publishing (Optional)                               │
 │ ┌─────────────────────────────────────────────────┐ │
 │ │ ☐ Enable publish hook                           │ │
 │ │   Script: ~/.config/fn/publish.sh  [Choose...] │ │
 │ │                                                 │ │
 │ │ Base URL: https://example.com/notes            │ │
 │ │   (Used for generating shareable links)        │ │
 │ └─────────────────────────────────────────────────┘ │
 │                                                     │
 │ Web Viewer                                          │
 │ ┌─────────────────────────────────────────────────┐ │
 │ │ [Start Local Preview]  http://localhost:8765   │ │
 │ │ [Generate Standalone HTML...]                   │ │
 │ │ [Open Sync Folder]                              │ │
 │ └─────────────────────────────────────────────────┘ │
 │                                                     │
 │ Privacy                                             │
 │ ┌─────────────────────────────────────────────────┐ │
 │ │ ☑ Filter secrets before syncing                 │ │
 │ │   (Removes API keys, tokens, etc.)              │ │
 │ └─────────────────────────────────────────────────┘ │
 │                                                     │
 └─────────────────────────────────────────────────────┘

 ---
 Example Publish Hook Scripts

 1. GitHub Pages

 #!/bin/bash
 # Publish to GitHub Pages

 REPO_PATH=~/code/my-notes-site
 event=$(cat)
 event_type=$(echo "$event" | jq -r '.type')

 case "$event_type" in
   "sync_all")
     sync_folder=$(echo "$event" | jq -r '.sync_folder')
     cp -r "$sync_folder/notes" "$REPO_PATH/notes/"
     cp -r "$sync_folder/images" "$REPO_PATH/images/"
     cd "$REPO_PATH" && git add -A && git commit -m "Update notes" && git push
     ;;
 esac

 2. S3/Cloudflare R2

 #!/bin/bash
 # Publish to S3-compatible storage

 BUCKET="my-notes-bucket"
 event=$(cat)
 event_type=$(echo "$event" | jq -r '.type')

 case "$event_type" in
   "note_updated")
     note_path=$(echo "$event" | jq -r '.note_path')
     note_id=$(echo "$event" | jq -r '.note_id')
     aws s3 cp "$note_path" "s3://$BUCKET/notes/$note_id.json"
     ;;
   "image_uploaded")
     local_path=$(echo "$event" | jq -r '.local_path')
     hash=$(echo "$event" | jq -r '.hash')
     aws s3 cp "$local_path" "s3://$BUCKET/images/$hash"
     echo "https://cdn.example.com/images/$hash"  # Return public URL
     ;;
 esac

 3. rsync to VPS

 #!/bin/bash
 # Sync to VPS via rsync

 REMOTE="user@myserver.com:/var/www/notes"
 event=$(cat)

 if [ "$(echo "$event" | jq -r '.type')" = "sync_all" ]; then
   sync_folder=$(echo "$event" | jq -r '.sync_folder')
   rsync -avz "$sync_folder/" "$REMOTE/"
 fi

 ---
 Migration from Anthropic Version

 Migration Script

 // Included in the app as a one-time migration
 func migrateFromAnthropicVersion() {
     // 1. Notes are already in the same local format - no change needed

     // 2. Download images from S3 to local storage
     // (User runs: ff cp s3://anthropic-serve/<user>/floating-notes/images/ ~/FloatingNotes/images/)

     // 3. Update image URLs in notes
     for note in notes {
         note.content = note.content.replacingOccurrences(
             of: "https://s3-frontend.infra.ant.dev/anthropic-serve/.*/floating-notes/images/",
             with: "images/",
             options: .regularExpression
         )
         saveNote(note)
     }

     // 4. Clear Anthropic-specific config
     config.ffPath = nil
     config.s3Bucket = nil
 }

 ---
 Files to Remove/Modify

 Remove

 - CloudSync class (replaced by SyncProvider protocol)
 - oxyEnv environment configuration
 - ff command execution
 - S3-specific URL handling
 - go/ link generation

 Modify

 - LinkPasteTextView.handleImagePaste() - Use local storage + hook
 - SyncStatusView - Simplify for folder sync
 - Settings/preferences - Add sync folder selection
 - Image URL handling throughout

 Keep As-Is

 - Note model and persistence
 - UI components
 - Keyboard shortcuts
 - Template system
 - Emoji completion
 - Secret filtering
 - Most of the HTML viewer (just remove go-link specific code)

 ---
 Implementation Plan

 1. Phase 1: Extract and Clean
   - Copy FloatingNotes.swift to new project
   - Remove CloudSync class and ff-related code
   - Remove oxyEnv and Anthropic environment setup
   - Verify app runs in local-only mode
 2. Phase 2: Folder Sync
   - Implement SyncProvider protocol
   - Implement FolderSyncProvider
   - Add settings UI for sync folder selection
   - Handle image copying to sync folder
 3. Phase 3: Publish Hooks
   - Implement PublishHook class
   - Define hook event types and JSON schema
   - Add hook script configuration in settings
   - Test with sample hook scripts
 4. Phase 4: Web Viewer
   - Bundle HTML template in app
   - Remove go/ link generation
   - Add standalone viewer generation option
   - Support custom base URL for links
 5. Phase 5: Polish
   - Migration assistant for Anthropic users
   - Documentation and example hooks
   - Notarization for distribution

 ---
 Design Decisions Summary
 ┌──────────────────────────┬───────────────────────────────────────────────────────────────────────┐
 │         Decision         │                                Choice                                 │
 ├──────────────────────────┼───────────────────────────────────────────────────────────────────────┤
 │ Sync folder              │ Auto-detect iCloud/Dropbox, prompt on first launch                    │
 ├──────────────────────────┼───────────────────────────────────────────────────────────────────────┤
 │ Image handling           │ Local storage + relative paths (simpler, publish hook rewrites later) │
 ├──────────────────────────┼───────────────────────────────────────────────────────────────────────┤
 │ Web preview              │ Built-in HTTP server on localhost:8765                                │
 ├──────────────────────────┼───────────────────────────────────────────────────────────────────────┤
 │ Image URLs in editor     │ file:// paths for local editing                                       │
 ├──────────────────────────┼───────────────────────────────────────────────────────────────────────┤
 │ Image URLs in web viewer │ Relative paths, rewritten by publish hook if needed                   │
 └──────────────────────────┴───────────────────────────────────────────────────────────────────────┘
