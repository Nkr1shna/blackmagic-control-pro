import Foundation
import MetricKit

final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    let directoryURL: URL

    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.krishnanelloore.camcontrolpro.crash-reporter")

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        super.init()
        MXMetricManager.shared.add(self)
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        queue.async { [fileManager, directoryURL] in
            try? fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            for payload in payloads {
                let fileURL = Self.availableFileURL(
                    in: directoryURL,
                    fileManager: fileManager,
                    date: Date()
                )
                try? payload.jsonRepresentation().write(to: fileURL, options: .atomic)
            }

            Self.keepNewestFiles(count: 10, in: directoryURL, fileManager: fileManager)
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        AppLog.lifecycle.debug("received \(payloads.count) MetricKit metric payloads")
    }

    private static func availableFileURL(
        in directoryURL: URL,
        fileManager: FileManager,
        date: Date
    ) -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let baseName = "crash-\(formatter.string(from: date))"
        var candidate = directoryURL.appendingPathComponent(baseName).appendingPathExtension("json")
        var suffix = 1

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directoryURL
                .appendingPathComponent("\(baseName)-\(suffix)")
                .appendingPathExtension("json")
            suffix += 1
        }
        return candidate
    }

    private static func keepNewestFiles(
        count: Int,
        in directoryURL: URL,
        fileManager: FileManager
    ) {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }

        let files = urls.filter { url in
            let values = try? url.resourceValues(forKeys: keys)
            return values?.isRegularFile == true && url.pathExtension.lowercased() == "json"
        }.sorted { lhs, rhs in
            let leftDate = try? lhs.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
            let rightDate = try? rhs.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
            return (leftDate ?? .distantPast) > (rightDate ?? .distantPast)
        }

        for fileURL in files.dropFirst(count) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
