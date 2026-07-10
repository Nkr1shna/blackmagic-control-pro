import XCTest
@testable import BlackmagicControl

final class DiagnosticsExporterTests: XCTestCase {
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

    func testReportContainsVersionAndSnapshotFields() {
        let report = DiagnosticsExporter.buildReport(
            snapshot: testSnapshot,
            info: testReportInfo
        )

        XCTAssertTrue(report.contains("Version: 2.3"))
        XCTAssertTrue(report.contains("Build: 45"))
        XCTAssertTrue(report.contains("Build SHA: abc123"))
        XCTAssertTrue(report.contains("BLE phase: Connected"))
        XCTAssertTrue(report.contains("Camera model: Cinema Camera 6K"))
        XCTAssertTrue(report.contains("CCU protocol version: 1.2"))
        XCTAssertTrue(report.contains("Feed format: 4K DCI 24p"))
        XCTAssertTrue(report.contains("- Pairing timed out"))
    }

    func testExportFolderHasReportJournalAndCrashLayout() throws {
        let diagnosticsURL = temporaryDirectory.appendingPathComponent("Diagnostics")
        let crashesURL = diagnosticsURL.appendingPathComponent("Crashes")
        try FileManager.default.createDirectory(at: crashesURL, withIntermediateDirectories: true)
        try Data("{\"crash\":true}".utf8).write(
            to: crashesURL.appendingPathComponent("crash-test.json")
        )

        let journal = LogJournal(directoryURL: diagnosticsURL)
        journal.append("2026-07-10T12:34:56Z [ble] INFO Studio iPad connected")
        let exporter = DiagnosticsExporter(
            journal: journal,
            crashesDirectoryURL: crashesURL,
            fileManager: .default
        )
        let outputURL = temporaryDirectory.appendingPathComponent("Export")

        try exporter.writeExportFolder(
            snapshot: testSnapshot,
            reportInfo: testReportInfo,
            redactionNames: ["Studio iPad", nil],
            folderURL: outputURL
        )

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: outputURL.appendingPathComponent("report.txt").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: outputURL.appendingPathComponent("journal.log").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: outputURL.appendingPathComponent("crashes/crash-test.json").path
        ))

        let journalExport = try String(
            contentsOf: outputURL.appendingPathComponent("journal.log"),
            encoding: .utf8
        )
        XCTAssertTrue(journalExport.contains("[REDACTED] connected"))
    }

    private var testSnapshot: DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            blePhase: "Connected",
            recentErrors: ["Pairing timed out"],
            cameraModel: "Cinema Camera 6K",
            ccuProtocolVersion: "1.2",
            feedFormat: "4K DCI 24p"
        )
    }

    private var testReportInfo: DiagnosticsReportInfo {
        DiagnosticsReportInfo(
            appName: "Blackmagic Control",
            version: "2.3",
            build: "45",
            buildSHA: "abc123",
            deviceModelIdentifier: "iPad14,6",
            operatingSystemVersion: "17.5",
            cameraPermission: "Authorized",
            microphonePermission: "Denied",
            bluetoothPermission: "Authorized",
            freeDiskSpace: "120 GB",
            thermalState: "Nominal",
            timestamp: Date(timeIntervalSince1970: 1_783_686_000)
        )
    }
}
