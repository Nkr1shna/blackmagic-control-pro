import XCTest
@testable import BlackmagicControl

final class CameraStateStoreTests: XCTestCase {
    @MainActor
    func testConnectUsesRestWhenDiscoveryFindsEndpoint() async {
        let restClient = FakeCameraControlClient(transport: .rest, state: Self.state(transport: .rest, status: "REST"))
        let bleClient = FakeCameraControlClient(transport: .ble, state: Self.state(transport: .ble, status: "BLE"))
        let store = CameraStateStore(
            restDiscovery: FakeRestDiscovery(endpoint: RestCameraEndpoint(baseURL: URL(string: "http://camera.local")!)),
            bleClient: bleClient,
            restClientFactory: { _ in restClient }
        )

        await store.connect()

        let restConnectCallCount = await restClient.callCount("connect")
        let bleConnectCallCount = await bleClient.callCount("connect")
        XCTAssertEqual(restConnectCallCount, 1)
        XCTAssertEqual(bleConnectCallCount, 0)
        XCTAssertEqual(store.state.controlTransport, .rest)
        XCTAssertEqual(store.state.connectionStatus, "REST")
        XCTAssertFalse(store.isBusy)
    }

    @MainActor
    func testConnectFallsBackToBleWhenRestDiscoveryFails() async {
        let bleClient = FakeCameraControlClient(transport: .ble, state: Self.state(transport: .ble, status: "BLE"))
        let store = CameraStateStore(
            restDiscovery: FakeRestDiscovery(endpoint: nil),
            bleClient: bleClient,
            restClientFactory: { _ in XCTFail("REST client should not be created"); return bleClient }
        )

        await store.connect()

        let bleConnectCallCount = await bleClient.callCount("connect")
        XCTAssertEqual(bleConnectCallCount, 1)
        XCTAssertEqual(store.state.controlTransport, .ble)
        XCTAssertEqual(store.state.connectionStatus, "BLE")
    }

    @MainActor
    func testConnectFallsBackToBleAndKeepsRestErrorWhenRestConnectFails() async {
        let restClient = FakeCameraControlClient(
            transport: .rest,
            state: Self.state(transport: .rest, status: "REST"),
            connectError: TestError(message: "REST unavailable")
        )
        let bleClient = FakeCameraControlClient(transport: .ble, state: Self.state(transport: .ble, status: "BLE"))
        let store = CameraStateStore(
            restDiscovery: FakeRestDiscovery(endpoint: RestCameraEndpoint(baseURL: URL(string: "http://camera.local")!)),
            bleClient: bleClient,
            restClientFactory: { _ in restClient }
        )

        await store.connect()

        let restConnectCallCount = await restClient.callCount("connect")
        let bleConnectCallCount = await bleClient.callCount("connect")
        XCTAssertEqual(restConnectCallCount, 1)
        XCTAssertEqual(bleConnectCallCount, 1)
        XCTAssertEqual(store.state.controlTransport, .ble)
        XCTAssertEqual(store.state.errors.map(\.message), ["REST unavailable"])
    }

    @MainActor
    func testCommandMethodsForwardToActiveClient() async {
        let restClient = FakeCameraControlClient(transport: .rest, state: Self.state(transport: .rest, status: "REST"))
        let store = CameraStateStore(
            restDiscovery: FakeRestDiscovery(endpoint: RestCameraEndpoint(baseURL: URL(string: "http://camera.local")!)),
            bleClient: FakeCameraControlClient(transport: .ble, state: Self.state(transport: .ble, status: "BLE")),
            restClientFactory: { _ in restClient }
        )

        await store.connect()
        await store.refresh()
        await store.setRecording(true)
        await store.setISO(800)
        await store.setShutter("180")
        await store.setWhiteBalance(kelvin: 5600, tint: 10)
        await store.triggerAutoWhiteBalance()
        await store.setIris(0.4)
        await store.setFocus(0.7)
        await store.triggerAutoFocus()

        let calls = await restClient.callsSnapshot()
        XCTAssertEqual(calls, [
            "connect",
            "refreshState",
            "setRecording:true",
            "setISO:800",
            "setShutter:180",
            "setWhiteBalance:5600:10",
            "triggerAutoWhiteBalance",
            "setIris:0.4",
            "setFocus:0.7",
            "triggerAutoFocus"
        ])
    }

    @MainActor
    func testBusyCommandRejectsOverlappingCommandWithoutForwarding() async {
        let blocker = FakeOperationBlocker(blockedCall: "setISO:400")
        let restClient = FakeCameraControlClient(
            transport: .rest,
            state: Self.state(transport: .rest, status: "REST"),
            blocker: blocker
        )
        let store = CameraStateStore(
            restDiscovery: FakeRestDiscovery(endpoint: RestCameraEndpoint(baseURL: URL(string: "http://camera.local")!)),
            bleClient: FakeCameraControlClient(transport: .ble, state: Self.state(transport: .ble, status: "BLE")),
            restClientFactory: { _ in restClient }
        )
        await store.connect()

        async let first: Void = store.setISO(400)
        await blocker.waitUntilEntered()

        XCTAssertTrue(store.isBusy)

        await store.setShutter("180")

        let callsBeforeRelease = await restClient.callsSnapshot()
        XCTAssertEqual(callsBeforeRelease, ["connect", "setISO:400"])
        XCTAssertEqual(store.state.errors.map(\.message), ["Camera control is busy"])

        await blocker.release()
        await first
        XCTAssertFalse(store.isBusy)

        let callsAfterRelease = await restClient.callsSnapshot()
        XCTAssertEqual(callsAfterRelease, ["connect", "setISO:400"])
    }

