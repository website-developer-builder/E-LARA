import AVFoundation
import SwiftUI

/// Hosts Quick View in its own view so that only this layer re-renders when the selection
/// changes. If the detail view read the selection itself, every click on a card would rebuild
/// the window toolbar and the next click on a toolbar button would be lost (found in testing).
struct QuickViewLayer: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let item = model.quickViewItem, model.viewerItem == nil {
            QuickViewOverlay(item: item)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }
}

/// Floating preview of the selected item, opened with Space (Finder-style Quick View).
/// The library underneath keeps keyboard focus, so ← → ↑ ↓ keep moving the selection
/// and the preview follows. Space or Esc closes it; holding Space "peeks".
struct QuickViewOverlay: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { model.closeQuickView() }
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                header
                Divider()
                content
                    .id(item.id) // Fresh preview (and player) for each item.
            }
            .frame(maxWidth: 960, maxHeight: 680)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator))
            .shadow(color: .black.opacity(0.35), radius: 30, y: 10)
            .padding(36)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick View: \(item.displayName)")
        .accessibilityAddTraits(.isModal)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: item.mediaType.symbolName).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.fileName).font(.headline).lineLimit(1).truncationMode(.middle)
                Group {
                    if let position = model.quickViewPosition {
                        Text("\(position.index + 1) of \(position.count) · ← → to browse · Space to close")
                    } else {
                        Text("Space to close")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.toggleFavorite(item) } label: {
                Label("Favorite", systemImage: item.isFavorite ? "heart.fill" : "heart")
            }
            .help(item.isFavorite ? "Remove from Favorites" : "Add to Favorites")
            Button { model.showInFinder(item) } label: { Label("Show in Finder", systemImage: "folder") }
                .help("Show in Finder")
            Button { model.open(item) } label: {
                Label(item.mediaType == .audio ? "Play in Player" : "Open Full Window",
                      systemImage: item.mediaType == .audio ? "play.square" : "arrow.up.left.and.arrow.down.right")
            }
            .help(item.mediaType == .audio ? "Play in the music player" : "Open in the full-window viewer (Return)")
            Button { model.closeQuickView() } label: { Label("Close", systemImage: "xmark.circle.fill") }
                .help("Close (Space or Esc)")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if !item.isAvailable || !FileManager.default.fileExists(atPath: item.path) {
            ZStack {
                Color.black
                ViewerMessage(icon: "exclamationmark.triangle", title: "This file isn't available",
                              message: item.isAvailable
                                ? "“\(item.fileName)” may have been moved, renamed, or deleted. Rescan to update your library."
                                : item.availability.userDescription,
                              onClose: { model.closeQuickView() })
            }
        } else {
            switch item.mediaType {
            case .image:
                ZStack { Color.black; PhotoView(item: item, maxPixelSize: 2400) }
            case .video:
                ZStack { Color.black; VideoPlayerView(item: item, recordsPlay: false) }
            case .audio:
                AudioPreviewView(item: item, recordsPlay: false)
            }
        }
    }
}

/// Plays one song inside Quick View or the viewer, separately from the mini-player.
/// Starts automatically (the user just asked to preview it) and stops when closed.
struct AudioPreviewView: View {
    @Environment(AppModel.self) private var model
    let item: MediaItem
    var onDark = false
    /// Quick View previews don't count as "played" (keeps Recently Played stable while browsing).
    var recordsPlay = true

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var scrubbing: Double?
    @State private var failed = false
    @State private var timeObserver: Any?
    @State private var endObserver: NSObjectProtocol?
    @State private var statusObservation: NSKeyValueObservation?

