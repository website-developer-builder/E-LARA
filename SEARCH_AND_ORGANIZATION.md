# Search and Organization

## 1. Universal search
Search the indexed library by filename, including extension where helpful. Search must work across photos, videos, and music from one field.

Expected behavior:
- Results update while typing.
- Case-insensitive matching.
- Trim accidental leading/trailing spaces.
- Empty query shows the current section's default content.
- Clear query action.
- Search should not require scanning the disk on every keystroke.
- Do not claim content/semantic search in MVP.

## 2. Filters
- All media
- Photos
- Videos
- Music
- Favorites
Optional future filters: date ranges, file size, folder, duration.

## 3. Sorting
At minimum:
- Date added, newest first
- Name ascending/descending
- Date modified, newest first
- File size largest first

Make the active sort visible.

## 4. Favorites
- Toggle favorite from card, detail view, and context menu.
- Favorites persist across app relaunches.
- Removing a favorite never affects the original file.
- If the item becomes unavailable, retain the favorite and show unavailable status.

## 5. Recently added and played
- Recently added uses date added to library, not file creation date, unless clearly labelled.
- Recently played appears only after playback history exists.
- If playback position tracking is unreliable, do not display misleading progress.

## 6. Details and Finder integration
A details panel or Get Info view should include:
- Filename
- Media type
- File size
- Date modified
- Duration and dimensions when applicable
- Original folder/location
- Availability state

“Show in Finder” should reveal the original file using a native macOS integration and handle missing files gracefully.

## 7. Custom collections
Custom albums/playlists are a nice-to-have, not a blocker. If implemented:
- They should store references to media items, not copies of media.
- Removing an item from a collection does not remove it from the library.
- Deleting a collection does not delete files.
