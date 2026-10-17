import XCTest
@testable import ELARA

final class SpacebarPeekTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1000)

    func testTapOpensAndStaysOpen() {
        var s = SpacebarPeek()
        XCTAssertEqual(s.keyDown(isOpen: false, at: t0), .open)
        XCTAssertEqual(s.keyUp(isOpen: true, at: t0.addingTimeInterval(0.1)), .none, "quick tap keeps it open")
    }

    func testSecondTapCloses() {
        var s = SpacebarPeek()
        _ = s.keyDown(isOpen: false, at: t0); _ = s.keyUp(isOpen: true, at: t0.addingTimeInterval(0.1))
        XCTAssertEqual(s.keyDown(isOpen: true, at: t0.addingTimeInterval(1)), .close)
        XCTAssertEqual(s.keyUp(isOpen: false, at: t0.addingTimeInterval(1.1)), .none)
    }

    func testHoldPeeksAndClosesOnRelease() {
        var s = SpacebarPeek()
        XCTAssertEqual(s.keyDown(isOpen: false, at: t0), .open)
        XCTAssertEqual(s.keyUp(isOpen: true, at: t0.addingTimeInterval(0.8)), .close)
    }

    func testHoldingSpaceToCloseDoesNotReopen() {
        var s = SpacebarPeek()
        XCTAssertEqual(s.keyDown(isOpen: true, at: t0), .close)
        XCTAssertEqual(s.keyUp(isOpen: false, at: t0.addingTimeInterval(2)), .none)
    }

    func testRepeatedKeyDownWithoutUpIsIgnored() {
        var s = SpacebarPeek()
        XCTAssertEqual(s.keyDown(isOpen: false, at: t0), .open)
        XCTAssertEqual(s.keyDown(isOpen: true, at: t0.addingTimeInterval(0.05)), .none)
    }
}

final class SelectionMoverTests: XCTestCase {
    func testMovesAndClamps() {
        XCTAssertEqual(SelectionMover.index(from: 2, step: 1, count: 5), 3)
        XCTAssertEqual(SelectionMover.index(from: 4, step: 1, count: 5), 4)
        XCTAssertEqual(SelectionMover.index(from: 0, step: -1, count: 5), 0)
        XCTAssertEqual(SelectionMover.index(from: 1, step: 4, count: 10), 5)   // ↓ in a 4-column grid
        XCTAssertEqual(SelectionMover.index(from: 2, step: -4, count: 10), 0)  // ↑ clamps to first
    }

    func testNoSelectionStartsAtAnEnd() {
        XCTAssertEqual(SelectionMover.index(from: nil, step: 1, count: 5), 0)
        XCTAssertEqual(SelectionMover.index(from: nil, step: -1, count: 5), 4)
        XCTAssertNil(SelectionMover.index(from: nil, step: 1, count: 0))
    }
}

@MainActor
final class QuickViewModelTests: XCTestCase {
    private func items() -> [MediaItem] {
        [(1, MediaType.image), (2, .video), (3, .audio), (4, .image)].map { id, type in
            MediaItem(id: Int64(id), path: "/tmp/\(id)", fileName: "\(id)", fileExtension: "x", mediaType: type,
                      fileSizeBytes: 1, dateAddedToLibrary: Date(), isFavorite: false, playCount: 0,
                      availability: .available, folderID: 1)
        }
    }

    private func model() throws -> AppModel {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("qv-\(UUID().uuidString).sqlite")
        let m = AppModel(store: try LibraryStore(url: url))
        m.items = items()
        return m
    }

    func testSpaceTapOpensQuickViewOnSelectionAndArrowsMoveAcrossTypes() throws {
        let m = try model(), list = items()
        m.selectedItemID = 1
        let t = Date()
        XCTAssertTrue(m.handleSpace(down: true, in: list, at: t))
        XCTAssertTrue(m.handleSpace(down: false, in: list, at: t.addingTimeInterval(0.1)))
        XCTAssertTrue(m.isQuickViewOpen)
        XCTAssertEqual(m.quickViewItem?.id, 1)
        XCTAssertEqual(m.quickViewPosition?.index, 0)
        XCTAssertEqual(m.quickViewPosition?.count, 4)

        m.moveSelection(by: 1, in: list)   // → video
        XCTAssertEqual(m.quickViewItem?.mediaType, .video)
        m.moveSelection(by: 1, in: list)   // → audio
        XCTAssertEqual(m.quickViewItem?.mediaType, .audio)
        m.moveSelection(by: 10, in: list)  // clamps at the end
        XCTAssertEqual(m.quickViewItem?.id, 4)
        m.moveSelection(by: -1, in: list)
        XCTAssertEqual(m.quickViewPosition?.index, 2)

        _ = m.handleSpace(down: true, in: list, at: t.addingTimeInterval(2))
        _ = m.handleSpace(down: false, in: list, at: t.addingTimeInterval(2.1))
        XCTAssertFalse(m.isQuickViewOpen)
        XCTAssertEqual(m.selectedItemID, 3, "closing keeps the selection")
    }

    func testHoldSpacePeeks() throws {
        let m = try model(), list = items()
        m.selectedItemID = 2
        let t = Date()
        _ = m.handleSpace(down: true, in: list, at: t)
        XCTAssertTrue(m.isQuickViewOpen)
        m.moveSelection(by: 1, in: list) // browsing while holding
        _ = m.handleSpace(down: false, in: list, at: t.addingTimeInterval(1))
        XCTAssertFalse(m.isQuickViewOpen)
        XCTAssertEqual(m.selectedItemID, 3)
    }

    func testSpaceWithNoSelectionPreviewsFirstItem() throws {
        let m = try model(), list = items()
        _ = m.handleSpace(down: true, in: list)
        XCTAssertEqual(m.quickViewItem?.id, 1)
    }

    func testSpaceIgnoredWhenNothingToShowOrPlay() throws {
        let m = try model()
        XCTAssertFalse(m.handleSpace(down: true, in: []))
        XCTAssertFalse(m.isQuickViewOpen)
    }

    func testChangingSectionOrOpeningClosesQuickView() throws {
        let m = try model(), list = items()
        m.selectedItemID = 1
        m.openQuickView(in: list)
        m.section = .music
        XCTAssertFalse(m.isQuickViewOpen)
    }
}
