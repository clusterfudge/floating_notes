import SwiftUI

/// Main split-pane layout view
struct ContentView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var configManager: ConfigurationManager

    @State private var searchText: String = ""
    @State private var showArchived: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                searchText: $searchText,
                showArchived: $showArchived
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            if let selectedId = noteStore.selectedNoteId,
               let note = noteStore.notes.first(where: { $0.id == selectedId }) {
                EditorView(note: note)
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    Task { @MainActor in
                        _ = noteStore.createNote()
                    }
                }) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New Note (⌘N)")
            }

            ToolbarItemGroup(placement: .status) {
                SyncStatusBadge(status: noteStore.syncStatus)
            }
        }
        .onAppear {
            // Restore selected note
            if let savedId = configManager.config.selectedNoteId,
               noteStore.notes.contains(where: { $0.id == savedId }) {
                noteStore.selectedNoteId = savedId
            } else if noteStore.selectedNoteId == nil, let first = noteStore.notes.first {
                noteStore.selectedNoteId = first.id
            }

            // Configure sync provider
            setupSyncProvider()
        }
        .onChange(of: noteStore.selectedNoteId) { _, newValue in
            configManager.setSelectedNote(newValue)
        }
    }

    private func setupSyncProvider() {
        let syncConfig = configManager.config.sync

        switch syncConfig.provider {
        case .none:
            noteStore.configureSyncProvider(LocalOnlySyncProvider())

        case .folder:
            if let folderPath = syncConfig.folderPath {
                let publishHook = PublishHookFactory.create(from: syncConfig)
                let provider = FolderSyncProvider(
                    syncFolderURL: URL(fileURLWithPath: folderPath),
                    publishHook: publishHook
                )
                noteStore.configureSyncProvider(provider)
            } else {
                noteStore.configureSyncProvider(LocalOnlySyncProvider())
            }
        }
    }
}

/// Empty state when no note is selected
struct EmptyStateView: View {
    @EnvironmentObject var noteStore: NoteStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Note Selected")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Select a note from the sidebar or create a new one")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: {
                Task { @MainActor in
                    _ = noteStore.createNote()
                }
            }) {
                Label("New Note", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Sync status indicator badge
struct SyncStatusBadge: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(status.displayText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .synced: return .green
        case .syncing: return .blue
        case .error: return .red
        case .disabled: return .gray
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore.shared)
        .environmentObject(ConfigurationManager.shared)
}
