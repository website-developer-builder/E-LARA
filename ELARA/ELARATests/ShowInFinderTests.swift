import XCTest
@testable import ELARA

final class ShowInFinderTests: XCTestCase {
    private func target(_ path: String, root: String?, existing: Set<String>) -> AppModel.FinderTarget {
        AppModel.finderTarget(forFileAt: path, libraryFolder: root, exists: { existing.contains($0) })
    }

    func testExistingFileIsRevealedItself() {
        XCTAssertEqual(target("/Lib/Trip/a.jpg", root: "/Lib", existing: ["/Lib", "/Lib/Trip", "/Lib/Trip/a.jpg"]),
                       .file("/Lib/Trip/a.jpg"))
    }

    func testDeletedFileOpensItsFolder() {
        XCTAssertEqual(target("/Lib/Trip/a.jpg", root: "/Lib", existing: ["/Lib", "/Lib/Trip"]),
                       .formerFolder("/Lib/Trip"))
    }

    func testDeletedSubfolderFallsBackToNearestExistingParent() {
        XCTAssertEqual(target("/Lib/2024/Trip/a.jpg", root: "/Lib", existing: ["/Lib"]),
                       .formerFolder("/Lib"))
    }

    func testDisconnectedDriveHasNothingToShow() {
        XCTAssertEqual(target("/Volumes/Drive/Media/a.mov", root: "/Volumes/Drive/Media", existing: ["/Volumes"]),
                       .unavailable, "never walk above the folder the user added")
    }

    func testUnknownLibraryFolderHasNothingToShow() {
        XCTAssertEqual(target("/Lib/a.jpg", root: nil, existing: ["/Lib"]), .unavailable)
    }

    func testRealFileOnDisk() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Finder-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("photo.jpg")
        try Data([1]).write(to: file)
        XCTAssertEqual(AppModel.finderTarget(forFileAt: file.path, libraryFolder: dir.path), .file(file.path))
        try FileManager.default.removeItem(at: file)
        XCTAssertEqual(AppModel.finderTarget(forFileAt: file.path, libraryFolder: dir.path),
                       .formerFolder(dir.standardizedFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path), "never deletes anything")
    }
}
