import CoreBluetooth
import Foundation
import UIKit

extension CameraBleController {
    // MARK: - Delegate handlers (main actor)

    func handleCentralStateChange() {
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

    func handleDiscovered(_ discovered: CBPeripheral, rssi: Int) {
        let name = discovered.name ?? "Blackmagic Camera"
        let entry = DiscoveredCamera(id: discovered.identifier, name: name, rssi: rssi)
        discoveredCameras = DiscoveredCameraList.updating(discoveredCameras, with: entry)

        // Auto-reconnect path: the saved camera reappeared while scanning.
        if discovered.identifier == savedCameraID, peripheral == nil {
            rediscoveringSavedCamera = false
            central.stopScan()
            connect(peripheral: discovered)
        }
    }

    func handleConnected(_ connected: CBPeripheral) {
        savedCameraID = connected.identifier
        defaults.set(connected.name ?? "Blackmagic Camera", forKey: Self.savedNameKey)
        connectedName = connected.name ?? "Blackmagic Camera"
        phase = .pairing
        connected.discoverServices([
            BlackmagicBleConstants.cameraService,
            BlackmagicBleConstants.deviceInformationService
        ])
    }

    func handleDisconnected(_ disconnected: CBPeripheral, error: Error?) {
        guard disconnected.identifier == peripheral?.identifier else { return }
        characteristics = [:]
        camera = CameraState()

        if userInitiatedDisconnect {
            AppLog.ble.info("Disconnected at user request")
            peripheral = nil
            connectedName = nil
            phase = .idle
            return
        }

        // Unexpected drop: keep the peripheral and ask CoreBluetooth to
        // reconnect. The request stays pending until the camera reappears.
        if let error {
            reportError("Camera connection lost (\(error.localizedDescription)). Reconnecting…")
        } else {
            AppLog.ble.warning("Camera connection lost without an error. Reconnecting…")
        }
        phase = .reconnecting
        central.connect(disconnected, options: nil)
    }

    func handleFailedToConnect(_ failed: CBPeripheral, error: Error?) {
        guard failed.identifier == peripheral?.identifier else { return }
        reportError(error?.localizedDescription ?? "Failed to connect to the camera.")
        phase = .reconnecting
        central.connect(failed, options: nil)
    }

    func handleServicesDiscovered(_ serviced: CBPeripheral, error: Error?) {
        guard error == nil, let services = serviced.services else {
            if let error {
                reportError("Service discovery failed: \(error.localizedDescription)")
            }
            return
        }
        for service in services {
            serviced.discoverCharacteristics(nil, for: service)
        }
    }

    func handleCharacteristicsDiscovered(_ discovered: CBPeripheral, service: CBService, error: Error?) {
        guard error == nil, let found = service.characteristics else {
            if let error {
                reportError("Characteristic discovery failed: \(error.localizedDescription)")
            }
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
            do {
                try write(Data([0x01]), to: BlackmagicBleConstants.cameraStatus)
            } catch {
                AppLog.ble.warning("Couldn't send wake command: \(friendlyMessage(for: error))")
            }
        }
    }

    func handleNotificationStateUpdate(_ characteristic: CBCharacteristic, error: Error?) {
        if let error {
            let code = (error as NSError).code
            if code == CBATTError.insufficientEncryption.rawValue
                || code == CBATTError.insufficientAuthentication.rawValue {
                reportError("Pairing failed. Re-enable Bluetooth on the camera and enter the PIN it displays.")
            } else {
                reportError(error.localizedDescription)
            }
            return
        }

        // A successful subscription to an encrypted characteristic means
        // bonding completed.
        if characteristic.uuid == BlackmagicBleConstants.incomingCameraControl, phase != .connected {
            phase = .connected
        }
    }

    func handleValueUpdate(_ characteristic: CBCharacteristic, error: Error?) {
        if let error {
            // Logged and kept in history, but not toasted: value updates can
            // arrive many times per second and would spam the UI.
            reportError("Camera data error: \(error.localizedDescription)", toast: false)
            return
        }
        guard let data = characteristic.value else { return }

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

    func handleWriteResult(_ characteristic: CBCharacteristic, error: Error?) {
        guard let error else { return }
        reportError("The camera rejected a command: \(error.localizedDescription)", category: AppLog.ccu)
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

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        MainActor.assumeIsolated { handleWriteResult(characteristic, error: error) }
    }
}
