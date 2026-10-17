import AVFoundation
import Foundation
import ImageIO

/// Reads lightweight metadata (dimensions, duration) without loading full media into memory.
enum MetadataService {
    static func enrich(_ file: ScannedFile) async -> ScannedFile {
        var file = file
        let url = URL(fileURLWithPath: file.path)
        switch file.mediaType {
        case .image:
            // Reads only the header, not the pixels.
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            if let source = CGImageSourceCreateWithURL(url as CFURL, options),
               let props = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any] {
                var w = props[kCGImagePropertyPixelWidth] as? Int
                var h = props[kCGImagePropertyPixelHeight] as? Int
                // EXIF orientations 5–8 are rotated 90°, so width and height swap.
                if let o = props[kCGImagePropertyOrientation] as? Int, (5...8).contains(o) { swap(&w, &h) }
                file.width = w
                file.height = h
            }
        case .video, .audio:
            let asset = AVURLAsset(url: url)
            if let duration = try? await asset.load(.duration), duration.isNumeric {
                let seconds = duration.seconds
                file.durationSeconds = seconds.isFinite && seconds > 0 ? seconds : nil
            }
            if file.mediaType == .video,
               let track = try? await asset.loadTracks(withMediaType: .video).first,
               let (size, transform) = try? await track.load(.naturalSize, .preferredTransform) {
                let rect = CGRect(origin: .zero, size: size).applying(transform)
                file.width = Int(abs(rect.width).rounded())
                file.height = Int(abs(rect.height).rounded())
            }
        }
        return file
    }

    /// Enriches many files with bounded parallelism so huge folders don't spawn thousands of tasks.
    static func enrich(_ files: [ScannedFile], maxConcurrent: Int = 8) async -> [ScannedFile] {
        await withTaskGroup(of: (Int, ScannedFile).self) { group in
            var results = files
            var next = 0
            func addNext() {
                guard next < files.count else { return }
                let i = next, f = files[i]
                next += 1
                group.addTask { (i, await enrich(f)) }
            }
            for _ in 0..<min(maxConcurrent, files.count) { addNext() }
            while let (i, f) = await group.next() {
                results[i] = f
                if !Task.isCancelled { addNext() }
            }
            return results
        }
    }
}
