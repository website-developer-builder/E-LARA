# Version 1 Acceptance Checklist

## Product and UI
- [ ] Native macOS SwiftUI app launches successfully.
- [ ] Interface is simple, consistent, and understandable without a tutorial.
- [ ] Sidebar includes Home, All Media, Photos, Videos, Music, Favorites, Settings.
- [ ] Empty, loading, scanning, error, and no-results states exist.
- [ ] Light/Dark appearance and resizing work.

## Library
- [ ] User can select folders through native macOS UI.
- [ ] Only selected folders are indexed.
- [ ] App can scan nested folders in the background.
- [ ] Index persists after app restart.
- [ ] Duplicate indexing from overlapping folders is minimized.
- [ ] Rescan discovers new media and reconciles changed/missing files safely.
- [ ] User can remove a folder from MediaHub without deleting originals.

## Search and organization
- [ ] One search field searches all indexed media filenames.
- [ ] Photos, Videos, Music, All Media, Favorites filters work.
- [ ] Sorting works.
- [ ] Favorites persist.
- [ ] Item details show useful metadata and original location.
- [ ] Show in Finder works when the original file is available.

## Playback
- [ ] Photo preview works for tested image types.
- [ ] Audio playback works for tested audio types.
- [ ] Video playback works for tested video types.
- [ ] Audio controls remain accessible while navigating.
- [ ] Unsupported/missing files produce helpful messages, not crashes.

## Privacy and reliability
- [ ] No network or cloud service is required.
- [ ] No Full Disk Access request is required for normal use.
- [ ] Folder permission failures are handled.
- [ ] External drive disconnection is handled.
- [ ] Scanning and thumbnails do not freeze the UI.
- [ ] Original files are not moved, renamed, or deleted.
- [ ] Tests and known limitations are documented.

## Release
- [ ] Build and run steps documented.
- [ ] Tested macOS version documented.
- [ ] Tested media formats documented.
- [ ] No claim of full format support beyond verified tests.
