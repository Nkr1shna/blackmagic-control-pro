import CoreBluetooth
import Foundation

enum BleCameraControlError: Error, Equatable {
    case bluetoothUnavailable
    case notConnected
    case cameraControlNotReady
    case writeNotSupported
    case cannotWriteWithoutResponse
}

final class BleCameraControlClient: NSObject, CameraControlClient {
    let transport: CameraControlTransport = .ble

    private static let destination: UInt8 = 255

    private let bleQueue = DispatchQueue(label: "BlackmagicControl.BleCameraControlClient")
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var outgoingCameraControlCharacteristic: CBCharacteristic?

    func connect() async throws -> CameraState {
        try await performOnBleQueue {
            if self.centralManager == nil {
                self.centralManager = CBCentralManager(delegate: self, queue: self.bleQueue)
            }

            if self.centralManager?.state == .poweredOn {
                self.scanForCamera()
            }

            return self.currentState()
        }
    }

    func disconnect() async {
        await performOnBleQueue {
            self.centralManager?.stopScan()
            self.outgoingCameraControlCharacteristic = nil

            guard let peripheral = self.peripheral else {
                return
            }

            self.centralManager?.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
        }
    }

    func refreshState() async throws -> CameraState {
        try await performOnBleQueue {
            self.currentState()
        }
    }

    func setRecording(_ recording: Bool) async throws -> CameraState {
        let packet = try Self.makeRecordTransportModePacket(recording: recording)
        return try await performOnBleQueue {
            try self.write(packet)
            return self.currentState()
        }
    }

    func setISO(_ iso: Int) async throws -> CameraState {
        let packet = try Self.makeISOPacket(iso)
        return try await performOnBleQueue {
            try self.write(packet)
            return self.currentState()
        }
    }

    func setShutter(_ shutter: String) async throws -> CameraState {
        let packet = try Self.makeShutterAnglePacket(shutter)
        return try await performOnBleQueue {
            try self.write(packet)
            return self.currentState()
        }
    }

    func setWhiteBalance(kelvin: Int, tint: Int) async throws -> CameraState {
        let packet = try Self.makeWhiteBalancePacket(kelvin: kelvin, tint: tint)
        return try await performOnBleQueue {
            try self.write(packet)
            return self.currentState()
        }
    }

    func triggerAutoWhiteBalance() async throws -> CameraState {
        let packet = try Self.makeAutoWhiteBalancePacket()
        return try await performOnBleQueue {
            try self.write(packet)
            return self.currentState()
        }
    }

    func setIris(_ iris: Double) async throws -> CameraState {
        let packet = try Self.makeIrisPacket(iris)
        return try await performOnBleQueue {
            try self.write(packet)
            return self.currentState()
        }
    }

    func setFocus(_ focus: Double) async throws -> CameraState {
        let packet = try Self.makeFocusPacket(focus)
        return try await performOnBleQueue {
            try self.write(packet)
            return self.currentState()
        }
    }

    func triggerAutoFocus() async throws -> CameraState {
        let packet = try Self.makeAutoFocusPacket()
        return try await performOnBleQueue {
            try self.write(packet)
            return self.currentState()
        }
    }

    static func makeRecordTransportModePacket(recording: Bool) throws -> BlackmagicCcuPacket {
        try BlackmagicCcuPacket.changeConfiguration(
            destination: destination,
            category: 10,
            parameter: 1,
            dataType: .int8,
            operation: .assign,
            payload: Data([recording ? UInt8(2) : UInt8(0)])
        )
    }

    static func makeISOPacket(_ iso: Int) throws -> BlackmagicCcuPacket {
        try BlackmagicCcuPacket.changeConfiguration(
            destination: destination,
            category: 1,
            parameter: 14,
            dataType: .int32,
            operation: .assign,
            payload: BlackmagicCcuPacket.int32Payload(clampedInt32(iso))
        )
    }

    static func makeShutterAnglePacket(_ shutter: String) throws -> BlackmagicCcuPacket {
        try BlackmagicCcuPacket.changeConfiguration(
            destination: destination,
            category: 1,
            parameter: 11,
            dataType: .int32,
            operation: .assign,
            payload: BlackmagicCcuPacket.int32Payload(shutterAngleHundredths(shutter))
        )
    }

