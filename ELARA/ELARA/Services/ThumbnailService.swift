import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Makes small preview images and caches them in memory and on disk.
///
/// - Thumbnails are generated off the main thread, at most a few at a time.
/// - Full-size images are never decoded for the grid (Image I/O downsamples while reading).
/// - Disk cache: `~/Library/Containers/<app>/Data/Library/Caches/E-LARA/Thumbnails`, JPEG files keyed
///   by path + size + modification date, so an edited file gets a fresh thumbnail.
///   It's trimmed to `diskLimitBytes` at launch and can be cleared in Settings. Originals are never touched.
final class ThumbnailService: @unchecked Sendable {
    static let shared = ThumbnailService()

    static let maxPixelSize = 440
    static let diskLimitBytes: Int64 = 500 * 1024 * 1024

    private let memory = NSCache<NSString, NSImage>()
    private let cacheDirectory: URL?
    private let limiter = AsyncLimiter(limit: 6)

    init(cacheDirectory: URL? = ThumbnailService.defaultCacheDirectory()) {
        self.cacheDirectory = cacheDirectory
        memory.countLimit = 600
        if let cacheDirectory {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    static func defaultCacheDirectory() -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = caches.appendingPathComponent(AppConfig.appName, isDirectory: true)
        LibraryStore.moveLegacyFolder(named: AppConfig.legacyDataFolderName, in: caches, to: dir)
        return dir.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    static func cacheKey(for item: MediaItem) -> String {
        // FNV-1a: stable across launches (Swift's Hasher isn't).
        var hash: UInt64 = 0xcbf29ce484222325
        let source = "\(item.path)|\(item.fileSizeBytes)|\(item.dateModified?.timeIntervalSince1970 ?? 0)"
        for byte in source.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return String(hash, radix: 16)
    }

    func cachedThumbnail(for item: MediaItem) -> NSImage? {
        memory.object(forKey: Self.cacheKey(for: item) as NSString)
    }

    /// Returns a thumbnail, or nil if none can be made (e.g. audio without artwork, broken file).
    func thumbnail(for item: MediaItem) async -> NSImage? {
        let key = Self.cacheKey(for: item)
        if let image = memory.object(forKey: key as NSString) { return image }
        guard item.isAvailable else { return nil }

        await limiter.acquire()
        defer { Task { await limiter.release() } }
        if Task.isCancelled { return nil } // Card scrolled away while waiting.

        let fileURL = cacheDirectory?.appendingPathComponent(key + ".jpg")
        if let fileURL, let image = NSImage(contentsOf: fileURL) {
            memory.setObject(image, forKey: key as NSString)
            return image
        }
        guard let cgImage = await Self.generate(for: item) else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        memory.setObject(image, forKey: key as NSString)
        if let fileURL { Self.writeJPEG(cgImage, to: fileURL) }
        return image
    }

    private static func generate(for item: MediaItem) async -> CGImage? {
        switch item.mediaType {
        case .image:
            return imageThumbnail(url: item.url)
        case .video:
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: item.url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
            let time = CMTime(seconds: min(1, (item.durationSeconds ?? 0) / 3), preferredTimescale: 600)
            return try? await generator.image(at: time).image
        case .audio:
            return await audioArtwork(url: item.url)
        }
    }

    /// Downsampled decode — reads only as many pixels as the thumbnail needs.
    static func imageThumbnail(url: URL, maxPixelSize: Int = maxPixelSize) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func audioArtwork(url: URL) async -> CGImage? {
        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }
        let artwork = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtwork)
        guard let item = artwork.first, let data = try? await item.load(.dataValue),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func writeJPEG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        CGImageDestinationFinalize(dest)
    }

    // MARK: Cache maintenance

    var diskUsageBytes: Int64 {
        guard let cacheDirectory else { return 0 }
        return Self.files(in: cacheDirectory).reduce(0) { $0 + $1.size }
    }

    func clearCache() {
        memory.removeAllObjects()
        guard let cacheDirectory else { return }
        for file in Self.files(in: cacheDirectory) { try? FileManager.default.removeItem(at: file.url) }
    }

    /// Deletes the least recently used thumbnails until the cache is under the limit.
    func trimDiskCache(limit: Int64 = diskLimitBytes) {
        guard let cacheDirectory else { return }
        var files = Self.files(in: cacheDirectory)
        var total = files.reduce(0) { $0 + $1.size }
        guard total > limit else { return }
        files.sort { $0.date < $1.date }
        for file in files where total > limit {
            try? FileManager.default.removeItem(at: file.url)
            total -= file.size
        }
    }

    private static func files(in dir: URL) -> [(url: URL, size: Int64, date: Date)] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentAccessDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys)) ?? []
        return urls.compactMap { url in
            guard url.pathExtension == "jpg", let v = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, Int64(v.fileSize ?? 0), v.contentAccessDate ?? .distantPast)
        }
    }
}

/// Simple async semaphore: limits how many thumbnails are generated at once.
actor AsyncLimiter {
    private let limit: Int
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) { self.limit = limit }

    func acquire() async {
        if running < limit { running += 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty { running -= 1 } else { waiters.removeFirst().resume() }
    }
}
