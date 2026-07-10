@preconcurrency import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
final class ExternalCameraPreviewModel: NSObject, ObservableObject {
    @Published private(set) var session = AVCaptureSession()
    @Published private(set) var isActive = false
    @Published private(set) var status: String = "Waiting for video"
    @Published private(set) var errorMessage: String?
    /// Human-readable description of the incoming feed, e.g. "1920×1080 · 60 fps".
    @Published private(set) var feedDescription: String?

    // Local (iPad) recording of the monitor feed.
    @Published private(set) var isRecordingLocally = false
    @Published private(set) var localRecordingStart: Date?
    @Published private(set) var localRecordingMessage: String?
    @Published private(set) var externalDestinationName: String?

    private static let destinationBookmarkKey = "ExternalCameraPreviewModel.destinationBookmark"

    private let sessionQueue = DispatchQueue(label: "BlackmagicControl.ExternalCameraPreviewModel.session")
    private let sessionQueueState = SessionQueueState()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var previewRequestID = 0
    private var observers: [NSObjectProtocol] = []
    private var currentDeviceID: String?
    private var hasAudioInput = false

    override init() {
        super.init()

        externalDestinationName = Self.resolveDestinationName()

        // Restart the preview whenever an external camera is plugged in,
        // torn down, or the app returns to the foreground — the feed should
        // never require an app relaunch.
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.startIfIdle()
            }
        })
        observers.append(center.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let disconnectedID = (notification.object as? AVCaptureDevice)?.uniqueID
            Task { @MainActor [weak self] in
                self?.handleDeviceDisconnected(disconnectedID)
            }
        })
        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.startIfIdle()
            }
        })
    }

    deinit {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    func start() async {
        previewRequestID += 1
        let requestID = previewRequestID

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard isCurrentPreviewRequest(requestID) else {
            return
        }

        guard granted else {
            errorMessage = "Camera permission denied"
            status = "Preview unavailable"
            isActive = false
            return
        }

        guard let device = discoverExternalCamera() else {
            errorMessage = nil
            status = "Waiting for video"
            isActive = false
            feedDescription = nil
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let result = await configureAndStartSession(with: input, requestID: requestID)
            guard isCurrentPreviewRequest(requestID) else {
                if case .success = result {
                    enqueueStopSession(ifActiveRequestID: requestID)
                }
                return
            }

            switch result {
            case .success:
                currentDeviceID = device.uniqueID
                status = "Live"
                errorMessage = nil
                isActive = true
                feedDescription = Self.describeFeed(of: device)
            case .failure(let error):
                errorMessage = error.localizedDescription
                status = "Preview unavailable"
                isActive = false
            }
        } catch {
            errorMessage = error.localizedDescription
            status = "Preview unavailable"
            isActive = false
        }
    }

    func stop() {
        previewRequestID += 1
        status = "Preview stopped"
        isActive = false
        currentDeviceID = nil
        feedDescription = nil
        enqueueStopSession()
    }

    // MARK: - Local recording

    /// Records the incoming monitor feed to the iPad. Note this captures the
    /// USB webcam stream (a fixed monitor-quality feed), not the camera's
    /// internal recording format.
    func startLocalRecording() async {
        guard isActive else {
            localRecordingMessage = "No video feed to record."
            return
        }
        guard !isRecordingLocally, !movieOutput.isRecording else { return }

        // Best effort audio: the BMPCC presents audio over USB on most
        // setups; fall back silently to video-only if denied/unavailable.
        let audioGranted = await AVCaptureDevice.requestAccess(for: .audio)

        let url = Self.recordingsDirectory().appendingPathComponent(Self.recordingFileName())
        let session = session
        let movieOutput = movieOutput
        let needsAudio = audioGranted && !hasAudioInput
        if needsAudio {
            hasAudioInput = true
        }

        localRecordingMessage = nil
        sessionQueue.async { [weak self] in
            if needsAudio,
               let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                session.beginConfiguration()
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
                session.commitConfiguration()
            }

            guard let self, session.isRunning, movieOutput.connection(with: .video) != nil else {
                Task { @MainActor [weak self] in
                    self?.localRecordingMessage = "Recording output is not ready."
                }
                return
            }

            movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopLocalRecording() {
        let movieOutput = movieOutput
        sessionQueue.async {
            if movieOutput.isRecording {
                movieOutput.stopRecording()
            }
        }
    }

    /// Sets an external folder (e.g. a USB drive picked in Files) that
    /// finished recordings are moved to.
    func setExternalDestination(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let bookmark = try url.bookmarkData()
            UserDefaults.standard.set(bookmark, forKey: Self.destinationBookmarkKey)
            externalDestinationName = url.lastPathComponent
            localRecordingMessage = "Recordings will be moved to “\(url.lastPathComponent)”."
        } catch {
            localRecordingMessage = "Couldn't save that folder: \(error.localizedDescription)"
        }
    }

    func clearExternalDestination() {
        UserDefaults.standard.removeObject(forKey: Self.destinationBookmarkKey)
        externalDestinationName = nil
    }

    private static func resolveDestinationName() -> String? {
        guard let bookmark = UserDefaults.standard.data(forKey: destinationBookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) else { return nil }
        return url.lastPathComponent
    }

    static func recordingsDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordings = documents.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
        return recordings
    }

    static func recordingFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "BMPCC \(formatter.string(from: date)).mov"
    }

    private func handleRecordingFinished(at url: URL, error: Error?) {
        isRecordingLocally = false
        localRecordingStart = nil

        if let error {
            // AVFoundation reports a benign "error" when recording stops
            // normally; only surface it if no usable file was produced.
            let produced = (try? url.checkResourceIsReachable()) ?? false
            if !produced {
                localRecordingMessage = "Recording failed: \(error.localizedDescription)"
                return
            }
        }

        moveToExternalDestinationIfConfigured(url)
    }

    private func moveToExternalDestinationIfConfigured(_ url: URL) {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.destinationBookmarkKey) else {
            localRecordingMessage = "Saved to Files → On My iPad → Blackmagic Control → Recordings."
            return
        }

        localRecordingMessage = "Moving recording to external storage…"
        Task.detached(priority: .utility) {
            var stale = false
            let result: String
            do {
                let folder = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale)
                let accessing = folder.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        folder.stopAccessingSecurityScopedResource()
                    }
                }

                let target = folder.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: target)
                try FileManager.default.copyItem(at: url, to: target)
                try FileManager.default.removeItem(at: url)
                result = "Saved to “\(folder.lastPathComponent)”."
            } catch {
                result = "Kept in app Recordings folder (external move failed: \(error.localizedDescription))"
            }

            await MainActor.run { [weak self] in
                self?.localRecordingMessage = result
            }
        }
    }

    private static func describeFeed(of device: AVCaptureDevice) -> String {
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let maxRate = device.activeFormat.videoSupportedFrameRateRanges
            .map(\.maxFrameRate)
            .max()
        if let maxRate {
            let rate = maxRate.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", maxRate)
                : String(format: "%.2f", maxRate)
            return "\(dimensions.width)×\(dimensions.height) · \(rate) fps"
        }
        return "\(dimensions.width)×\(dimensions.height)"
    }

    // MARK: - Session plumbing

    private func startIfIdle() async {
        guard !isActive else { return }
        await start()
    }

    private func handleDeviceDisconnected(_ deviceID: String?) {
        guard deviceID != nil, deviceID == currentDeviceID else { return }
        currentDeviceID = nil
        isActive = false
        isRecordingLocally = false
        localRecordingStart = nil
        status = "Waiting for video"
        errorMessage = nil
        feedDescription = nil
        enqueueStopSession()
    }

    private func discoverExternalCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first { device in
            device.localizedName.localizedCaseInsensitiveContains("blackmagic")
        } ?? discovery.devices.first
    }

    private func isCurrentPreviewRequest(_ requestID: Int) -> Bool {
        previewRequestID == requestID
    }

    private func configureAndStartSession(
        with input: AVCaptureDeviceInput,
        requestID: Int
    ) async -> Result<Void, Error> {
        let session = session
        let sessionQueue = sessionQueue
        let sessionQueueState = sessionQueueState
        let movieOutput = movieOutput

        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                do {
                    try Self.configureAndStartSession(session, input: input, movieOutput: movieOutput)
                    sessionQueueState.activeRequestID = requestID
                    continuation.resume(returning: .success(()))
                } catch {
                    sessionQueueState.activeRequestID = nil
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    private func enqueueStopSession(ifActiveRequestID requestID: Int? = nil) {
        let session = session
        let sessionQueue = sessionQueue
        let sessionQueueState = sessionQueueState
        let movieOutput = movieOutput

        sessionQueue.async {
            if let requestID = requestID, sessionQueueState.activeRequestID != requestID {
                return
            }

            if movieOutput.isRecording {
                movieOutput.stopRecording()
            }
            session.stopRunning()
            sessionQueueState.activeRequestID = nil
        }
    }

    nonisolated private static func configureAndStartSession(
        _ session: AVCaptureSession,
        input: AVCaptureDeviceInput,
        movieOutput: AVCaptureMovieFileOutput
    ) throws {
        session.beginConfiguration()
        session.inputs
            .filter { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) ?? true }
            .forEach { session.removeInput($0) }

        let canAddInput = session.canAddInput(input)
        if canAddInput {
            session.addInput(input)
        }

        if canAddInput, !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()

        guard canAddInput else {
            if session.isRunning {
                session.stopRunning()
            }
            throw PreviewSessionError.cannotAddInput
        }

        session.startRunning()
    }

    private enum PreviewSessionError: LocalizedError {
        case cannotAddInput

        var errorDescription: String? {
            switch self {
            case .cannotAddInput:
                return "External camera input cannot be added to the preview session"
            }
        }
    }

    private final class SessionQueueState: @unchecked Sendable {
        var activeRequestID: Int?
    }
}

extension ExternalCameraPreviewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        Task { @MainActor [weak self] in
            self?.isRecordingLocally = true
            self?.localRecordingStart = Date()
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.handleRecordingFinished(at: outputFileURL, error: error)
        }
    }
}
