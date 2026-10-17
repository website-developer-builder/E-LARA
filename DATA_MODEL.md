# Data Model

The implementation can use SwiftData or SQLite. Keep the logical model below regardless of persistence choice.

## 1. MediaItem
Fields:
- `id`: stable local identifier.
- `url/bookmark reference`: reference to original file, stored in a way compatible with macOS permissions.
- `displayName`: filename without or with extension as chosen consistently.
- `fileName`: full filename.
- `fileExtension`: lowercase extension.
- `mediaType`: image, audio, video, or unsupported/other if needed.
- `fileSizeBytes`: integer.
- `dateCreated`: optional filesystem creation date.
- `dateModified`: optional filesystem modification date.
- `dateAddedToLibrary`: date first indexed.
- `durationSeconds`: optional for audio/video.
- `width`, `height`: optional for images/video.
- `thumbnailCacheKey`: optional app-owned cache reference.
- `isFavorite`: Boolean or separate relationship.
- `lastPlayedAt`: optional date.
- `lastPlaybackPositionSeconds`: optional number.
- `availabilityStatus`: available, missing, permissionRequired, unsupported, or unknown.
- `folderID`: relationship to a selected library folder when applicable.
- `resourceIdentifier`: optional filesystem resource identity for deduplication/relinking.

## 2. LibraryFolder
Fields:
- `id`
- `displayName`
- `bookmarkData` or equivalent scoped access reference
- `lastScanStartedAt`
- `lastSuccessfulScanAt`
- `scanStatus`: idle, scanning, completed, failed, needsPermission, unavailable
- `lastErrorSummary`: optional user-readable summary
- `isEnabled`

Do not assume a bookmark's path remains valid forever. Resolve and validate it.

## 3. PlaybackHistory (optional MVP)
Fields:
- `id`
- `mediaItemID`
- `lastPlayedAt`
- `lastPositionSeconds`
- `playCount`

## 4. UserPreferences
- last selected sidebar section
- preferred grid/list view
- sort order
- thumbnail size
- whether to show hidden files (default false)
- theme preference only if not using system appearance by default

## 5. Indexing rules
- Store metadata and references, not the actual media file bytes.
- Use migrations if the schema changes.
- Index common search fields such as filename and extension.
- Keep database operations out of SwiftUI view rendering.
- Use transactions or batches to avoid partial, inconsistent scans.
