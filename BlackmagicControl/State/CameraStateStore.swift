import Combine
import Foundation

protocol CameraStateStoreRestDiscovery {
    func discover() async -> RestCameraEndpoint?
}

extension RestCameraDiscovery: CameraStateStoreRestDiscovery {}

@MainActor
final class CameraStateStore: ObservableObject {
    @Published private(set) var state = CameraState()
    @Published private(set) var isBusy = false

    private let restDiscovery: any CameraStateStoreRestDiscovery
    private let bleClient: any CameraControlClient
    private let restClientFactory: (RestCameraEndpoint) -> any CameraControlClient
    private var activeClient: (any CameraControlClient)?

    init(restDiscovery: RestCameraDiscovery, bleClient: BleCameraControlClient) {
        self.restDiscovery = restDiscovery
        self.bleClient = bleClient
        self.restClientFactory = { endpoint in
            RestCameraControlClient(baseURL: endpoint.baseURL)
        }
    }

    init(
        restDiscovery: any CameraStateStoreRestDiscovery,
        bleClient: any CameraControlClient,
        restClientFactory: @escaping (RestCameraEndpoint) -> any CameraControlClient
    ) {
        self.restDiscovery = restDiscovery
        self.bleClient = bleClient
        self.restClientFactory = restClientFactory
    }

    func connect() async {
        guard beginOperation() else {
            return
        }
        defer { finishOperation() }

        if let endpoint = await restDiscovery.discover() {
            let restClient = restClientFactory(endpoint)

            do {
                let connectedState = try await restClient.connect()
                activeClient = restClient
                apply(connectedState)
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

    private func apply(_ newState: CameraState) {
        let existingErrors = state.errors
        var mergedState = newState
        mergedState.errors = existingErrors + newState.errors
        state = mergedState
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
