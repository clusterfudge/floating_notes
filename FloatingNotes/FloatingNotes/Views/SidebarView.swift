import SwiftUI

/// Sidebar view showing note list grouped by sections
struct SidebarView: View {
    @EnvironmentObject var noteStore: NoteStore
    @Binding var searchText: String
    @Binding var showArchived: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $searchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // Note list
            List(selection: $noteStore.selectedNoteId) {
                ForEach(groupedNotes, id: \.section) { group in
                    Section(header: SectionHeader(title: group.section, count: group.notes.count)) {
                        ForEach(group.notes) { note in
                            NoteRow(note: note)
                                .tag(note.id)
                                .contextMenu {
                                    NoteContextMenu(note: note)
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Footer with archive toggle
            SidebarFooter(showArchived: $showArchived, noteCount: noteStore.notes.count)
        }
        .onChange(of: searchText) { _, newValue in
            noteStore.searchText = newValue
        }
    }

    private var groupedNotes: [(section: String, notes: [Note])] {
        noteStore.groupedNotes(showArchived: showArchived)
    }
}

/// Search bar component
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search notes...", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}

/// Section header with note count
struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()

            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
    }
}

/// Single note row in the sidebar
struct NoteRow: View {
    let note: Note
    @EnvironmentObject var noteStore: NoteStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Color indicator
                if let colorName = note.color,
                   let color = NoteColor(rawValue: colorName) {
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 8, height: 8)
                }

                // Title
                Text(note.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                // Pinned indicator
                if note.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                // Archived indicator
                if note.archived {
                    Image(systemName: "archivebox.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Preview
            Text(note.preview)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // Date
            Text(formattedDate(note.updated_at))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Context menu for notes
struct NoteContextMenu: View {
    let note: Note
    @EnvironmentObject var noteStore: NoteStore

    var body: some View {
        Button(action: {
            Task {
                await noteStore.togglePinned(note.id)
            }
        }) {
            Label(note.pinned ? "Unpin" : "Pin", systemImage: note.pinned ? "pin.slash" : "pin")
        }

        Button(action: {
            Task {
                await noteStore.toggleArchived(note.id)
            }
        }) {
            Label(note.archived ? "Unarchive" : "Archive", systemImage: note.archived ? "tray.and.arrow.up" : "archivebox")
        }

        Divider()

        Menu("Set Color") {
            ForEach(NoteColor.allCases, id: \.self) { color in
                Button(action: {
                    Task {
                        await noteStore.setNoteColor(note.id, color: color == .none ? nil : color.rawValue)
                    }
                }) {
                    HStack {
                        if color != .none {
                            Circle()
                                .fill(color.swiftUIColor)
                                .frame(width: 12, height: 12)
                        }
                        Text(color.displayName)
                    }
                }
            }
        }

        Divider()

        Button(role: .destructive, action: {
            Task {
                await noteStore.deleteNote(note.id)
            }
        }) {
            Label("Delete", systemImage: "trash")
        }
    }
}

/// Sidebar footer with stats and toggle
struct SidebarFooter: View {
    @Binding var showArchived: Bool
    let noteCount: Int

    var body: some View {
        HStack {
            Text("\(noteCount) notes")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Toggle("Show Archived", isOn: $showArchived)
                .toggleStyle(.checkbox)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    SidebarView(searchText: .constant(""), showArchived: .constant(false))
        .environmentObject(NoteStore.shared)
        .frame(width: 300)
}
