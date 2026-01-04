import Foundation

/// Generates web viewer HTML for notes
class WebViewerGenerator {
    static let shared = WebViewerGenerator()

    private let encoder: JSONEncoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
    }

    /// Generate the viewer HTML with dynamic data loading
    func generateViewerHTML() -> String {
        return viewerTemplate
    }

    /// Generate a standalone HTML file with embedded notes
    func generateStandaloneViewer(notes: [Note], to outputPath: URL) async throws {
        var html = standaloneTemplate

        // Encode notes as JSON
        let notesJSON = try encoder.encode(notes)
        let notesJSONString = String(data: notesJSON, encoding: .utf8) ?? "[]"

        // Embed notes data
        html = html.replacingOccurrences(
            of: "/* NOTES_DATA_PLACEHOLDER */",
            with: "const NOTES_DATA = \(notesJSONString);"
        )

        try html.write(to: outputPath, atomically: true, encoding: .utf8)
    }

    /// Generate index.json for the web viewer
    func generateIndex(notes: [Note], to folder: URL) throws {
        let entries = notes.map { NoteIndexEntry(from: $0) }
        let data = try encoder.encode(entries)
        let indexURL = folder.appendingPathComponent("index.json")
        try data.write(to: indexURL, options: .atomic)
    }

    // MARK: - Templates

    private var viewerTemplate: String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Floating Notes</title>
            <style>
                \(viewerStyles)
            </style>
        </head>
        <body>
            <div class="app">
                <aside class="sidebar">
                    <div class="sidebar-header">
                        <h1>Floating Notes</h1>
                        <input type="search" id="search" placeholder="Search notes...">
                    </div>
                    <nav id="note-list" class="note-list"></nav>
                </aside>
                <main class="content">
                    <article id="note-content" class="note-content">
                        <div class="empty-state">
                            <p>Select a note from the sidebar</p>
                        </div>
                    </article>
                </main>
            </div>
            <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
            <script>
                \(viewerScript)
            </script>
        </body>
        </html>
        """
    }

    private var standaloneTemplate: String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Floating Notes</title>
            <style>
                \(viewerStyles)
            </style>
        </head>
        <body>
            <div class="app">
                <aside class="sidebar">
                    <div class="sidebar-header">
                        <h1>Floating Notes</h1>
                        <input type="search" id="search" placeholder="Search notes...">
                    </div>
                    <nav id="note-list" class="note-list"></nav>
                </aside>
                <main class="content">
                    <article id="note-content" class="note-content">
                        <div class="empty-state">
                            <p>Select a note from the sidebar</p>
                        </div>
                    </article>
                </main>
            </div>
            <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
            <script>
                /* NOTES_DATA_PLACEHOLDER */
                \(standaloneScript)
            </script>
        </body>
        </html>
        """
    }

    private var viewerStyles: String {
        """
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        :root {
            --sidebar-width: 280px;
            --bg-primary: #ffffff;
            --bg-secondary: #f5f5f7;
            --text-primary: #1d1d1f;
            --text-secondary: #6e6e73;
            --border-color: #d2d2d7;
            --accent-color: #007aff;
            --hover-color: #f0f0f5;
        }

        @media (prefers-color-scheme: dark) {
            :root {
                --bg-primary: #1d1d1f;
                --bg-secondary: #2d2d2f;
                --text-primary: #f5f5f7;
                --text-secondary: #a1a1a6;
                --border-color: #424245;
                --hover-color: #3d3d3f;
            }
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.5;
        }

        .app {
            display: flex;
            height: 100vh;
        }

        .sidebar {
            width: var(--sidebar-width);
            background: var(--bg-secondary);
            border-right: 1px solid var(--border-color);
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }

        .sidebar-header {
            padding: 16px;
            border-bottom: 1px solid var(--border-color);
        }

        .sidebar-header h1 {
            font-size: 1.25rem;
            font-weight: 600;
            margin-bottom: 12px;
        }

        .sidebar-header input {
            width: 100%;
            padding: 8px 12px;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            background: var(--bg-primary);
            color: var(--text-primary);
            font-size: 14px;
        }

        .note-list {
            flex: 1;
            overflow-y: auto;
            padding: 8px;
        }

        .note-item {
            padding: 12px;
            border-radius: 8px;
            cursor: pointer;
            margin-bottom: 4px;
            transition: background 0.15s;
        }

        .note-item:hover {
            background: var(--hover-color);
        }

        .note-item.active {
            background: var(--accent-color);
            color: white;
        }

        .note-item-title {
            font-weight: 500;
            margin-bottom: 4px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .note-item-preview {
            font-size: 13px;
            color: var(--text-secondary);
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            overflow: hidden;
        }

        .note-item.active .note-item-preview {
            color: rgba(255, 255, 255, 0.8);
        }

        .note-item-date {
            font-size: 12px;
            color: var(--text-secondary);
            margin-top: 4px;
        }

        .note-item.active .note-item-date {
            color: rgba(255, 255, 255, 0.7);
        }

        .content {
            flex: 1;
            overflow-y: auto;
            padding: 32px;
        }

        .note-content {
            max-width: 800px;
            margin: 0 auto;
        }

        .empty-state {
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100%;
            color: var(--text-secondary);
        }

        /* Markdown styles */
        .note-content h1 { font-size: 2rem; margin: 1.5rem 0 1rem; }
        .note-content h2 { font-size: 1.5rem; margin: 1.25rem 0 0.75rem; }
        .note-content h3 { font-size: 1.25rem; margin: 1rem 0 0.5rem; }
        .note-content p { margin: 0.75rem 0; }
        .note-content ul, .note-content ol { margin: 0.75rem 0; padding-left: 1.5rem; }
        .note-content li { margin: 0.25rem 0; }
        .note-content code {
            background: var(--bg-secondary);
            padding: 0.2em 0.4em;
            border-radius: 4px;
            font-size: 0.9em;
        }
        .note-content pre {
            background: var(--bg-secondary);
            padding: 16px;
            border-radius: 8px;
            overflow-x: auto;
            margin: 1rem 0;
        }
        .note-content pre code {
            background: none;
            padding: 0;
        }
        .note-content blockquote {
            border-left: 4px solid var(--accent-color);
            padding-left: 16px;
            margin: 1rem 0;
            color: var(--text-secondary);
        }
        .note-content a {
            color: var(--accent-color);
            text-decoration: none;
        }
        .note-content a:hover {
            text-decoration: underline;
        }
        .note-content img {
            max-width: 100%;
            border-radius: 8px;
        }
        .note-content hr {
            border: none;
            border-top: 1px solid var(--border-color);
            margin: 2rem 0;
        }
        .note-content input[type="checkbox"] {
            margin-right: 8px;
        }

        .section-header {
            font-size: 12px;
            font-weight: 600;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            padding: 8px 12px 4px;
        }
        """
    }

    private var viewerScript: String {
        """
        let notes = [];
        let currentNoteId = null;

        async function loadNotes() {
            try {
                const response = await fetch('/notes/');
                if (!response.ok) throw new Error('Failed to load notes');

                // Load index.json
                const indexResponse = await fetch('/index.json');
                if (indexResponse.ok) {
                    notes = await indexResponse.json();
                } else {
                    // Fallback: list notes directory
                    notes = [];
                }

                renderNoteList();
            } catch (error) {
                console.error('Error loading notes:', error);
            }
        }

        function renderNoteList() {
            const list = document.getElementById('note-list');
            const search = document.getElementById('search').value.toLowerCase();

            const filteredNotes = notes.filter(note =>
                note.title.toLowerCase().includes(search) ||
                (note.preview && note.preview.toLowerCase().includes(search))
            );

            // Group by section
            const grouped = {};
            filteredNotes.forEach(note => {
                const section = note.section || 'Notes';
                if (!grouped[section]) grouped[section] = [];
                grouped[section].push(note);
            });

            list.innerHTML = '';

            // Pinned first
            const pinned = filteredNotes.filter(n => n.pinned);
            if (pinned.length > 0) {
                list.innerHTML += '<div class="section-header">Pinned</div>';
                pinned.forEach(note => {
                    list.innerHTML += renderNoteItem(note);
                });
            }

            // Other sections
            Object.keys(grouped).sort().forEach(section => {
                const sectionNotes = grouped[section].filter(n => !n.pinned);
                if (sectionNotes.length > 0) {
                    list.innerHTML += `<div class="section-header">${section}</div>`;
                    sectionNotes.forEach(note => {
                        list.innerHTML += renderNoteItem(note);
                    });
                }
            });

            // Add click handlers
            list.querySelectorAll('.note-item').forEach(item => {
                item.addEventListener('click', () => selectNote(item.dataset.id));
            });
        }

        function renderNoteItem(note) {
            const date = new Date(note.updated_at).toLocaleDateString();
            const active = note.id === currentNoteId ? 'active' : '';
            return `
                <div class="note-item ${active}" data-id="${note.id}">
                    <div class="note-item-title">${escapeHtml(note.title)}</div>
                    <div class="note-item-preview">${escapeHtml(note.preview || '')}</div>
                    <div class="note-item-date">${date}</div>
                </div>
            `;
        }

        async function selectNote(id) {
            currentNoteId = id;
            renderNoteList();

            try {
                const response = await fetch(`/notes/${id}.json`);
                if (!response.ok) throw new Error('Failed to load note');

                const note = await response.json();
                const content = document.getElementById('note-content');

                // Render markdown
                content.innerHTML = marked.parse(note.content || '');
            } catch (error) {
                console.error('Error loading note:', error);
            }
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // Search handler
        document.getElementById('search').addEventListener('input', renderNoteList);

        // Initial load
        loadNotes();
        """
    }

    private var standaloneScript: String {
        """
        let notes = typeof NOTES_DATA !== 'undefined' ? NOTES_DATA : [];
        let currentNoteId = null;

        function renderNoteList() {
            const list = document.getElementById('note-list');
            const search = document.getElementById('search').value.toLowerCase();

            const filteredNotes = notes.filter(note =>
                (note.title || note.displayName || '').toLowerCase().includes(search) ||
                (note.content || '').toLowerCase().includes(search)
            );

            // Group by section
            const grouped = {};
            filteredNotes.forEach(note => {
                const section = note.section || 'Notes';
                if (!grouped[section]) grouped[section] = [];
                grouped[section].push(note);
            });

            list.innerHTML = '';

            // Pinned first
            const pinned = filteredNotes.filter(n => n.pinned);
            if (pinned.length > 0) {
                list.innerHTML += '<div class="section-header">Pinned</div>';
                pinned.forEach(note => {
                    list.innerHTML += renderNoteItem(note);
                });
            }

            // Other sections
            Object.keys(grouped).sort().forEach(section => {
                const sectionNotes = grouped[section].filter(n => !n.pinned);
                if (sectionNotes.length > 0) {
                    list.innerHTML += `<div class="section-header">${section}</div>`;
                    sectionNotes.forEach(note => {
                        list.innerHTML += renderNoteItem(note);
                    });
                }
            });

            // Add click handlers
            list.querySelectorAll('.note-item').forEach(item => {
                item.addEventListener('click', () => selectNote(item.dataset.id));
            });
        }

        function renderNoteItem(note) {
            const title = note.title || note.displayName || getFirstLine(note.content) || 'Untitled';
            const preview = getPreview(note.content);
            const date = note.updated_at ? new Date(note.updated_at).toLocaleDateString() : '';
            const active = note.id === currentNoteId ? 'active' : '';
            return `
                <div class="note-item ${active}" data-id="${note.id}">
                    <div class="note-item-title">${escapeHtml(title)}</div>
                    <div class="note-item-preview">${escapeHtml(preview)}</div>
                    <div class="note-item-date">${date}</div>
                </div>
            `;
        }

        function selectNote(id) {
            currentNoteId = id;
            renderNoteList();

            const note = notes.find(n => n.id === id);
            if (note) {
                const content = document.getElementById('note-content');
                content.innerHTML = marked.parse(note.content || '');
            }
        }

        function getFirstLine(content) {
            if (!content) return '';
            const lines = content.split('\\n').filter(l => l.trim());
            return lines[0]?.replace(/^#+\\s*/, '') || '';
        }

        function getPreview(content) {
            if (!content) return '';
            const lines = content.split('\\n').filter(l => l.trim() && !l.startsWith('#'));
            return lines.slice(0, 2).join(' ').substring(0, 100);
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // Search handler
        document.getElementById('search').addEventListener('input', renderNoteList);

        // Initial render
        renderNoteList();
        if (notes.length > 0) {
            selectNote(notes[0].id);
        }
        """
    }
}
