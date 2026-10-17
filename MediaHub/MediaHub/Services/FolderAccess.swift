import AppKit
import Foundation

/// Handles the sandbox side of folder access.
///
/// MediaHub runs in the App Sandbox, so it can only read folders the user picks in the
/// Open panel. To keep that access after the app quits, we save a *security-scoped bookmark*
/// for each folder. On launch we resolve the bookmark and call
/// `startAccessingSecurityScopedResource()`, which re-opens access to the folder (and every
/// file inside it) until we call `stopAccessingSecurityScopedResource()`.
///
/// MediaHub keeps access open while a folder is in the library — thumbnails and playback can
/// touch any file at any time — and stops it when the folder is removed or the app quits.
@MainActor
final class FolderAccess {
    private var active: [Int64: URL] = [:]

    enum AccessError: Error, LocalizedError {
        case bookmarkInvalid
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .bookmarkInvalid: "MediaHub lost permission to this folder. Choose it again to restore access."
            case .accessDenied: "macOS didn't allow MediaHub to open this folder. Choose it again to restore access."
            }
        }
    }

    /// Creates a read-only bookmark for a URL the user just picked in the Open panel.
    static func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                             includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Resolves a folder's bookmark and starts access.
    /// Returns the folder's current URL and, if the bookmark was stale, a refreshed bookmark to save.
    func startAccess(for folder: LibraryFolder) throws -> (url: URL, refreshedBookmark: Data?) {
        if let url = active[folder.id] { return (url, nil) }
        guard let data = folder.bookmarkData else { throw AccessError.bookmarkInvalid }
        var stale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        } catch {
            // Typically: the drive holding the folder isn't connected, or the folder was deleted.
            if !FileManager.default.fileExists(atPath: folder.path) {
                throw MediaScanner.ScanError.folderMissing(folder.displayName)
            }
            throw AccessError.bookmarkInvalid
        }
        guard url.startAccessingSecurityScopedResource() else { throw AccessError.accessDenied }
        active[folder.id] = url
        // A stale bookmark still works this time; replace it so it keeps working.
        let refreshed = stale ? try? Self.makeBookmark(for: url) : nil
        return (url, refreshed)
    }

    /// Takes over access that the Open panel already granted for a freshly picked URL.
    func adopt(_ url: URL, for folderID: Int64) {
        if active[folderID] == nil, url.startAccessingSecurityScopedResource() {
            active[folderID] = url
        }
    }

    func stopAccess(folderID: Int64) {
        active.removeValue(forKey: folderID)?.stopAccessingSecurityScopedResource()
    }

    func stopAll() {
        for url in active.values { url.stopAccessingSecurityScopedResource() }
        active.removeAll()
    }

    /// Shows the standard macOS folder picker. Returns the chosen folders (empty if cancelled).
    static func chooseFolders(startingAt directory: URL? = nil, allowsMultiple: Bool = true,
                              prompt: String = "Add to Library") -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = allowsMultiple
        panel.canCreateDirectories = false
        panel.prompt = prompt
        panel.message = "Choose folders with photos, videos, or music. \(AppConfig.appName) will only read them — your files won't be moved or changed."
        panel.directoryURL = directory
        return panel.runModal() == .OK ? panel.urls : []
    }
}