    var body: some View {
        VStack(spacing: 18) {
            ThumbnailView(item: item, iconSize: 64)
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)
            Text(item.displayName)
                .font(.title2.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if failed {
                Label("This song can't be played. Its format may not be supported by macOS.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                HStack(spacing: 10) {
                    Text(Format.duration(scrubbing ?? currentTime)).monospacedDigit()
                    Slider(value: Binding(get: { scrubbing ?? currentTime }, set: { scrubbing = $0 }),
                           in: 0...max(duration, 0.1)) { editing in
                        if !editing, let value = scrubbing {
                            player?.seek(to: CMTime(seconds: value, preferredTimescale: 600))
                            currentTime = value
                            scrubbing = nil
                        }
                    }
                    .accessibilityLabel("Playback position")
                    Text(Format.duration(duration)).monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)

                Button {
                    togglePlay()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(onDark ? .white : .primary)
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private func start() {
        let player = AVPlayer(url: item.url)
        self.player = player
        duration = item.durationSeconds ?? 0
        statusObservation = player.currentItem?.observe(\.status) { playerItem, _ in
            if playerItem.status == .failed { Task { @MainActor in failed = true; isPlaying = false } }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                                                      queue: .main) { time in
            MainActor.assumeIsolated {
                currentTime = time.seconds
                if let d = player.currentItem?.duration.seconds, d.isFinite, d > 0 { duration = d }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification,
                                                             object: player.currentItem, queue: .main) { _ in
            MainActor.assumeIsolated { isPlaying = false; player.seek(to: .zero); currentTime = 0 }
        }
        model.playback.pause() // Don't play two songs at once.
        player.play()
        isPlaying = true
        if recordsPlay { model.recordPlay(item) }
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying { player.pause() } else { model.playback.pause(); player.play() }
        isPlaying.toggle()
    }

    private func stop() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        statusObservation?.invalidate()
        player?.pause()
        player = nil
        timeObserver = nil
        endObserver = nil
    }
}

/// Keyboard handling shared by the grid, the list, and Home:
/// Space = Quick View (tap) / peek (hold) · arrows = move selection · Return = open · Esc = close Quick View.
struct MediaKeyboardModifier: ViewModifier {
    @Environment(AppModel.self) private var model
    let items: [MediaItem]
    /// How far ↑/↓ move (the grid's column count). Pass nil when the view handles ↑/↓ itself (List).
    var verticalStep: Int?
    /// Whether this view handles ← → itself (List doesn't use them).
    var handlesHorizontal = true
    var scrollTo: ((MediaItem.ID) -> Void)?
    var makeFocusable = true

    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .modifier(FocusableIf(enabled: makeFocusable, focused: $focused))
            // Clicking a card selects it; take keyboard focus so Space and arrows work right away.
            .onChange(of: model.selectedItemID) { _, id in
                if makeFocusable, id != nil, !focused { focused = true }
            }
            .onKeyPress(.space, phases: [.down, .repeat, .up]) { press in
                if press.phase == .repeat { return model.isQuickViewOpen || model.selectedItem != nil ? .handled : .ignored }
                return model.handleSpace(down: press.phase == .down, in: items) ? .handled : .ignored
            }
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                let step: Int
                switch press.key {
                case .leftArrow, .rightArrow:
                    guard handlesHorizontal else { return .ignored }
                    step = press.key == .leftArrow ? -1 : 1
                default:
                    guard let vertical = verticalStep else { return .ignored }
                    step = press.key == .upArrow ? -vertical : vertical
                }
                if let id = model.moveSelection(by: step, in: items) { scrollTo?(id) }
                return .handled
            }
            .onKeyPress(.return) {
                guard let item = model.selectedItem else { return .ignored }
                model.open(item)
                return .handled
            }
            .onKeyPress(.escape) {
                guard model.isQuickViewOpen else { return .ignored }
                model.closeQuickView()
                return .handled
            }
    }
}

private struct FocusableIf: ViewModifier {
    let enabled: Bool
    var focused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if enabled {
            content.focusable().focused(focused).focusEffectDisabled()
        } else {
            content
        }
    }
}

extension View {
    func mediaKeyboard(items: [MediaItem], verticalStep: Int? = 1, handlesHorizontal: Bool = true,
                       makeFocusable: Bool = true, scrollTo: ((MediaItem.ID) -> Void)? = nil) -> some View {
        modifier(MediaKeyboardModifier(items: items, verticalStep: verticalStep, handlesHorizontal: handlesHorizontal,
                                       scrollTo: scrollTo, makeFocusable: makeFocusable))
    }
}
