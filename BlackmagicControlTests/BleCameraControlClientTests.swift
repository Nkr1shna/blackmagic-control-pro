import CoreBluetooth
import XCTest
@testable import BlackmagicControl

final class BleCameraControlClientTests: XCTestCase {
    func testCommandPacketsUseBlackmagicCameraControlIds() throws {
        XCTAssertEqual(
            Array(try BleCameraControlClient.makeRecordTransportModePacket(recording: true).bytes.prefix(9)),
            [255, 5, 0, 0, 10, 1, 1, 0, 2]
        )
        XCTAssertEqual(
            Array(try BleCameraControlClient.makeISOPacket(1250).bytes.prefix(8)),
            [255, 8, 0, 0, 1, 14, 3, 0]
        )
        XCTAssertEqual(
            Array(try BleCameraControlClient.makeShutterAnglePacket("bad input").bytes),
            [255, 8, 0, 0, 1, 11, 3, 0, 0x50, 0x46, 0, 0]
        )
        XCTAssertEqual(
            Array(try BleCameraControlClient.makeWhiteBalancePacket(kelvin: 5600, tint: 10).bytes.prefix(8)),
            [255, 8, 0, 0, 1, 2, 2, 0]
        )
        XCTAssertEqual(
            Array(try BleCameraControlClient.makeAutoWhiteBalancePacket().bytes),
            [255, 4, 0, 0, 1, 3, 0, 0]
        )
        XCTAssertEqual(
            Array(try BleCameraControlClient.makeIrisPacket(0.5).bytes.prefix(8)),
            [255, 6, 0, 0, 0, 3, 128, 0]
        )
        XCTAssertEqual(
            Array(try BleCameraControlClient.makeFocusPacket(0.5).bytes.prefix(8)),
            [255, 6, 0, 0, 0, 0, 128, 0]
        )
        XCTAssertEqual(
            Array(try BleCameraControlClient.makeAutoFocusPacket().bytes),
            [255, 4, 0, 0, 0, 1, 0, 0]
        )
    }

    func testBluetoothStateMappingDoesNotReportScanningWhenUnavailable() {
        let poweredOff = BleCameraControlClient.makeState(
            centralState: .poweredOff,
            peripheralState: nil,
            isScanning: true
        )
        XCTAssertEqual(poweredOff.controlTransport, .disconnected)
        XCTAssertEqual(poweredOff.connectionStatus, "BLE powered off")

        let unsupported = BleCameraControlClient.makeState(
            centralState: .unsupported,
            peripheralState: nil,
            isScanning: true
        )
        XCTAssertEqual(unsupported.controlTransport, .disconnected)
        XCTAssertEqual(unsupported.connectionStatus, "BLE unsupported")

        let unauthorized = BleCameraControlClient.makeState(
            centralState: .unauthorized,
            peripheralState: nil,
            isScanning: true
        )
        XCTAssertEqual(unauthorized.controlTransport, .disconnected)
        XCTAssertEqual(unauthorized.connectionStatus, "BLE unauthorized")

        let resetting = BleCameraControlClient.makeState(
            centralState: .resetting,
            peripheralState: nil,
            isScanning: true
        )
        XCTAssertEqual(resetting.controlTransport, .disconnected)
        XCTAssertEqual(resetting.connectionStatus, "BLE resetting")

        let unknown = BleCameraControlClient.makeState(
            centralState: .unknown,
            peripheralState: nil,
            isScanning: true
        )
        XCTAssertEqual(unknown.controlTransport, .disconnected)
        XCTAssertEqual(unknown.connectionStatus, "BLE unavailable")

        let scanning = BleCameraControlClient.makeState(
            centralState: .poweredOn,
            peripheralState: nil,
            isScanning: true
        )
        XCTAssertEqual(scanning.controlTransport, .ble)
        XCTAssertEqual(scanning.connectionStatus, "BLE scanning")
    }

    func testWriteReadinessReportsExplicitErrorsAndPrefersWritesWithResponse() throws {
        XCTAssertThrowsError(
            try BleCameraControlClient.writeType(
                centralState: .poweredOff,
                peripheralState: .connected,
                characteristicProperties: [.write],
                canSendWriteWithoutResponse: true
            )
        ) { error in
            XCTAssertEqual(error as? BleCameraControlError, .bluetoothUnavailable)
        }

        XCTAssertThrowsError(
            try BleCameraControlClient.writeType(
                centralState: .poweredOn,
                peripheralState: .disconnected,
                characteristicProperties: [.write],
                canSendWriteWithoutResponse: true
            )
        ) { error in
            XCTAssertEqual(error as? BleCameraControlError, .notConnected)
        }

        XCTAssertThrowsError(
            try BleCameraControlClient.writeType(
                centralState: .poweredOn,
                peripheralState: .connected,
                characteristicProperties: nil,
                canSendWriteWithoutResponse: true
            )
        ) { error in
            XCTAssertEqual(error as? BleCameraControlError, .cameraControlNotReady)
        }

        XCTAssertThrowsError(
            try BleCameraControlClient.writeType(
                centralState: .poweredOn,
                peripheralState: .connected,
                characteristicProperties: CBCharacteristicProperties(rawValue: 0),
                canSendWriteWithoutResponse: true
            )
        ) { error in
            XCTAssertEqual(error as? BleCameraControlError, .writeNotSupported)
        }

        XCTAssertThrowsError(
            try BleCameraControlClient.writeType(
                centralState: .poweredOn,
                peripheralState: .connected,
                characteristicProperties: [.writeWithoutResponse],
                canSendWriteWithoutResponse: false
            )
        ) { error in
            XCTAssertEqual(error as? BleCameraControlError, .cannotWriteWithoutResponse)
        }

        let preferredWriteType = try BleCameraControlClient.writeType(
            centralState: .poweredOn,
            peripheralState: .connected,
            characteristicProperties: [.write, .writeWithoutResponse],
            canSendWriteWithoutResponse: false
        )
        XCTAssertEqual(preferredWriteType, .withResponse)

        let writeWithoutResponseType = try BleCameraControlClient.writeType(
            centralState: .poweredOn,
            peripheralState: .connected,
            characteristicProperties: [.writeWithoutResponse],
            canSendWriteWithoutResponse: true
        )
        XCTAssertEqual(writeWithoutResponseType, .withoutResponse)
    }
}
