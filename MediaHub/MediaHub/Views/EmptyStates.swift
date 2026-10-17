import SwiftUI

/// First-launch screen shown when no folders have been added.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                ForEach([MediaType.image, .video, .audio], id: \.self) { type in
                    Image(systemName: type.symbolName)
                        .font(.system(size: 30, weight: .regular))
                        .frame(width: 64, height: 64)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .foregroundStyle(.tint)
            .accessibilityHidden(true)

            Text("All your media, in one place.")
                .font(.largeTitle.weight(.semibold))

            Text("Choose the folders where your photos, videos, and music live. \(AppConfig.appName) will organize them without moving your files.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            Button {
                model.addFolders()
            } label: {
                Text("Choose Folders…")
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("welcome.chooseFolders")

            Label("Your files stay on your Mac. You control which folders are scanned.", systemImage: "lock")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown inside a library section when there is nothing to display.
struct LibraryEmptyState: View {
    @Environment(AppModel.self) private var model
    let section: SidebarSection

    var body: some View {
        if model.isSearching {
            ContentUnavailableView {
                Label("No media found for “\(LibraryQuery.normalized(model.searchText))”", systemImage: "magnifyingglass")
            } description: {
                Text(section == .allMedia
                     ? "Try a shorter part of the filename, or add another folder."
                     : "Nothing in \(section.title) matches. Try All Media, a shorter filename, or add another folder.")
            } actions: {
                Button("Clear Search") { model.searchText = "" }
            }
        } else if !model.hasFolders {
            WelcomeView()
        } else {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: section.symbolName)
            } description: {
                Text(emptyMessage)
            } actions: {
                if section != .favorites {
                    Button("Add Folder…") { model.addFolders() }
                }
            }
        }
    }

    private var emptyTitle: String {
        switch section {
        case .favorites: "No favorites yet"
        case .photos: "No photos found"
        case .videos: "No videos found"
        case .music: "No music found"
        default: "No media found"
        }
    }

    private var emptyMessage: String {
        switch section {
        case .favorites:
            "Click the heart on any photo, video, or song to keep it here."
        default:
            "Your folders don't contain any supported \(section == .allMedia ? "media" : section.title.lowercased()) yet. Add another folder, or check Settings for supported formats."
        }
    }
}
