import SwiftUI

/// One tile in the grid: thumbnail, name, duration, favorite heart.
struct MediaCardView: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ThumbnailView(item: item)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                    }
                if item.mediaType == .video {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.9), .black.opacity(0.35))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
                if item.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.white, .pink)
                        .padding(6)
                        .background(.black.opacity(0.35), in: Circle())
                        .padding(6)
                        .accessibilityLabel("Favorite")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    Image(systemName: item.mediaType.symbolName)
                    if let duration = item.durationSeconds {
                        Text(Format.duration(duration))
                    } else {
                        Text(item.fileExtension.uppercased())
                    }
                    if !item.isAvailable {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Unavailable")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        // One click handler using macOS's own click count: 1 = select, 2 = open.
        // (A separate double-tap gesture kept tracking the mouse after a single click and
        // swallowed the next click elsewhere, e.g. on a toolbar button.)
        .onTapGesture {
            model.selectedItemID = item.id
            if (NSApp.currentEvent?.clickCount ?? 1) >= 2 { model.open(item) }
        }
        .contextMenu { MediaContextMenu(item: item) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.mediaType.displayName): \(item.displayName)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.open(item) }
        .accessibilityAction(named: item.isFavorite ? "Remove from Favorites" : "Add to Favorites") { model.toggleFavorite(item) }
    }
}

/// Right-click menu shared by cards, rows, and the details panel. Deliberately has no "Delete".
struct MediaContextMenu: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem

    var body: some View {
        Button(item.mediaType == .image ? "Open" : "Play") { model.open(item) }
        Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") { model.toggleFavorite(item) }
        Divider()
        Button("Show in Finder") { model.showInFinder(item) }
        Button("Get Info") {
            model.selectedItemID = item.id
            model.showInspector = true
        }
    }
}

/// A row in list mode.
struct MediaRowView: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 10) {
            ThumbnailView(item: item, iconSize: 14)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName).lineLimit(1).truncationMode(.middle)
                Text(item.fileExtension.uppercased() + " · " + Format.bytes(item.fileSizeBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item.isFavorite {
                Image(systemName: "heart.fill").foregroundStyle(.pink).accessibilityLabel("Favorite")
            }
            if !item.isAvailable {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).accessibilityLabel("Unavailable")
            }
            Text(item.durationSeconds.map(Format.duration) ?? "")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Shows a cached/generated thumbnail, or a type icon while loading or if none can be made.
struct ThumbnailView: View {
    let item: MediaItem
    var iconSize: CGFloat = 28
    @State private var image: NSImage?

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: item.isAvailable ? item.mediaType.symbolName : "exclamationmark.triangle")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.secondary)
                }
            }
            .clipped()
            // Re-runs when the file changes; cancelled automatically when scrolled off screen.
            .task(id: ThumbnailService.cacheKey(for: item) + item.availability.rawValue) {
                image = ThumbnailService.shared.cachedThumbnail(for: item)
                if image == nil { image = await ThumbnailService.shared.thumbnail(for: item) }
            }
            .accessibilityHidden(true)
    }
}

enum Format {
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}