    static func makeWhiteBalancePacket(kelvin: Int, tint: Int) throws -> BlackmagicCcuPacket {
        var payload = Data()
        payload.append(BlackmagicCcuPacket.int16Payload(clampedInt16(kelvin)))
        payload.append(BlackmagicCcuPacket.int16Payload(clampedInt16(tint)))

        return try BlackmagicCcuPacket.changeConfiguration(
            destination: destination,
            category: 1,
            parameter: 2,
            dataType: .int16,
            operation: .assign,
            payload: payload
        )
    }

    static func makeAutoWhiteBalancePacket() throws -> BlackmagicCcuPacket {
        try BlackmagicCcuPacket.changeConfiguration(
            destination: destination,
            category: 1,
            parameter: 3,
            dataType: .void,
            operation: .assign,
            payload: Data()
        )
    }

    static func makeIrisPacket(_ iris: Double) throws -> BlackmagicCcuPacket {
        try BlackmagicCcuPacket.changeConfiguration(
            destination: destination,
            category: 0,
            parameter: 3,
            dataType: .fixed16,
            operation: .assign,
            payload: BlackmagicCcuPacket.fixed16Payload(iris)
        )
    }

    static func makeFocusPacket(_ focus: Double) throws -> BlackmagicCcuPacket {
        try BlackmagicCcuPacket.changeConfiguration(
            destination: destination,
            category: 0,
            parameter: 0,
            dataType: .fixed16,
            operation: .assign,
            payload: BlackmagicCcuPacket.fixed16Payload(focus)
        )
    }

    static func makeAutoFocusPacket() throws -> BlackmagicCcuPacket {
        try BlackmagicCcuPacket.changeConfiguration(
            destination: destination,
            category: 0,
            parameter: 1,
            dataType: .void,
            operation: .assign,
            payload: Data()
        )
    }

    static func makeState(
        centralState: CBManagerState?,
        peripheralState: CBPeripheralState?,
        isScanning: Bool
    ) -> CameraState {
        guard let centralState else {
            return state(transport: .disconnected, status: "BLE unavailable")
        }

        switch centralState {
        case .poweredOn:
            if peripheralState == .connected {
                return state(transport: .ble, status: "BLE connected")
            }
            if peripheralState == .connecting {
                return state(transport: .ble, status: "BLE connecting")
            }
            if isScanning {
                return state(transport: .ble, status: "BLE scanning")
            }
            return state(transport: .disconnected, status: "BLE disconnected")
        case .poweredOff:
            return state(transport: .disconnected, status: "BLE powered off")
        case .unsupported:
            return state(transport: .disconnected, status: "BLE unsupported")
        case .unauthorized:
            return state(transport: .disconnected, status: "BLE unauthorized")
        case .resetting:
            return state(transport: .disconnected, status: "BLE resetting")
        case .unknown:
            return state(transport: .disconnected, status: "BLE unavailable")
        @unknown default:
            return state(transport: .disconnected, status: "BLE unavailable")
        }
    }

    static func writeType(
        centralState: CBManagerState?,
        peripheralState: CBPeripheralState?,
        characteristicProperties: CBCharacteristicProperties?,
        canSendWriteWithoutResponse: Bool
    ) throws -> CBCharacteristicWriteType {
        guard centralState == .poweredOn else {
            throw BleCameraControlError.bluetoothUnavailable
        }
        guard peripheralState == .connected else {
            throw BleCameraControlError.notConnected
        }
        guard let characteristicProperties else {
            throw BleCameraControlError.cameraControlNotReady
        }

        if characteristicProperties.contains(.write) {
            return .withResponse
        }
        if characteristicProperties.contains(.writeWithoutResponse) {
            guard canSendWriteWithoutResponse else {
                throw BleCameraControlError.cannotWriteWithoutResponse
            }
            return .withoutResponse
        }

        throw BleCameraControlError.writeNotSupported
    }

    private static func state(transport: CameraControlTransport, status: String) -> CameraState {
        var state = CameraState()
        state.controlTransport = transport
        state.connectionStatus = status
        return state
    }

