import SwiftUI

/// "Get Info" panel on the right side of the window.
struct DetailsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let item = model.selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ThumbnailView(item: item, iconSize: 40)
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text(item.fileName)
                        .font(.headline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button {
                            model.open(item)
                        } label: {
                            Label(item.mediaType == .image ? "Open" : "Play",
                                  systemImage: item.mediaType == .image ? "eye" : "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!item.isAvailable)

                        Button {
                            model.toggleFavorite(item)
                        } label: {
                            Label(item.isFavorite ? "Favorited" : "Favorite",
                                  systemImage: item.isFavorite ? "heart.fill" : "heart")
                        }
                        .help(item.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                    }

                    if !item.isAvailable {
                        Label(item.availability.userDescription, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }

                    Divider()
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                        row("Kind", "\(item.mediaType.displayName) (\(item.fileExtension.uppercased()))")
                        row("Size", Format.bytes(item.fileSizeBytes))
                        if let w = item.width, let h = item.height { row("Dimensions", "\(w) × \(h)") }
                        if let d = item.durationSeconds { row("Duration", Format.duration(d)) }
                        if let date = item.dateModified { row("Modified", date.formatted(date: .abbreviated, time: .shortened)) }
                        if let date = item.dateCreated { row("Created", date.formatted(date: .abbreviated, time: .shortened)) }
                        row("Added", item.dateAddedToLibrary.formatted(date: .abbreviated, time: .shortened))
                        if let date = item.lastPlayedAt { row("Last Opened", date.formatted(.relative(presentation: .named))) }
                        row("Status", item.isAvailable ? "Available" : "Unavailable")
                    }
                    .font(.callout)

                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location").font(.callout).foregroundStyle(.secondary)
                        Text(item.folderPath)
                            .font(.callout)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Show in Finder") { model.showInFinder(item) }
                    }
                }
                .padding(16)
            }
        } else {
            ContentUnavailableView("Nothing selected", systemImage: "info.circle",
                                   description: Text("Select a photo, video, or song to see its details."))
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value).textSelection(.enabled)
        }
    }
}
