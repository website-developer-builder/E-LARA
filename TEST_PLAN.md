# Test Plan

## 1. Test fixture
Create a test directory with:
- Several JPG/PNG/HEIC images if available.
- Multiple MP3/M4A/WAV files.
- Several MP4/MOV videos.
- Unsupported text/PDF files.
- A nested folder.
- Duplicate filenames in different folders.
- A large image and a large video.
- A filename with spaces, punctuation, and non-English characters.

Use files the developer owns or is permitted to test.

## 2. Functional tests
1. First launch shows a clear folder-selection prompt.
2. User can add a folder.
3. Scan discovers supported media recursively.
4. Unsupported files do not appear as playable media, unless explicitly represented as unsupported.
5. Search returns matches across all media types.
6. Type filters work.
7. Sorting works and remains understandable.
8. Thumbnail failure does not break the grid.
9. Photo preview opens and closes.
10. Audio play/pause and seek work for tested formats.
11. Video playback works for tested formats.
12. Favorites persist after relaunch.
13. Recently added and played sections behave accurately.
14. Show in Finder opens the correct location.
15. Rescan discovers newly added files.
16. Rescan handles renamed/deleted files without crashing.
17. Removing a folder from the library does not delete original files.
18. App relaunch restores indexed library and resolves folder permissions.
19. Cancelled scan does not incorrectly mark all unvisited files as deleted.
20. Overlapping folders do not create duplicate entries unnecessarily.

## 3. Permissions and privacy tests
- Deny folder access and confirm a helpful error appears.
- Remove/move a selected folder and confirm app recovers gracefully.
- Disconnect an external drive and confirm entries become unavailable rather than crashing.
- Relaunch and verify scoped bookmark access.
- Confirm the app does not request Full Disk Access.
- Confirm no network upload or account sign-in is present in MVP.
- Confirm no original media is moved, renamed, or deleted.

## 4. Performance tests
- Scan a small folder of 100 items.
- Scan a larger fixture of at least 5,000 media items if practical.
- Scroll through a large grid and check memory usage.
- Search while indexing.
- Cancel a scan.
- Open a large image and video.
- Verify the main UI remains responsive during scans and thumbnail generation.

## 5. Accessibility tests
- Navigate main screens with keyboard only.
- Test VoiceOver labels for buttons and media cards.
- Verify visible focus states.
- Test Light and Dark appearance.
- Test window resizing and text truncation.

## 6. Regression
After each milestone:
- Build the app.
- Run unit tests.
- Run relevant manual test cases.
- Note any untested formats or known limitations in README.
