import AVFoundation
import CoreBluetooth
import Foundation
import UIKit

struct DiagnosticsReportInfo {
    var appName: String
    var version: String
    var build: String
    var buildSHA: String?
    var deviceModelIdentifier: String
    var operatingSystemVersion: String
    var cameraPermission: String
    var microphonePermission: String
    var bluetoothPermission: String
    var freeDiskSpace: String
    var thermalState: String
    var timestamp: Date
}

final class DiagnosticsExporter {
    private static let savedCameraNameKey = "CameraBleController.savedCameraName"

    private let journal: LogJournal
    private let crashesDirectoryURL: URL
    private let fileManager: FileManager
    private let bundle: Bundle
    private let defaults: UserDefaults
    private let deviceName: () -> String

    init(
        journal: LogJournal,
        crashesDirectoryURL: URL,
        fileManager: FileManager = .default,
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        deviceName: @escaping () -> String = { UIDevice.current.name }
    ) {
        self.journal = journal
        self.crashesDirectoryURL = crashesDirectoryURL
        self.fileManager = fileManager
        self.bundle = bundle
        self.defaults = defaults
        self.deviceName = deviceName
    }

    func export(snapshot: DiagnosticsSnapshot) throws -> URL {
        let now = Date()
        let timestamp = Self.fileTimestamp(from: now)
        let folderURL = fileManager.temporaryDirectory
            .appendingPathComponent("BlackmagicControlPro-diagnostics-\(timestamp)-\(UUID().uuidString)", isDirectory: true)

        try writeExportFolder(
            snapshot: snapshot,
            reportInfo: makeReportInfo(timestamp: now),
            redactionNames: [deviceName(), defaults.string(forKey: Self.savedCameraNameKey)],
            folderURL: folderURL
        )

        let zipURL = fileManager.temporaryDirectory
            .appendingPathComponent("BlackmagicControlPro-diagnostics-\(timestamp)")
            .appendingPathExtension("zip")
        if fileManager.fileExists(atPath: zipURL.path) {
            try fileManager.removeItem(at: zipURL)
        }

        // The zip the coordinator provides only exists for the duration of
        // the accessor block, so it must be copied out inside the block.
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: folderURL,
            options: .forUploading,
            error: &coordinationError
        ) { archiveURL in
            do {
                try fileManager.copyItem(at: archiveURL, to: zipURL)
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let copyError {
            throw copyError
        }
        guard fileManager.fileExists(atPath: zipURL.path) else {
            throw CocoaError(.fileReadUnknown)
        }
        return zipURL
    }

    func writeExportFolder(
        snapshot: DiagnosticsSnapshot,
        reportInfo: DiagnosticsReportInfo,
        redactionNames: [String?],
        folderURL: URL
    ) throws {
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let report = Self.redact(
            Self.buildReport(snapshot: snapshot, info: reportInfo),
            names: redactionNames
        )
        let journalContents = Self.redact(journal.recentContents(), names: redactionNames)

        try Data(report.utf8).write(
            to: folderURL.appendingPathComponent("report.txt"),
            options: .atomic
        )
        try Data(journalContents.utf8).write(
            to: folderURL.appendingPathComponent("journal.log"),
            options: .atomic
        )

        let exportedCrashesURL = folderURL.appendingPathComponent("crashes", isDirectory: true)
        try fileManager.createDirectory(at: exportedCrashesURL, withIntermediateDirectories: true)
        try copyCrashFiles(to: exportedCrashesURL)
    }

    static func buildReport(snapshot: DiagnosticsSnapshot, info: DiagnosticsReportInfo) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [
            "Diagnostics Report",
            "Timestamp: \(formatter.string(from: info.timestamp))",
            "App: \(info.appName)",
            "Version: \(info.version)",
            "Build: \(info.build)",
        ]

        if let buildSHA = info.buildSHA, !buildSHA.isEmpty {
            lines.append("Build SHA: \(buildSHA)")
        }

        lines.append(contentsOf: [
            "Device: \(info.deviceModelIdentifier)",
            "iPadOS: \(info.operatingSystemVersion)",
            "Camera permission: \(info.cameraPermission)",
            "Microphone permission: \(info.microphonePermission)",
            "Bluetooth permission: \(info.bluetoothPermission)",
            "Free disk space: \(info.freeDiskSpace)",
            "Thermal state: \(info.thermalState)",
            "",
            "BLE phase: \(snapshot.blePhase)",
            "Camera model: \(snapshot.cameraModel ?? "Unavailable")",
            "CCU protocol version: \(snapshot.ccuProtocolVersion ?? "Unavailable")",
            "Feed format: \(snapshot.feedFormat ?? "Unavailable")",
            "Recent errors:",
        ])

        if snapshot.recentErrors.isEmpty {
            lines.append("None")
        } else {
            lines.append(contentsOf: snapshot.recentErrors.map { "- \($0)" })
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func redact(_ text: String, deviceName: String?, cameraName: String?) -> String {
        redact(text, names: [deviceName, cameraName])
    }

    static func redact(_ text: String, names: [String?]) -> String {
        let names = Set(names.compactMap { name -> String? in
            guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  trimmed.count >= 3 else { return nil }
            return trimmed
        }).sorted { $0.count > $1.count }

        guard !names.isEmpty else { return text }
        let pattern = names
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: "[REDACTED]"
        )
    }

    private func makeReportInfo(timestamp: Date) -> DiagnosticsReportInfo {
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "BlackmagicControlPro"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "Unknown"
        let freeDiskSpace = Self.freeDiskSpace(fileManager: fileManager)

        return DiagnosticsReportInfo(
            appName: appName,
            version: version,
            build: build,
            buildSHA: bundle.object(forInfoDictionaryKey: "KNBuildSHA") as? String,
            deviceModelIdentifier: Self.deviceModelIdentifier(),
            operatingSystemVersion: UIDevice.current.systemVersion,
            cameraPermission: Self.authorizationDescription(
                AVCaptureDevice.authorizationStatus(for: .video)
            ),
            microphonePermission: Self.authorizationDescription(
                AVCaptureDevice.authorizationStatus(for: .audio)
            ),
            bluetoothPermission: Self.bluetoothAuthorizationDescription(CBManager.authorization),
            freeDiskSpace: freeDiskSpace,
            thermalState: Self.thermalStateDescription(ProcessInfo.processInfo.thermalState),
            timestamp: timestamp
        )
    }

    private func copyCrashFiles(to destinationURL: URL) throws {
        guard fileManager.fileExists(atPath: crashesDirectoryURL.path) else { return }
        let files = try fileManager.contentsOfDirectory(
            at: crashesDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for fileURL in files where fileURL.pathExtension.lowercased() == "json" {
            try fileManager.copyItem(
                at: fileURL,
                to: destinationURL.appendingPathComponent(fileURL.lastPathComponent)
            )
        }
    }

    private static func fileTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    private static func freeDiskSpace(fileManager: FileManager) -> String {
        let values = try? fileManager.temporaryDirectory.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        guard let bytes = values?.volumeAvailableCapacityForImportantUsage else {
            return "Unavailable"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static func authorizationDescription(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        @unknown default: return "Unknown"
        }
    }

    private static func bluetoothAuthorizationDescription(_ status: CBManagerAuthorization) -> String {
        switch status {
        case .notDetermined: return "Not determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .allowedAlways: return "Authorized"
        @unknown default: return "Unknown"
        }
    }

    private static func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
