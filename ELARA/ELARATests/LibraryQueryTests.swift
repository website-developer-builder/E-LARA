import XCTest
@testable import ELARA

final class LibraryQueryTests: XCTestCase {
    private func item(_ id: Int64, _ name: String, _ type: MediaType, size: Int64 = 100,
                      added: TimeInterval = 0, modified: TimeInterval = 0, favorite: Bool = false,
                      played: Date? = nil) -> MediaItem {
        MediaItem(id: id, path: "/tmp/\(name)", fileName: name, fileExtension: (name as NSString).pathExtension.lowercased(),
                  mediaType: type, fileSizeBytes: size, dateCreated: nil,
                  dateModified: Date(timeIntervalSince1970: modified),
                  dateAddedToLibrary: Date(timeIntervalSince1970: added),
                  durationSeconds: nil, width: nil, height: nil, isFavorite: favorite,
                  lastPlayedAt: played, playCount: 0, availability: .available, folderID: 1)
    }

    private lazy var sample: [MediaItem] = [
        item(1, "Beach Day.jpg", .image, size: 500, added: 10, modified: 30),
        item(2, "beach-song.mp3", .audio, size: 900, added: 20, modified: 10, favorite: true),
        item(3, "Birthday.MOV", .video, size: 9000, added: 30, modified: 20),
        item(4, "Café Noir.m4a", .audio, size: 50, added: 5, modified: 5),
    ]

    func testSectionFiltersByType() {
        XCTAssertEqual(LibraryQuery.results(from: sample, section: .photos, search: "", sort: .nameAscending).map(\.id), [1])
        XCTAssertEqual(LibraryQuery.results(from: sample, section: .videos, search: "", sort: .nameAscending).map(\.id), [3])
        XCTAssertEqual(Set(LibraryQuery.results(from: sample, section: .music, search: "", sort: .nameAscending).map(\.id)), [2, 4])
        XCTAssertEqual(LibraryQuery.results(from: sample, section: .allMedia, search: "", sort: .nameAscending).count, 4)
        XCTAssertEqual(LibraryQuery.results(from: sample, section: .favorites, search: "", sort: .nameAscending).map(\.id), [2])
    }

    func testSearchIsCaseInsensitiveTrimmedAndAcrossTypes() {
        let r = LibraryQuery.results(from: sample, section: .allMedia, search: "  BEACH ", sort: .nameAscending)
        XCTAssertEqual(Set(r.map(\.id)), [1, 2])
    }

    func testSearchMatchesExtensionAndDiacritics() {
        XCTAssertEqual(LibraryQuery.results(from: sample, section: .allMedia, search: "mov", sort: .nameAscending).map(\.id), [3])
        XCTAssertEqual(LibraryQuery.results(from: sample, section: .allMedia, search: "cafe", sort: .nameAscending).map(\.id), [4])
    }

    func testSearchKeepsSectionFilter() {
        XCTAssertEqual(LibraryQuery.results(from: sample, section: .photos, search: "beach", sort: .nameAscending).map(\.id), [1])
    }

    func testNoResults() {
        XCTAssertTrue(LibraryQuery.results(from: sample, section: .allMedia, search: "zzz", sort: .nameAscending).isEmpty)
    }

    func testSorts() {
        XCTAssertEqual(LibraryQuery.sorted(sample, by: .dateAddedNewest).map(\.id), [3, 2, 1, 4])
        XCTAssertEqual(LibraryQuery.sorted(sample, by: .dateModifiedNewest).map(\.id), [1, 3, 2, 4])
        XCTAssertEqual(LibraryQuery.sorted(sample, by: .sizeLargest).map(\.id), [3, 2, 1, 4])
        XCTAssertEqual(LibraryQuery.sorted(sample, by: .nameAscending).map(\.id), [1, 2, 3, 4])
        XCTAssertEqual(LibraryQuery.sorted(sample, by: .nameDescending).map(\.id), [4, 3, 2, 1])
    }

    func testRecentlyPlayedOnlyIncludesPlayedItems() {
        var items = sample
        items[0].lastPlayedAt = Date(timeIntervalSince1970: 100)
        items[2].lastPlayedAt = Date(timeIntervalSince1970: 200)
        XCTAssertEqual(LibraryQuery.recentlyPlayed(items).map(\.id), [3, 1])
        XCTAssertTrue(LibraryQuery.recentlyPlayed(sample).isEmpty)
    }

    func testClassification() {
        XCTAssertEqual(MediaType.classify(fileExtension: "JPG"), .image)
        XCTAssertEqual(MediaType.classify(fileExtension: "heic"), .image)
        XCTAssertEqual(MediaType.classify(fileExtension: "mov"), .video)
        XCTAssertEqual(MediaType.classify(fileExtension: "mp3"), .audio)
        XCTAssertNil(MediaType.classify(fileExtension: "pdf"))
        XCTAssertNil(MediaType.classify(fileExtension: "txt"))
        XCTAssertNil(MediaType.classify(fileExtension: ""))
    }

    func testDurationFormatting() {
        XCTAssertEqual(Format.duration(65), "1:05")
        XCTAssertEqual(Format.duration(3725), "1:02:05")
        XCTAssertEqual(Format.duration(.nan), "--:--")
    }
}
