import Foundation

/// A file found on disk during a scan, plus any metadata we could read.
struct ScannedFile: Sendable, Equatable {
    var path: String
    var fileName: String
    var fileExtension: String
    var mediaType: MediaType
    var fileSizeBytes: Int64
    var dateCreated: Date?
    var dateModified: Date?
    var durationSeconds: Double?
    var width: Int?
    var height: Int?
}

/// Size + modification date — used to skip files that haven't changed since the last scan.
struct FileStamp: Sendable, Equatable {
    var size: Int64
    var modified: Date?
}

/// Owns the on-disk library index (SQLite). All database access goes through this actor,
/// so it never runs on the main thread and never races.
actor LibraryStore {
    private let db: Database

    /// ~/Library/Containers/<bundle id>/Data/Library/Application Support/MediaHub/Library.sqlite
    static func defaultURL() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        let dir = support.appendingPathComponent(AppConfig.appName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("Library.sqlite")
    }

    init(url: URL) throws {
        db = try Database(path: url.path)
        try Self.migrate(db)
    }

    // MARK: Schema

    /// Bump `currentVersion` and add a step whenever the schema changes.
    private static let currentVersion = 1

    private static func migrate(_ db: Database) throws {
        let version = db.userVersion
        if version < 1 {
            try db.transaction {
                try db.execute("""
                CREATE TABLE IF NOT EXISTS folders (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    path TEXT NOT NULL UNIQUE,
                    display_name TEXT NOT NULL,
                    bookmark BLOB,
                    last_scan_started REAL,
                    last_successful_scan REAL,
                    scan_status TEXT NOT NULL DEFAULT 'idle',
                    last_error TEXT,
                    is_enabled INTEGER NOT NULL DEFAULT 1
                );
                CREATE TABLE IF NOT EXISTS items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    path TEXT NOT NULL UNIQUE,
                    file_name TEXT NOT NULL,
                    file_extension TEXT NOT NULL,
                    media_type TEXT NOT NULL,
                    file_size INTEGER NOT NULL,
                    date_created REAL,
                    date_modified REAL,
                    date_added REAL NOT NULL,
                    duration REAL,
                    width INTEGER,
                    height INTEGER,
                    is_favorite INTEGER NOT NULL DEFAULT 0,
                    last_played REAL,
                    play_count INTEGER NOT NULL DEFAULT 0,
                    availability TEXT NOT NULL DEFAULT 'available',
                    folder_id INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE
                );
                CREATE INDEX IF NOT EXISTS items_folder ON items(folder_id);
                CREATE INDEX IF NOT EXISTS items_name ON items(file_name COLLATE NOCASE);
                """)
            }
            db.userVersion = 1
        }
        if db.userVersion > currentVersion {
            throw Database.SQLError(message: "This library was created by a newer version of \(AppConfig.appName).")
        }
    }

    // MARK: Folders

    func allFolders() throws -> [LibraryFolder] {
        var result: [LibraryFolder] = []
        try db.run("""
            SELECT id, path, display_name, bookmark, last_scan_started, last_successful_scan,
                   scan_status, last_error, is_enabled FROM folders ORDER BY display_name COLLATE NOCASE
            """) { r in
            result.append(LibraryFolder(
                id: r.int(0), path: r.text(1), displayName: r.text(2), bookmarkData: r.blob(3),
                lastScanStartedAt: r.optionalDate(4), lastSuccessfulScanAt: r.optionalDate(5),
                scanStatus: ScanStatus(rawValue: r.text(6)) ?? .idle, lastErrorSummary: r.optionalText(7),
                isEnabled: r.int(8) != 0))
        }
        return result
    }

    func addFolder(path: String, displayName: String, bookmark: Data?) throws -> LibraryFolder {
        try db.run("INSERT INTO folders (path, display_name, bookmark) VALUES (?, ?, ?)",
                   [.text(path), .text(displayName), bookmark.map { .blob($0) } ?? .null])
        return LibraryFolder(id: db.lastInsertRowID, path: path, displayName: displayName, bookmarkData: bookmark,
                             scanStatus: .idle, isEnabled: true)
    }

    func updateFolder(_ f: LibraryFolder) throws {
        try db.run("""
            UPDATE folders SET path = ?, display_name = ?, bookmark = ?, last_scan_started = ?,
                last_successful_scan = ?, scan_status = ?, last_error = ?, is_enabled = ? WHERE id = ?
            """, [.text(f.path), .text(f.displayName), f.bookmarkData.map { .blob($0) } ?? .null,
                  .date(f.lastScanStartedAt), .date(f.lastSuccessfulScanAt), .text(f.scanStatus.rawValue),
                  .optional(f.lastErrorSummary), .int(f.isEnabled ? 1 : 0), .int(f.id)])
    }

    /// Removes a folder and its index entries. Never touches the files themselves.
    func removeFolder(id: Int64) throws {
        try db.run("DELETE FROM folders WHERE id = ?", [.int(id)])
    }

    /// When a newly added parent folder covers existing child folders, move the children's
    /// items under the parent (keeping favorites/history) and drop the child folder entries.
    func absorbFolders(_ childIDs: [Int64], into parentID: Int64) throws {
        guard !childIDs.isEmpty else { return }
        try db.transaction {
            for child in childIDs {
                try db.run("UPDATE items SET folder_id = ? WHERE folder_id = ?", [.int(parentID), .int(child)])
                try db.run("DELETE FROM folders WHERE id = ?", [.int(child)])
            }
        }
    }

    // MARK: Items

    func allItems() throws -> [MediaItem] {
        var result: [MediaItem] = []
        try db.run("""
            SELECT id, path, file_name, file_extension, media_type, file_size, date_created, date_modified,
                   date_added, duration, width, height, is_favorite, last_played, play_count, availability, folder_id
            FROM items
            """) { r in
            guard let type = MediaType(rawValue: r.text(4)) else { return }
            result.append(MediaItem(
                id: r.int(0), path: r.text(1), fileName: r.text(2), fileExtension: r.text(3), mediaType: type,
                fileSizeBytes: r.int(5), dateCreated: r.optionalDate(6), dateModified: r.optionalDate(7),
                dateAddedToLibrary: Date(timeIntervalSince1970: r.double(8)), durationSeconds: r.optionalDouble(9),
                width: r.optionalInt(10).map(Int.init), height: r.optionalInt(11).map(Int.init),
                isFavorite: r.int(12) != 0, lastPlayedAt: r.optionalDate(13), playCount: Int(r.int(14)),
                availability: Availability(rawValue: r.text(15)) ?? .available, folderID: r.int(16)))
        }
        return result
    }

    /// Size/date of each file already indexed for a folder — anything whose stamp matches is skipped on rescan.
    func fileStamps(folderID: Int64) throws -> [String: FileStamp] {
        var result: [String: FileStamp] = [:]
        try db.run("SELECT path, file_size, date_modified FROM items WHERE folder_id = ?", [.int(folderID)]) { r in
            result[r.text(0)] = FileStamp(size: r.int(1), modified: r.optionalDate(2))
        }
        return result
    }

    /// Inserts new files or refreshes changed ones in a single transaction.
    /// Existing rows keep their id, date added, favorite flag, and play history.
    func upsert(_ files: [ScannedFile], folderID: Int64, now: Date = Date()) throws {
        guard !files.isEmpty else { return }
        try db.transaction {
            for f in files {
                try db.run("""
                    INSERT INTO items (path, file_name, file_extension, media_type, file_size, date_created,
                        date_modified, date_added, duration, width, height, availability, folder_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'available', ?)
                    ON CONFLICT(path) DO UPDATE SET
                        file_name = excluded.file_name, file_extension = excluded.file_extension,
                        media_type = excluded.media_type, file_size = excluded.file_size,
                        date_created = excluded.date_created, date_modified = excluded.date_modified,
                        duration = excluded.duration, width = excluded.width, height = excluded.height,
                        availability = 'available'
                    """, [.text(f.path), .text(f.fileName), .text(f.fileExtension), .text(f.mediaType.rawValue),
                          .int(f.fileSizeBytes), .date(f.dateCreated), .date(f.dateModified), .date(now),
                          .optional(f.durationSeconds), .optional(f.width), .optional(f.height), .int(folderID)])
            }
        }
    }

    /// Called only after a scan of the folder finished completely (not cancelled or failed).
    /// Files that were not seen are gone: their index entries are removed — except favorites,
    /// which are kept and marked missing so the user's choice isn't silently lost.
    @discardableResult
    func reconcile(folderID: Int64, seenPaths: Set<String>) throws -> (removed: Int, markedMissing: Int) {
        var stale: [(id: Int64, favorite: Bool)] = []
        try db.run("SELECT id, path, is_favorite FROM items WHERE folder_id = ?", [.int(folderID)]) { r in
            if !seenPaths.contains(r.text(1)) { stale.append((r.int(0), r.int(2) != 0)) }
        }
        var removed = 0, missing = 0
        try db.transaction {
            try db.run("UPDATE items SET availability = 'available' WHERE folder_id = ?", [.int(folderID)])
            for s in stale {
                if s.favorite {
                    try db.run("UPDATE items SET availability = 'missing' WHERE id = ?", [.int(s.id)]); missing += 1
                } else {
                    try db.run("DELETE FROM items WHERE id = ?", [.int(s.id)]); removed += 1
                }
            }
        }
        return (removed, missing)
    }

    /// Marks every item in a folder, e.g. `.unavailable` when its drive is ejected.
    /// Entries are kept so they come back when the drive does.
    func setAvailability(_ availability: Availability, folderID: Int64) throws {
        try db.run("UPDATE items SET availability = ? WHERE folder_id = ?", [.text(availability.rawValue), .int(folderID)])
    }

    func setAvailability(_ availability: Availability, itemID: Int64) throws {
        try db.run("UPDATE items SET availability = ? WHERE id = ?", [.text(availability.rawValue), .int(itemID)])
    }

    func setFavorite(_ favorite: Bool, itemID: Int64) throws {
        try db.run("UPDATE items SET is_favorite = ? WHERE id = ?", [.int(favorite ? 1 : 0), .int(itemID)])
    }

    func recordPlay(itemID: Int64, at date: Date = Date()) throws {
        try db.run("UPDATE items SET last_played = ?, play_count = play_count + 1 WHERE id = ?",
                   [.date(date), .int(itemID)])
    }
}
