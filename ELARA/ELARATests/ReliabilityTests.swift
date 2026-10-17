import XCTest
@testable import ELARA

@MainActor
final class ReliabilityTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("Reliability-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Drive/Media"), withIntermediateDirectories: true)
    }

    override func tearDown() async throws { try? FileManager.default.removeItem(at: root) }

    private func makeFiles(_ count: Int, in dir: URL) throws {
        for i in 0..<count {
            let sub = dir.appendingPathComponent("Folder \(i % 50)", isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            let ext = ["jpg", "mp3", "mov", "png", "m4a"][i % 5]
            try Data(count: 16).write(to: sub.appendingPathComponent("file \(i).\(ext)"))
        }
    }

    private func waitForScan(_ model: AppModel) async throws {
        let deadline = Date().addingTimeInterval(60)
        try await Task.sleep(nanoseconds: 50_000_000)
        while model.isScanning, Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
    }

    func testDriveEjectKeepsEntriesAndReconnectRestores() async throws {
        let media = root.appendingPathComponent("Drive/Media")
        try makeFiles(10, in: media)
        let model = AppModel(store: try LibraryStore(url: root.appendingPathComponent("lib.sqlite")))
        await model.start()
        await model.add([media])
        try await waitForScan(model)
        XCTAssertEqual(model.items.count, 10)

        await model.volumeChanged(root.appendingPathComponent("Drive").path, mounted: false)
        XCTAssertEqual(model.items.count, 10, "eject must not erase entries")
        XCTAssertTrue(model.items.allSatisfy { $0.availability == .unavailable })
        XCTAssertEqual(model.folders.first?.scanStatus, .unavailable)

        await model.volumeChanged(root.appendingPathComponent("Drive").path, mounted: true)
        try await waitForScan(model)
        XCTAssertTrue(model.items.allSatisfy { $0.isAvailable })
        XCTAssertEqual(model.folders.first?.scanStatus, .completed)
        model.shutdown()
    }

    func testCancelledRescanDoesNotDeleteEntries() async throws {
        let media = root.appendingPathComponent("Drive/Media")
        try makeFiles(3000, in: media)
        let model = AppModel(store: try LibraryStore(url: root.appendingPathComponent("lib.sqlite")))
        await model.start()
        await model.add([media])
        try await waitForScan(model)
        XCTAssertEqual(model.items.count, 3000)

        model.rescanAll()
        model.cancelScan()
        try await waitForScan(model)
        XCTAssertEqual(model.items.count, 3000, "a cancelled scan must not be treated as 'files deleted'")
        XCTAssertNotEqual(model.folders.first?.scanStatus, .scanning)
        model.shutdown()
    }

    /// Full pipeline on 5,000 files: enumerate, read metadata, save. Prints the time for the README.
    func testScanFiveThousandFiles() async throws {
        let media = root.appendingPathComponent("Drive/Media")
        try makeFiles(5000, in: media)
        let model = AppModel(store: try LibraryStore(url: root.appendingPathComponent("lib.sqlite")))
        await model.start()
        let start = Date()
        await model.add([media])
        try await waitForScan(model)
        let elapsed = Date().timeIntervalSince(start)
        print("PERF: scanned 5000 files in \(String(format: "%.2f", elapsed)) s")
        XCTAssertEqual(model.items.count, 5000)
        XCTAssertLessThan(elapsed, 60)

        // Unchanged rescan should skip metadata work entirely and be quick.
        let rescanStart = Date()
        model.rescanAll()
        try await waitForScan(model)
        print("PERF: unchanged rescan of 5000 files in \(String(format: "%.2f", Date().timeIntervalSince(rescanStart))) s")
        model.shutdown()
    }

    func testSearchAndSortPerformanceOnFiftyThousandItems() {
        let types: [MediaType] = [.image, .video, .audio]
        var items: [MediaItem] = []
        items.reserveCapacity(50_000)
        for i in 0..<50_000 {
            let date = Date(timeIntervalSince1970: Double(i))
            items.append(MediaItem(id: Int64(i), path: "/lib/item \(i).jpg", fileName: "Holiday photo \(i).jpg",
                                   fileExtension: "jpg", mediaType: types[i % 3], fileSizeBytes: Int64(i),
                                   dateModified: date, dateAddedToLibrary: date, isFavorite: i % 10 == 0,
                                   playCount: 0, availability: .available, folderID: 1))
        }
        let start = Date()
        let r1 = LibraryQuery.results(from: items, section: .allMedia, search: "photo 4999", sort: .nameAscending)
        let r2 = LibraryQuery.results(from: items, section: .photos, search: "", sort: .dateAddedNewest)
        let elapsed = Date().timeIntervalSince(start)
        print("PERF: search+sort over 50k items in \(String(format: "%.3f", elapsed)) s")
        XCTAssertEqual(r1.count, 11) // 4999 and 49990…49999
        XCTAssertEqual(r2.count, 16_667)
        XCTAssertLessThan(elapsed, 2)
    }
}
