import SwiftUI

/// Command palette for quick actions (Cmd+K)
struct CommandPaletteWindow: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var noteStore: NoteStore

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Type a command...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit {
                        executeSelectedCommand()
                    }
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            // Command list
            ScrollViewReader { proxy in
                List(selection: Binding(
                    get: { filteredCommands.indices.contains(selectedIndex) ? filteredCommands[selectedIndex].id : nil },
                    set: { newValue in
                        if let index = filteredCommands.firstIndex(where: { $0.id == newValue }) {
                            selectedIndex = index
                        }
                    }
                )) {
                    ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                        CommandRow(command: command, isSelected: index == selectedIndex)
                            .id(command.id)
                            .onTapGesture {
                                selectedIndex = index
                                executeSelectedCommand()
                            }
                    }
                }
                .listStyle(.plain)
                .onChange(of: selectedIndex) { _, newValue in
                    if filteredCommands.indices.contains(newValue) {
                        withAnimation {
                            proxy.scrollTo(filteredCommands[newValue].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            isFocused = true
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredCommands.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }

    private var filteredCommands: [Command] {
        let allCommands = Command.allCommands(noteStore: noteStore)

        if searchText.isEmpty {
            return allCommands
        }

        let searchLower = searchText.lowercased()
        return allCommands.filter {
            $0.name.lowercased().contains(searchLower) ||
            $0.keywords.contains { $0.lowercased().contains(searchLower) }
        }
    }

    private func executeSelectedCommand() {
        guard filteredCommands.indices.contains(selectedIndex) else { return }
        let command = filteredCommands[selectedIndex]
        command.action()
        isPresented = false
    }
}

/// Single command row
struct CommandRow: View {
    let command: Command
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: command.icon)
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.name)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .primary)

                if let shortcut = command.shortcut {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                }
            }

            Spacer()

            if let category = command.category {
                Text(category)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
    }
}

/// Command definition
struct Command: Identifiable {
    let id: String
    let name: String
    let icon: String
    let shortcut: String?
    let category: String?
    let keywords: [String]
    let action: () -> Void

    init(
        id: String = UUID().uuidString,
        name: String,
        icon: String,
        shortcut: String? = nil,
        category: String? = nil,
        keywords: [String] = [],
        action: @escaping () -> Void
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.shortcut = shortcut
        self.category = category
        self.keywords = keywords
        self.action = action
    }

    static func allCommands(noteStore: NoteStore) -> [Command] {
        var commands: [Command] = []

        // Note commands
        commands.append(Command(
            id: "new-note",
            name: "New Note",
            icon: "square.and.pencil",
            shortcut: "⌘N",
            category: "Notes",
            keywords: ["create", "add"],
            action: {
                Task { @MainActor in
                    _ = noteStore.createNote()
                }
            }
        ))

        commands.append(Command(
            id: "delete-note",
            name: "Delete Note",
            icon: "trash",
            shortcut: "⌘⌫",
            category: "Notes",
            keywords: ["remove"],
            action: {
                if let noteId = noteStore.selectedNoteId {
                    Task {
                        await noteStore.deleteNote(noteId)
                    }
                }
            }
        ))

        commands.append(Command(
            id: "pin-note",
            name: "Toggle Pin",
            icon: "pin",
            shortcut: "⇧⌘P",
            category: "Notes",
            keywords: ["unpin", "favorite"],
            action: {
                if let noteId = noteStore.selectedNoteId {
                    Task {
                        await noteStore.togglePinned(noteId)
                    }
                }
            }
        ))

        commands.append(Command(
            id: "archive-note",
            name: "Toggle Archive",
            icon: "archivebox",
            shortcut: "⇧⌘E",
            category: "Notes",
            keywords: ["unarchive", "hide"],
            action: {
                if let noteId = noteStore.selectedNoteId {
                    Task {
                        await noteStore.toggleArchived(noteId)
                    }
                }
            }
        ))

        // Sync commands
        commands.append(Command(
            id: "sync-all",
            name: "Sync All Notes",
            icon: "arrow.triangle.2.circlepath",
            shortcut: "⌥⌘S",
            category: "Sync",
            keywords: ["upload", "cloud"],
            action: {
                Task {
                    await noteStore.syncAll()
                }
            }
        ))

        // Web viewer commands
        commands.append(Command(
            id: "start-preview",
            name: "Start Local Preview",
            icon: "globe",
            category: "Web Viewer",
            keywords: ["server", "browser"],
            action: {
                LocalPreviewServer.shared.start()
                if let url = LocalPreviewServer.shared.url {
                    NSWorkspace.shared.open(url)
                }
            }
        ))

        commands.append(Command(
            id: "stop-preview",
            name: "Stop Local Preview",
            icon: "xmark.circle",
            category: "Web Viewer",
            keywords: ["server", "stop"],
            action: {
                LocalPreviewServer.shared.stop()
            }
        ))

        // Recent notes
        for note in noteStore.recentNotes.prefix(5) {
            commands.append(Command(
                id: "recent-\(note.id)",
                name: note.displayName,
                icon: "doc.text",
                category: "Recent",
                keywords: ["open", "switch"],
                action: {
                    noteStore.selectedNoteId = note.id
                }
            ))
        }

        return commands
    }
}

#Preview {
    CommandPaletteWindow(isPresented: .constant(true))
        .environmentObject(NoteStore.shared)
}
