import SwiftUI

/// Music controls pinned to the bottom of the window. Stays visible in every section.
struct MiniPlayerView: View {
    @Environment(AppModel.self) private var model
    @State private var scrubbing: Double?

    var body: some View {
        let playback = model.playback
        if let item = playback.current {
            HStack(spacing: 14) {
                ThumbnailView(item: item, iconSize: 16)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onTapGesture { model.selectedItemID = item.id; model.showInspector = true }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                    if let error = playback.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange).lineLimit(1)
                    } else {
                        Text(playback.queue.count > 1 ? "Song \(playback.index + 1) of \(playback.queue.count)" : "Music")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 200, alignment: .leading)

                HStack(spacing: 6) {
                    Button { playback.previous() } label: { Image(systemName: "backward.fill") }
                        .help("Previous")
                        .accessibilityLabel("Previous")
                    Button { playback.togglePlayPause() } label: {
                        Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 28)
                    }
                    .help(playback.isPlaying ? "Pause" : "Play")
                    .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
                    Button { playback.next() } label: { Image(systemName: "forward.fill") }
                        .disabled(!playback.hasNext)
                        .help("Next")
                        .accessibilityLabel("Next")
                }
                .buttonStyle(.borderless)
                .disabled(playback.errorMessage != nil && !playback.hasNext)

                Text(Format.duration(scrubbing ?? playback.currentTime))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Slider(value: Binding(get: { scrubbing ?? playback.currentTime }, set: { scrubbing = $0 }),
                       in: 0...max(playback.duration, 0.1)) { editing in
                    if !editing, let value = scrubbing { playback.seek(to: value); scrubbing = nil }
                }
                .controlSize(.small)
                .accessibilityLabel("Playback position")
                Text(Format.duration(playback.duration))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)

                Image(systemName: "speaker.wave.2.fill").foregroundStyle(.secondary).accessibilityHidden(true)
                Slider(value: Binding(get: { Double(playback.volume) }, set: { playback.volume = Float($0) }), in: 0...1)
                    .frame(width: 80)
                    .controlSize(.small)
                    .accessibilityLabel("Volume")

                Button { playback.stop() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .help("Stop and close player")
                    .accessibilityLabel("Close player")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Music player")
        }
    }
}
