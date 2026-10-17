import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import MediaHub

/// End-to-end: add a folder → background scan → metadata → "relaunch" with the saved library.
@MainActor
final class LibraryFlowTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("MediaHubFlow-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Media/Nested"), withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func writePNG(_ url: URL, width: Int, height: Int) {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
    }

    /// Writes a silent 16-bit mono PCM WAV of the given length.
    private func writeWAV(_ url: URL, seconds: Double) throws {
        let rate = 8000, samples = Int(Double(rate) * seconds), dataSize = samples * 2
        var d = Data()
        func u32(_ v: Int) { var x = UInt32(v).littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: Int) { var x = UInt16(v).littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append("RIFF".data(using: .ascii)!); u32(36 + dataSize); d.append("WAVEfmt ".data(using: .ascii)!)
        u32(16); u16(1); u16(1); u32(rate); u32(rate * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(dataSize); d.append(Data(count: dataSize))
        try d.write(to: url)
    }

    private func waitForScan(_ model: AppModel, timeout: TimeInterval = 20) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        try await Task.sleep(nanoseconds: 50_000_000)
        while model.isScanning || model.folders.contains(where: { $0.scanStatus == .scanning || $0.scanStatus == .idle }) {
            if Date() > deadline { XCTFail("scan did not finish"); return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func testAddScanAndRelaunch() async throws {
        let media = root.appendingPathComponent("Media")
        writePNG(media.appendingPathComponent("Blue Sky.png"), width: 320, height: 200)
        writePNG(media.appendingPathComponent("Nested/Ünïcode 写真.png"), width: 10, height: 20)
        try writeWAV(media.appendingPathComponent("Nested/Quiet.wav"), seconds: 2)
        try "x".write(to: media.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        try "garbage".write(to: media.appendingPathComponent("Broken.jpg"), atomically: true, encoding: .utf8)

        let dbURL = root.appendingPathComponent("lib.sqlite")
        let model = AppModel(store: try LibraryStore(url: dbURL))
        await model.start()
        await model.add([media])
        try await waitForScan(model)

        XCTAssertEqual(model.folders.count, 1)
        XCTAssertEqual(model.folders.first?.scanStatus, .completed, model.folders.first?.lastErrorSummary ?? "")
        XCTAssertEqual(Set(model.items.map(\.fileName)), ["Blue Sky.png", "Ünïcode 写真.png", "Quiet.wav", "Broken.jpg"])
        let sky = model.items.first { $0.fileName == "Blue Sky.png" }!
        XCTAssertEqual(sky.width, 320); XCTAssertEqual(sky.height, 200)
        let wav = model.items.first { $0.fileName == "Quiet.wav" }!
        XCTAssertEqual(wav.durationSeconds ?? 0, 2, accuracy: 0.05)
        XCTAssertNil(model.items.first { $0.fileName == "Broken.jpg" }!.width, "broken file is listed but has no metadata")

        // Adding the same folder or a subfolder again must not duplicate anything.
        await model.add([media, media.appendingPathComponent("Nested")])
        XCTAssertEqual(model.folders.count, 1)
        XCTAssertNotNil(model.alert)

        model.toggleFavorite(sky)
        try await Task.sleep(nanoseconds: 200_000_000)

        // Change files on disk, then rescan.
        writePNG(media.appendingPathComponent("New Photo.png"), width: 50, height: 50)
        try FileManager.default.removeItem(at: media.appendingPathComponent("Nested/Quiet.wav"))
        model.rescanAll()
        try await waitForScan(model)
        XCTAssertEqual(Set(model.items.map(\.fileName)), ["Blue Sky.png", "Ünïcode 写真.png", "New Photo.png", "Broken.jpg"])

        // "Relaunch": a fresh model over the same database.
        model.shutdown()
        let relaunched = AppModel(store: try LibraryStore(url: dbURL))
        await relaunched.start()
        try await waitForScan(relaunched)
        XCTAssertEqual(relaunched.items.count, 4)
        XCTAssertTrue(relaunched.items.first { $0.fileName == "Blue Sky.png" }!.isFavorite)
        XCTAssertEqual(relaunched.folders.first?.scanStatus, .completed)
        relaunched.shutdown()
    }

    func testMissingFolderBecomesUnavailableWithoutLosingEntries() async throws {
        let media = root.appendingPathComponent("Media")
        writePNG(media.appendingPathComponent("a.png"), width: 10, height: 10)
        let dbURL = root.appendingPathComponent("lib.sqlite")
        let model = AppModel(store: try LibraryStore(url: dbURL))
        await model.start()
        await model.add([media])
        try await waitForScan(model)
        XCTAssertEqual(model.items.count, 1)
        model.shutdown()

        // Simulate an ejected drive: the folder disappears.
        let moved = root.appendingPathComponent("Elsewhere")
        try FileManager.default.moveItem(at: media, to: moved)
        let relaunched = AppModel(store: try LibraryStore(url: dbURL))
        await relaunched.start()
        relaunched.rescanAll()
        try await waitForScan(relaunched)
        XCTAssertEqual(relaunched.items.count, 1, "entries must survive a missing folder")
        XCTAssertNotEqual(relaunched.items.first?.availability, .available)
        XCTAssertTrue(relaunched.folders.first?.scanStatus.needsAttention ?? false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.appendingPathComponent("a.png").path))
        relaunched.shutdown()
    }
}
