import XCTest
@testable import BlackmagicControl

final class CameraStateTests: XCTestCase {
    func testShutterLabelPrefersAngle() {
        var state = CameraState()
        state.shutterAngleHundredths = 17280
        state.exposureMicroseconds = 20_000
        XCTAssertEqual(state.shutterLabel, "172.8°")
    }

    func testShutterLabelWholeAngleOmitsDecimal() {
        var state = CameraState()
        state.shutterAngleHundredths = 18_000
        XCTAssertEqual(state.shutterLabel, "180°")
    }

    func testShutterLabelFallsBackToSpeedThenExposure() {
        var state = CameraState()
        state.shutterSpeedFraction = 50
        XCTAssertEqual(state.shutterLabel, "1/50")

        state.shutterSpeedFraction = nil
        state.exposureMicroseconds = 20_000
        XCTAssertEqual(state.shutterLabel, "1/50")
    }

    func testFNumberDerivedFromApertureValue() {
        var state = CameraState()
        state.apertureStop = 2.0 // AV 2 → f/2
        XCTAssertEqual(state.fNumber ?? 0, 2.0, accuracy: 0.001)

        state.apertureStop = 5.0 // AV 5 → f/5.66
        XCTAssertEqual(state.fNumber ?? 0, 5.657, accuracy: 0.01)
    }

    func testFrameRateLabelHandlesMRate() {
        XCTAssertEqual(RecordingFormat.frameRateLabel(fps: 24, mRate: true), "23.98")
        XCTAssertEqual(RecordingFormat.frameRateLabel(fps: 30, mRate: true), "29.97")
        XCTAssertEqual(RecordingFormat.frameRateLabel(fps: 60, mRate: true), "59.94")
        XCTAssertEqual(RecordingFormat.frameRateLabel(fps: 25, mRate: false), "25")
    }

    func testResolutionLabels() {
        var format = RecordingFormat(fileFrameRate: 24, sensorFrameRate: 24, width: 4096, height: 2160, flags: [])
        XCTAssertEqual(format.resolutionLabel, "4K DCI")

        format.width = 1920
        format.height = 1080
        XCTAssertEqual(format.resolutionLabel, "HD")
    }

    func testCodecLabels() {
        XCTAssertEqual(CodecInfo(codec: .blackmagicRaw, variant: 0).label, "BRAW Q0")
        XCTAssertEqual(CodecInfo(codec: .proRes, variant: 0).label, "ProRes HQ")
        XCTAssertEqual(CodecInfo(codec: .proRes, variant: 3).label, "ProRes Proxy")
    }

    func testStatusFlagsParsing() {
        let flags = CameraStatusFlags(rawValue: 0x3F)
        XCTAssertTrue(flags.contains(.powerOn))
        XCTAssertTrue(flags.contains(.paired))
        XCTAssertTrue(flags.contains(.cameraReady))

        let offFlags = CameraStatusFlags(rawValue: 0x00)
        XCTAssertFalse(offFlags.contains(.powerOn))
    }

    func testIsRecordingFollowsTransportMode() {
        var state = CameraState()
        XCTAssertFalse(state.isRecording)

        state.transport = TransportState(mode: .record, speed: 0, flags: [], slot1Medium: nil, slot2Medium: nil)
        XCTAssertTrue(state.isRecording)

        state.transport?.mode = .preview
        XCTAssertFalse(state.isRecording)
    }

    func testPlaceholderLabelsWhenDisconnected() {
        let state = CameraState()
        XCTAssertEqual(state.isoLabel, "—")
        XCTAssertEqual(state.shutterLabel, "—")
        XCTAssertEqual(state.irisLabel, "—")
        XCTAssertEqual(state.whiteBalanceLabel, "—")
        XCTAssertEqual(state.fpsLabel, "—")
    }
}
