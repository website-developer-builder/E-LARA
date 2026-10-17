# UX and UI Specification

## 1. Design direction
MediaHub should feel like a calm, clean, native Mac gallery. Prefer clarity over visual effects. The app should not look like a file-management utility with a large settings burden.

- Use SwiftUI and native macOS controls.
- Support Light and Dark appearance automatically.
- Use a sidebar, clear section titles, comfortable spacing, and consistent iconography.
- Use SF Symbols where appropriate.
- Avoid overdecorated gradients, excessive cards, and tiny metadata.
- Use a thumbnail grid for visual media and a compact list option for audio.
- Ensure the app works in a normal resizable Mac window.

## 2. Main window layout
### Sidebar
- Home
- All Media
- Photos
- Videos
- Music
- Favorites
- Settings

Show item counts only if they can be computed cheaply and kept accurate. At the bottom, show a compact library status such as “2 folders · 1,245 items” and scan status.

### Toolbar
- Search field, available globally.
- Sort menu.
- Grid/list view toggle where useful.
- Refresh/rescan button.
- Add Folder button, especially on empty states.
- Optional context-sensitive action such as Play or Reveal in Finder.

### Content area
- Title and short description for the selected section.
- Optional quick filters: All, Photos, Videos, Music, Favorites.
- Lazy grid of media cards.
- Recently Added and Continue Listening/Watching on Home when data exists.
- Show useful empty states rather than blank screens.

## 3. First launch
Show a welcoming screen:
Title: “All your media, in one place.”
Body: “Choose the folders where your photos, videos, and music live. MediaHub will organize them without moving your files.”
Primary button: “Choose Folders”
Secondary text: “Your files stay on your Mac. You control which folders are scanned.”

Do not request full-disk access. Use the native folder picker and request only the locations the user selects.

## 4. Home screen
- Welcome/summary at the top.
- Recently Added grid.
- Recently Played row if history exists.
- Quick access tiles or sidebar navigation for Photos, Videos, Music.
- If no folders are configured, show the first-launch empty state.
- If folders are configured but no media is found, explain how to add more folders or check supported formats.

## 5. Media grid cards
Each card should include:
- Thumbnail for image/video where available.
- Audio artwork if available; otherwise a music-note placeholder.
- File name, truncated safely.
- Optional duration for audio/video.
- Favorite indicator.
- Avoid showing long paths in the grid; show path in Details.

Click behavior:
- Single click selects an item.
- Double-click or pressing Return opens the preview/player.
- Context menu offers: Open/Play, Add/Remove Favorite, Show in Finder, Get Info.
- Never delete the original from the context menu in the MVP.

## 6. Preview and playback
- Photo preview: fit-to-window, zoom if straightforward, previous/next navigation.
- Video: in-app player with standard controls and clear playback errors.
- Music: persistent mini-player at the bottom of the window when audio is playing; play/pause, track title, seek/progress, elapsed/total duration, next/previous when available.
- Playback should continue when browsing other sections.
- Do not auto-play sound on app launch.
- If a file is missing or unsupported, show a helpful message and a way back to the library.

## 7. Search
- Search field always easy to find.
- Search should update results as the user types, with a small debounce if needed.
- Search filenames first. Search metadata only when it is reliably available.
- Clear button should reset the query.
- Search results should preserve selected type filters or make filter state obvious.
- Empty search result: “No media found for ‘…’” and suggestion to try a shorter filename or add another folder.

## 8. Settings
- Managed folders list with folder name and access status.
- Add folder, remove folder from index, rescan folder.
- Explain that removing a folder from MediaHub does not delete files.
- Thumbnail/cache cleanup action only if implemented safely.
- About/version.
- Privacy note: media remains local; no cloud upload in MVP.

## 9. Accessibility and keyboard
- Use accessibility labels and identifiers.
- Full keyboard navigation.
- Search shortcut: Command-F.
- Add folder shortcut: Command-O or a clearly documented equivalent, respecting native conventions.
- Play/pause shortcut: Space when a player or media item has focus and it will not conflict with text input.
- Return opens selected item where appropriate.
- Support VoiceOver and sufficient contrast.
- Do not rely on color alone to communicate scan/error state.

## 10. Interaction rules
- Keep the most common actions visible.
- Ask for confirmation only for meaningful changes, never for routine playback.
- Never block the main thread during indexing or thumbnail generation.
- Show progress for long scans and allow cancellation.
- Preserve the user's current section and search when possible after a rescan.
