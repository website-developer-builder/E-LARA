import OSLog
import SwiftUI

private let uiLog = Logger(subsystem: "com.example.MediaHub", category: "ui")

/// Progress of the scan that is currently running.
struct ScanProgress: Equatable {
    var folderName: String
    var phase: Phase
    var found = 0
    var processed = 0
    var toProcess = 0
    var foldersRemaining = 0

    enum Phase { case looking, reading }

    var description: String {
        switch phase {
        case .looking: "Looking in “\(folderName)”… \(found.formatted()) found"
        case .reading: "Reading “\(folderName)”… \(processed.formatted()) of \(toProcess.formatted())"
        }
    }

    var fraction: Double? {
        phase == .reading && toProcess > 0 ? Double(processed) / Double(toProcess) : nil
    }
}

struct AppAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

/// App-wide state. Lives on the main actor; disk and database work happens in services.
@Observable
@MainActor
final class AppModel {
    // MARK: Navigation & view options (remembered between launches)
    var section: SidebarSection = .home { didSet { Preferences.section = section; closeQuickView() } }
    var sort: LibrarySort = .dateAddedNewest { didSet { Preferences.sort = sort } }
    var viewMode: ViewMode = .grid { didSet { Preferences.viewMode = viewMode } }
    var searchText = ""
    var selectedItemID: MediaItem.ID?
    var showInspector = false

    // MARK: Library contents
    var items: [MediaItem] = [] {
        didSet {
            // Large libraries: compute sidebar counts once per change instead of on every redraw.
            resultsCache.removeAll()
            var counts: [SidebarSection: Int] = [:]
            for item in items {
                counts[.allMedia, default: 0] += 1
                switch item.mediaType {
                case .image: counts[.photos, default: 0] += 1
                case .video: counts[.videos, default: 0] += 1
                case .audio: counts[.music, default: 0] += 1
                }
                if item.isFavorite { counts[.favorites, default: 0] += 1 }
            }
            sectionCounts = counts
        }
    }
    private(set) var sectionCounts: [SidebarSection: Int] = [:]
    @ObservationIgnored private var resultsCache: [String: [MediaItem]] = [:]
    var folders: [LibraryFolder] = []
    var isLoaded = false
    var libraryError: String?
    var scanProgress: ScanProgress?
    var alert: AppAlert?

    // MARK: Playback & viewing
    let playback = PlaybackController()
    /// Photo/video currently open in the full-window viewer.
    var viewerItemID: MediaItem.ID?
    /// The results the viewer was opened from, for ← → navigation.
    private var viewerList: [MediaItem.ID] = []

    /// Quick View (Space) shows the selected item in a floating preview over the library.
    var isQuickViewOpen = false {
        didSet { if oldValue != isQuickViewOpen { uiLog.debug("Quick View \(self.isQuickViewOpen ? "opened" : "closed", privacy: .public)") } }
    }
    /// The items Quick View was opened from, for the "3 of 120" counter.
    private(set) var quickViewList: [MediaItem.ID] = []
    @ObservationIgnored private var spacebar = SpacebarPeek()

    private var store: LibraryStore?
    private let access = FolderAccess()
    private var scanTask: Task<Void, Never>?
    private var scanQueue: [Int64] = []
    private var scanningFolderID: Int64?

    init() {
        section = Preferences.section
        sort = Preferences.sort
        viewMode = Preferences.viewMode
        playback.onStart = { [weak self] in self?.recordPlay($0) }
    }

    /// Tests can inject a store at a temporary location.
    init(store: LibraryStore) {
        self.store = store
        playback.onStart = { [weak self] in self?.recordPlay($0) }
    }

    var hasFolders: Bool { !folders.isEmpty }
    var isScanning: Bool { scanProgress != nil }
    var isSearching: Bool { !LibraryQuery.normalized(searchText).isEmpty }

    /// The section whose items are being shown. Typing a search on Home/Settings
    /// searches everything rather than doing nothing.
    var effectiveSection: SidebarSection {
        if isSearching && !section.isLibraryList { return .allMedia }
        return section
    }

    /// Filtered + sorted items for a section. Memoized until items, search, or sort change.
    func results(for section: SidebarSection) -> [MediaItem] {
        let key = "\(section.rawValue)|\(sort.rawValue)|\(LibraryQuery.normalized(searchText))"
        if let cached = resultsCache[key] { return cached }
        let result = LibraryQuery.results(from: items, section: section, search: searchText, sort: sort)
        resultsCache[key] = result
        return result
    }

