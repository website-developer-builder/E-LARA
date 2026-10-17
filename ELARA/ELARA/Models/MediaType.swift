import Foundation
import UniformTypeIdentifiers

/// The three kinds of media E-LARA shows.
enum MediaType: String, CaseIterable, Codable, Sendable {
    case image
    case video
    case audio

    var displayName: String {
        switch self {
        case .image: "Photo"
        case .video: "Video"
        case .audio: "Music"
        }
    }

    var symbolName: String {
        switch self {
        case .image: "photo"
        case .video: "film"
        case .audio: "music.note"
        }
    }

    /// File extensions we recognise. Kept deliberately conservative: only formats macOS
    /// can open natively (Image I/O and AVFoundation). See README "Supported formats".
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tif", "tiff", "bmp", "webp",
        "dng", "cr2", "cr3", "nef", "arw", "orf", "raf", "rw2",
    ]
    static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "3gp"]
    static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "amr"]

    /// Classifies a file by extension, falling back to its Uniform Type.
    /// Returns nil for anything that isn't a photo, video, or audio file.
    static func classify(fileExtension ext: String) -> MediaType? {
        let ext = ext.lowercased()
        if imageExtensions.contains(ext) { return .image }
        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return nil }
        // Fallbacks for less common extensions macOS still knows about.
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .audio) { return .audio }
        return nil
    }
}
