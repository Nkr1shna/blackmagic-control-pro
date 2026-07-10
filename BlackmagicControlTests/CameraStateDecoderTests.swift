import XCTest
@testable import BlackmagicControl

final class CameraStateDecoderTests: XCTestCase {
    private func message(
        category: UInt8,
        parameter: UInt8,
        dataType: UInt8 = 0,
        payload: [UInt8] = []
    ) -> CcuMessage {
        CcuMessage(
            destination: 255,
            category: category,
            parameter: parameter,
            dataType: dataType,
            operation: 0,
            payload: Data(payload)
        )
    }

    func testDecodesISO() {
        var state = CameraState()
        CameraStateDecoder.apply(
            message(category: 1, parameter: 14, dataType: 3, payload: [0x20, 0x03, 0, 0]),
            to: &state
        )
        XCTAssertEqual(state.iso, 800)
    }

    func testDecodesWhiteBalanceAndTint() {
        var state = CameraState()
        CameraStateDecoder.apply(
            message(category: 1, parameter: 2, dataType: 2, payload: [0xE0, 0x15, 0xF6, 0xFF]),
            to: &state
        )
        XCTAssertEqual(state.whiteBalanceKelvin, 5600)
        XCTAssertEqual(state.tint, -10)
    }

    func testDecodesShutterAngleAndClearsSpeed() {
        var state = CameraState()
        state.shutterSpeedFraction = 50
        CameraStateDecoder.apply(
            message(category: 1, parameter: 11, dataType: 3, payload: [0x80, 0x43, 0, 0]),
            to: &state
        )
        XCTAssertEqual(state.shutterAngleHundredths, 17280)
        XCTAssertNil(state.shutterSpeedFraction)
    }

    func testDecodesRecordingFormat() {
        var state = CameraState()
        CameraStateDecoder.apply(
            message(
                category: 1, parameter: 9, dataType: 2,
                payload: [24, 0, 24, 0, 0x00, 0x10, 0x70, 0x08, 0x01, 0x00]
            ),
            to: &state
        )
        XCTAssertEqual(state.recordingFormat?.fileFrameRate, 24)
        XCTAssertEqual(state.recordingFormat?.width, 4096)
        XCTAssertEqual(state.recordingFormat?.height, 2160)
        XCTAssertEqual(state.recordingFormat?.flags.contains(.fileMRate), true)
    }

    func testDecodesTransportRecording() {
        var state = CameraState()
        CameraStateDecoder.apply(
            message(category: 10, parameter: 1, dataType: 1, payload: [2, 0, 0b0010_0000, 1, 1]),
            to: &state
        )
        XCTAssertTrue(state.isRecording)
        XCTAssertEqual(state.transport?.slot1Medium, .sd)
        XCTAssertEqual(state.transport?.activeMediumLabel, "SD")
    }

    func testDecodesCodec() {
        var state = CameraState()
        CameraStateDecoder.apply(
            message(category: 10, parameter: 0, dataType: 1, payload: [3, 3]),
            to: &state
        )
        XCTAssertEqual(state.codec?.codec, .blackmagicRaw)
        XCTAssertEqual(state.codec?.label, "BRAW 5:1")
    }

    func testDecodesApertureStop() {
        var state = CameraState()
        // AV = 4.0 → 4.0 * 2048 = 8192 = 0x2000 → f/4
        CameraStateDecoder.apply(
            message(category: 0, parameter: 2, dataType: 128, payload: [0x00, 0x20]),
            to: &state
        )
        XCTAssertEqual(state.apertureStop ?? 0, 4.0, accuracy: 0.001)
        XCTAssertEqual(state.fNumber ?? 0, 4.0, accuracy: 0.01)
        XCTAssertEqual(state.irisLabel, "f4.0")
    }

    func testDecodesColorCorrectionGamma() {
        var state = CameraState()
        CameraStateDecoder.apply(
            message(
                category: 8, parameter: 1, dataType: 128,
                payload: [0, 0, 0x9A, 0xFD, 0x9A, 0xFD, 0, 0]
            ),
            to: &state
        )
        XCTAssertEqual(state.colorCorrection.gamma.green, -0.3, accuracy: 0.001)
        XCTAssertEqual(state.colorCorrection.gamma.blue, -0.3, accuracy: 0.001)
        XCTAssertEqual(state.colorCorrection.gamma.red, 0, accuracy: 0.001)
    }

    func testDecodesExposureTools() {
        var state = CameraState()
        CameraStateDecoder.apply(
            message(category: 4, parameter: 1, dataType: 2, payload: [0b011, 0, 0b11, 0]),
            to: &state
        )
        XCTAssertTrue(state.exposureTools.tools.contains(.zebra))
        XCTAssertTrue(state.exposureTools.tools.contains(.focusAssist))
        XCTAssertFalse(state.exposureTools.tools.contains(.falseColor))
    }

    func testDecodesDisplayLutWithTwoElements() {
        var state = CameraState()
        CameraStateDecoder.apply(
            message(category: 1, parameter: 15, dataType: 1, payload: [2, 1]),
            to: &state
        )
        XCTAssertEqual(state.displayLut?.selectedLut, 2)
        XCTAssertEqual(state.displayLut?.isEnabled, true)
    }

    func testDecodesDisplayLutWithSingleElement() {
        var state = CameraState()
        CameraStateDecoder.apply(
            message(category: 1, parameter: 15, dataType: 1, payload: [3]),
            to: &state
        )
        XCTAssertEqual(state.displayLut?.selectedLut, 3)
        XCTAssertEqual(state.displayLut?.isEnabled, true)

        CameraStateDecoder.apply(
            message(category: 1, parameter: 15, dataType: 1, payload: [0]),
            to: &state
        )
        XCTAssertEqual(state.displayLut?.selectedLut, 0)
    }

    func testIgnoresUnknownCategories() {
        var state = CameraState()
        let before = state
        CameraStateDecoder.apply(
            message(category: 200, parameter: 9, dataType: 1, payload: [1, 2, 3]),
            to: &state
        )
        XCTAssertEqual(state, before)
    }

    func testBatteryDecodeRejectsImplausibleValues() {
        var state = CameraState()
        CameraStateDecoder.apply(
            message(category: 9, parameter: 0, dataType: 2, payload: [0x00, 0x00, 0xFF, 0x7F]),
            to: &state
        )
        XCTAssertNil(state.battery)
    }

    func testBatteryDecodeAcceptsPlausibleValues() {
        var state = CameraState()
        // 14.4 V (14400 mV = 0x3840), 76 %
        CameraStateDecoder.apply(
            message(category: 9, parameter: 0, dataType: 2, payload: [0x40, 0x38, 76, 0]),
            to: &state
        )
        XCTAssertEqual(state.battery?.voltageMillivolts, 14400)
        XCTAssertEqual(state.battery?.percent, 76)
    }
}