    @MainActor
    func testBusyConnectRejectsCommandWithoutUsingPreviousActiveClient() async {
        let initialRestClient = FakeCameraControlClient(
            transport: .rest,
            state: Self.state(transport: .rest, status: "Initial REST")
        )
        let reconnectBlocker = FakeOperationBlocker(blockedCall: "connect")
        let reconnectRestClient = FakeCameraControlClient(
            transport: .rest,
            state: Self.state(transport: .rest, status: "Replacement REST"),
            blocker: reconnectBlocker
        )
        var restClients = [initialRestClient, reconnectRestClient]
        let store = CameraStateStore(
            restDiscovery: FakeRestDiscovery(endpoint: RestCameraEndpoint(baseURL: URL(string: "http://camera.local")!)),
            bleClient: FakeCameraControlClient(transport: .ble, state: Self.state(transport: .ble, status: "BLE")),
            restClientFactory: { _ in restClients.removeFirst() }
        )

        await store.connect()

        async let reconnect: Void = store.connect()
        await reconnectBlocker.waitUntilEntered()

        XCTAssertTrue(store.isBusy)

        await store.setISO(800)

        let initialCallsBeforeRelease = await initialRestClient.callsSnapshot()
        let reconnectCallsBeforeRelease = await reconnectRestClient.callsSnapshot()
        XCTAssertEqual(initialCallsBeforeRelease, ["connect"])
        XCTAssertEqual(reconnectCallsBeforeRelease, ["connect"])
        XCTAssertEqual(store.state.errors.map(\.message), ["Camera control is busy"])

        await reconnectBlocker.release()
        await reconnect
        XCTAssertFalse(store.isBusy)

        let initialCallsAfterRelease = await initialRestClient.callsSnapshot()
        XCTAssertEqual(initialCallsAfterRelease, ["connect"])
    }

    private static func state(transport: CameraControlTransport, status: String) -> CameraState {
        var state = CameraState()
        state.controlTransport = transport
        state.connectionStatus = status
        return state
    }
}

private struct TestError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

private struct FakeRestDiscovery: CameraStateStoreRestDiscovery {
    let endpoint: RestCameraEndpoint?

    func discover() async -> RestCameraEndpoint? {
        endpoint
    }
}

private final class FakeCameraControlClient: CameraControlClient {
    let transport: CameraControlTransport
    private let state: CameraState
    private let connectError: Error?
    private let blocker: FakeOperationBlocker?
    private let recorder = FakeCameraControlClientRecorder()

    init(
        transport: CameraControlTransport,
        state: CameraState,
        connectError: Error? = nil,
        blocker: FakeOperationBlocker? = nil
    ) {
        self.transport = transport
        self.state = state
        self.connectError = connectError
        self.blocker = blocker
    }

    func callsSnapshot() async -> [String] {
        await recorder.callsSnapshot()
    }

    func callCount(_ call: String) async -> Int {
        await recorder.callCount(call)
    }

    func connect() async throws -> CameraState {
        try await perform("connect")
        if let connectError {
            throw connectError
        }
        return state
    }

    func disconnect() async {
        await recorder.record("disconnect")
    }

    func refreshState() async throws -> CameraState {
        try await perform("refreshState")
        return state
    }

    func setRecording(_ recording: Bool) async throws -> CameraState {
        try await perform("setRecording:\(recording)")
        return state
    }

    func setISO(_ iso: Int) async throws -> CameraState {
        try await perform("setISO:\(iso)")
        return state
    }

    func setShutter(_ shutter: String) async throws -> CameraState {
        try await perform("setShutter:\(shutter)")
        return state
    }

    func setWhiteBalance(kelvin: Int, tint: Int) async throws -> CameraState {
        try await perform("setWhiteBalance:\(kelvin):\(tint)")
        return state
    }

    func triggerAutoWhiteBalance() async throws -> CameraState {
        try await perform("triggerAutoWhiteBalance")
        return state
    }

    func setIris(_ iris: Double) async throws -> CameraState {
        try await perform("setIris:\(iris)")
        return state
    }

    func setFocus(_ focus: Double) async throws -> CameraState {
        try await perform("setFocus:\(focus)")
        return state
    }

    func triggerAutoFocus() async throws -> CameraState {
        try await perform("triggerAutoFocus")
        return state
    }

    private func perform(_ call: String) async throws {
        await recorder.record(call)
        if let blocker {
            await blocker.waitIfNeeded(for: call)
        }
    }
}

private actor FakeCameraControlClientRecorder {
    private var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }

    func callsSnapshot() -> [String] {
        calls
    }

    func callCount(_ call: String) -> Int {
        calls.filter { $0 == call }.count
    }
}

private actor FakeOperationBlocker {
    private let blockedCall: String
    private var didEnter = false
    private var isReleased = false
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(blockedCall: String) {
        self.blockedCall = blockedCall
    }

    func waitIfNeeded(for call: String) async {
        guard call == blockedCall else {
            return
        }

        didEnter = true
        enteredContinuation?.resume()
        enteredContinuation = nil

        guard !isReleased else {
            return
        }

        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func waitUntilEntered() async {
        guard !didEnter else {
            return
        }

        await withCheckedContinuation { continuation in
            enteredContinuation = continuation
        }
    }

    func release() {
        isReleased = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
