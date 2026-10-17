// Generates test images and videos with Apple frameworks only.
// Usage: swift scripts/MakeFixtures.swift <output-dir>
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments[1])

func makeImage(width: Int, height: Int, hue: CGFloat, label: String) -> CGImage {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    for i in 0..<12 {
        let t = CGFloat(i) / 12
        ctx.setFillColor(CGColor(red: (hue + t).truncatingRemainder(dividingBy: 1), green: 0.5 * t + 0.3, blue: 1 - hue, alpha: 1))
        ctx.fill(CGRect(x: 0, y: CGFloat(height) * t, width: CGFloat(width), height: CGFloat(height) / 12 + 1))
    }
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.85))
    ctx.fillEllipse(in: CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
    return ctx.makeImage()!
}

func writeImage(_ name: String, _ type: UTType, width: Int = 1600, height: Int = 1200, hue: CGFloat) {
    let url = out.appendingPathComponent(name)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, makeImage(width: width, height: height, hue: hue, label: name), nil)
    print(CGImageDestinationFinalize(dest) ? "wrote \(name)" : "FAILED \(name)")
}

func writeVideo(_ name: String, fileType: AVFileType, seconds: Int, hue: CGFloat) async throws {
    let url = out.appendingPathComponent(name)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: url)
    let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
    let w = 640, h = 360, fps = 15
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    for frame in 0..<(seconds * fps) {
        while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
        CVPixelBufferLockBaseAddress(pb!, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb!), width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        ctx.draw(makeImage(width: w, height: h, hue: (hue + CGFloat(frame) / CGFloat(seconds * fps)).truncatingRemainder(dividingBy: 1), label: ""), in: CGRect(x: 0, y: 0, width: w, height: h))
        let x = CGFloat(frame % fps) / CGFloat(fps) * CGFloat(w - 60)
        ctx.setFillColor(CGColor(red: 1, green: 0.2, blue: 0.2, alpha: 1))
        ctx.fill(CGRect(x: x, y: 150, width: 60, height: 60))
        CVPixelBufferUnlockBaseAddress(pb!, [])
        adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps)))
    }
    input.markAsFinished()
    await writer.finishWriting()
    print(writer.status == .completed ? "wrote \(name)" : "FAILED \(name): \(String(describing: writer.error))")
}

writeImage("Photos/Beach Day.jpg", .jpeg, hue: 0.55)
writeImage("Photos/Sunset.png", .png, hue: 0.05)
writeImage("Photos/Mountains.heic", .heic, hue: 0.3)
writeImage("Photos/Scan 2019.tiff", .tiff, width: 800, height: 1000, hue: 0.8)
writeImage("Photos/Vacation/Beach Day.jpg", .jpeg, hue: 0.65)   // duplicate name, different folder
writeImage("Photos/Vacation/Café — été 2024 (copie).jpg", .jpeg, hue: 0.15)
writeImage("Photos/Vacation/日本の写真.png", .png, hue: 0.95)
writeImage("Photos/Big Panorama.jpg", .jpeg, width: 8000, height: 3000, hue: 0.4)
try await writeVideo("Videos/Birthday Party.mov", fileType: .mov, seconds: 6, hue: 0.1)
try await writeVideo("Videos/Clips/Dog Running.mp4", fileType: .mp4, seconds: 4, hue: 0.5)
try await writeVideo("Videos/Clips/Short Clip.m4v", fileType: .m4v, seconds: 3, hue: 0.7)
