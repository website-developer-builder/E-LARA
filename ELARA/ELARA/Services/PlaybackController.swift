import AVFoundation
import Foundation

/// Plays music in the background while the user browses. One instance for the whole app, so
/// there's never more than one song playing at once.
///
/// Rules (see README "Playback behaviour"):
/// - Nothing ever plays automatically at launch.
/// - Starting a video pauses music; starting music closes nothing but the video is paused by the viewer.
/// - The queue is the list of songs the user started from, so Next/Previous work from any section.
@Observable
@MainActor
final class PlaybackController {
    private(set) var queue: [MediaItem] = []
    private(set) var index = 0
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var errorMessage: String?
    var volume: Float = 1 { didSet { player?.volume = volume } }

    /// Called when a song actually starts, so the library can record "recently played".
    var onStart: ((MediaItem) -> Void)?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?

    var current: MediaItem? { queue.indices.contains(index) ? queue[index] : nil }
    var hasNext: Bool { index + 1 < queue.count }
    var hasPrevious: Bool { index > 0 }

    func play(_ item: MediaItem, queue newQueue: [MediaItem]) {
        let list = newQueue.contains(where: { $0.id == item.id }) ? newQueue : [item]
        queue = list
        index = list.firstIndex { $0.id == item.id } ?? 0
        startCurrent()
    }

    func togglePlayPause() {
        guard let player else {
            if current != nil { startCurrent() }
            return
        }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func next() {
        guard hasNext else { return }
        index += 1
        startCurrent()
    }

    /// Like most players: restarts the song if more than 3 seconds in, otherwise goes back one.
    func previous() {
        if currentTime > 3 || !hasPrevious {
            seek(to: 0)
        } else {
            index -= 1
            startCurrent()
        }
    }

    func seek(to seconds: Double) {
        currentTime = seconds
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func stop() {
        tearDown()
        queue = []
        index = 0
        errorMessage = nil
    }

    private func startCurrent() {
        tearDown()
        errorMessage = nil
        guard let item = current else { return }
        guard FileManager.default.fileExists(atPath: item.path) else {
            errorMessage = "“\(item.displayName)” can't be found. It may have been moved or deleted."
            return
        }
        let playerItem = AVPlayerItem(url: item.url)
        let player = AVPlayer(playerItem: playerItem)
        player.volume = volume
        self.player = player
        duration = item.durationSeconds ?? 0
        currentTime = 0

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                                                      queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds
                if let d = self.player?.currentItem?.duration.seconds, d.isFinite, d > 0 { self.duration = d }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification,
                                                             object: playerItem, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.hasNext { self.next() } else { self.isPlaying = false; self.seek(to: 0) }
            }
        }
        statusObservation = playerItem.observe(\.status) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in
                self?.isPlaying = false
                self?.errorMessage = "This file can't be played. Its format may not be supported by macOS."
            }
        }
        player.play()
        isPlaying = true
        onStart?(item)
    }

    private func tearDown() {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        statusObservation?.invalidate()
        player?.pause()
        player = nil
        timeObserver = nil
        endObserver = nil
        statusObservation = nil
        isPlaying = false
    }
}