    func count(for section: SidebarSection) -> Int {
        sectionCounts[section] ?? 0
    }

    var selectedItem: MediaItem? {
        guard let id = selectedItemID else { return nil }
        return items.first { $0.id == id }
    }

    func folder(for item: MediaItem) -> LibraryFolder? {
        folders.first { $0.id == item.folderID }
    }

    var foldersNeedingAttention: [LibraryFolder] { folders.filter { $0.scanStatus.needsAttention } }

    // MARK: Startup

    /// Opens the saved library and restores folder access. Doesn't rescan everything:
    /// only folders whose last scan didn't finish, or that just came back (e.g. a drive was reconnected).
    func start() async {
        guard !isLoaded else { return }
        defer { isLoaded = true }
        Task.detached(priority: .background) { ThumbnailService.shared.trimDiskCache() }
        do {
            if store == nil { store = try LibraryStore(url: try LibraryStore.defaultURL()) }
            try await reload()
        } catch {
            libraryError = error.localizedDescription
            return
        }
        var toScan: [LibraryFolder] = []
        for folder in folders {
            let wasProblem = folder.scanStatus.needsAttention
            if await openAccess(folder), wasProblem || folder.scanStatus != .completed {
                toScan.append(folder)
            }
        }
        try? await reload()
        enqueueScan(toScan)
        observeVolumes()
    }

    // MARK: External drives

    @ObservationIgnored private var volumeObservers: [NSObjectProtocol] = []