    private static func shutterAngleHundredths(_ shutter: String) -> Int32 {
        let normalized = shutter
            .replacingOccurrences(of: "degrees", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "degree", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "deg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "°", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let angle = Double(normalized), angle.isFinite else {
            return 18_000
        }

        let scaled = (angle * 100).rounded()
        if scaled > Double(Int32.max) {
            return Int32.max
        }
        if scaled < Double(Int32.min) {
            return Int32.min
        }
        return Int32(scaled)
    }

    private static func clampedInt16(_ value: Int) -> Int16 {
        Int16(min(max(value, Int(Int16.min)), Int(Int16.max)))
    }

    private static func clampedInt32(_ value: Int) -> Int32 {
        Int32(min(max(value, Int(Int32.min)), Int(Int32.max)))
    }

    private func performOnBleQueue<T>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            bleQueue.async {
                do {
                    continuation.resume(returning: try operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performOnBleQueue(_ operation: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            bleQueue.async {
                operation()
                continuation.resume()
            }
        }
    }

    private func currentState() -> CameraState {
        Self.makeState(
            centralState: centralManager?.state,
            peripheralState: peripheral?.state,
            isScanning: centralManager?.isScanning == true
        )
    }

    private func scanForCamera() {
        guard let centralManager, centralManager.state == .poweredOn else {
            return
        }

        centralManager.scanForPeripherals(
            withServices: [BlackmagicBleConstants.cameraService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func write(_ packet: BlackmagicCcuPacket) throws {
        let writeType = try Self.writeType(
            centralState: centralManager?.state,
            peripheralState: peripheral?.state,
            characteristicProperties: outgoingCameraControlCharacteristic?.properties,
            canSendWriteWithoutResponse: peripheral?.canSendWriteWithoutResponse ?? false
        )

        guard let peripheral else {
            throw BleCameraControlError.notConnected
        }
        guard let characteristic = outgoingCameraControlCharacteristic else {
            throw BleCameraControlError.cameraControlNotReady
        }

        peripheral.writeValue(packet.bytes, for: characteristic, type: writeType)
    }
}

extension BleCameraControlClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            return
        }

        scanForCamera()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover discoveredPeripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard peripheral == nil else {
            return
        }

        central.stopScan()
        peripheral = discoveredPeripheral
        discoveredPeripheral.delegate = self
        central.connect(discoveredPeripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([
            BlackmagicBleConstants.cameraService,
            BlackmagicBleConstants.deviceInformationService
        ])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if self.peripheral === peripheral {
            self.peripheral = nil
            outgoingCameraControlCharacteristic = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if self.peripheral === peripheral {
            self.peripheral = nil
            outgoingCameraControlCharacteristic = nil
        }
    }
}

extension BleCameraControlClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            return
        }

        for service in services {
            switch service.uuid {
            case BlackmagicBleConstants.cameraService:
                peripheral.discoverCharacteristics([
                    BlackmagicBleConstants.outgoingCameraControl,
                    BlackmagicBleConstants.incomingCameraControl,
                    BlackmagicBleConstants.timecode,
                    BlackmagicBleConstants.cameraStatus,
                    BlackmagicBleConstants.deviceName,
                    BlackmagicBleConstants.protocolVersion
                ], for: service)
            case BlackmagicBleConstants.deviceInformationService:
                peripheral.discoverCharacteristics([
                    BlackmagicBleConstants.manufacturerCharacteristic,
                    BlackmagicBleConstants.modelCharacteristic
                ], for: service)
            default:
                continue
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else {
            return
        }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case BlackmagicBleConstants.outgoingCameraControl:
                outgoingCameraControlCharacteristic = characteristic
            case BlackmagicBleConstants.incomingCameraControl,
                BlackmagicBleConstants.timecode,
                BlackmagicBleConstants.cameraStatus:
                subscribeIfSupported(characteristic, on: peripheral)
            default:
                continue
            }
        }
    }

    private func subscribeIfSupported(_ characteristic: CBCharacteristic, on peripheral: CBPeripheral) {
        guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
            return
        }

        peripheral.setNotifyValue(true, for: characteristic)
    }
}
