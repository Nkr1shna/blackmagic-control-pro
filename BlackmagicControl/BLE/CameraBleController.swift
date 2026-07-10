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

// MARK: - Controller

/// Owns the whole BLE lifecycle for one Blackmagic camera: scanning,
/// connecting, bonding (PIN pairing), notification decoding, outgoing
/// commands, persistence of the chosen camera, and automatic reconnection.
@MainActor
final class CameraBleController: NSObject, ObservableObject {
    @Published private(set) var phase: ConnectionPhase = .idle
    @Published private(set) var discoveredCameras: [DiscoveredCamera] = []
    @Published private(set) var camera = CameraState()
    @Published private(set) var connectedName: String?
    @Published var lastError: String?
    /// Set while a record start/stop command awaits confirmation from the
    /// camera's transport notification.
    @Published private(set) var pendingRecordRequest: Bool?

    private var recordConfirmationTask: Task<Void, Never>?

    var hasSavedCamera: Bool { savedCameraID != nil }
    var savedCameraName: String? { defaults.string(forKey: Self.savedNameKey) }

    private static let savedIDKey = "CameraBleController.savedCameraID"
    private static let savedNameKey = "CameraBleController.savedCameraName"

    private let defaults = UserDefaults.standard
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    private var userInitiatedDisconnect = false
    private var wantsScan = false

    private var savedCameraID: UUID? {
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
        if central.state == .poweredOn {
            central.stopScan()
        }
        if phase == .scanning {
            phase = savedCameraID == nil ? .idle : phase
        }
    }

    func connect(to cameraID: UUID) {
        guard central.state == .poweredOn else { return }
        guard let target = central.retrievePeripherals(withIdentifiers: [cameraID]).first else {
            lastError = "Camera is no longer in range."
            return
        }
        central.stopScan()
        connect(peripheral: target)
    }

