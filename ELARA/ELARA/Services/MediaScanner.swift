import Foundation

/// Walks a folder and finds supported media files. Pure file-system reading — never writes.
enum MediaScanner {
    enum ScanError: Error, LocalizedError {
        case folderMissing(String)
        case notReadable(String)

        var errorDescription: String? {
            switch self {
            case .folderMissing(let name): "“\(name)” can't be found. If it's on an external drive, connect the drive and rescan."
            case .notReadable(let name): "\(AppConfig.appName) doesn't have permission to read “\(name)”."
            }
        }
    }

    /// Folders we never descend into: developer clutter, and the system's ~/Library
    /// (caches, app data) if the user picks their whole home folder.
    static func shouldSkipDirectory(_ url: URL) -> Bool {
        if url.lastPathComponent == "node_modules" { return true }
        return url.lastPathComponent == "Library"
            && url.deletingLastPathComponent().standardizedFileURL.path == realHomeDirectory
    }

    /// The user's real home folder (inside the sandbox, NSHomeDirectory() is the app container).
    static let realHomeDirectory: String = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir { return String(cString: dir) }
        return NSHomeDirectory()
    }()

    private static let keys: [URLResourceKey] = [
        .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey,
        .creationDateKey, .contentModificationDateKey,
    ]

    /// Recursively lists supported media under `root`.
    /// - Hidden files and package contents (apps, Photos libraries, bundles) are skipped.
    /// - Symbolic links are not followed, which also rules out symlink loops.
    /// - `isCancelled` is polled so a long scan can stop promptly.
    /// - `progress` is called with the running count of media files found.
    static func enumerate(
        root: URL,
        isCancelled: () -> Bool = { false },
        progress: (Int) -> Void = { _ in }
    ) throws -> [ScannedFile] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            throw ScanError.folderMissing(root.lastPathComponent)
        }
        guard fm.isReadableFile(atPath: root.path) else {
            throw ScanError.notReadable(root.lastPathComponent)
        }

        var results: [ScannedFile] = []
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true } // Skip unreadable subfolders, keep going.
        ) else {
            throw ScanError.notReadable(root.lastPathComponent)
        }

        var visited = 0
        for case let url as URL in enumerator {
            visited += 1
            if visited % 200 == 0, isCancelled() { break }

            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true { continue }
            if values.isDirectory == true {
                if shouldSkipDirectory(url) { enumerator.skipDescendants() }
                continue
            }
            guard values.isRegularFile == true else { continue }

            let ext = url.pathExtension.lowercased()
            guard let type = MediaType.classify(fileExtension: ext) else { continue }

            results.append(ScannedFile(
                path: url.standardizedFileURL.path,
                fileName: url.lastPathComponent,
                fileExtension: ext,
                mediaType: type,
                fileSizeBytes: Int64(values.fileSize ?? 0),
                dateCreated: values.creationDate,
                dateModified: values.contentModificationDate))
            if results.count % 50 == 0 { progress(results.count) }
        }
        progress(results.count)
        return results
    }

    /// Async wrapper: runs the enumeration off the main actor and honours task cancellation.
    static func enumerateInBackground(root: URL, progress: @escaping @Sendable (Int) -> Void) async throws -> [ScannedFile] {
        try enumerate(root: root, isCancelled: { Task.isCancelled }, progress: progress)
    }

    /// Files that are new or whose size/modification date changed since the last scan.
    static func changedFiles(_ files: [ScannedFile], comparedTo stamps: [String: FileStamp]) -> [ScannedFile] {
        files.filter { f in
            guard let old = stamps[f.path] else { return true }
            return old.size != f.fileSizeBytes || !sameDate(old.modified, f.dateModified)
        }
    }

    /// Dates round-trip through the database as Doubles; compare with a small tolerance.
    private static func sameDate(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (a?, b?): abs(a.timeIntervalSince(b)) < 0.001
        default: false
        }
    }
}

/// How a newly picked folder relates to folders already in the library.
enum FolderOverlap: Equatable {
    case independent
    case alreadyAdded
    case insideExisting(parentPath: String)
    case containsExisting(childPaths: [String])

    static func classify(_ newPath: String, existing: [String]) -> FolderOverlap {
        let new = normalize(newPath)
        var children: [String] = []
        for path in existing {
            let old = normalize(path)
            if old == new { return .alreadyAdded }
            if new.hasPrefix(old + "/") { return .insideExisting(parentPath: path) }
            if old.hasPrefix(new + "/") { children.append(path) }
        }
        return children.isEmpty ? .independent : .containsExisting(childPaths: children)
    }

    private static func normalize(_ path: String) -> String {
        var p = URL(fileURLWithPath: path).standardizedFileURL.path
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }
}
