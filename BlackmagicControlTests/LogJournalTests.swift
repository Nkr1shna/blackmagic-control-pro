import XCTest
@testable import BlackmagicControl

final class LogJournalTests: XCTestCase {
    private var temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testAppendRotatesAtConfiguredCap() throws {
        let journal = LogJournal(
            directoryURL: temporaryDirectory,
            rotationSizeBytes: 20
        )

        journal.append("123456789")
        journal.append("abcdefghj")
        journal.append("rotated")
        _ = journal.recentContents()

        let rotated = try String(
            contentsOf: temporaryDirectory.appendingPathComponent("journal.1.log"),
            encoding: .utf8
        )
        let current = try String(
            contentsOf: temporaryDirectory.appendingPathComponent("journal.log"),
            encoding: .utf8
        )

        XCTAssertEqual(rotated, "123456789\nabcdefghj\n")
        XCTAssertEqual(current, "rotated\n")
    }

    func testInitializationPrunesEntriesOlderThanSevenDays() throws {
        let now = Date(timeIntervalSince1970: 1_783_686_000)
        let oldLine = JournalLineFormatter.format(
            date: now.addingTimeInterval(-8 * 24 * 60 * 60),
            category: "ble",
            level: "ERROR",
            message: "old"
        )
        let recentLine = JournalLineFormatter.format(
            date: now.addingTimeInterval(-6 * 24 * 60 * 60),
            category: "ble",
            level: "INFO",
            message: "recent"
        )
        try Data("\(oldLine)\n\(recentLine)\n".utf8).write(
            to: temporaryDirectory.appendingPathComponent("journal.log")
        )

        let journal = LogJournal(directoryURL: temporaryDirectory, now: { now })
        let contents = journal.recentContents()

        XCTAssertFalse(contents.contains("old"))
        XCTAssertTrue(contents.contains("recent"))
    }

    func testRecentContentsReturnsRotatedFileBeforeCurrentFile() throws {
        let now = Date()
        let older = JournalLineFormatter.format(
            date: now.addingTimeInterval(-60),
            category: "lifecycle",
            level: "INFO",
            message: "older"
        )
        let newer = JournalLineFormatter.format(
            date: now,
            category: "lifecycle",
            level: "INFO",
            message: "newer"
        )
        try Data("\(older)\n".utf8).write(
            to: temporaryDirectory.appendingPathComponent("journal.1.log")
        )
        try Data("\(newer)\n".utf8).write(
            to: temporaryDirectory.appendingPathComponent("journal.log")
        )

        let journal = LogJournal(directoryURL: temporaryDirectory, now: { now })

        XCTAssertEqual(journal.recentContents(), "\(older)\n\(newer)\n")
    }
}
