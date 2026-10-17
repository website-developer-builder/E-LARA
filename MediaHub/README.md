# MediaHub

**Your photos, videos, and music. One simple library.**

MediaHub is a native macOS app (SwiftUI) that gathers the photos, videos, and music from folders you choose into one friendly gallery. Your files stay where they are. MediaHub only reads them, and never moves, renames, or deletes anything.

The product spec lives one folder up (`../PRODUCT_REQUIREMENTS.md`, `../UX_AND_UI_SPEC.md`, and so on) and is the source of truth.

---

## Quick start

**Requirements:** a Mac running macOS 14 Sonoma or later, and Xcode 16 or later to build. Built and tested with **Xcode 26.6 on macOS 26.6** (Apple Silicon).

### Run from Xcode
1. Open `MediaHub.xcodeproj`.
2. Pick the **MediaHub** scheme and **My Mac**, then press **⌘R**.
3. Click **Choose Folders…** and pick a folder with photos, videos, or music.

### Build from the command line
```bash
scripts/build.sh            # Debug build
scripts/test.sh             # run all unit tests
scripts/release.sh          # Release build → dist/MediaHub.app
open dist/MediaHub.app
```
If `xcodebuild` says it "requires Xcode", your command-line tools point at the standalone CLT. The scripts already set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. To fix it system-wide instead, run `sudo xcode-select -s /Applications/Xcode.app` yourself.

### Sample media for testing
```bash
scripts/make_fixtures.sh    # writes TestFixtures/Media (git-ignored)
```
This generates JPG/PNG/HEIC/TIFF images (including a 8000×3000 panorama, duplicate names in different folders, and accented and Japanese filenames), MOV/MP4/M4V videos, AIFF/M4A/WAV/CAF audio, and a few junk or corrupt files that must not crash anything.

---

## Using MediaHub

| Where | What |
|---|---|
| **Sidebar** | Home · All Media · Photos · Videos · Music · Favorites · Settings, with item counts. The bottom shows "N folders · N items", scan progress with **Cancel**, and any folder that needs attention. |
| **Toolbar** | Add Folder · Rescan · Sort · Grid/List · Info · Search |
| **Cards** | Click to select · double-click (or Return) to open or play · right-click for Open/Play, Favorite, Show in Finder, Get Info. There is no Delete, by design. |
| **Viewer** | Photos fit the window, pinch or double-click to zoom, ← → for previous/next, Esc to go back. Videos use the standard macOS player controls. |
| **Mini-player** | Music keeps playing while you browse: play/pause, previous/next, seek, volume. |
| **Drag & drop** | Drop folders from Finder onto the window to add them. |

### Keyboard shortcuts
| Shortcut | Action |
|---|---|
| ⌘O | Add folder |
| ⌘F | Search |
| ⌘R | Rescan all folders |
| ⌘1 … ⌘6 | Home, All Media, Photos, Videos, Music, Favorites |
| ⌘, | Settings |
| ⌘I | Show or hide details |
| Arrows / Return | Move the selection in the grid / open it |
| Space | Play/pause music (when the grid has focus) |
| ⌘P | Play/pause (Controls menu, works anywhere) |
| ⌥⌘→ / ⌥⌘← | Next / previous song |
| ⌘L | Add to / remove from Favorites |
| ⇧⌘R | Show in Finder |
| ← → / Esc | Previous / next / close in the viewer |

---

## Technical decisions

