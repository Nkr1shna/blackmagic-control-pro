import Combine
import Foundation

protocol CameraStateStoreRestDiscovery {
    func discover() async -> RestCameraEndpoint?
}

extension RestCameraDiscovery: CameraStateStoreRestDiscovery {}

protocol CameraStateStoreRestEventStream: AnyObject {
    func connect(onEvent: @escaping (RestEventMessage) -> Void)
    func disconnect()
}

extension RestEventStream: CameraStateStoreRestEventStream {}

protocol BleCameraStateReporting: AnyObject {
    var onStateChange: ((CameraState) -> Void)? { get set }
}

extension BleCameraControlClient: BleCameraStateReporting {}

@MainActor
final class CameraStateStore: ObservableObject {
    @Published private(set) var state = CameraState()
    @Published private(set) var isBusy = false

    private let restDiscovery: any CameraStateStoreRestDiscovery
    private let bleClient: any CameraControlClient
    private let bleStateReporter: BleCameraStateReporting?
    private let restClientFactory: (RestCameraEndpoint) -> any CameraControlClient
    private let restEventStreamFactory: (RestCameraEndpoint) -> CameraStateStoreRestEventStream
    private var activeClient: (any CameraControlClient)?
    private var restEventStream: CameraStateStoreRestEventStream?

    init(restDiscovery: RestCameraDiscovery, bleClient: BleCameraControlClient) {
        self.restDiscovery = restDiscovery
        self.bleClient = bleClient
        self.bleStateReporter = bleClient
        self.restClientFactory = { endpoint in
            RestCameraControlClient(baseURL: endpoint.baseURL)
        }
        self.restEventStreamFactory = { endpoint in
            RestEventStream(baseURL: endpoint.baseURL)
        }
        wireBleStateChanges()
    }

    init(
        restDiscovery: any CameraStateStoreRestDiscovery,
        bleClient: any CameraControlClient,
        bleStateReporter: BleCameraStateReporting? = nil,
        restClientFactory: @escaping (RestCameraEndpoint) -> any CameraControlClient,
        restEventStreamFactory: @escaping (RestCameraEndpoint) -> CameraStateStoreRestEventStream = { endpoint in
            RestEventStream(baseURL: endpoint.baseURL)
        }
    ) {
        self.restDiscovery = restDiscovery
        self.bleClient = bleClient
        self.bleStateReporter = bleStateReporter
        self.restClientFactory = restClientFactory
        self.restEventStreamFactory = restEventStreamFactory
        wireBleStateChanges()
    }

    func connect() async {
        guard beginOperation() else {
            return
        }
        defer { finishOperation() }
        stopRestEventStream()

        if let endpoint = await restDiscovery.discover() {
            let restClient = restClientFactory(endpoint)

            do {
                let connectedState = try await restClient.connect()
                activeClient = restClient
                apply(connectedState)
                startRestEventStream(for: endpoint, client: restClient)
                return
            } catch {
                appendControlError(error)
            }
        }

        do {
            let connectedState = try await bleClient.connect()
            activeClient = bleClient
            apply(connectedState)
        } catch {
            activeClient = nil
            stopRestEventStream()
            appendControlError(error)
        }
    }

    func refresh() async {
        await performActiveCommand { client in
            try await client.refreshState()
        }
    }

    func setRecording(_ recording: Bool) async {
        await performActiveCommand { client in
            try await client.setRecording(recording)
        }
    }

    func setISO(_ iso: Int) async {
        await performActiveCommand { client in
            try await client.setISO(iso)
        }
    }

    func setShutter(_ shutter: String) async {
        await performActiveCommand { client in
            try await client.setShutter(shutter)
        }
    }

    func setWhiteBalance(kelvin: Int, tint: Int) async {
        await performActiveCommand { client in
            try await client.setWhiteBalance(kelvin: kelvin, tint: tint)
        }
    }

    func triggerAutoWhiteBalance() async {
        await performActiveCommand { client in
            try await client.triggerAutoWhiteBalance()
        }
    }

    func setIris(_ iris: Double) async {
        await performActiveCommand { client in
            try await client.setIris(iris)
        }
    }

    func setFocus(_ focus: Double) async {
        await performActiveCommand { client in
            try await client.setFocus(focus)
        }
    }

    func triggerAutoFocus() async {
        await performActiveCommand { client in
            try await client.triggerAutoFocus()
        }
    }

    private func performActiveCommand(
        _ operation: (any CameraControlClient) async throws -> CameraState
    ) async {
        guard beginOperation() else {
            return
        }
        defer { finishOperation() }

        guard let activeClient else {
            appendControlError(CameraStateStoreError.noActiveControlClient)
            return
        }

        do {
            apply(try await operation(activeClient))
        } catch {
            appendControlError(error)
        }
    }

    private func beginOperation() -> Bool {
        guard !isBusy else {
            appendControlError(CameraStateStoreError.busy)
            return false
        }

        isBusy = true
        return true
    }

    private func finishOperation() {
        isBusy = false
    }

    private func wireBleStateChanges() {
        bleStateReporter?.onStateChange = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self, self.isActiveClient(self.bleClient) else {
                    return
                }

                self.apply(newState)
            }
        }
    }

    private func startRestEventStream(for endpoint: RestCameraEndpoint, client: any CameraControlClient) {
        stopRestEventStream()

        let clientID = ObjectIdentifier(client)
        let stream = restEventStreamFactory(endpoint)
        restEventStream = stream
        stream.connect { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isActiveClient(with: clientID) else {
                    return
                }

                await self.refreshFromRestEvent(activeClientID: clientID)
            }
        }
    }

    private func stopRestEventStream() {
        restEventStream?.disconnect()
        restEventStream = nil
    }

    private func refreshFromRestEvent(activeClientID: ObjectIdentifier) async {
        guard !isBusy,
              let activeClient,
              isActiveClient(with: activeClientID) else {
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            apply(try await activeClient.refreshState())
        } catch {
            appendControlError(error)
        }
    }

    private func apply(_ newState: CameraState) {
        let existingErrors = state.errors
        var mergedState = newState
        mergedState.errors = existingErrors + newState.errors
        state = mergedState
    }

    private func isActiveClient(_ client: any CameraControlClient) -> Bool {
        guard let activeClient else {
            return false
        }

        return ObjectIdentifier(activeClient) == ObjectIdentifier(client)
    }

    private func isActiveClient(with clientID: ObjectIdentifier) -> Bool {
        guard let activeClient else {
            return false
        }

        return ObjectIdentifier(activeClient) == clientID
    }

    private func appendControlError(_ error: Error) {
        var nextState = state
        nextState.errors.append(CameraError(subsystem: "Control", message: error.localizedDescription))
        state = nextState
    }
}

private enum CameraStateStoreError: LocalizedError {
    case busy
    case noActiveControlClient

    var errorDescription: String? {
        switch self {
        case .busy:
            return "Camera control is busy"
        case .noActiveControlClient:
            return "No active camera control transport"
        }
    }
}
