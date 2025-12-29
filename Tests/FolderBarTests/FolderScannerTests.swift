@testable import FolderBarCore
import XCTest

final class FolderScannerTests: XCTestCase {
    func testScanReturnsImmediateChildrenSortedByCreationDate() throws {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let fileA = tempDirectory.appendingPathComponent("A.txt")
        let fileB = tempDirectory.appendingPathComponent("B.txt")
        let subdirectory = tempDirectory.appendingPathComponent("Subdir")
        let nestedFile = subdirectory.appendingPathComponent("Nested.txt")

        XCTAssertTrue(fileManager.createFile(atPath: fileA.path, contents: Data("a".utf8)))
        XCTAssertTrue(fileManager.createFile(atPath: fileB.path, contents: Data("b".utf8)))
        try fileManager.createDirectory(at: subdirectory, withIntermediateDirectories: true)
        XCTAssertTrue(fileManager.createFile(atPath: nestedFile.path, contents: Data("nested".utf8)))

        let baseDate = Date()
        try setDates(for: fileA, creation: baseDate.addingTimeInterval(-600), modification: baseDate.addingTimeInterval(600))
        try setDates(for: fileB, creation: baseDate.addingTimeInterval(-120), modification: baseDate.addingTimeInterval(-300))
        try setDates(for: subdirectory, creation: baseDate.addingTimeInterval(-30), modification: baseDate.addingTimeInterval(-30))

        let items = try FolderScanner().scan(folderURL: tempDirectory)

        XCTAssertEqual(items.map(\.name), ["Subdir", "B.txt", "A.txt"])
        XCTAssertEqual(items.count, 3)
        XCTAssertFalse(items.contains { $0.name == "Nested.txt" })

        let itemsByName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })
        XCTAssertEqual(itemsByName["Subdir"]?.isDirectory, true)
        XCTAssertEqual(itemsByName["B.txt"]?.isDirectory, false)
        XCTAssertEqual(itemsByName["A.txt"]?.isDirectory, false)
    }

    func testResolvedCreationDateFallsBackToModificationDate() {
        let modificationDate = Date()
        let resolved = FolderScanner.resolvedCreationDate(creationDate: nil, contentModificationDate: modificationDate)
        XCTAssertEqual(resolved, modificationDate)
    }

    func testResolvedCreationDateFallsBackToDistantPastWhenDatesAreMissing() {
        let resolved = FolderScanner.resolvedCreationDate(creationDate: nil, contentModificationDate: nil)
        XCTAssertEqual(resolved, Date.distantPast)
    }

    func testFolderConfigResolvedDisplayNameUsesFallback() {
        let url = URL(fileURLWithPath: "/tmp/Photos")
        let config = FolderConfig(folderURL: url)
        XCTAssertEqual(config.resolvedDisplayName, "Photos")
    }

    func testFolderConfigResolvedDisplayNameUsesExplicitName() {
        let url = URL(fileURLWithPath: "/tmp/Photos")
        let config = FolderConfig(folderURL: url, displayName: "Screenshots")
        XCTAssertEqual(config.resolvedDisplayName, "Screenshots")
    }

    private func setDates(for url: URL, creation: Date, modification: Date) throws {
        try FileManager.default.setAttributes(
            [
                .creationDate: creation,
                .modificationDate: modification
            ],
            ofItemAtPath: url.path
        )
    }
}
