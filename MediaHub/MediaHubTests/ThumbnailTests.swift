import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import MediaHub

final class ThumbnailTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("Thumbs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func item(_ url: URL, type: MediaType = .image, size: Int64 = 1, modified: TimeInterval = 0) -> MediaItem {
        MediaItem(id: 1, path: url.path, fileName: url.lastPathComponent, fileExtension: url.pathExtension,
                  mediaType: type, fileSizeBytes: size, dateModified: Date(timeIntervalSince1970: modified),
                  dateAddedToLibrary: Date(), isFavorite: false, playCount: 0, availability: .available, folderID: 1)
    }

    private func writeJPEG(width: Int, height: Int) -> URL {
        let url = dir.appendingPathComponent("big.jpg")
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
        return url
    }

    func testLargeImageIsDownsampled() {
        let url = writeJPEG(width: 6000, height: 4000)
        let thumb = ThumbnailService.imageThumbnail(url: url)
        XCTAssertNotNil(thumb)
        XCTAssertEqual(max(thumb!.width, thumb!.height), ThumbnailService.maxPixelSize)
    }

    func testBrokenImageReturnsNilInsteadOfCrashing() async throws {
        let url = dir.appendingPathComponent("broken.jpg")
        try "not an image".write(to: url, atomically: true, encoding: .utf8)
        let service = ThumbnailService(cacheDirectory: dir.appendingPathComponent("cache"))
        let image = await service.thumbnail(for: item(url))
        XCTAssertNil(image)
    }

    func testThumbnailIsCachedOnDiskAndCleared() async throws {
        let url = writeJPEG(width: 800, height: 600)
        let cache = dir.appendingPathComponent("cache")
        let service = ThumbnailService(cacheDirectory: cache)
        let image = await service.thumbnail(for: item(url))
        XCTAssertNotNil(image)
        XCTAssertGreaterThan(service.diskUsageBytes, 0)
        service.clearCache()
        XCTAssertEqual(service.diskUsageBytes, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "original must remain")
    }

    func testCacheKeyChangesWhenFileChanges() {
        let url = dir.appendingPathComponent("a.jpg")
        let a = ThumbnailService.cacheKey(for: item(url, size: 1, modified: 1))
        XCTAssertEqual(a, ThumbnailService.cacheKey(for: item(url, size: 1, modified: 1)))
        XCTAssertNotEqual(a, ThumbnailService.cacheKey(for: item(url, size: 2, modified: 1)))
        XCTAssertNotEqual(a, ThumbnailService.cacheKey(for: item(url, size: 1, modified: 2)))
    }

    func testTrimKeepsCacheUnderLimit() async {
        let cache = dir.appendingPathComponent("cache")
        let service = ThumbnailService(cacheDirectory: cache)
        for i in 0..<5 { try? Data(count: 1000).write(to: cache.appendingPathComponent("\(i).jpg")) }
        service.trimDiskCache(limit: 2500)
        XCTAssertLessThanOrEqual(service.diskUsageBytes, 2500)
    }
}
