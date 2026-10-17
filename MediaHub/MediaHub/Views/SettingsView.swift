import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var cacheSize: Int64 = 0

    var body: some View {
        Form {
            Section {
                if model.folders.isEmpty {
                    Text("No folders yet. Add the folders where your photos, videos, and music live.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.folders) { folder in
                        FolderRow(folder: folder)
                    }
                }
                HStack {
                    Button("Add Folder…") { model.addFolders() }
                    Button("Rescan All") { model.rescanAll() }
                        .disabled(!model.hasFolders || model.isScanning)
                }
            } header: {
                Text("Library Folders")
            } footer: {
                Text("Removing a folder from \(AppConfig.appName) only removes it from the library. Your files are never moved or deleted.")
                    .foregroundStyle(.secondary)
            }

            Section("Supported Formats") {
                LabeledContent("Photos", value: MediaType.imageExtensions.sorted().joined(separator: ", "))
                LabeledContent("Videos", value: MediaType.videoExtensions.sorted().joined(separator: ", "))
                LabeledContent("Music", value: MediaType.audioExtensions.sorted().joined(separator: ", "))
                Text("Playback uses macOS's built-in support. Some files with unusual codecs may not play.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Thumbnails") {
                LabeledContent("Cache size", value: Format.bytes(cacheSize))
                Button("Clear Thumbnail Cache") {
                    ThumbnailService.shared.clearCache()
                    cacheSize = 0
                }
                Text("Small preview images are stored in \(AppConfig.appName)'s own cache and rebuilt when needed. Clearing them never affects your files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("Your media stays on your Mac. Nothing is uploaded, and there's no account or tracking.", systemImage: "lock.shield")
                Label("\(AppConfig.appName) only reads the folders you choose and never changes your files.", systemImage: "folder")
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.appVersionString)
            }
        }
        .formStyle(.grouped)
        .task { cacheSize = await Task.detached { ThumbnailService.shared.diskUsageBytes }.value }
    }
}

struct FolderRow: View {
    @Environment(AppModel.self) private var model
    let folder: LibraryFolder
    @State private var confirmRemove = false

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: folder.scanStatus.needsAttention ? "folder.badge.questionmark" : "folder.fill")
                .foregroundStyle(folder.scanStatus.needsAttention ? .orange : Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                Text(folder.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                HStack(spacing: 4) {
                    if folder.scanStatus.needsAttention {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    Text(statusText)
                }
                .font(.caption)
                .foregroundStyle(folder.scanStatus.needsAttention ? .primary : .secondary)
                if let error = folder.lastErrorSummary, folder.scanStatus.needsAttention {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if folder.scanStatus == .needsPermission || folder.scanStatus == .unavailable {
                Button("Grant Access…") { model.regrantAccess(folder) }
                    .help("Choose this folder again so \(AppConfig.appName) can read it")
            }
            Button("Rescan") { model.rescan(folder) }
                .disabled(model.isScanning)
            Button("Remove…", role: .destructive) { confirmRemove = true }
        }
        .confirmationDialog("Remove “\(folder.displayName)” from \(AppConfig.appName)?", isPresented: $confirmRemove) {
            Button("Remove from Library", role: .destructive) { Task { await model.removeFolder(folder) } }
        } message: {
            Text("The folder and its files stay exactly where they are on your Mac. They just won't appear in \(AppConfig.appName) anymore.")
        }
        .accessibilityElement(children: .contain)
    }

    private var statusText: String {
        let count = model.items.filter { $0.folderID == folder.id }.count
        var parts = ["\(count.formatted()) items", folder.scanStatus.userDescription]
        if let date = folder.lastSuccessfulScanAt, folder.scanStatus == .completed {
            parts[1] = "Scanned \(date.formatted(.relative(presentation: .named)))"
        }
        return parts.joined(separator: " · ")
    }
}

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