    /// When a drive is ejected, its folders are marked unavailable (entries are kept).
    /// When it comes back, those folders are reopened and rescanned.
    private func observeVolumes() {
        guard volumeObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didUnmountNotification, NSWorkspace.didMountNotification] {
            volumeObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let volume = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
                let mounted = note.name == NSWorkspace.didMountNotification
                Task { @MainActor in await self?.volumeChanged(volume.standardizedFileURL.path, mounted: mounted) }
            })
        }
    }

    func volumeChanged(_ volumePath: String, mounted: Bool) async {
        guard let store else { return }
        let prefix = volumePath.hasSuffix("/") ? volumePath : volumePath + "/"
        let affected = folders.filter { $0.path == volumePath || $0.path.hasPrefix(prefix) }
        guard !affected.isEmpty else { return }
        var toScan: [LibraryFolder] = []
        for var folder in affected {
            access.stopAccess(folderID: folder.id)
            if mounted {
                if await openAccess(folder) { toScan.append(folder) }
            } else {
                if scanningFolderID == folder.id { cancelScan() }
                folder.scanStatus = .unavailable
                folder.lastErrorSummary = "The drive “\((volumePath as NSString).lastPathComponent)” was disconnected. Reconnect it to see these files again."
                try? await store.updateFolder(folder)
                try? await store.setAvailability(.unavailable, folderID: folder.id)
            }
        }
        try? await reload()
        enqueueScan(toScan)
    }

    /// Starts sandbox access for a folder and records whether it's reachable.
    @discardableResult
    private func openAccess(_ folder: LibraryFolder) async -> Bool {
        guard let store else { return false }
        var folder = folder
        do {
            let (_, refreshed) = try access.startAccess(for: folder)
            if let refreshed { folder.bookmarkData = refreshed }
            if folder.scanStatus.needsAttention { folder.scanStatus = .idle; folder.lastErrorSummary = nil }
            try? await store.updateFolder(folder)
            return true
        } catch {
            let isMissing = error is MediaScanner.ScanError
            folder.scanStatus = isMissing ? .unavailable : .needsPermission
            folder.lastErrorSummary = error.localizedDescription
            try? await store.updateFolder(folder)
            // Keep the entries — a disconnected drive shouldn't erase the library.
            try? await store.setAvailability(isMissing ? .unavailable : .permissionRequired, folderID: folder.id)
            return false
        }
    }

    func reload() async throws {
        guard let store else { return }
        folders = try await store.allFolders()
        items = try await store.allItems()
    }

    // MARK: Adding and removing folders

    func addFolders() {
        let urls = FolderAccess.chooseFolders()
        guard !urls.isEmpty else { return }
        Task { await add(urls) }
    }

    /// Adds folders the user picked (or dropped), avoiding overlap with folders already in the library.
    func add(_ urls: [URL]) async {
        guard let store else { return }
        var added: [LibraryFolder] = []
        var notes: [String] = []
        for url in urls {
            let path = url.standardizedFileURL.path
            switch FolderOverlap.classify(path, existing: folders.map(\.path) + added.map(\.path)) {
            case .alreadyAdded:
                notes.append("“\(url.lastPathComponent)” is already in your library.")
                continue
            case .insideExisting(let parent):
                notes.append("“\(url.lastPathComponent)” is already included because it's inside “\((parent as NSString).lastPathComponent)”.")
                continue
            case .containsExisting, .independent:
                break
            }
            do {
                let bookmark = try FolderAccess.makeBookmark(for: url)
                let folder = try await store.addFolder(path: path, displayName: url.lastPathComponent, bookmark: bookmark)
                access.adopt(url, for: folder.id)
                // A parent folder replaces any child folders already in the library (keeps their favorites).
                if case .containsExisting(let childPaths) = FolderOverlap.classify(path, existing: folders.map(\.path)) {
                    let childIDs = folders.filter { childPaths.contains($0.path) }.map(\.id)
                    try await store.absorbFolders(childIDs, into: folder.id)
                    childIDs.forEach(access.stopAccess(folderID:))
                }
                added.append(folder)
            } catch {
                notes.append("Couldn't add “\(url.lastPathComponent)”: \(error.localizedDescription)")
            }
        }
        try? await reload()
        if !added.isEmpty, section == .settings || !hasFolders { section = .home }
        enqueueScan(added)
        if !notes.isEmpty {
            alert = AppAlert(title: added.isEmpty ? "Nothing new to add" : "Some folders were skipped",
                             message: notes.joined(separator: "\n"))
        }
    }

    /// Removes a folder from the library. The folder and its files on disk are not touched.
    func removeFolder(_ folder: LibraryFolder) async {
        guard let store else { return }
        if scanningFolderID == folder.id { cancelScan() }
        scanQueue.removeAll { $0 == folder.id }
        access.stopAccess(folderID: folder.id)
        do {
            try await store.removeFolder(id: folder.id)
            try await reload()
        } catch {
            alert = AppAlert(title: "Couldn't remove folder", message: error.localizedDescription)
        }
        if let id = selectedItemID, !items.contains(where: { $0.id == id }) { selectedItemID = nil }
    }

    /// Lets the user pick a folder again after permission was lost or it moved.
    func regrantAccess(_ folder: LibraryFolder) {
        let parent = URL(fileURLWithPath: folder.path).deletingLastPathComponent()
        guard let url = FolderAccess.chooseFolders(startingAt: parent, allowsMultiple: false, prompt: "Grant Access").first,
              let store else { return }
        Task {
            var updated = folder
            do {
                updated.bookmarkData = try FolderAccess.makeBookmark(for: url)
                updated.path = url.standardizedFileURL.path
                updated.displayName = url.lastPathComponent
                updated.scanStatus = .idle
                updated.lastErrorSummary = nil
                access.stopAccess(folderID: folder.id)
                access.adopt(url, for: folder.id)
                try await store.updateFolder(updated)
                try await reload()
                enqueueScan([updated])
            } catch {
                alert = AppAlert(title: "Couldn't restore access", message: error.localizedDescription)
            }
        }
    }

    // MARK: Scanning

    func rescanAll() { enqueueScan(folders) }

    func rescan(_ folder: LibraryFolder) { enqueueScan([folder]) }

    func cancelScan() {
        scanQueue.removeAll()
        scanTask?.cancel()
    }

    private func enqueueScan(_ toScan: [LibraryFolder]) {
        for f in toScan where !scanQueue.contains(f.id) { scanQueue.append(f.id) }
        guard scanTask == nil, !scanQueue.isEmpty else { return }
        scanTask = Task {
            while !Task.isCancelled, !scanQueue.isEmpty {
                let id = scanQueue.removeFirst()
                if let folder = folders.first(where: { $0.id == id }) {
                    scanningFolderID = id
                    await scanFolder(folder)
                    scanningFolderID = nil
                }
            }
            scanProgress = nil
            scanTask = nil
            try? await reload()
            // Something may have been queued right as we were finishing.
            if !scanQueue.isEmpty { enqueueScan([]) }
        }
    }

    /// Scans one folder: list files → read metadata for new/changed ones → save in batches →
    /// remove entries for deleted files (only if the scan finished completely).
    private func scanFolder(_ folder: LibraryFolder) async {
        guard let store else { return }
        var folder = folder
        scanProgress = ScanProgress(folderName: folder.displayName, phase: .looking, foldersRemaining: scanQueue.count)

        guard await openAccess(folder) else { try? await reload(); return }
        folder = (try? await store.allFolders().first { $0.id == folder.id }) ?? folder
        folder.scanStatus = .scanning
        folder.lastScanStartedAt = Date()
        try? await store.updateFolder(folder)
        updateFolderInMemory(folder)

        do {
            let stamps = try await store.fileStamps(folderID: folder.id)
            let files = try await MediaScanner.enumerateInBackground(root: folder.url) { count in
                Task { @MainActor [weak self] in self?.scanProgress?.found = count }
            }
            try Task.checkCancellation()

            let changed = MediaScanner.changedFiles(files, comparedTo: stamps)
            scanProgress?.phase = .reading
            scanProgress?.found = files.count
            scanProgress?.toProcess = changed.count

            var sinceReload = 0
            for start in stride(from: 0, to: changed.count, by: 100) {
                try Task.checkCancellation()
                let batch = Array(changed[start..<min(start + 100, changed.count)])
                let enriched = await MetadataService.enrich(batch)
                try await store.upsert(enriched, folderID: folder.id)
                scanProgress?.processed += batch.count
                sinceReload += batch.count
                if sinceReload >= 500 { try await reload(); sinceReload = 0 }
            }
            try Task.checkCancellation()

            // The scan saw everything, so anything not seen really is gone.
            try await store.reconcile(folderID: folder.id, seenPaths: Set(files.map(\.path)))
            folder.scanStatus = .completed
            folder.lastSuccessfulScanAt = Date()
            folder.lastErrorSummary = nil
        } catch is CancellationError {
            // Partial results are kept; nothing is treated as deleted.
            folder.scanStatus = .cancelled
        } catch let error as MediaScanner.ScanError {
            folder.scanStatus = .unavailable
            folder.lastErrorSummary = error.localizedDescription
            try? await store.setAvailability(.unavailable, folderID: folder.id)
        } catch {
            folder.scanStatus = .failed
            folder.lastErrorSummary = error.localizedDescription
        }
        try? await store.updateFolder(folder)
        try? await reload()
    }

    private func updateFolderInMemory(_ folder: LibraryFolder) {
        if let i = folders.firstIndex(where: { $0.id == folder.id }) { folders[i] = folder }
    }

    // MARK: Item actions

    /// Opens a photo or video in the viewer, or plays a song (queueing the songs around it).
    func open(_ item: MediaItem) {
        selectedItemID = item.id
        guard ensureExists(item) else { return }
        let visible = results(for: effectiveSection)
        switch item.mediaType {
        case .audio:
            closeViewer()
            playback.play(item, queue: visible.filter { $0.mediaType == .audio && $0.isAvailable })
        case .image, .video:
            // ← → in the viewer step through everything shown, songs included.
            viewerList = visible.map(\.id)
            if !viewerList.contains(item.id) { viewerList = [item.id] }
            viewerItemID = item.id
        }
        closeQuickView()
    }

    var viewerItem: MediaItem? {
        guard let id = viewerItemID else { return nil }
        return items.first { $0.id == id }
    }

    var viewerPosition: (index: Int, count: Int)? {
        guard let id = viewerItemID, let i = viewerList.firstIndex(of: id) else { return nil }
        return (i, viewerList.count)
    }

    func stepViewer(by delta: Int) {
        guard let position = viewerPosition else { return }
        let next = position.index + delta
        guard viewerList.indices.contains(next) else { return }
        viewerItemID = viewerList[next]
        selectedItemID = viewerItemID
    }

    func closeViewer() {
        viewerItemID = nil
    }

    // MARK: Quick View

    var quickViewItem: MediaItem? { isQuickViewOpen ? selectedItem : nil }

    var quickViewPosition: (index: Int, count: Int)? {
        guard let id = selectedItemID, let i = quickViewList.firstIndex(of: id) else { return nil }
        return (i, quickViewList.count)
    }

    func openQuickView(in items: [MediaItem]) {
        if selectedItem == nil, let first = items.first { selectedItemID = first.id }
        guard selectedItem != nil else { return }
        quickViewList = items.map(\.id)
        isQuickViewOpen = true
    }

    func closeQuickView() {
        isQuickViewOpen = false
        spacebar.reset()
    }

    /// Space pressed or released over a list of items. Returns true if it was handled.
    /// Tap = toggle Quick View; hold = peek until release. With nothing to preview,
    /// Space falls back to play/pause for music that's already loaded.
    func handleSpace(down: Bool, in items: [MediaItem], at time: Date = Date()) -> Bool {
        if down {
            if !isQuickViewOpen && selectedItem == nil && items.isEmpty {
                guard playback.current != nil else { return false }
                playback.togglePlayPause()
                return true
            }
            switch spacebar.keyDown(isOpen: isQuickViewOpen, at: time) {
            case .open: openQuickView(in: items)
            case .close: isQuickViewOpen = false
            case .none: break
            }
        } else if spacebar.keyUp(isOpen: isQuickViewOpen, at: time) == .close {
            isQuickViewOpen = false
        }
        return true
    }

    /// Arrow keys: moves the selection (and Quick View, if open) through `items`.
    @discardableResult
    func moveSelection(by step: Int, in items: [MediaItem]) -> MediaItem.ID? {
        let current = items.firstIndex { $0.id == selectedItemID }
        guard let next = SelectionMover.index(from: current, step: step, count: items.count) else { return nil }
        selectedItemID = items[next].id
        if isQuickViewOpen, !quickViewList.contains(items[next].id) { quickViewList = items.map(\.id) }
        return selectedItemID
    }

    /// Reveals the original file in Finder, or explains why it can't.
    func showInFinder(_ item: MediaItem) {
        guard ensureExists(item) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    /// Checks the file is still there right before using it; if not, says so and marks it.
    func ensureExists(_ item: MediaItem) -> Bool {
        if FileManager.default.fileExists(atPath: item.path) { return true }
        let folder = folder(for: item)
        let reason = folder?.scanStatus == .unavailable || folder?.scanStatus == .needsPermission
            ? (folder?.lastErrorSummary ?? item.availability.userDescription)
            : "“\(item.fileName)” isn't in its folder anymore. It may have been moved, renamed, or deleted. Rescan to update your library."
        if item.availability == .available { markMissing(item) }
        alert = AppAlert(title: "File not found", message: reason)
        return false
    }

    func toggleFavorite(_ item: MediaItem) {
        guard let store, let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].isFavorite.toggle()
        let value = items[i].isFavorite
        Task { try? await store.setFavorite(value, itemID: item.id) }
    }

    func recordPlay(_ item: MediaItem) {
        guard let store, let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        let now = Date()
        items[i].lastPlayedAt = now
        items[i].playCount += 1
        Task { try? await store.recordPlay(itemID: item.id, at: now) }
    }

    /// Marks one item missing when we discover its file is gone (e.g. when trying to open it).
    func markMissing(_ item: MediaItem) {
        guard let store, let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].availability = .missing
        Task { try? await store.setAvailability(.missing, itemID: item.id) }
    }

    func shutdown() {
        volumeObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        volumeObservers.removeAll()
        scanTask?.cancel()
        access.stopAll()
    }
}

/// Small wrapper over UserDefaults for remembered UI choices.
enum Preferences {
    private static let defaults = UserDefaults.standard

    static var section: SidebarSection {
        get { defaults.string(forKey: "section").flatMap(SidebarSection.init(rawValue:)) ?? .home }
        set { defaults.set(newValue.rawValue, forKey: "section") }
    }
    static var sort: LibrarySort {
        get { defaults.string(forKey: "sort").flatMap(LibrarySort.init(rawValue:)) ?? .dateAddedNewest }
        set { defaults.set(newValue.rawValue, forKey: "sort") }
    }
    static var viewMode: ViewMode {
        get { defaults.string(forKey: "viewMode").flatMap(ViewMode.init(rawValue:)) ?? .grid }
        set { defaults.set(newValue.rawValue, forKey: "viewMode") }
    }
}
