# Playback and Preview Requirements

## 1. Photos
- Use ImageIO or Quick Look to preview common image types.
- Fit image to available area by default.
- Keep original aspect ratio.
- Provide previous/next navigation within current results where feasible.
- Handle large images without loading full-resolution data into the grid.
- If preview fails, show filename and a friendly error state.

## 2. Audio
- Use AVFoundation/AVPlayer or the best native API for the chosen supported formats.
- Provide play/pause, elapsed time, duration, seek/progress, and volume where practical.
- Display track filename and artwork if available; artwork extraction is optional for the MVP.
- A compact persistent mini-player should remain available while browsing other sections.
- Switching tracks should not require returning to the Music page if a queue is already established.
- Avoid surprise autoplay.
- If a codec/file is unsupported, show a helpful message rather than crashing.

## 3. Video
- Use AVKit VideoPlayer or another native SwiftUI-compatible player.
- Include standard controls.
- Show duration and a thumbnail in the library.
- Provide graceful handling of missing, inaccessible, or unsupported files.
- Playback should remain in-app by default.

## 4. Playback lifecycle
- Release player resources when appropriate.
- Avoid starting multiple audio players unintentionally.
- Define clear behavior when opening a second video or starting music while video plays.
- Persist playback position only if reliable and useful; do not let it delay MVP.
- Ensure UI updates on the main actor and file/metadata work happens off the main actor.

## 5. Scope boundary
Native frameworks do not support every codec/container combination. Do not promise universal playback. Document tested formats and report unsupported formats clearly.
