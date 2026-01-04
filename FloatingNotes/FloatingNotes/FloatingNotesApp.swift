import SwiftUI

@main
struct FloatingNotesApp: App {
    @StateObject private var noteStore = NoteStore.shared
    @StateObject private var configManager = ConfigurationManager.shared
    @State private var showingWelcome = false
    @State private var showingSettings = false
    @State private var showingCommandPalette = false
    @State private var showingTemplatePicker = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !configManager.config.hasCompletedOnboarding {
                    WelcomeView(onComplete: {
                        configManager.completeOnboarding()
                    })
                } else {
                    ContentView()
                        .environmentObject(noteStore)
                        .environmentObject(configManager)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(configManager)
                    .environmentObject(noteStore)
            }
            .sheet(isPresented: $showingCommandPalette) {
                CommandPaletteWindow(isPresented: $showingCommandPalette)
                    .environmentObject(noteStore)
            }
            .sheet(isPresented: $showingTemplatePicker) {
                TemplatePickerWindow(isPresented: $showingTemplatePicker)
                    .environmentObject(noteStore)
            }
        }
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    Task { @MainActor in
                        _ = noteStore.createNote()
                    }
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Note from Template...") {
                    showingTemplatePicker = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Delete Note") {
                    if let noteId = noteStore.selectedNoteId {
                        Task {
                            await noteStore.deleteNote(noteId)
                        }
                    }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(noteStore.selectedNoteId == nil)
            }

            // Edit menu additions
            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Command Palette...") {
                    showingCommandPalette = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            // View menu
            CommandGroup(replacing: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(
                        #selector(NSSplitViewController.toggleSidebar(_:)),
                        with: nil
                    )
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }

            // Note menu
            CommandMenu("Note") {
                Button("Pin/Unpin Note") {
                    if let noteId = noteStore.selectedNoteId {
                        Task {
                            await noteStore.togglePinned(noteId)
                        }
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(noteStore.selectedNoteId == nil)

                Button("Archive/Unarchive Note") {
                    if let noteId = noteStore.selectedNoteId {
                        Task {
                            await noteStore.toggleArchived(noteId)
                        }
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(noteStore.selectedNoteId == nil)

                Divider()

                Menu("Set Color") {
                    ForEach(NoteColor.allCases, id: \.self) { color in
                        Button(color.displayName) {
                            if let noteId = noteStore.selectedNoteId {
                                Task {
                                    await noteStore.setNoteColor(noteId, color: color == .none ? nil : color.rawValue)
                                }
                            }
                        }
                    }
                }
                .disabled(noteStore.selectedNoteId == nil)

                Divider()

                Button("Sync All Notes") {
                    Task {
                        await noteStore.syncAll()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }

            // Web Viewer menu
            CommandMenu("Web Viewer") {
                Button("Start Local Preview") {
                    LocalPreviewServer.shared.start()
                    if let url = LocalPreviewServer.shared.url {
                        NSWorkspace.shared.open(url)
                    }
                }
                .disabled(LocalPreviewServer.shared.isRunning)

                Button("Stop Local Preview") {
                    LocalPreviewServer.shared.stop()
                }
                .disabled(!LocalPreviewServer.shared.isRunning)

                Divider()

                Button("Generate Standalone HTML...") {
                    generateStandaloneViewer()
                }

                Button("Open Sync Folder in Finder") {
                    if let folderPath = configManager.config.sync.folderPath {
                        NSWorkspace.shared.open(URL(fileURLWithPath: folderPath))
                    }
                }
                .disabled(configManager.config.sync.folderPath == nil)
            }

            // Settings
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    showingSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(configManager)
                .environmentObject(noteStore)
        }
        #endif
    }

    private func generateStandaloneViewer() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.html]
        savePanel.nameFieldStringValue = "floating-notes-viewer.html"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                Task {
                    do {
                        try await WebViewerGenerator.shared.generateStandaloneViewer(
                            notes: noteStore.notes.filter { !$0.archived },
                            to: url
                        )
                    } catch {
                        print("Failed to generate viewer: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - NoteColor SwiftUI Extension

extension NoteColor {
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
}
