import XCTest
@testable import ELARA

final class IndexingTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ELARATests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func touch(_ relative: String, bytes: Int = 10) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: bytes).write(to: url)
    }

    private func makeStore() throws -> LibraryStore {
        try LibraryStore(url: root.appendingPathComponent("test.sqlite"))
    }

    // MARK: Scanner

    func testScannerFindsMediaRecursivelyAndSkipsOtherFiles() throws {
        try touch("a.jpg"); try touch("Nested/Deeper/b.MOV"); try touch("c.mp3")
        try touch("notes.txt"); try touch("doc.pdf"); try touch(".hidden.jpg")
        try touch("Some.app/Contents/Resources/icon.png")         // package contents
        try touch("Photos Library.photoslibrary/originals/x.jpg") // package contents
        try touch("Café Ünïcode/naïve file (1).heic")
        let found = try MediaScanner.enumerate(root: root)
        let names = Set(found.map(\.fileName))
        XCTAssertEqual(names, ["a.jpg", "b.MOV", "c.mp3", "naïve file (1).heic"])
        XCTAssertEqual(found.first { $0.fileName == "b.MOV" }?.mediaType, .video)
        XCTAssertEqual(found.first { $0.fileName == "b.MOV" }?.fileExtension, "mov")
    }

    func testScannerDoesNotFollowSymlinks() throws {
        try touch("real/a.jpg")
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("loop"), withDestinationURL: root)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link.jpg"),
                                                   withDestinationURL: root.appendingPathComponent("real/a.jpg"))
        XCTAssertEqual(try MediaScanner.enumerate(root: root).map(\.fileName), ["a.jpg"])
    }

    func testScannerReportsMissingFolder() {
        XCTAssertThrowsError(try MediaScanner.enumerate(root: root.appendingPathComponent("nope"))) { error in
            guard case MediaScanner.ScanError.folderMissing = error else { return XCTFail("\(error)") }
        }
    }

    func testScannerStopsWhenCancelled() throws {
        for i in 0..<500 { try touch("f\(i).jpg", bytes: 1) }
        let found = try MediaScanner.enumerate(root: root, isCancelled: { true })
        XCTAssertLessThan(found.count, 500)
    }

    func testChangedFilesDetectsNewAndModified() {
        let f1 = ScannedFile(path: "/a.jpg", fileName: "a.jpg", fileExtension: "jpg", mediaType: .image,
                             fileSizeBytes: 10, dateModified: Date(timeIntervalSince1970: 100))
        var f2 = f1; f2.path = "/b.jpg"
        var f3 = f1; f3.path = "/c.jpg"
        let stamps: [String: FileStamp] = [
            "/a.jpg": FileStamp(size: 10, modified: Date(timeIntervalSince1970: 100)),  // unchanged
            "/b.jpg": FileStamp(size: 99, modified: Date(timeIntervalSince1970: 100)),  // size changed
        ]
        XCTAssertEqual(MediaScanner.changedFiles([f1, f2, f3], comparedTo: stamps).map(\.path), ["/b.jpg", "/c.jpg"])
    }

    // MARK: Overlap

    func testFolderOverlap() {
        let existing = ["/Users/me/Pictures", "/Users/me/Music/Rock"]
        XCTAssertEqual(FolderOverlap.classify("/Users/me/Pictures", existing: existing), .alreadyAdded)
        XCTAssertEqual(FolderOverlap.classify("/Users/me/Pictures/", existing: existing), .alreadyAdded)
        XCTAssertEqual(FolderOverlap.classify("/Users/me/Pictures/2024", existing: existing),
                       .insideExisting(parentPath: "/Users/me/Pictures"))
        XCTAssertEqual(FolderOverlap.classify("/Users/me/Music", existing: existing),
                       .containsExisting(childPaths: ["/Users/me/Music/Rock"]))
        XCTAssertEqual(FolderOverlap.classify("/Users/me/Pictures Old", existing: existing), .independent)
    }

    // MARK: Store

    private func scanned(_ path: String, size: Int64 = 10) -> ScannedFile {
        let name = (path as NSString).lastPathComponent
        let ext = (name as NSString).pathExtension.lowercased()
        return ScannedFile(path: path, fileName: name, fileExtension: ext,
                           mediaType: MediaType.classify(fileExtension: ext)!, fileSizeBytes: size,
                           dateModified: Date(timeIntervalSince1970: 1000))
    }

    func testStorePersistsAcrossReopen() async throws {
        do {
            let store = try makeStore()
            let folder = try await store.addFolder(path: "/x", displayName: "x", bookmark: Data([1, 2, 3]))
            try await store.upsert([scanned("/x/a.jpg"), scanned("/x/b.mp3")], folderID: folder.id)
            let item = try await store.allItems().first { $0.fileName == "a.jpg" }!
            try await store.setFavorite(true, itemID: item.id)
            try await store.recordPlay(itemID: item.id)
        }
        let reopened = try makeStore()
        let folders = try await reopened.allFolders()
        XCTAssertEqual(folders.map(\.path), ["/x"])
        XCTAssertEqual(folders.first?.bookmarkData, Data([1, 2, 3]))
        let items = try await reopened.allItems()
        XCTAssertEqual(items.count, 2)
        let a = items.first { $0.fileName == "a.jpg" }!
        XCTAssertTrue(a.isFavorite)
        XCTAssertEqual(a.playCount, 1)
        XCTAssertNotNil(a.lastPlayedAt)
    }

    func testUpsertDoesNotDuplicateAndKeepsFavorite() async throws {
        let store = try makeStore()
        let folder = try await store.addFolder(path: "/x", displayName: "x", bookmark: nil)
        try await store.upsert([scanned("/x/a.jpg")], folderID: folder.id, now: Date(timeIntervalSince1970: 1))
        let id = try await store.allItems()[0].id
        try await store.setFavorite(true, itemID: id)
        try await store.upsert([scanned("/x/a.jpg", size: 999)], folderID: folder.id, now: Date(timeIntervalSince1970: 2))
        let items = try await store.allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, id)
        XCTAssertEqual(items[0].fileSizeBytes, 999)
        XCTAssertTrue(items[0].isFavorite)
        XCTAssertEqual(items[0].dateAddedToLibrary, Date(timeIntervalSince1970: 1), "date added must not change on rescan")
    }

    func testReconcileRemovesDeletedButKeepsMissingFavorites() async throws {
        let store = try makeStore()
        let folder = try await store.addFolder(path: "/x", displayName: "x", bookmark: nil)
        try await store.upsert([scanned("/x/a.jpg"), scanned("/x/b.jpg"), scanned("/x/c.jpg")], folderID: folder.id)
        let fav = try await store.allItems().first { $0.fileName == "b.jpg" }!
        try await store.setFavorite(true, itemID: fav.id)

        let result = try await store.reconcile(folderID: folder.id, seenPaths: ["/x/a.jpg"])
        XCTAssertEqual(result.removed, 1)
        XCTAssertEqual(result.markedMissing, 1)
        let items = try await store.allItems()
        XCTAssertEqual(Set(items.map(\.fileName)), ["a.jpg", "b.jpg"])
        XCTAssertEqual(items.first { $0.fileName == "b.jpg" }?.availability, .missing)

        // File comes back on a later scan → available again.
        try await store.upsert([scanned("/x/b.jpg")], folderID: folder.id)
        try await store.reconcile(folderID: folder.id, seenPaths: ["/x/a.jpg", "/x/b.jpg"])
        let back = try await store.allItems().first { $0.fileName == "b.jpg" }
        XCTAssertEqual(back?.availability, .available)
    }

    func testUnavailableFolderKeepsEntries() async throws {
        let store = try makeStore()
        let folder = try await store.addFolder(path: "/Volumes/Drive", displayName: "Drive", bookmark: nil)
        try await store.upsert([scanned("/Volumes/Drive/a.mov")], folderID: folder.id)
        try await store.setAvailability(.unavailable, folderID: folder.id)
        let items = try await store.allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].availability, .unavailable)
    }

    func testRemoveFolderRemovesOnlyIndexEntries() async throws {
        try touch("keep/a.jpg")
        let store = try makeStore()
        let folder = try await store.addFolder(path: root.appendingPathComponent("keep").path, displayName: "keep", bookmark: nil)
        try await store.upsert(try MediaScanner.enumerate(root: root.appendingPathComponent("keep")), folderID: folder.id)
        try await store.removeFolder(id: folder.id)
        let remaining = try await store.allItems()
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("keep/a.jpg").path),
                      "original file must never be deleted")
    }

    func testAbsorbChildFolderKeepsFavorites() async throws {
        let store = try makeStore()
        let child = try await store.addFolder(path: "/m/rock", displayName: "rock", bookmark: nil)
        try await store.upsert([scanned("/m/rock/song.mp3")], folderID: child.id)
        let song = try await store.allItems()[0]
        try await store.setFavorite(true, itemID: song.id)

        let parent = try await store.addFolder(path: "/m", displayName: "m", bookmark: nil)
        try await store.absorbFolders([child.id], into: parent.id)
        // Rescan of the parent sees the same file — must not create a duplicate.
        try await store.upsert([scanned("/m/rock/song.mp3"), scanned("/m/other.mp3")], folderID: parent.id)

        let folders = try await store.allFolders()
        XCTAssertEqual(folders.map(\.path), ["/m"])
        let items = try await store.allItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.first { $0.id == song.id }!.isFavorite)
        XCTAssertTrue(items.allSatisfy { $0.folderID == parent.id })
    }
}
