import AVFoundation
import Combine
import Foundation

@MainActor
final class ExternalCameraPreviewModel: ObservableObject {
    @Published private(set) var session = AVCaptureSession()
    @Published private(set) var status: String = "Preview stopped"
    @Published private(set) var errorMessage: String?

    private let sessionQueue = DispatchQueue(label: "BlackmagicControl.ExternalCameraPreviewModel.session")
    private let sessionQueueState = SessionQueueState()
    private var previewRequestID = 0

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
            return
        }

        guard let device = discoverExternalCamera() else {
            errorMessage = "No external UVC camera found"
            status = "Preview unavailable"
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
                status = "Preview active"
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
                status = "Preview unavailable"
            }
        } catch {
            errorMessage = error.localizedDescription
            status = "Preview unavailable"
        }
    }

    func stop() {
        previewRequestID += 1
        status = "Preview stopped"
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

        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                do {
                    try Self.configureAndStartSession(session, input: input)
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

        sessionQueue.async {
            if let requestID = requestID, sessionQueueState.activeRequestID != requestID {
                return
            }

            session.stopRunning()
            sessionQueueState.activeRequestID = nil
        }
    }

    nonisolated private static func configureAndStartSession(
        _ session: AVCaptureSession,
        input: AVCaptureDeviceInput
    ) throws {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }

        let canAddInput = session.canAddInput(input)
        if canAddInput {
            session.addInput(input)
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
