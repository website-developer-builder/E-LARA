import AppKit
import AVFoundation
import AVKit

// Deliberately does NOT import SwiftUI.
//
// Importing SwiftUI and AVKit in the same file links Apple's `_AVKit_SwiftUI` bridge library.
// In testing (macOS 26.6, Xcode 26.6 SDK, deployment target 14) that library aborted at runtime
// as soon as a video view appeared — both with SwiftUI's `VideoPlayer` and with an
// `NSViewRepresentable` wrapping `AVPlayerView`. Hosting AVPlayerView inside a plain NSView here,
// and wrapping *this* view from SwiftUI, avoids that library entirely.

/// A plain AppKit view that hosts the standard macOS video player (AVPlayerView).
final class VideoContainerView: NSView {
    private let playerView = AVPlayerView()

    init(player: AVPlayer) {
        super.init(frame: .zero)
        playerView.controlsStyle = .floating
        playerView.showsFullScreenToggleButton = true
        playerView.allowsPictureInPicturePlayback = false
        playerView.player = player
        playerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    var player: AVPlayer? {
        get { playerView.player }
        set { playerView.player = newValue }
    }
}
