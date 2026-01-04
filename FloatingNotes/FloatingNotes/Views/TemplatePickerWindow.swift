import SwiftUI

/// Template picker window for creating notes from templates
struct TemplatePickerWindow: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var noteStore: NoteStore

    @State private var searchText: String = ""
    @State private var selectedTemplateId: String?
    @State private var showingTemplateEditor = false
    @State private var editingTemplate: Template?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose a Template")
                    .font(.headline)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search templates...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Template list
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                    // Blank note
                    TemplateCard(
                        name: "Blank Note",
                        preview: "Start with an empty note",
                        icon: "doc",
                        isSelected: selectedTemplateId == nil
                    )
                    .onTapGesture {
                        selectedTemplateId = nil
                    }
                    .onTapGesture(count: 2) {
                        createNote(from: nil)
                    }

                    // Templates
                    ForEach(filteredTemplates) { template in
                        TemplateCard(
                            name: template.name,
                            preview: templatePreview(template),
                            icon: "doc.text",
                            isSelected: selectedTemplateId == template.id
                        )
                        .onTapGesture {
                            selectedTemplateId = template.id
                        }
                        .onTapGesture(count: 2) {
                            createNote(from: template)
                        }
                        .contextMenu {
                            Button("Edit Template") {
                                editingTemplate = template
                                showingTemplateEditor = true
                            }

                            if !Template.builtIn.contains(where: { $0.id == template.id }) {
                                Divider()
                                Button("Delete Template", role: .destructive) {
                                    noteStore.deleteTemplate(template.id)
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button(action: {
                    editingTemplate = Template(name: "New Template")
                    showingTemplateEditor = true
                }) {
                    Label("New Template", systemImage: "plus")
                }

                Spacer()

                Button("Create Note") {
                    if let templateId = selectedTemplateId,
                       let template = noteStore.templates.first(where: { $0.id == templateId }) {
                        createNote(from: template)
                    } else {
                        createNote(from: nil)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showingTemplateEditor) {
            if let template = editingTemplate {
                TemplateEditorView(template: template, isPresented: $showingTemplateEditor)
                    .environmentObject(noteStore)
            }
        }
    }

    private var filteredTemplates: [Template] {
        if searchText.isEmpty {
            return noteStore.templates
        }

        let searchLower = searchText.lowercased()
        return noteStore.templates.filter {
            $0.name.lowercased().contains(searchLower) ||
            $0.content.lowercased().contains(searchLower)
        }
    }

    private func templatePreview(_ template: Template) -> String {
        let lines = template.content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " ")

        if lines.count > 100 {
            return String(lines.prefix(100)) + "..."
        }
        return lines
    }

    private func createNote(from template: Template?) {
        _ = noteStore.createNote(from: template)
        isPresented = false
    }
}

/// Template card in the picker grid
struct TemplateCard: View {
    let name: String
    let preview: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)

                Text(name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()
            }

            Text(preview)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .lineLimit(3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Template editor view
struct TemplateEditorView: View {
    @State var template: Template
    @Binding var isPresented: Bool
    @EnvironmentObject var noteStore: NoteStore

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(template.id.isEmpty ? "New Template" : "Edit Template")
                    .font(.headline)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Name field
            HStack {
                Text("Name:")
                    .frame(width: 60, alignment: .trailing)

                TextField("Template name", text: $template.name)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            .padding(.top)

            // Content editor
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Content:")

                    Spacer()

                    // Variable help
                    Menu("Insert Variable") {
                        ForEach(Template.Variable.allCases, id: \.rawValue) { variable in
                            Button(action: {
                                template.content += variable.rawValue
                            }) {
                                VStack(alignment: .leading) {
                                    Text(variable.rawValue)
                                    Text(variable.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                TextEditor(text: $template.content)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(Color.gray.opacity(0.3))
            }
            .padding()

            // Variables reference
            DisclosureGroup("Available Variables") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Template.Variable.allCases, id: \.rawValue) { variable in
                        HStack {
                            Text(variable.rawValue)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.accentColor)

                            Text("- \(variable.description)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Save") {
                    saveTemplate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(template.name.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
    }

    private func saveTemplate() {
        var updatedTemplate = template
        updatedTemplate.updated_at = Date()
        noteStore.saveTemplate(updatedTemplate)
        isPresented = false
    }
}

#Preview {
    TemplatePickerWindow(isPresented: .constant(true))
        .environmentObject(NoteStore.shared)
}
