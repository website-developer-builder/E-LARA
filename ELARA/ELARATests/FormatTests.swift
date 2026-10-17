import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ELARA

/// Generates one file per format with Apple frameworks, then checks E-LARA can classify it,
/// read its metadata, make a thumbnail (visual media), and that macOS reports it playable (audio/video).
final class FormatTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("Formats-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func item(_ url: URL, _ type: MediaType) -> MediaItem {
        MediaItem(id: 1, path: url.path, fileName: url.lastPathComponent, fileExtension: url.pathExtension,
                  mediaType: type, fileSizeBytes: 1, dateAddedToLibrary: Date(), isFavorite: false,
                  playCount: 0, availability: .available, folderID: 1)
    }

    private func scanned(_ url: URL, _ type: MediaType) -> ScannedFile {
        ScannedFile(path: url.path, fileName: url.lastPathComponent, fileExtension: url.pathExtension,
                    mediaType: type, fileSizeBytes: 1)
    }

    func testImageFormats() async throws {
        let ctx = CGContext(data: nil, width: 300, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0, green: 0.6, blue: 0.3, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        let image = ctx.makeImage()!
        let formats: [(String, UTType)] = [("jpg", .jpeg), ("png", .png), ("heic", .heic), ("tiff", .tiff), ("gif", .gif), ("bmp", .bmp)]
        for (ext, type) in formats {
            let url = dir.appendingPathComponent("test.\(ext)")
            let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil), ext)
            CGImageDestinationAddImage(dest, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(dest), ext)
            XCTAssertEqual(MediaType.classify(fileExtension: ext), .image, ext)
            let meta = await MetadataService.enrich(scanned(url, .image))
            XCTAssertEqual(meta.width, 300, ext); XCTAssertEqual(meta.height, 200, ext)
            XCTAssertNotNil(ThumbnailService.imageThumbnail(url: url), ext)
        }
    }

    func testAudioFormats() async throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100 // 1 second of silence
        let formats: [(String, [String: Any])] = [
            ("m4a", [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1]),
            ("wav", [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16]),
            ("aiff", [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsBigEndianKey: true]),
            ("caf", [AVFormatIDKey: kAudioFormatAppleLossless, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1]),
        ]
        for (ext, settings) in formats {
            let url = dir.appendingPathComponent("test.\(ext)")
            do {
                let file = try AVAudioFile(forWriting: url, settings: settings)
                try file.write(from: buffer)
            }
            XCTAssertEqual(MediaType.classify(fileExtension: ext), .audio, ext)
            let meta = await MetadataService.enrich(scanned(url, .audio))
            XCTAssertEqual(meta.durationSeconds ?? 0, 1, accuracy: 0.1, ext)
            let playable = try await AVURLAsset(url: url).load(.isPlayable)
            XCTAssertTrue(playable, ext)
        }
    }

    func testVideoFormats() async throws {
        for (ext, fileType) in [("mov", AVFileType.mov), ("mp4", .mp4), ("m4v", .m4v)] {
            let url = dir.appendingPathComponent("test.\(ext)")
            let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240])
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
            writer.add(input)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            for frame in 0..<20 {
                while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
                var pb: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
                adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 10))
            }
            input.markAsFinished()
            await writer.finishWriting()
            XCTAssertEqual(writer.status, .completed, ext)

            XCTAssertEqual(MediaType.classify(fileExtension: ext), .video, ext)
            let meta = await MetadataService.enrich(scanned(url, .video))
            XCTAssertEqual(meta.durationSeconds ?? 0, 2, accuracy: 0.2, ext)
            XCTAssertEqual(meta.width, 320, ext)
            let playable = try await AVURLAsset(url: url).load(.isPlayable)
            XCTAssertTrue(playable, ext)
            let thumb = await ThumbnailService(cacheDirectory: nil).thumbnail(for: item(url, .video))
            XCTAssertNotNil(thumb, ext)
        }
    }
}
