import Foundation

/// Sidebar destinations.
enum SidebarSection: String, CaseIterable, Identifiable, Codable {
    case home, allMedia, photos, videos, music, favorites, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .allMedia: "All Media"
        case .photos: "Photos"
        case .videos: "Videos"
        case .music: "Music"
        case .favorites: "Favorites"
        case .settings: "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .home: "Recently added and recently played."
        case .allMedia: "Every photo, video, and song in your library."
        case .photos: "Pictures from your folders."
        case .videos: "Movies and clips from your folders."
        case .music: "Songs and audio from your folders."
        case .favorites: "Items you've marked with a heart."
        case .settings: "Folders, privacy, and app info."
        }
    }

    var symbolName: String {
        switch self {
        case .home: "house"
        case .allMedia: "square.grid.2x2"
        case .photos: "photo.on.rectangle"
        case .videos: "film"
        case .music: "music.note"
        case .favorites: "heart"
        case .settings: "gearshape"
        }
    }

    /// Restricts the section to one media type, if applicable.
    var mediaType: MediaType? {
        switch self {
        case .photos: .image
        case .videos: .video
        case .music: .audio
        default: nil
        }
    }

    var isLibraryList: Bool {
        switch self {
        case .allMedia, .photos, .videos, .music, .favorites: true
        default: false
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable, Codable {
    case dateAddedNewest, nameAscending, nameDescending, dateModifiedNewest, sizeLargest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateAddedNewest: "Recently Added"
        case .nameAscending: "Name (A–Z)"
        case .nameDescending: "Name (Z–A)"
        case .dateModifiedNewest: "Date Modified"
        case .sizeLargest: "Largest First"
        }
    }
}

enum ViewMode: String, CaseIterable, Codable {
    case grid, list
}

/// Pure filtering/sorting logic, kept separate from the UI so it can be unit-tested.
enum LibraryQuery {
    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func results(
        from items: [MediaItem],
        section: SidebarSection,
        search: String,
        sort: LibrarySort
    ) -> [MediaItem] {
        let query = normalized(search)
        let filtered = items.filter { item in
            if let type = section.mediaType, item.mediaType != type { return false }
            if section == .favorites, !item.isFavorite { return false }
            if !query.isEmpty, !matches(item, query: query) { return false }
            return true
        }
        return sorted(filtered, by: sort)
    }

    /// Case- and diacritic-insensitive filename match (extension included, so "mp3" works).
    static func matches(_ item: MediaItem, query: String) -> Bool {
        item.fileName.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    static func sorted(_ items: [MediaItem], by sort: LibrarySort) -> [MediaItem] {
        items.sorted { a, b in
            switch sort {
            case .dateAddedNewest:
                if a.dateAddedToLibrary != b.dateAddedToLibrary { return a.dateAddedToLibrary > b.dateAddedToLibrary }
            case .nameAscending:
                let r = a.fileName.localizedStandardCompare(b.fileName)
                if r != .orderedSame { return r == .orderedAscending }
            case .nameDescending:
                let r = a.fileName.localizedStandardCompare(b.fileName)
                if r != .orderedSame { return r == .orderedDescending }
            case .dateModifiedNewest:
                let da = a.dateModified ?? .distantPast, db = b.dateModified ?? .distantPast
                if da != db { return da > db }
            case .sizeLargest:
                if a.fileSizeBytes != b.fileSizeBytes { return a.fileSizeBytes > b.fileSizeBytes }
            }
            return a.id < b.id // Stable tie-breaker.
        }
    }

    static func recentlyAdded(_ items: [MediaItem], limit: Int = 12) -> [MediaItem] {
        Array(sorted(items, by: .dateAddedNewest).prefix(limit))
    }

    static func recentlyPlayed(_ items: [MediaItem], limit: Int = 12) -> [MediaItem] {
        Array(items.filter { $0.lastPlayedAt != nil }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
            .prefix(limit))
    }
}