| Decision | Choice | Why |
|---|---|---|
| **Minimum macOS** | **14.0 Sonoma** | Gives `@Observable`, `.inspector`, `ContentUnavailableView`, `onKeyPress`, and modern AVFoundation async loading. Covers most Macs in use. No newer APIs are required. ⌘F search focus uses an AppKit fallback because SwiftUI's `searchFocused` needs macOS 15. |
| **Sandbox** | **On.** Entitlements: `app-sandbox`, `files.user-selected.read-only`, `files.bookmarks.app-scope`. No network entitlement. | Least privilege. The app can only *read* folders the user picks, and never needs Full Disk Access. |
| **Folder access** | Security-scoped, read-only **bookmarks** saved per folder. | At launch each bookmark is resolved and `startAccessingSecurityScopedResource()` is called. Access stays open while the folder is in the library (thumbnails and playback can touch any file), and stops when the folder is removed or the app quits. A stale bookmark is refreshed automatically. A broken one shows "Needs permission", with a **Grant Access…** button that asks the user to pick the folder again. See `Services/FolderAccess.swift`. |
| **Persistence** | **SQLite** (system `libsqlite3`, no third-party code), in `~/Library/Containers/com.example.MediaHub/Data/Library/Application Support/MediaHub/Library.sqlite` | Full control over batched, transactional writes and upserts, fast to open, and easy to unit-test. SwiftData was considered, but it's harder to batch and test under strict concurrency. Migrations use `PRAGMA user_version` (see `LibraryStore.migrate`). UI preferences (section, sort, grid/list) live in `UserDefaults`. |
| **Search** | Case- and diacritic-insensitive filename match (extension included) over the in-memory index, memoized per section/sort/query. | No disk access per keystroke. 50,000 items search and sort in ~0.17 s in tests. |
| **Thumbnails** | Image I/O downsampling (never decodes full-size images for the grid), `AVAssetImageGenerator` for video, embedded artwork for audio. At most 6 are generated at once, and they're cancelled when cards scroll away. | Memory cache (600 images) plus JPEG disk cache in `Library/Caches/MediaHub/Thumbnails`, keyed by path, size, and modification date. Trimmed to **500 MB** at launch (least recently used first). Can be cleared in Settings. |
| **Scanning** | Background enumeration that skips hidden files, package contents (apps, `.photoslibrary`), `node_modules`, and `~/Library`. Symlinks are **not followed**, so there are no loops. | New or changed files are detected by size and modification date. Only those get their metadata read (8 at a time) and saved in batches of 100. |
| **Overlapping folders** | Adding a folder **inside** an existing one is refused with a note. Adding a **parent** of existing folders absorbs them, and their items (favorites, play history) move to the parent. Each file path is unique in the index. | No duplicate entries, and no lost favorites. |
| **Deleted / moved files** | Entries are removed **only after a scan completes**. A cancelled or failed scan never deletes anything. Missing **favorites** are kept and marked "Missing". | Matches the spec's "don't treat a cancelled scan as proof of deletion". A moved file reappears as a new entry on the next scan. |
| **External drives** | Eject: the folder is marked "Not reachable" and its entries are kept. Reconnect (or relaunch): the folder is reopened and rescanned automatically. | Uses `NSWorkspace` mount/unmount notifications. |
| **Playback** | Music: one shared `AVPlayer` (never two songs at once), queue = the songs in the list you started from. Opening a video pauses music. Nothing plays at launch. | |
| **Video player** | AppKit `AVPlayerView`, hosted from a file that doesn't import SwiftUI | SwiftUI's `VideoPlayer` **crashed** in testing (an abort inside Apple's `_AVKit_SwiftUI` library on macOS 26.6 / SDK 26.5). Any file importing both SwiftUI and AVKit links that library, so `Views/VideoContainerView.swift` keeps them apart. |
| **Collections / playlists** | **Deferred** | Marked "nice-to-have". The data model supports adding them later without migration pain. |
| **App name** | `AppConfig.appName` in `App/AppConfig.swift`, plus `PRODUCT_NAME` in the project | One place to rebrand. |

---

## Source tree
```
MediaHub/
├── MediaHub.xcodeproj           (shared scheme: MediaHub)
├── MediaHub/
│   ├── App/        MediaHubApp (window + menus), AppModel (state, scanning), AppConfig, WindowHelpers
│   ├── Models/     MediaType, MediaItem, LibraryFolder, LibraryQuery (filter/sort/search)
│   ├── Services/   Database (SQLite), LibraryStore (actor), MediaScanner, MetadataService,
│   │               FolderAccess (sandbox bookmarks), ThumbnailService, PlaybackController
│   ├── Views/      ContentView, SidebarView, HomeView, LibraryView, MediaCardView, DetailsView,
│   │               MediaViewer, VideoContainerView, MiniPlayerView, SettingsView, EmptyStates
│   └── Resources/  Assets (app icon), MediaHub.entitlements
├── MediaHubTests/  39 unit + integration tests
├── scripts/        build.sh, test.sh, release.sh, make_fixtures.sh, MakeFixtures.swift, MakeIcon.swift
└── TestFixtures/   generated sample media (git-ignored)
```

---

## Tests

`scripts/test.sh` runs 39 XCTest cases inside the sandboxed app:

| Suite | Covers |
|---|---|
| `LibraryQueryTests` | Section filters, case/diacritic/extension search, search + filter together, all 5 sorts, recently played, classification |
| `IndexingTests` | Recursive scan, skipping non-media/hidden/package contents, symlink loops, cancellation, change detection, folder overlap rules, persistence across reopen, upsert without duplicates, reconciliation (removed vs. missing favorites), unavailable drive, removing a folder never deletes files, parent folder absorbing a child |
| `LibraryFlowTests` | End-to-end: add folder → scan → metadata → re-add (no duplicates) → rescan after add/delete on disk → "relaunch" keeps the library and favorites; missing folder keeps entries |
| `ThumbnailTests` | 6000×4000 image downsampled to 440 px, broken image returns nil (no crash), disk cache write and clear, cache key changes with the file, trimming |
| `PlaybackTests` | Real AVPlayer: queue, play/pause, next/previous, auto-advance at the end, play history, missing file error, corrupt file error |
| `ReliabilityTests` | Drive eject/reconnect, cancelled rescan doesn't delete, 5,000-file scan timing, 50,000-item search/sort timing |
| `FormatTests` | Generates each format and checks classification, metadata, thumbnail, and playability |

**Last run: 39 tests, 0 failures** (macOS 26.6, Xcode 26.6). Measured: 5,000-file scan 0.63 s (small synthetic files), unchanged rescan 0.15 s, 50k-item search+sort 0.17 s.

### Formats actually verified
| Kind | Verified | How |
|---|---|---|
| Photos | JPG/JPEG, PNG, HEIC, TIFF, GIF, BMP | Generated in `FormatTests` (metadata + thumbnail) |
| | WEBP, NEF (Nikon RAW), HEIC, JPEG, PNG | Read-only decode check on a real 7,258-item library (all samples decoded), plus browsing it in the app |
| Videos | MOV, MP4, M4V (H.264) | Generated in `FormatTests` (duration, size, thumbnail, playable). MOV/MP4 were also played in the app from a real library |
| Music | M4A (AAC), WAV, AIFF, CAF (ALAC) | Generated in `FormatTests` (duration, playable) |
| | MP3, AMR | MP3: system sample is playable (32.7 s). AMR: 7/7 real files playable; music was played in the app |

**Listed but not verified:** HEIF, TIF, DNG/CR2/CR3/ARW/ORF/RAF/RW2 RAW (depends on your Mac's RAW support), 3GP, AAC (raw), FLAC. They're recognized. If macOS can't open one, MediaHub shows a friendly "can't be shown/played" message instead of crashing (tested with corrupt JPG and MP3 files).

---

## Manual test checklist (from `../TEST_PLAN.md`)

What was actually exercised in the running app during development:

- [x] First launch shows the welcome screen with **Choose Folders…**
- [x] Native folder picker. A real 7,258-item folder was indexed (6,472 photos, 776 videos, 10 music); the UI stayed responsive.
- [x] Relaunch restores the library and folder access, **including from a Release build in a different location**
- [x] Thumbnails load lazily while scrolling
- [x] Search updates while typing; ⌘F focuses search; "No media found for '…'" state with **Clear Search**
- [x] Select a card → Info panel shows kind, size, dimensions, dates, location, Show in Finder
- [x] Double-click a photo → viewer; → goes to the next photo; Esc returns to the library with the selection kept
- [x] Open a video → plays in-app with standard controls (after fixing the `VideoPlayer` crash described above)
- [x] Play a song → mini-player appears; Controls ▸ Pause works; the player stays visible on Home; Recently Played appears
- [x] Light and Dark appearance (Light checked by forcing the app's appearance)
- [x] Settings: folder list with status and item count, Rescan / Remove… / Add Folder, supported formats, thumbnail cache size and clear, privacy notes, version

**Not yet exercised by hand (covered only by automated tests or not at all):** a physically ejected external drive (simulated in tests), revoking permission via System Settings, VoiceOver end to end, keyboard-only navigation of every screen, a Show in Finder click, drag-and-drop of a folder, very small window sizes.

---

## Known limitations
- **Ad-hoc signed.** `dist/MediaHub.app` runs on the Mac that built it. To share it with others you need an Apple Developer ID: set your Team in Signing & Capabilities, archive (Product ▸ Archive), then **Distribute App ▸ Developer ID** and notarize (`xcrun notarytool submit … --wait`, then `xcrun stapler staple`). Not done here.
- **Bookmarks and rebuilds.** Bookmarks are tied to the app's identity. With ad-hoc signing they survived Debug→Release rebuilds in testing, but if a future build ever shows "Needs permission", use **Grant Access…** in Settings.
- **Search is filename-only.** No tags, EXIF, or content search (by design for v1).
- **No automatic watching.** New files appear after **Rescan** (⌘R) or the next launch for unfinished folders. FSEvents monitoring is a future step.
- **Apple Photos libraries** (`.photoslibrary`) are packages and are intentionally not scanned.
- **Duplicates:** the same file reached through two selected folders appears once. Identical copies at different paths appear separately (no content hashing).
- **Grid keyboard navigation** needs the grid focused (click it once). VoiceOver activates a card's default action (open/play).
- Playback position isn't remembered between sessions (only "last played" and play count).
- Placeholder app icon.

---

## Files by milestone
| Milestone | Files |
|---|---|
| 0 Setup | `MediaHub.xcodeproj` (+ shared scheme), `App/AppConfig.swift`, `App/MediaHubApp.swift`, `Resources/MediaHub.entitlements`, `Resources/Assets.xcassets`, `scripts/build.sh`, `scripts/test.sh` |
| 1 UI shell | `Models/MediaType.swift`, `Models/MediaItem.swift`, `Models/LibraryFolder.swift`, `Models/LibraryQuery.swift`, `App/AppModel.swift`, `Views/ContentView.swift`, `SidebarView.swift`, `HomeView.swift`, `LibraryView.swift`, `MediaCardView.swift`, `SettingsView.swift`, `EmptyStates.swift`, `MediaHubTests/LibraryQueryTests.swift` |
| 2 Indexing | `Services/Database.swift`, `LibraryStore.swift`, `MediaScanner.swift`, `MetadataService.swift`, `FolderAccess.swift`; `AppModel` scanning; sidebar/settings status; `IndexingTests.swift`, `LibraryFlowTests.swift`, `scripts/make_fixtures.sh`, `MakeFixtures.swift` |
| 3 Grid & details | `Services/ThumbnailService.swift`, `Views/DetailsView.swift`; thumbnails, context menu, Show in Finder, cache settings; `ThumbnailTests.swift` |
| 4 Playback | `Services/PlaybackController.swift`, `Views/MediaViewer.swift`, `VideoContainerView.swift`, `MiniPlayerView.swift`; Controls menu; grid keyboard navigation; `PlaybackTests.swift` |
| 5 Reliability | `App/WindowHelpers.swift` (⌘F); drive mount/unmount, drag & drop, memoized results, VoiceOver hiding behind the viewer; `ReliabilityTests.swift`, `FormatTests.swift` |
| 6 Packaging | App icon (`scripts/MakeIcon.swift`), `scripts/release.sh`, `.gitignore`, this README. Version **0.1.0 (1)** in the project's `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`. |
