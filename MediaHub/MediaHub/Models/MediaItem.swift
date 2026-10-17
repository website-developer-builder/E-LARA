import Foundation

/// Whether the original file can currently be opened.
enum Availability: String, Codable, Sendable {
    case available
    case missing            // File no longer found at its last known location.
    case permissionRequired // Its folder needs to be granted again.
    case unavailable        // Folder or drive is not reachable right now (e.g. ejected drive).

    var userDescription: String {
        switch self {
        case .available: "Available"
        case .missing: "Missing — the file may have been moved or deleted"
        case .permissionRequired: "MediaHub needs permission to open this folder again"
        case .unavailable: "Not reachable — the drive may be disconnected"
        }
    }
}

/// One indexed photo, video, or audio file. Points at the original — never a copy.
struct MediaItem: Identifiable, Hashable, Sendable {
    var id: Int64
    var path: String
    var fileName: String
    var fileExtension: String
    var mediaType: MediaType
    var fileSizeBytes: Int64
    var dateCreated: Date?
    var dateModified: Date?
    var dateAddedToLibrary: Date
    var durationSeconds: Double?
    var width: Int?
    var height: Int?
    var isFavorite: Bool
    var lastPlayedAt: Date?
    var playCount: Int
    var availability: Availability
    var folderID: Int64

    var url: URL { URL(fileURLWithPath: path) }

    /// Filename without the extension, used as the card title.
    var displayName: String { (fileName as NSString).deletingPathExtension }

    var folderPath: String { (path as NSString).deletingLastPathComponent }

    var isAvailable: Bool { availability == .available }
}
