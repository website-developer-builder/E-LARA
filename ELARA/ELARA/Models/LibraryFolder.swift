import Foundation

enum ScanStatus: String, Codable, Sendable {
    case idle, scanning, completed, failed, cancelled, needsPermission, unavailable

    var userDescription: String {
        switch self {
        case .idle: "Not scanned yet"
        case .scanning: "Scanning…"
        case .completed: "Up to date"
        case .failed: "Scan failed"
        case .cancelled: "Scan cancelled"
        case .needsPermission: "Needs permission"
        case .unavailable: "Not reachable"
        }
    }

    var needsAttention: Bool {
        switch self {
        case .failed, .needsPermission, .unavailable: true
        default: false
        }
    }
}

/// A folder the user chose to include in the library.
struct LibraryFolder: Identifiable, Hashable, Sendable {
    var id: Int64
    var path: String
    var displayName: String
    /// Security-scoped bookmark so we can reopen the folder after relaunch (sandbox).
    var bookmarkData: Data?
    var lastScanStartedAt: Date?
    var lastSuccessfulScanAt: Date?
    var scanStatus: ScanStatus
    var lastErrorSummary: String?
    var isEnabled: Bool

    var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
}
