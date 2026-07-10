import Foundation

enum JournalLineFormatter {
    static func format(date: Date, category: String, level: String, message: String) -> String {
        let timestamp = ISO8601DateFormatter().string(from: date)
        let singleLineMessage = message
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
        return "\(timestamp) [\(category)] \(level) \(singleLineMessage)"
    }

    static func date(from line: String) -> Date? {
        guard let timestamp = line.split(separator: " ", maxSplits: 1).first else { return nil }
        return ISO8601DateFormatter().date(from: String(timestamp))
    }
}

struct LogJournalStorage {
    let fileManager: FileManager
    let directoryURL: URL
    let rotationSizeBytes: Int

    var currentFileURL: URL { directoryURL.appendingPathComponent("journal.log") }
    var rotatedFileURL: URL { directoryURL.appendingPathComponent("journal.1.log") }

    func append(_ line: String) throws {
        try createDirectory()
        let data = Data((line + "\n").utf8)
        let currentSize = fileSize(at: currentFileURL)

        if currentSize > 0 && currentSize + data.count > rotationSizeBytes {
            try rotate()
        }

        if fileManager.fileExists(atPath: currentFileURL.path) {
            let handle = try FileHandle(forWritingTo: currentFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: currentFileURL, options: .atomic)
        }
    }

    func prune(before cutoff: Date) throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }

        for fileURL in [rotatedFileURL, currentFileURL] {
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            let contents = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let lines = contents.split(whereSeparator: \.isNewline).map(String.init)
            let keptLines = lines.filter { line in
                if let date = JournalLineFormatter.date(from: line) {
                    return date >= cutoff
                }
                let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                return values?.contentModificationDate.map { $0 >= cutoff } ?? true
            }

            if keptLines.isEmpty {
                try fileManager.removeItem(at: fileURL)
            } else if keptLines.count != lines.count {
                try Data((keptLines.joined(separator: "\n") + "\n").utf8)
                    .write(to: fileURL, options: .atomic)
            }
        }
    }

    func recentContents() -> String {
        [rotatedFileURL, currentFileURL]
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .joined()
    }

    private func createDirectory() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func rotate() throws {
        if fileManager.fileExists(atPath: rotatedFileURL.path) {
            try fileManager.removeItem(at: rotatedFileURL)
        }
        try fileManager.moveItem(at: currentFileURL, to: rotatedFileURL)
    }

    private func fileSize(at url: URL) -> Int {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.intValue ?? 0
    }
}

final class LogJournal {
    static let defaultRotationSizeBytes = 2_500_000
    static let defaultRetentionInterval: TimeInterval = 7 * 24 * 60 * 60

    let directoryURL: URL

    private let queue = DispatchQueue(label: "com.krishnanelloore.camcontrolpro.log-journal")
    private let storage: LogJournalStorage
    private let retentionInterval: TimeInterval
    private let now: () -> Date

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil,
        rotationSizeBytes: Int = defaultRotationSizeBytes,
        retentionInterval: TimeInterval = defaultRetentionInterval,
        now: @escaping () -> Date = Date.init
    ) {
        let resolvedDirectory = directoryURL ?? Self.defaultDirectory(fileManager: fileManager)
        self.directoryURL = resolvedDirectory
        self.storage = LogJournalStorage(
            fileManager: fileManager,
            directoryURL: resolvedDirectory,
            rotationSizeBytes: rotationSizeBytes
        )
        self.retentionInterval = retentionInterval
        self.now = now
        pruneExpiredEntries()
    }

    func append(_ line: String) {
        queue.async { [storage] in
            try? storage.append(line)
        }
    }

    func recentContents() -> String {
        queue.sync { storage.recentContents() }
    }

    func pruneExpiredEntries() {
        queue.sync {
            try? storage.prune(before: now().addingTimeInterval(-retentionInterval))
        }
    }

    static func defaultDirectory(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL.appendingPathComponent("Diagnostics", isDirectory: true)
    }
}
