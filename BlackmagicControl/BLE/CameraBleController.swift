import CoreBluetooth
import Foundation
import UIKit

// MARK: - Connection model

enum ConnectionPhase: Equatable {
    case bluetoothOff
    case bluetoothUnauthorized
    case idle
    case scanning
    case connecting
    case pairing
    case connected
    case reconnecting

    var label: String {
        switch self {
        case .bluetoothOff: return "Bluetooth Off"
        case .bluetoothUnauthorized: return "Bluetooth Denied"
        case .idle: return "Not Connected"
        case .scanning: return "Searching…"
        case .connecting: return "Connecting…"
        case .pairing: return "Pairing…"
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting…"
        }
    }

    var isConnected: Bool { self == .connected }
}

struct DiscoveredCamera: Identifiable, Equatable {
    let id: UUID
    var name: String
    var rssi: Int
}

enum DiscoveredCameraList {
    static func updating(
        _ cameras: [DiscoveredCamera],
        with entry: DiscoveredCamera
    ) -> [DiscoveredCamera] {
        var updated = cameras
        if let index = updated.firstIndex(where: { $0.id == entry.id }) {
            updated[index] = entry
        } else {
            updated.append(entry)
        }
        return updated
    }
}

struct LoggedError: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let message: String

    init(date: Date = Date(), message: String) {
        self.id = UUID()
        self.date = date
        self.message = message
    }
}

// MARK: - Controller

/// Owns the whole BLE lifecycle for one Blackmagic camera: scanning,
/// connecting, bonding (PIN pairing), notification decoding, outgoing
/// commands, persistence of the chosen camera, and automatic reconnection.
@MainActor
final class CameraBleController: NSObject, ObservableObject {
    @Published var phase: ConnectionPhase = .idle {
        didSet {
            if oldValue != phase {
                AppLog.ble.info("Connection phase: \(oldValue.label) → \(phase.label)")
            }
        }
    }
    @Published var discoveredCameras: [DiscoveredCamera] = []
    @Published var camera = CameraState()
    @Published var connectedName: String?
    @Published var lastError: String?
    @Published private(set) var errorToastID: UInt = 0
    /// Rolling history of surfaced errors, included in diagnostics exports.
    @Published private(set) var errorHistory: [LoggedError] = []
    /// Set while a record start/stop command awaits confirmation from the
    /// camera's transport notification.
    @Published var pendingRecordRequest: Bool?

    var recordConfirmationTask: Task<Void, Never>?

    var hasSavedCamera: Bool { savedCameraID != nil }
    var savedCameraName: String? { defaults.string(forKey: Self.savedNameKey) }

    static let savedIDKey = "CameraBleController.savedCameraID"
    static let savedNameKey = "CameraBleController.savedCameraName"

    let defaults = UserDefaults.standard
    var central: CBCentralManager!
    var peripheral: CBPeripheral?
    var characteristics: [CBUUID: CBCharacteristic] = [:]
    var userInitiatedDisconnect = false
    var wantsScan = false
    var rediscoveringSavedCamera = false

