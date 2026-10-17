# Technical Architecture

## 1. Platform and baseline
- Native macOS app using SwiftUI.
- Prefer a current stable Xcode and Swift version available to the developer.
- Set a reasonable minimum macOS deployment target based on the APIs actually used; document the chosen target in the project README.
- Apple Silicon is the primary initial target, but avoid unnecessary architecture-specific assumptions.
- No server or account system for MVP.

## 2. Suggested architecture
Use clear, small components rather than one giant SwiftUI file.

Suggested folders:
- `App/`: app entry point, app-level state, window setup.
- `Models/`: MediaItem, LibraryFolder, Favorite, PlaybackHistory or equivalent.
- `Services/`: MediaScanner, ThumbnailService, MetadataService, PersistenceService, FolderAccessService, PlaybackCoordinator.
- `ViewModels/`: HomeViewModel, LibraryViewModel, SearchViewModel, PlayerViewModel, SettingsViewModel if MVVM is used.
- `Views/`: SidebarView, HomeView, MediaGridView, MediaRowView, SearchFieldView, PhotoViewerView, VideoPlayerView, MiniPlayerView, SettingsView, EmptyStateView, ErrorStateView.
- `Resources/`: assets, icons, app metadata.
- `Tests/`: unit and UI tests.

Claude may adjust the structure if the resulting architecture remains understandable, testable, and native.

## 3. State management
Use SwiftUI state intentionally:
- `@State` for local view state.
- `@Observable` or `ObservableObject` depending on deployment target and selected Swift version.
- Keep file scanning and media services outside view bodies.
- Do not perform disk scanning in `body` or synchronously on the main actor.
- Use async tasks and cancellation.

## 4. Framework choices
- SwiftUI: app UI.
- AppKit: NSOpenPanel, NSWorkspace reveal in Finder, and native Mac integration.
- AVFoundation / AVKit: playback of supported audio and video formats.
- QuickLook: preview integration where useful.
- ImageIO / CoreGraphics: image metadata and thumbnail creation.
- UniformTypeIdentifiers: classify file types where possible.
- FileManager: directory enumeration and file attributes.
- SwiftData or SQLite: local index persistence. Choose one approach, explain the tradeoff, and use it consistently.
- CryptoKit is not required unless a real feature needs it.

## 5. Persistence recommendation
For an MVP, SwiftData is acceptable if it supports the selected macOS deployment target and required query patterns. SQLite is also valid if the app needs more control over indexing and migrations. Do not add a third-party database dependency without a clear reason.

Persist:
- selected folder bookmarks and display names
- media metadata and stable identifiers
- favorites
- last indexed/modified values
- playback history/progress where practical
- app preferences

Do not persist full-size media contents or duplicate original files.

## 6. Threading and responsiveness
- Enumerate folders away from the main actor.
- Batch database writes and UI updates.
- Generate thumbnails asynchronously and cache them.
- Avoid holding all media objects or full-size image data in memory.
- Use lazy grids/lists.
- Support cancellation of long scans.
- Avoid repeated full scans when metadata indicates no change, but prioritize correctness over premature optimization.

## 7. Error handling
Represent failures with user-readable states:
- access denied or bookmark invalid
- folder missing or external drive unavailable
- file deleted or moved
- unsupported format
- thumbnail generation failed
- playback failed
- database migration failed

Log useful diagnostic details locally without logging sensitive media content. Do not silently swallow errors.

## 8. Security and privacy
- No network access needed for the MVP.
- Do not request Full Disk Access.
- Use user-selected folder permissions and security-scoped bookmarks as appropriate for a sandboxed app.
- Store bookmarks securely and resolve them safely on relaunch.
- Release security-scoped access when no longer needed.
- Avoid scanning system folders, application bundles, or package contents unnecessarily.
- Do not change or delete user files.
- Include a short privacy explanation in onboarding/settings.

## 9. Distribution
Initially run from Xcode for local development. Later, if distributing outside the developer's Mac, investigate Developer ID signing, notarization, sandbox entitlements, and packaging. Do not claim the app is distributable until it has been built and tested in the target environment.
