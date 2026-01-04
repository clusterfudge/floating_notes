import SwiftUI

/// First-launch welcome view for sync setup
struct WelcomeView: View {
    let onComplete: () -> Void

    @StateObject private var configManager = ConfigurationManager.shared
    @State private var selectedOption: SyncOption = .iCloud
    @State private var customPath: String = ""
    @State private var showingFolderPicker = false
    @State private var availableLocations: [CloudLocation] = []

    enum SyncOption: String, CaseIterable {
        case iCloud
        case dropbox
        case iCloudDocuments
        case custom
        case localOnly

        var title: String {
            switch self {
            case .iCloud: return "iCloud Drive (Recommended)"
            case .dropbox: return "Dropbox"
            case .iCloudDocuments: return "Documents (iCloud synced)"
            case .custom: return "Custom folder..."
            case .localOnly: return "Local only (no sync)"
            }
        }

        var description: String {
            switch self {
            case .iCloud: return "Syncs automatically across all your Apple devices"
            case .dropbox: return "Syncs to Dropbox-connected devices"
            case .iCloudDocuments: return "Your Documents folder is synced to iCloud"
            case .custom: return "Choose any folder (can still be cloud-synced)"
            case .localOnly: return "Notes stay on this Mac only"
            }
        }

        var icon: String {
            switch self {
            case .iCloud, .iCloudDocuments: return "icloud"
            case .dropbox: return "shippingbox"
            case .custom: return "folder"
            case .localOnly: return "desktopcomputer"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)

                Text("Welcome to Floating Notes")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Where would you like to sync your notes?")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)

            // Options
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(visibleOptions, id: \.self) { option in
                        SyncOptionRow(
                            option: option,
                            path: pathForOption(option),
                            isSelected: selectedOption == option
                        )
                        .onTapGesture {
                            if option == .custom {
                                showingFolderPicker = true
                            }
                            selectedOption = option
                        }
                    }
                }
                .padding(.horizontal, 40)
            }

            Spacer()

            // Footer
            HStack {
                Spacer()

                Button("Continue") {
                    saveSelection()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
        }
        .frame(width: 600, height: 550)
        .onAppear {
            availableLocations = CloudLocationDetector.detectAvailableLocations()
            // Pre-select based on available locations
            if availableLocations.contains(where: { if case .iCloud = $0 { return true }; return false }) {
                selectedOption = .iCloud
            } else if availableLocations.contains(where: { if case .dropbox = $0 { return true }; return false }) {
                selectedOption = .dropbox
            } else {
                selectedOption = .localOnly
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                customPath = url.path
                selectedOption = .custom
            }
        }
    }

    private var visibleOptions: [SyncOption] {
        var options: [SyncOption] = []

        // Show available cloud locations
        for location in availableLocations {
            switch location {
            case .iCloud:
                if !options.contains(.iCloud) { options.append(.iCloud) }
            case .dropbox:
                if !options.contains(.dropbox) { options.append(.dropbox) }
            case .iCloudDocuments:
                if !options.contains(.iCloudDocuments) { options.append(.iCloudDocuments) }
            case .custom:
                break
            }
        }

        // Always show custom and local only
        options.append(.custom)
        options.append(.localOnly)

        return options
    }

    private func pathForOption(_ option: SyncOption) -> String? {
        switch option {
        case .iCloud:
            return availableLocations.first { if case .iCloud(let url) = $0 { return true } else { return false } }
                .map { CloudLocationDetector.displayPath(for: $0) }
        case .dropbox:
            return availableLocations.first { if case .dropbox(let url) = $0 { return true } else { return false } }
                .map { CloudLocationDetector.displayPath(for: $0) }
        case .iCloudDocuments:
            return availableLocations.first { if case .iCloudDocuments(let url) = $0 { return true } else { return false } }
                .map { CloudLocationDetector.displayPath(for: $0) }
        case .custom:
            return customPath.isEmpty ? nil : customPath
        case .localOnly:
            return nil
        }
    }

    private func saveSelection() {
        var sync = configManager.config.sync

        switch selectedOption {
        case .iCloud:
            sync.provider = .folder
            sync.folderPath = availableLocations.first { if case .iCloud = $0 { return true }; return false }?.url.path
        case .dropbox:
            sync.provider = .folder
            sync.folderPath = availableLocations.first { if case .dropbox = $0 { return true }; return false }?.url.path
        case .iCloudDocuments:
            sync.provider = .folder
            sync.folderPath = availableLocations.first { if case .iCloudDocuments = $0 { return true }; return false }?.url.path
        case .custom:
            sync.provider = .folder
            sync.folderPath = customPath
        case .localOnly:
            sync.provider = .none
            sync.folderPath = nil
        }

        configManager.updateSync(sync)

        // Create sync folder if needed
        if let path = sync.folderPath {
            try? CloudLocationDetector.ensureSyncFolder(at: .custom(URL(fileURLWithPath: path)))
        }
    }
}

/// Single sync option row
struct SyncOptionRow: View {
    let option: WelcomeView.SyncOption
    let path: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Radio button
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.gray, lineWidth: 2)
                    .frame(width: 20, height: 20)

                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 12, height: 12)
                }
            }

            // Icon
            Image(systemName: option.icon)
                .font(.title2)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .primary : .secondary)

                if let path = path {
                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Text(option.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    WelcomeView(onComplete: {})
}