    var savedCameraID: UUID? {
        get { defaults.string(forKey: Self.savedIDKey).flatMap(UUID.init(uuidString:)) }
        set {
            if let newValue {
                defaults.set(newValue.uuidString, forKey: Self.savedIDKey)
            } else {
                defaults.removeObject(forKey: Self.savedIDKey)
                defaults.removeObject(forKey: Self.savedNameKey)
            }
        }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    func startScan() {
        wantsScan = true
        beginScan()
    }

    private func beginScan() {
        discoveredCameras = []
        guard central.state == .poweredOn else { return }
        guard peripheral?.state != .connected else { return }
        central.scanForPeripherals(
            withServices: [BlackmagicBleConstants.cameraService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        if phase == .idle || phase == .scanning {
            phase = .scanning
        }
    }

    func stopScan() {
        wantsScan = false
        guard !rediscoveringSavedCamera else { return }
        if central.state == .poweredOn {
            central.stopScan()
        }
        if phase == .scanning {
            phase = .idle
        }
    }

    func connect(to cameraID: UUID) {
        guard central.state == .poweredOn else { return }
        guard let target = central.retrievePeripherals(withIdentifiers: [cameraID]).first else {
            reportError("Camera is no longer in range.")
            return
        }
        rediscoveringSavedCamera = false
        central.stopScan()
        connect(peripheral: target)
    }

    /// Disconnects but keeps the camera saved for automatic reconnection.
    func disconnect() {
        userInitiatedDisconnect = true
        cancelConnection()
        phase = .idle
    }

    /// Disconnects and forgets the saved camera entirely.
    func forgetCamera() {
        savedCameraID = nil
        userInitiatedDisconnect = true
        cancelConnection()
        phase = .idle
    }

    /// Re-attempts connection to the saved camera. CoreBluetooth connect
    /// requests do not time out, so this also covers "camera switched on
    /// after the app launched" — the connection completes whenever the
    /// camera appears.
    func connectToSavedCamera() {
        guard central.state == .poweredOn, let savedCameraID else { return }
        guard peripheral?.state != .connected, peripheral?.state != .connecting else { return }
        if let target = central.retrievePeripherals(withIdentifiers: [savedCameraID]).first {
            connect(peripheral: target)
        } else {
            // Identifier unknown to this central — rediscover by scanning.
            rediscoveringSavedCamera = true
            beginScan()
        }
    }

    // MARK: - Sending

    @discardableResult
    func send(_ packet: () throws -> BlackmagicCcuPacket) -> Bool {
        do {
            let packet = try packet()
            AppLog.ccu.debug("send \(packet.bytes.map { String(format: "%02X", $0) }.joined())")
            try write(packet.bytes, to: BlackmagicBleConstants.outgoingCameraControl)
            return true
        } catch {
            reportError(friendlyMessage(for: error), category: AppLog.ccu)
            return false
        }
    }

    @discardableResult
    func sendApplying(
        _ packet: () throws -> BlackmagicCcuPacket,
        mutate: (inout CameraState) -> Void
    ) -> Bool {
        guard send(packet) else { return false }
        mutate(&camera)
        return true
    }

    // MARK: - Connection internals

    func connect(peripheral target: CBPeripheral) {
        userInitiatedDisconnect = false
        rediscoveringSavedCamera = false
        peripheral = target
        target.delegate = self
        connectedName = target.name ?? savedCameraName
        phase = .connecting
        central.connect(target, options: nil)
    }

    func cancelConnection() {
        wantsScan = false
        rediscoveringSavedCamera = false
        if central.state == .poweredOn {
            central.stopScan()
        }
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        characteristics = [:]
        connectedName = nil
        camera = CameraState()
    }

    func write(_ data: Data, to characteristicID: CBUUID) throws {
        guard central.state == .poweredOn else { throw ControllerError.bluetoothUnavailable }
        guard let peripheral, peripheral.state == .connected else { throw ControllerError.notConnected }
        guard let characteristic = characteristics[characteristicID] else { throw ControllerError.notReady }

        if characteristic.properties.contains(.write) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        } else if characteristic.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        } else {
            throw ControllerError.notReady
        }
    }

    /// Logs an error, records it in the history for diagnostics exports, and
    /// (optionally) surfaces it as the toast the UI shows.
    func reportError(_ message: String, category: AppLog.Category = AppLog.ble, toast: Bool = true) {
        category.error(message)
        errorHistory.append(LoggedError(message: message))
        if errorHistory.count > 50 {
            errorHistory.removeFirst(errorHistory.count - 50)
        }
        if toast {
            errorToastID &+= 1
            lastError = message
        }
    }

    func friendlyMessage(for error: Error) -> String {
        switch error {
        case ControllerError.bluetoothUnavailable: return "Bluetooth is unavailable."
        case ControllerError.notConnected: return "Camera is not connected."
        case ControllerError.notReady: return "Camera control is not ready yet."
        default: return error.localizedDescription
        }
    }

    private enum ControllerError: Error {
        case bluetoothUnavailable
        case notConnected
        case notReady
    }
}
