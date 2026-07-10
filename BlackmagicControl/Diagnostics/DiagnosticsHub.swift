import Foundation
import SwiftUI

@MainActor
final class DiagnosticsHub: ObservableObject {
    let journal: LogJournal
    let crashReporter: CrashReporter

    private let exporter: DiagnosticsExporter

    init(fileManager: FileManager = .default) {
        let journal = LogJournal(fileManager: fileManager)
        let crashDirectory = journal.directoryURL.appendingPathComponent("Crashes", isDirectory: true)
        let crashReporter = CrashReporter(
            directoryURL: crashDirectory,
            fileManager: fileManager
        )

        self.journal = journal
        self.crashReporter = crashReporter
        self.exporter = DiagnosticsExporter(
            journal: journal,
            crashesDirectoryURL: crashDirectory,
            fileManager: fileManager
        )
        AppLog.journalSink = { [weak journal] line in
            journal?.append(line)
        }
    }

    func exportDiagnostics(snapshot: DiagnosticsSnapshot) throws -> URL {
        try exporter.export(snapshot: snapshot)
    }

    func performHousekeeping() {
        journal.pruneExpiredEntries()
    }
}
