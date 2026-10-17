# Product Requirements Document (PRD)

## 1. Product summary
**Working name:** MediaHub  
**Platform:** macOS  
**Implementation:** Native SwiftUI application  
**Primary purpose:** Bring a user's local photos, videos, and music into one friendly, searchable place.

### Product promise
"Your photos, videos, and music. One simple library."

The user opens MediaHub, sees their media organized by type and recency, searches for an item, and opens or plays it without navigating Finder folders manually.

## 2. Problem
Media files are scattered across locations such as Downloads, Desktop, Documents, Pictures, Movies, Music, user-created folders, and external drives. Finding a specific item requires remembering where it was saved and navigating multiple folders.

## 3. Target users
- Everyday Mac users with media scattered across folders.
- Students and professionals who download and collect images, music, and videos.
- Users who want one simple gallery, not a complex editing or server product.
- Users who value local privacy and do not want to upload their files.

## 4. Product principles
1. **Simple first:** the interface should be understandable without a tutorial.
2. **One library:** photos, videos, and audio are accessible from one app.
3. **Local-first:** media stays in its existing location by default.
4. **Respect permissions:** scan only folders the user has explicitly granted.
5. **Fast discovery:** search, recent items, and type filters should make files easy to find.
6. **No destructive actions by default:** never move, rename, or delete originals in the MVP.
7. **Honest status:** show when indexing, permission, or file access needs attention.
8. **Native Mac feel:** keyboard shortcuts, standard macOS controls, resizing, and accessibility.

## 5. MVP scope
### Must have
- Native macOS app built with SwiftUI.
- Sidebar with Home, All Media, Photos, Videos, Music, Favorites, and Settings.
- First-launch welcome screen explaining the app and offering “Choose Folders”.
- Folder picker using a native macOS open panel, supporting multiple selected folders where feasible.
- Recursively scan authorized folders for supported media types.
- Persist a local index so the app does not need to fully rescan every launch.
- Unified search across indexed filenames.
- Type filters and sorting by name, date modified, date added, and file size.
- Grid view with image thumbnails or sensible file-type placeholders.
- Details for each item: filename, media type, location, size, modified date, and duration for audio/video when available.
- Photo preview.
- Audio playback with play/pause, progress, duration, and previous/next where practical.
- Video playback with standard playback controls.
- Favorites.
- Recently added and recently played sections where data is available.
- Refresh/rescan action and visible scan progress.
- Clear empty, loading, error, and permission states.
- Local persistence and safe handling of unavailable files.

### Should have, if achievable without destabilizing the MVP
- Quick Look preview integration.
- Drag-and-drop folders into the app to add them to the library.
- Remember last selected section and window size.
- Keyboard shortcuts for search, playback, and navigation.
- Hide duplicate index entries when the same file is found through overlapping selected folders, using standardized file URLs or resource identifiers.
- Basic custom collections/playlists.

### Not in MVP
- Cloud sync or accounts.
- Uploading media to a server.
- AI image recognition, face recognition, or semantic image search.
- Photo editing, video editing, audio editing, or transcoding.
- DRM bypass or protected-media extraction.
- Copying every file into a managed vault.
- Automatic scanning of the entire disk without user selection.
- Mobile app or Windows version.
- Complex media-server features.

## 6. Supported media
The app should support common formats through native macOS capabilities and clearly report unsupported files instead of crashing.

Suggested initial extensions:
- Images: jpg, jpeg, png, heic, heif, gif, tif, tiff, bmp, webp only if supported by the chosen rendering path, and common RAW formats where macOS Image I/O supports them.
- Audio: mp3, m4a, aac, wav, aiff, caf, alac, flac only if the chosen native playback path supports it on the target macOS version.
- Video: mp4, mov, m4v, and other formats supported by AVFoundation on the target macOS version.

Do not promise universal codec support. Build capability checks and graceful fallbacks.

## 7. Primary user stories
- As a user, I can add folders so MediaHub knows where to look.
- As a user, I can see all indexed photos, videos, and music from one place.
- As a user, I can search for a filename without remembering its folder.
- As a user, I can filter the library to photos, videos, or music.
- As a user, I can preview a photo and play audio/video in the app.
- As a user, I can favorite important files.
- As a user, I can see where a file lives and reveal it in Finder if I want.
- As a user, I can refresh a folder when files change.
- As a user, I can remove a folder from the library without deleting its contents.
- As a user, I can tell whether scanning is in progress and whether any folders need permission.

## 8. Non-functional requirements
- Native Apple Silicon performance; avoid needless heavy dependencies.
- Keep UI responsive during indexing by using background tasks.
- Do not load full-resolution thumbnails for every file at once.
- Use lazy grid/list rendering and thumbnail caching.
- Avoid indexing package contents or system folders unless explicitly selected and appropriate.
- Handle broken links, removed drives, permission loss, and deleted files safely.
- Store app metadata in Application Support or an appropriate local container.
- Use macOS privacy APIs and least-privilege folder access.
- No telemetry or analytics in the MVP unless the user explicitly chooses to add it later.

## 9. Success criteria
A user can select two or more folders, scan them, browse all recognized media in one app, search by filename, open a photo, play a supported audio file and video, favorite an item, and quit/reopen the app without losing the library index. No original media files are moved or changed.
