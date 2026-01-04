import SwiftUI
import Combine

/// Markdown editor view with auto-save
struct EditorView: View {
    let note: Note
    @EnvironmentObject var noteStore: NoteStore

    @State private var content: String = ""
    @State private var showingEmojiCompletion = false
    @State private var emojiSearchText = ""
    @State private var cursorPosition: Int = 0

    @FocusState private var isFocused: Bool

    private let saveDebouncer = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack(spacing: 0) {
            // Header with note info
            EditorHeader(note: note)

            Divider()

            // Editor
            ZStack(alignment: .topLeading) {
                MarkdownTextView(
                    text: $content,
                    onEmojiTrigger: { searchText, position in
                        emojiSearchText = searchText
                        cursorPosition = position
                        showingEmojiCompletion = true
                    },
                    onImagePaste: handleImagePaste
                )
                .focused($isFocused)
                .padding()

                // Emoji completion popup
                if showingEmojiCompletion {
                    EmojiCompletionPopup(
                        searchText: $emojiSearchText,
                        isPresented: $showingEmojiCompletion,
                        onSelect: { emoji in
                            insertEmoji(emoji)
                        }
                    )
                    .offset(x: 16, y: 48)
                }
            }
        }
        .onAppear {
            content = note.content
            setupAutoSave()
            isFocused = true
        }
        .onChange(of: note.id) { _, _ in
            content = note.content
        }
        .onChange(of: content) { _, newValue in
            saveDebouncer.send(newValue)
        }
    }

    private func setupAutoSave() {
        saveDebouncer
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { newContent in
                saveNote(content: newContent)
            }
            .store(in: &cancellables)
    }

    private func saveNote(content: String) {
        guard var updatedNote = noteStore.notes.first(where: { $0.id == note.id }) else { return }

        if updatedNote.content != content {
            updatedNote.updateContent(content)
            Task {
                await noteStore.saveNote(updatedNote)
            }
        }
    }

    private func insertEmoji(_ emoji: String) {
        // Replace the emoji shortcode with the emoji
        let shortcodePattern = ":[a-zA-Z0-9_+-]+$"
        if let regex = try? NSRegularExpression(pattern: shortcodePattern),
           let range = regex.rangeOfFirstMatch(in: content, range: NSRange(content.startIndex..., in: content)).toRange(in: content) {
            content.replaceSubrange(range, with: emoji)
        }
        showingEmojiCompletion = false
    }

    private func handleImagePaste() {
        guard let (_, imageURL) = ImageHandler.shared.imageFromPasteboard() else { return }

        let markdown = ImageHandler.shared.markdownForImage(url: imageURL)
        content += "\n\(markdown)\n"

        // Sync image if sync is enabled
        if let provider = noteStore.syncProvider as? FolderSyncProvider {
            Task {
                let hash = imageURL.deletingPathExtension().lastPathComponent
                _ = try? await provider.syncImage(imageURL, hash: hash)
            }
        }
    }
}

/// Editor header with note metadata
struct EditorHeader: View {
    let note: Note
    @EnvironmentObject var noteStore: NoteStore

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.displayName)
                    .font(.headline)

                HStack(spacing: 8) {
                    if let section = note.section {
                        Label(section, systemImage: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Modified \(formattedDate(note.updated_at))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        await noteStore.togglePinned(note.id)
                    }
                }) {
                    Image(systemName: note.pinned ? "pin.fill" : "pin")
                        .foregroundColor(note.pinned ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(note.pinned ? "Unpin" : "Pin")

                Button(action: {
                    Task {
                        await noteStore.toggleArchived(note.id)
                    }
                }) {
                    Image(systemName: note.archived ? "tray.and.arrow.up" : "archivebox")
                        .foregroundColor(note.archived ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(note.archived ? "Unarchive" : "Archive")

                Menu {
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
                } label: {
                    Image(systemName: "paintpalette")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .help("Set Color")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Helper extension for NSRange conversion
extension NSRange {
    func toRange(in string: String) -> Range<String.Index>? {
        guard let start = string.index(string.startIndex, offsetBy: location, limitedBy: string.endIndex),
              let end = string.index(start, offsetBy: length, limitedBy: string.endIndex) else {
            return nil
        }
        return start..<end
    }
}

#Preview {
    EditorView(note: Note(content: "# Hello World\n\nThis is a test note."))
        .environmentObject(NoteStore.shared)
}
