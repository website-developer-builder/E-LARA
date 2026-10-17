import XCTest
@testable import ELARA

/// The app was renamed MediaHub → E-LARA. Existing users must keep their library.
final class RenameMigrationTests: XCTestCase {
    private var parent: URL!

    override func setUpWithError() throws {
        parent = FileManager.default.temporaryDirectory.appendingPathComponent("Rename-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: parent) }

    func testLegacyLibraryIsMovedToNewFolder() async throws {
        let legacy = parent.appendingPathComponent("MediaHub")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        let store = try LibraryStore(url: legacy.appendingPathComponent("Library.sqlite"))
        _ = try await store.addFolder(path: "/x", displayName: "x", bookmark: nil)

        let destination = parent.appendingPathComponent(AppConfig.appName)
        LibraryStore.moveLegacyFolder(named: "MediaHub", in: parent, to: destination)

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        let moved = try LibraryStore(url: destination.appendingPathComponent("Library.sqlite"))
        let folders = try await moved.allFolders()
        XCTAssertEqual(folders.map(\.path), ["/x"], "library content survives the rename")
    }

    func testDoesNotOverwriteExistingNewFolder() throws {
        let legacy = parent.appendingPathComponent("MediaHub")
        let destination = parent.appendingPathComponent(AppConfig.appName)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: destination.appendingPathComponent("keep.txt"))

        LibraryStore.moveLegacyFolder(named: "MediaHub", in: parent, to: destination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path), "old folder left alone")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("keep.txt").path))
    }

    func testNameIsELARA() {
        XCTAssertEqual(AppConfig.appName, "E-LARA")
        XCTAssertEqual(Bundle.main.infoDictionary?["CFBundleName"] as? String, "E-LARA")
    }
}
