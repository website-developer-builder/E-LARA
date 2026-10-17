import XCTest
@testable import ELARA

@MainActor
final class PlaybackTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("Playback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws { try? FileManager.default.removeItem(at: dir) }

    /// Silent 16-bit mono WAV.
    private func wav(_ name: String, seconds: Double = 3) throws -> MediaItem {
        let url = dir.appendingPathComponent(name)
        let rate = 8000, size = Int(Double(rate) * seconds) * 2
        var d = Data()
        func u32(_ v: Int) { var x = UInt32(v).littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: Int) { var x = UInt16(v).littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append("RIFF".data(using: .ascii)!); u32(36 + size); d.append("WAVEfmt ".data(using: .ascii)!)
        u32(16); u16(1); u16(1); u32(rate); u32(rate * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(size); d.append(Data(count: size))
        try d.write(to: url)
        return MediaItem(id: Int64(name.hashValue & 0xffff), path: url.path, fileName: name, fileExtension: "wav",
                         mediaType: .audio, fileSizeBytes: Int64(d.count),
                         dateAddedToLibrary: Date(), durationSeconds: seconds, isFavorite: false, playCount: 0, availability: .available, folderID: 1)
    }

    func testQueueNextPreviousAndHistory() async throws {
        let a = try wav("a.wav"), b = try wav("b.wav"), c = try wav("c.wav")
        let playback = PlaybackController()
        playback.volume = 0
        var started: [String] = []
        playback.onStart = { started.append($0.fileName) }

        playback.play(b, queue: [a, b, c])
        XCTAssertEqual(playback.current?.fileName, "b.wav")
        XCTAssertTrue(playback.isPlaying)
        XCTAssertTrue(playback.hasNext); XCTAssertTrue(playback.hasPrevious)

        // Time actually advances → AVPlayer is really playing the file.
        try await Task.sleep(nanoseconds: 1_200_000_000)
        XCTAssertGreaterThan(playback.currentTime, 0.3)
        XCTAssertNil(playback.errorMessage)

        playback.togglePlayPause()
        XCTAssertFalse(playback.isPlaying)
        playback.togglePlayPause()
        XCTAssertTrue(playback.isPlaying)

        playback.next()
        XCTAssertEqual(playback.current?.fileName, "c.wav")
        XCTAssertFalse(playback.hasNext)
        playback.next() // No-op at the end.
        XCTAssertEqual(playback.current?.fileName, "c.wav")

        playback.previous() // < 3 s in → previous song.
        XCTAssertEqual(playback.current?.fileName, "b.wav")
        XCTAssertEqual(started, ["b.wav", "c.wav", "b.wav"])

        playback.stop()
        XCTAssertNil(playback.current)
        XCTAssertFalse(playback.isPlaying)
    }

    func testPlaysToEndAndAdvances() async throws {
        let a = try wav("short.wav", seconds: 0.5), b = try wav("next.wav")
        let playback = PlaybackController()
        playback.volume = 0
        playback.play(a, queue: [a, b])
        let deadline = Date().addingTimeInterval(8)
        while playback.current?.fileName != "next.wav", Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
        XCTAssertEqual(playback.current?.fileName, "next.wav")
        playback.stop()
    }

    func testMissingFileShowsErrorInsteadOfCrashing() async throws {
        var item = try wav("gone.wav")
        try FileManager.default.removeItem(atPath: item.path)
        item.fileName = "gone.wav"
        let playback = PlaybackController()
        playback.play(item, queue: [item])
        XCTAssertNotNil(playback.errorMessage)
        XCTAssertFalse(playback.isPlaying)
    }

    func testUnsupportedFileReportsError() async throws {
        let url = dir.appendingPathComponent("corrupt.mp3")
        try Data("definitely not audio".utf8).write(to: url)
        let item = MediaItem(id: 9, path: url.path, fileName: "corrupt.mp3", fileExtension: "mp3", mediaType: .audio,
                             fileSizeBytes: 20, dateAddedToLibrary: Date(), isFavorite: false, playCount: 0,
                             availability: .available, folderID: 1)
        let playback = PlaybackController()
        playback.play(item, queue: [item])
        let deadline = Date().addingTimeInterval(5)
        while playback.errorMessage == nil, Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
        XCTAssertNotNil(playback.errorMessage)
        XCTAssertFalse(playback.isPlaying)
        playback.stop()
    }
}
