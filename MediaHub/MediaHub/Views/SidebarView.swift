import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    private let librarySections: [SidebarSection] = [.home, .allMedia, .photos, .videos, .music, .favorites]

    var body: some View {
        let selection = Binding<SidebarSection?>(
            get: { model.section },
            set: { if let s = $0 { model.section = s } }
        )
        List(selection: selection) {
            Section(AppConfig.appName) {
                ForEach(librarySections) { section in
                    row(section)
                }
            }
            Section {
                row(.settings)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            LibraryStatusView()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func row(_ section: SidebarSection) -> some View {
        let count = (section.isLibraryList && model.hasFolders) ? model.count(for: section) : nil
        Label(section.title, systemImage: section.symbolName)
            .badge(count ?? 0)
            .tag(section)
            .accessibilityIdentifier("sidebar.\(section.rawValue)")
    }
}

/// Compact "2 folders · 1,245 items" status at the bottom of the sidebar, plus scan progress.
struct LibraryStatusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let progress = model.scanProgress {
                HStack(spacing: 6) {
                    if let fraction = progress.fraction {
                        ProgressView(value: fraction).controlSize(.small)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    Button("Cancel") { model.cancelScan() }
                        .controlSize(.small)
                        .help("Stop scanning. Anything found so far is kept.")
                }
                Text(progress.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            let attention = model.foldersNeedingAttention
            if !attention.isEmpty {
                Button {
                    model.section = .settings
                } label: {
                    Label("\(attention.count) \(attention.count == 1 ? "folder needs" : "folders need") attention",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("Open Settings to fix folder access")
            }
            Text(model.hasFolders
                 ? "\(model.folders.count) \(model.folders.count == 1 ? "folder" : "folders") · \(model.items.count.formatted()) items"
                 : "No folders yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sidebar.status")
    }
}
