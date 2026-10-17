# Media Indexing, Folder Access, and Permissions

## 1. Core rule
MediaHub indexes user-selected folders and points to the originals. It must not move, copy, rename, or delete originals in the MVP.

## 2. Adding folders
- Present a native macOS folder picker.
- Allow the user to select one or more folders if supported by the chosen panel configuration.
- Explain what the app will do before scanning.
- Save security-scoped bookmarks when required by the app's sandbox configuration.
- If the user selects a folder already covered by a selected parent folder, avoid duplicate indexing.
- Do not automatically choose the whole disk.

## 3. Scan behavior
- Run scans in the background.
- Show progress and a cancel option.
- Enumerate recursively, but avoid package contents and known system/application directories unless explicitly and intentionally selected.
- Skip hidden/system files by default, with a clear rationale.
- Recognize supported media extensions and/or UTType classifications.
- Store file URL/path representation only as needed; consider bookmark/resource identifiers and file metadata for robust relinking.
- Capture filename, extension/type, size, dates, and available duration/metadata.
- Generate thumbnails asynchronously.
- Batch database writes.
- Keep the UI usable while scanning.

## 4. Incremental refresh
- Support a manual “Rescan” action.
- Store last-seen modification date and size, plus a stable file identifier when practical.
- Refresh metadata if a file's modification date or size changes.
- Mark missing files as unavailable or remove stale index entries after a confirmed complete scan. Do not treat a cancelled or failed scan as proof that all missing items were deleted.
- A future release may use FSEvents or another change-detection mechanism. Do not make continuous background monitoring a blocker for the first release.

## 5. External drives and unavailable locations
- A disconnected external drive should not cause a crash or erase its library entries immediately.
- Mark media as unavailable and explain that the drive may be disconnected.
- On reconnect or rescan, reconcile entries.
- Do not continuously retry inaccessible folders in a tight loop.

## 6. macOS security-scoped access
The implementation must respect the selected sandbox configuration:
- If sandboxed, use user-selected read-only folder access and security-scoped bookmarks where appropriate.
- Start and stop security-scoped resource access according to Apple's API requirements.
- Handle bookmark resolution failures and permission revocation.
- Do not tell users to enable Full Disk Access as a normal setup step.
- Test permissions after relaunch.
- Do not store access tokens or bookmarks in logs.

## 7. Symlinks and duplicate files
- Avoid recursive symlink loops.
- Use standardized URLs and, where available, filesystem resource identifiers to prevent duplicate entries when folder selections overlap.
- Do not attempt expensive content hashing for every file in the MVP.
- Duplicate files with different names/locations may appear separately; this is acceptable unless a simple reliable deduplication method is available.

## 8. Safety and data integrity
- Read-only indexing in MVP.
- The only changes to the filesystem should be app-owned cache/database files and any explicitly generated app metadata.
- Removing a watched folder removes its association from MediaHub, not its original contents.
- All file access failures should degrade gracefully.