    /// Disconnects but keeps the camera saved for automatic reconnection.
    func disconnect() {
        userInitiatedDisconnect = true
        cancelConnection()
        phase = savedCameraID == nil ? .idle : .idle
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
            startScan()
        }
    }

    // MARK: - Commands

    func send(_ packet: () throws -> BlackmagicCcuPacket) {
        do {
            let packet = try packet()
            try write(packet.bytes, to: BlackmagicBleConstants.outgoingCameraControl)
        } catch {
            lastError = friendlyMessage(for: error)
        }
    }

    /// Record state is NOT applied optimistically: the button reflects only
    /// what the camera confirms via its transport-mode notification. If no
    /// confirmation arrives (no media, full card, …) a warning is surfaced.
    func setRecording(_ recording: Bool) {
        send { try CcuCommand.record(recording) }
        pendingRecordRequest = recording

        recordConfirmationTask?.cancel()
        recordConfirmationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            guard self.pendingRecordRequest == recording else { return }

            self.pendingRecordRequest = nil
            if self.camera.isRecording != recording {
                self.lastError = recording
                    ? "The camera did not start recording. Check its media and storage."
                    : "The camera did not confirm the recording stopped."
            }
        }
    }

    func setISO(_ iso: Int) {
        send { try CcuCommand.iso(Int32(clamping: iso)) }
        camera.iso = iso
    }

    func setGain(decibels: Int) {
        send { try CcuCommand.gain(decibels: Int8(clamping: decibels)) }
        camera.gainDb = decibels
    }

    func setShutterAngle(degrees: Double) {
        let hundredths = Int32((degrees * 100).rounded())
        send { try CcuCommand.shutterAngle(hundredths: hundredths) }
        camera.shutterAngleHundredths = hundredths
        camera.shutterSpeedFraction = nil
    }

    func setShutterSpeed(fraction: Int) {
        send { try CcuCommand.shutterSpeed(fraction: Int32(clamping: fraction)) }
        camera.shutterSpeedFraction = Int32(clamping: fraction)
        camera.shutterAngleHundredths = nil
    }

    func setWhiteBalance(kelvin: Int, tint: Int) {
        send {
            try CcuCommand.whiteBalance(
                kelvin: Int16(clamping: kelvin),
                tint: Int16(clamping: tint)
            )
        }
        camera.whiteBalanceKelvin = kelvin
        camera.tint = tint
    }

    func triggerAutoWhiteBalance() {
        send { try CcuCommand.autoWhiteBalance() }
    }

    func restoreAutoWhiteBalance() {
        send { try CcuCommand.restoreAutoWhiteBalance() }
    }

    func setFocus(_ normalised: Double) {
        send { try CcuCommand.focus(normalised) }
        camera.focusNormalised = normalised
    }

    func nudgeFocus(by delta: Double) {
        send { try CcuCommand.focusOffset(delta) }
    }

    func triggerAutoFocus() {
        send { try CcuCommand.instantaneousAutoFocus() }
    }

    func setApertureNormalised(_ normalised: Double) {
        send { try CcuCommand.apertureNormalised(normalised) }
        camera.apertureNormalised = normalised
    }

    func triggerAutoAperture() {
        send { try CcuCommand.instantaneousAutoAperture() }
    }

    func setOpticalImageStabilisation(_ enabled: Bool) {
        send { try CcuCommand.opticalImageStabilisation(enabled) }
        camera.opticalImageStabilisation = enabled
    }

    func setFrameRate(fps: Int, mRate: Bool) {
        guard var format = camera.recordingFormat else {
            lastError = "Waiting for the camera to report its recording format."
            return
        }
        format.fileFrameRate = fps
        format.sensorFrameRate = 0 // 0 = leave sensor rate unchanged
        if mRate {
            format.flags.insert(.fileMRate)
        } else {
            format.flags.remove(.fileMRate)
        }
        send { try CcuCommand.recordingFormat(format) }
        format.sensorFrameRate = camera.recordingFormat?.sensorFrameRate ?? 0
        camera.recordingFormat = format
    }

    func setResolution(width: Int, height: Int) {
        guard var format = camera.recordingFormat else {
            lastError = "Waiting for the camera to report its recording format."
            return
        }
        format.width = width
        format.height = height
        if width < 3800 {
            format.flags.insert(.windowed)
        } else {
            format.flags.remove(.windowed)
        }
        send { try CcuCommand.recordingFormat(format) }
        camera.recordingFormat = format
    }

    func setCodec(_ codec: BasicCodec, variant: UInt8) {
        send { try CcuCommand.codec(CodecInfo(codec: codec, variant: variant)) }
        camera.codec = CodecInfo(codec: codec, variant: variant)
    }

    func setDynamicRange(_ mode: DynamicRangeMode) {
        send { try CcuCommand.dynamicRange(mode) }
        camera.dynamicRange = mode
    }

    func setSharpening(_ level: SharpeningLevel) {
        send { try CcuCommand.sharpening(level) }
        camera.sharpening = level
    }

    func setAutoExposureMode(_ mode: AutoExposureMode) {
        send { try CcuCommand.autoExposureMode(mode) }
        camera.autoExposureMode = mode
    }

    func setDisplayLut(selected: Int, enabled: Bool) {
        send { try CcuCommand.displayLut(selected: Int8(clamping: selected), enabled: enabled) }
        camera.displayLut = DisplayLutState(selectedLut: selected, isEnabled: enabled)
    }

    func setOverlays(_ overlays: OverlayState) {
        send { try CcuCommand.overlays(overlays) }
        camera.overlays = overlays
    }

    func setExposureTools(_ tools: ExposureToolsState) {
        send { try CcuCommand.exposureTools(tools) }
        camera.exposureTools = tools
    }

    func toggleExposureTool(_ tool: ExposureToolsState.Tools) {
        var state = camera.exposureTools
        if state.tools.contains(tool) {
            state.tools.remove(tool)
        } else {
            state.tools.insert(tool)
        }
        if state.displays.isEmpty {
            state.displays = [.lcd, .hdmi]
        }
        setExposureTools(state)
    }

    func setZebraLevel(_ level: Double) {
        send { try CcuCommand.zebraLevel(level) }
        camera.zebraLevel = level
    }

    func setPeakingLevel(_ level: Double) {
        send { try CcuCommand.peakingLevel(level) }
        camera.peakingLevel = level
    }

    func setFocusAssist(_ style: FocusAssistStyle) {
        send { try CcuCommand.focusAssist(style) }
        camera.focusAssist = style
    }

    func setColorBars(seconds: Int) {
        send { try CcuCommand.colorBars(seconds: Int8(clamping: seconds)) }
        camera.colorBarsSeconds = Int8(clamping: seconds)
    }

    func setDisplayBrightness(_ level: Double) {
        send { try CcuCommand.displayBrightness(level) }
        camera.displayBrightness = level
    }

    func setAudio(_ update: (inout AudioState) -> Void) {
        var audio = camera.audio
        update(&audio)

        if audio.micLevel != camera.audio.micLevel, let value = audio.micLevel {
            send { try CcuCommand.micLevel(value) }
        }
        if audio.headphoneLevel != camera.audio.headphoneLevel, let value = audio.headphoneLevel {
            send { try CcuCommand.headphoneLevel(value) }
        }
        if audio.headphoneProgramMix != camera.audio.headphoneProgramMix, let value = audio.headphoneProgramMix {
            send { try CcuCommand.headphoneProgramMix(value) }
        }
        if audio.speakerLevel != camera.audio.speakerLevel, let value = audio.speakerLevel {
            send { try CcuCommand.speakerLevel(value) }
        }
        if audio.inputType != camera.audio.inputType, let value = audio.inputType {
            send { try CcuCommand.audioInputType(value) }
        }
        if audio.inputLevelCh0 != camera.audio.inputLevelCh0 || audio.inputLevelCh1 != camera.audio.inputLevelCh1 {
            send {
                try CcuCommand.audioInputLevels(
                    ch0: audio.inputLevelCh0 ?? 0,
                    ch1: audio.inputLevelCh1 ?? 0
                )
            }
        }
        if audio.phantomPower != camera.audio.phantomPower, let value = audio.phantomPower {
            send { try CcuCommand.phantomPower(value) }
        }

        camera.audio = audio
    }

    func setTallyBrightness(front: Double?, rear: Double?) {
        if let front {
            send { try CcuCommand.tallyFrontBrightness(front) }
            camera.tallyFrontBrightness = front
        }
        if let rear {
            send { try CcuCommand.tallyRearBrightness(rear) }
            camera.tallyRearBrightness = rear
        }
    }

    func setColorCorrection(_ update: (inout ColorCorrectionState) -> Void) {
        var color = camera.colorCorrection
        update(&color)

        if color.lift != camera.colorCorrection.lift {
            send { try CcuCommand.colorLift(color.lift) }
        }
        if color.gamma != camera.colorCorrection.gamma {
            send { try CcuCommand.colorGamma(color.gamma) }
        }
        if color.gain != camera.colorCorrection.gain {
            send { try CcuCommand.colorGain(color.gain) }
        }
        if color.offset != camera.colorCorrection.offset {
            send { try CcuCommand.colorOffset(color.offset) }
        }
        if color.contrastPivot != camera.colorCorrection.contrastPivot
            || color.contrastAdjust != camera.colorCorrection.contrastAdjust {
            send { try CcuCommand.contrast(pivot: color.contrastPivot, adjust: color.contrastAdjust) }
        }
        if color.lumaMix != camera.colorCorrection.lumaMix {
            send { try CcuCommand.lumaMix(color.lumaMix) }
        }
        if color.hue != camera.colorCorrection.hue || color.saturation != camera.colorCorrection.saturation {
            send { try CcuCommand.colorAdjust(hue: color.hue, saturation: color.saturation) }
        }

        camera.colorCorrection = color
    }

    func resetColorCorrection() {
        send { try CcuCommand.colorCorrectionReset() }
        camera.colorCorrection = ColorCorrectionState()
    }

    func setTimecodeSource(clip: Bool) {
        send { try CcuCommand.timecodeSource(clip: clip) }
        camera.timecodeSourceClip = clip
    }

    func setReferenceSource(_ source: Int) {
        send { try CcuCommand.referenceSource(Int8(clamping: source)) }
        camera.referenceSource = Int8(clamping: source)
    }

    func syncCameraClock() {
        send { try CcuCommand.realTimeClock(date: Date()) }
        send { try CcuCommand.timezone(minutesFromUTC: Int32(TimeZone.current.secondsFromGMT() / 60)) }
    }

    func playbackClip(next: Bool) {
        send { try CcuCommand.playbackClip(next: next) }
    }

    func startPlayback() {
        send { try CcuCommand.transportMode(.play, speed: 1) }
    }

    func stopPlayback() {
        send { try CcuCommand.transportMode(.preview) }
    }

    func powerOffCamera() {
        do {
            try write(Data([0x00]), to: BlackmagicBleConstants.cameraStatus)
        } catch {
            lastError = friendlyMessage(for: error)
        }
    }

    func setCameraDisplayName(_ name: String) {
        let trimmed = String(name.prefix(32))
        guard let data = trimmed.data(using: .utf8) else { return }
        try? write(data, to: BlackmagicBleConstants.deviceName)
    }

    // MARK: - Connection internals

    private func connect(peripheral target: CBPeripheral) {
        userInitiatedDisconnect = false
        peripheral = target
        target.delegate = self
        connectedName = target.name ?? savedCameraName
        phase = .connecting
        central.connect(target, options: nil)
    }

    private func cancelConnection() {
        wantsScan = false
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

    private func write(_ data: Data, to characteristicID: CBUUID) throws {
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

    private func friendlyMessage(for error: Error) -> String {
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

    // MARK: - Delegate handlers (main actor)

    fileprivate func handleCentralStateChange() {
        switch central.state {
        case .poweredOn:
            if savedCameraID != nil {
                connectToSavedCamera()
            } else if wantsScan {
                startScan()
            } else {
                phase = .idle
            }
        case .poweredOff:
            phase = .bluetoothOff
            peripheral = nil
            characteristics = [:]
        case .unauthorized:
            phase = .bluetoothUnauthorized
        default:
            break
        }
    }

    fileprivate func handleDiscovered(_ discovered: CBPeripheral, rssi: Int) {
        let name = discovered.name ?? "Blackmagic Camera"
        let entry = DiscoveredCamera(id: discovered.identifier, name: name, rssi: rssi)
        if let index = discoveredCameras.firstIndex(where: { $0.id == entry.id }) {
            discoveredCameras[index] = entry
        } else {
            discoveredCameras.append(entry)
        }
        discoveredCameras.sort { $0.rssi > $1.rssi }

        // Auto-reconnect path: the saved camera reappeared while scanning.
        if discovered.identifier == savedCameraID, peripheral == nil {
            central.stopScan()
            connect(peripheral: discovered)
        }
    }

    fileprivate func handleConnected(_ connected: CBPeripheral) {
        savedCameraID = connected.identifier
        defaults.set(connected.name ?? "Blackmagic Camera", forKey: Self.savedNameKey)
        connectedName = connected.name ?? "Blackmagic Camera"
        phase = .pairing
        connected.discoverServices([
            BlackmagicBleConstants.cameraService,
            BlackmagicBleConstants.deviceInformationService
        ])
    }

    fileprivate func handleDisconnected(_ disconnected: CBPeripheral, error: Error?) {
        guard disconnected.identifier == peripheral?.identifier else { return }
        characteristics = [:]
        camera = CameraState()

        if userInitiatedDisconnect {
            peripheral = nil
            connectedName = nil
            phase = .idle
            return
        }

        // Unexpected drop: keep the peripheral and ask CoreBluetooth to
        // reconnect. The request stays pending until the camera reappears.
        phase = .reconnecting
        central.connect(disconnected, options: nil)
    }

    fileprivate func handleFailedToConnect(_ failed: CBPeripheral, error: Error?) {
        guard failed.identifier == peripheral?.identifier else { return }
        lastError = error?.localizedDescription ?? "Failed to connect to the camera."
        phase = .reconnecting
        central.connect(failed, options: nil)
    }

    fileprivate func handleServicesDiscovered(_ serviced: CBPeripheral, error: Error?) {
        guard error == nil, let services = serviced.services else {
            lastError = error?.localizedDescription
            return
        }
        for service in services {
            serviced.discoverCharacteristics(nil, for: service)
        }
    }

    fileprivate func handleCharacteristicsDiscovered(_ discovered: CBPeripheral, service: CBService, error: Error?) {
        guard error == nil, let found = service.characteristics else {
            lastError = error?.localizedDescription
            return
        }

        for characteristic in found {
            characteristics[characteristic.uuid] = characteristic

            switch characteristic.uuid {
            case BlackmagicBleConstants.modelCharacteristic,
                 BlackmagicBleConstants.protocolVersion:
                discovered.readValue(for: characteristic)
            case BlackmagicBleConstants.incomingCameraControl,
                 BlackmagicBleConstants.timecode,
                 BlackmagicBleConstants.cameraStatus:
                // Subscribing to an encrypted characteristic initiates
                // bonding — iOS shows the PIN entry dialog and the camera
                // displays its 6-digit code.
                discovered.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }

        if service.uuid == BlackmagicBleConstants.cameraService {
            // Tell the camera who we are (shows in its Bluetooth menu) and
            // make sure it is awake.
            setCameraDisplayName(UIDevice.current.name)
            try? write(Data([0x01]), to: BlackmagicBleConstants.cameraStatus)
        }
    }

    fileprivate func handleNotificationStateUpdate(_ characteristic: CBCharacteristic, error: Error?) {
        if let error {
            let code = (error as NSError).code
            if code == CBATTError.insufficientEncryption.rawValue
                || code == CBATTError.insufficientAuthentication.rawValue {
                lastError = "Pairing failed. Re-enable Bluetooth on the camera and enter the PIN it displays."
            } else {
                lastError = error.localizedDescription
            }
            return
        }

        // A successful subscription to an encrypted characteristic means
        // bonding completed.
        if characteristic.uuid == BlackmagicBleConstants.incomingCameraControl, phase != .connected {
            phase = .connected
        }
    }

    fileprivate func handleValueUpdate(_ characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }

        switch characteristic.uuid {
        case BlackmagicBleConstants.incomingCameraControl:
            let messages = BlackmagicCcuPacket.parseMessages(from: data)
            var updated = camera
            CameraStateDecoder.apply(messages, to: &updated)
            camera = updated
            if phase != .connected {
                phase = .connected
            }
            if let pending = pendingRecordRequest, camera.isRecording == pending {
                pendingRecordRequest = nil
                recordConfirmationTask?.cancel()
            }

        case BlackmagicBleConstants.timecode:
            camera.timecode = BlackmagicCcuPacket.timecodeString(from: data)

        case BlackmagicBleConstants.cameraStatus:
            if let flags = data.first {
                camera.statusFlags = CameraStatusFlags(rawValue: flags)
            }

        case BlackmagicBleConstants.modelCharacteristic:
            camera.modelName = String(data: data, encoding: .utf8)

        case BlackmagicBleConstants.protocolVersion:
            camera.protocolVersion = String(data: data, encoding: .utf8)

        default:
            break
        }
    }
}

// MARK: - CoreBluetooth delegates
// The central manager runs on the main queue, so delegate callbacks can
// safely assume main-actor isolation.

extension CameraBleController: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated { handleCentralStateChange() }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        MainActor.assumeIsolated { handleDiscovered(peripheral, rssi: RSSI.intValue) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated { handleConnected(peripheral) }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        MainActor.assumeIsolated { handleFailedToConnect(peripheral, error: error) }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        MainActor.assumeIsolated { handleDisconnected(peripheral, error: error) }
    }
}

extension CameraBleController: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated { handleServicesDiscovered(peripheral, error: error) }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        MainActor.assumeIsolated { handleCharacteristicsDiscovered(peripheral, service: service, error: error) }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        MainActor.assumeIsolated { handleNotificationStateUpdate(characteristic, error: error) }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        MainActor.assumeIsolated { handleValueUpdate(characteristic, error: error) }
    }
}
