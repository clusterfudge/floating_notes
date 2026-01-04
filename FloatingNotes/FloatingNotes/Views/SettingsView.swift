import SwiftUI

/// Settings view with tabs for different settings categories
struct SettingsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @EnvironmentObject var noteStore: NoteStore

    var body: some View {
        TabView {
            SyncSettingsTab()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }

            PublishingSettingsTab()
                .tabItem {
                    Label("Publishing", systemImage: "globe")
                }

            WebViewerSettingsTab()
                .tabItem {
                    Label("Web Viewer", systemImage: "safari")
                }

            PrivacySettingsTab()
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
        }
        .padding(20)
        .frame(width: 500, height: 400)
    }
}

/// Sync settings tab
struct SyncSettingsTab: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var selectedLocation: CloudLocation?
    @State private var customPath: String = ""
    @State private var showingFolderPicker = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sync Location")
                        .font(.headline)

                    if let folderPath = configManager.config.sync.folderPath {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(shortenPath(folderPath))
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }

                    Picker("Provider", selection: Binding(
                        get: { configManager.config.sync.provider },
                        set: { newValue in
                            var sync = configManager.config.sync
                            sync.provider = newValue
                            configManager.updateSync(sync)
                        }
                    )) {
                        Text("Local Only").tag(SyncProviderType.none)
                        Text("Folder Sync").tag(SyncProviderType.folder)
                    }
                    .pickerStyle(.radioGroup)
                }
            }

            if configManager.config.sync.provider == .folder {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Locations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ForEach(CloudLocationDetector.detectAvailableLocations(), id: \.displayName) { location in
                            Button(action: {
                                selectLocation(location)
                            }) {
                                HStack {
                                    Image(systemName: iconForLocation(location))
                                        .foregroundColor(.blue)
                                        .frame(width: 24)

                                    VStack(alignment: .leading) {
                                        Text(location.displayName)
                                            .foregroundColor(.primary)
                                        Text(CloudLocationDetector.displayPath(for: location))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if configManager.config.sync.folderPath == location.url.path {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        }

                        Button("Choose Custom Folder...") {
                            showingFolderPicker = true
                        }
                    }
                }
            }

            Section {
                HStack {
                    SyncStatusBadge(status: noteStore.syncStatus)

                    Spacer()

                    Button("Sync Now") {
                        Task {
                            await noteStore.syncAll()
                        }
                    }
                    .disabled(configManager.config.sync.provider == .none)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                selectLocation(.custom(url))
            }
        }
    }

    private func selectLocation(_ location: CloudLocation) {
        do {
            try CloudLocationDetector.ensureSyncFolder(at: location)
            var sync = configManager.config.sync
            sync.folderPath = location.url.path
            configManager.updateSync(sync)
        } catch {
            print("Failed to setup sync folder: \(error)")
        }
    }

    private func iconForLocation(_ location: CloudLocation) -> String {
        switch location {
        case .iCloud, .iCloudDocuments: return "icloud"
        case .dropbox: return "shippingbox"
        case .custom: return "folder"
        }
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

/// Publishing settings tab
struct PublishingSettingsTab: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var enablePublishHook = false
    @State private var hookPath: String = ""
    @State private var baseURL: String = ""
    @State private var showingFilePicker = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable Publish Hook", isOn: $enablePublishHook)
                    .onChange(of: enablePublishHook) { _, newValue in
                        if !newValue {
                            var sync = configManager.config.sync
                            sync.publishHookPath = nil
                            configManager.updateSync(sync)
                        }
                    }

                if enablePublishHook {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hook Script")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("Path to script", text: $hookPath)
                                .textFieldStyle(.roundedBorder)

                            Button("Browse...") {
                                showingFilePicker = true
                            }
                        }

                        Text("The script receives JSON events on stdin and should exit with code 0 on success.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base URL")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("https://example.com/notes", text: $baseURL)
                            .textFieldStyle(.roundedBorder)

                        Text("Used for generating shareable links to published notes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Save") {
                        var sync = configManager.config.sync
                        sync.publishHookPath = hookPath.isEmpty ? nil : hookPath
                        sync.publishBaseURL = baseURL.isEmpty ? nil : baseURL
                        configManager.updateSync(sync)
                    }
                }
            }

            Section {
                DisclosureGroup("Example Hook Scripts") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GitHub Pages")
                            .font(.headline)
                        Text("Copy notes to a git repo and push")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("S3/Cloudflare R2")
                            .font(.headline)
                        Text("Upload notes using AWS CLI")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("rsync to VPS")
                            .font(.headline)
                        Text("Sync to a remote server via SSH")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onAppear {
            hookPath = configManager.config.sync.publishHookPath ?? ""
            baseURL = configManager.config.sync.publishBaseURL ?? ""
            enablePublishHook = configManager.config.sync.publishHookPath != nil
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.shellScript, .unixExecutable],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                hookPath = url.path
            }
        }
    }
}

/// Web viewer settings tab
struct WebViewerSettingsTab: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @ObservedObject var previewServer = LocalPreviewServer.shared

    var body: some View {
        Form {
            Section("Local Preview") {
                HStack {
                    if previewServer.isRunning {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Running at")
                        if let url = previewServer.url {
                            Link(url.absoluteString, destination: url)
                        }
                    } else {
                        Circle()
                            .fill(.gray)
                            .frame(width: 8, height: 8)
                        Text("Not running")
                    }

                    Spacer()

                    if previewServer.isRunning {
                        Button("Stop") {
                            previewServer.stop()
                        }
                    } else {
                        Button("Start") {
                            previewServer.start()
                            if let url = previewServer.url {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

            Section("Export") {
                Button("Generate Standalone HTML...") {
                    generateStandaloneViewer()
                }

                Text("Creates a single HTML file with all your notes embedded. Can be viewed offline.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Sync Folder") {
                if let folderPath = configManager.config.sync.folderPath {
                    Button("Open in Finder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: folderPath))
                    }
                } else {
                    Text("No sync folder configured")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func generateStandaloneViewer() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.html]
        savePanel.nameFieldStringValue = "floating-notes-viewer.html"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                Task {
                    do {
                        let notes = await NoteStore.shared.notes.filter { !$0.archived }
                        try await WebViewerGenerator.shared.generateStandaloneViewer(
                            notes: notes,
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

/// Privacy settings tab
struct PrivacySettingsTab: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var filterSecrets = true

    var body: some View {
        Form {
            Section {
                Toggle("Filter secrets before syncing", isOn: $filterSecrets)
                    .onChange(of: filterSecrets) { _, newValue in
                        var sync = configManager.config.sync
                        sync.filterSecrets = newValue
                        configManager.updateSync(sync)
                    }

                Text("Automatically removes API keys, tokens, passwords, and other sensitive data before syncing notes to the cloud or publishing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Detected Patterns") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(["API Keys", "AWS Credentials", "GitHub Tokens", "Private Keys", "Database URLs", "Bearer Tokens"], id: \.self) { pattern in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(pattern)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .onAppear {
            filterSecrets = configManager.config.sync.filterSecrets
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ConfigurationManager.shared)
        .environmentObject(NoteStore.shared)
}
