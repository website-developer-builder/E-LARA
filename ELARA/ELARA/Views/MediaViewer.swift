import AVFoundation
import SwiftUI

/// Full-window viewer for photos and videos, shown over the library.
/// ← → move through the current results, Esc closes.
struct MediaViewer: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem

    var body: some View {
        VStack(spacing: 0) {
            ViewerBar(item: item)
            ZStack {
                Color.black
                if !item.isAvailable || !FileManager.default.fileExists(atPath: item.path) {
                    ViewerMessage(icon: "exclamationmark.triangle",
                                  title: "This file isn't available",
                                  message: item.isAvailable
                                    ? "“\(item.fileName)” may have been moved, renamed, or deleted. Rescan to update your library."
                                    : item.availability.userDescription)
                } else if item.mediaType == .video {
                    VideoPlayerView(item: item)
                } else if item.mediaType == .audio {
                    AudioPreviewView(item: item, onDark: true)
                } else {
                    PhotoView(item: item)
                }
            }
            .id(item.id) // Fresh view (and player) per item.
        }
        .background(.black)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.escape) { model.closeViewer(); return .handled }
        .onKeyPress(.leftArrow) { model.stepViewer(by: -1); return .handled }
        .onKeyPress(.rightArrow) { model.stepViewer(by: 1); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Viewer: \(item.displayName)")
    }
}

struct ViewerBar: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem

    var body: some View {
        let position = model.viewerPosition
        HStack(spacing: 12) {
            Button {
                model.closeViewer()
            } label: {
                Label("Back to Library", systemImage: "chevron.backward")
            }
            .keyboardShortcut(.cancelAction)
            .help("Close (Esc)")

            Spacer()
            VStack(spacing: 1) {
                Text(item.displayName).font(.headline).lineLimit(1).truncationMode(.middle)
                if let position {
                    Text("\(position.index + 1) of \(position.count)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()

            Button { model.stepViewer(by: -1) } label: { Label("Previous", systemImage: "chevron.left") }
                .disabled(position.map { $0.index == 0 } ?? true)
                .help("Previous (←)")
            Button { model.stepViewer(by: 1) } label: { Label("Next", systemImage: "chevron.right") }
                .disabled(position.map { $0.index + 1 >= $0.count } ?? true)
                .help("Next (→)")
            Button { model.toggleFavorite(item) } label: {
                Label("Favorite", systemImage: item.isFavorite ? "heart.fill" : "heart")
            }
            .help(item.isFavorite ? "Remove from Favorites" : "Add to Favorites")
            Button { model.showInFinder(item) } label: { Label("Show in Finder", systemImage: "folder") }
                .help("Show in Finder")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// Photo shown fit-to-window. Pinch or double-click to zoom; drag to pan when zoomed.
struct PhotoView: View {
    let item: MediaItem
    /// Decode size cap. The full viewer uses 4096 px; Quick View uses less so ← → stays snappy.
    var maxPixelSize = 4096
    @State private var image: NSImage?
    @State private var failed = false
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(MagnifyGesture()
                        .onChanged { scale = min(max(baseScale * $0.magnification, 1), 8) }
                        .onEnded { _ in baseScale = scale; if scale == 1 { offset = .zero; baseOffset = .zero } })
                    .simultaneousGesture(DragGesture()
                        .onChanged { v in
                            guard scale > 1 else { return }
                            offset = CGSize(width: baseOffset.width + v.translation.width,
                                            height: baseOffset.height + v.translation.height)
                        }
                        .onEnded { _ in baseOffset = offset })
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scale = scale > 1 ? 1 : 2.5
                            baseScale = scale
                            offset = .zero; baseOffset = .zero
                        }
                    }
                    .accessibilityLabel(item.displayName)
            } else if failed {
                ViewerMessage(icon: "photo.badge.exclamationmark", title: "This photo can't be shown",
                              message: "“\(item.fileName)” may be damaged or in a format macOS can't read.")
            } else if let thumb = ThumbnailService.shared.cachedThumbnail(for: item) {
                // Show the grid thumbnail instantly while the sharper version loads.
                Image(nsImage: thumb).resizable().scaledToFit()
            } else {
                ProgressView().controlSize(.large).tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task {
            // Decode off the main thread, capped at a size that fills big screens without
            // loading a 100-megapixel original into memory.
            let url = item.url, size = maxPixelSize
            let cg = await Task.detached(priority: .userInitiated) {
                ThumbnailService.imageThumbnail(url: url, maxPixelSize: size)
            }.value
            if Task.isCancelled { return }
            if let cg { image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)) } else { failed = true }
        }
    }
}

/// In-app video player with the standard macOS controls.
struct VideoPlayerView: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem
    /// Quick View previews don't count as "played" (keeps Recently Played stable while browsing).
    var recordsPlay = true
    @State private var player: AVPlayer?
    @State private var failed = false
    @State private var statusObservation: NSKeyValueObservation?

    var body: some View {
        ZStack {
            if failed {
                ViewerMessage(icon: "film", title: "This video can't be played",
                              message: "“\(item.fileName)” may be damaged or use a format macOS doesn't support.")
            } else if let player {
                PlayerView(player: player)
            }
        }
        .onAppear {
            let player = AVPlayer(url: item.url)
            statusObservation = player.currentItem?.observe(\.status) { playerItem, _ in
                if playerItem.status == .failed { Task { @MainActor in failed = true } }
            }
            self.player = player
            model.playback.pause() // Don't play music over the video.
            player.play()          // User explicitly opened it.
            if recordsPlay { model.recordPlay(item) }
        }
        .onDisappear {
            // Release the player as soon as the viewer closes or moves on.
            player?.pause()
            statusObservation?.invalidate()
            player = nil
        }
    }
}

/// Wraps `VideoContainerView` (AppKit's standard player with macOS controls) for SwiftUI.
/// See VideoContainerView.swift for why SwiftUI's own `VideoPlayer` isn't used.
struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> VideoContainerView {
        VideoContainerView(player: player)
    }

    func updateNSView(_ view: VideoContainerView, context: Context) {
        if view.player !== player { view.player = player }
    }

    static func dismantleNSView(_ view: VideoContainerView, coordinator: ()) {
        view.player?.pause()
        view.player = nil
    }
}

struct ViewerMessage: View {
    @Environment(AppModel.self) private var model
    let icon: String
    let title: String
    let message: String
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40))
            Text(title).font(.title2.weight(.semibold))
            Text(message).multilineTextAlignment(.center).frame(maxWidth: 420)
            Button("Back to Library") { (onClose ?? model.closeViewer)() }
        }
        .foregroundStyle(.white)
        .padding()
    }
}
