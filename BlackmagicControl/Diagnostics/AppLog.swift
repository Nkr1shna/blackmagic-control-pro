import Foundation
import OSLog

enum AppLog {
    struct Category {
        let name: String
        private let logger: Logger

        init(_ name: String) {
            self.name = name
            logger = Logger(subsystem: AppLog.subsystem, category: name)
        }

        func info(_ message: String) {
            logger.info("\(message, privacy: .public)")
            AppLog.writeToJournal(category: name, level: "INFO", message: message)
        }

        func warning(_ message: String) {
            logger.warning("\(message, privacy: .public)")
            AppLog.writeToJournal(category: name, level: "WARNING", message: message)
        }

        func error(_ message: String) {
            logger.error("\(message, privacy: .public)")
            AppLog.writeToJournal(category: name, level: "ERROR", message: message)
        }

        func debug(_ message: String) {
            logger.debug("\(message, privacy: .public)")
        }
    }

    static let lifecycle = Category("lifecycle")
    static let ble = Category("ble")
    static let ccu = Category("ccu")
    static let preview = Category("preview")
    static let recording = Category("recording")

    private static let subsystem = Bundle.main.bundleIdentifier ?? "BlackmagicControl"
    private static let sinkLock = NSLock()
    private static var storedJournalSink: ((String) -> Void)?

    static var journalSink: ((String) -> Void)? {
        get {
            sinkLock.lock()
            defer { sinkLock.unlock() }
            return storedJournalSink
        }
        set {
            sinkLock.lock()
            storedJournalSink = newValue
            sinkLock.unlock()
        }
    }

    private static func writeToJournal(category: String, level: String, message: String) {
        let line = JournalLineFormatter.format(
            date: Date(),
            category: category,
            level: level,
            message: message
        )
        journalSink?(line)
    }
}
