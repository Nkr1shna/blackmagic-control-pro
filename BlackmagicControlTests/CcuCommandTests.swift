import XCTest
@testable import BlackmagicControl

final class CcuCommandTests: XCTestCase {
    func testAutoFocusMatchesProtocolExampleShape() throws {
        let packet = try CcuCommand.instantaneousAutoFocus()
        XCTAssertEqual(Array(packet.bytes), [255, 4, 0, 0, 0, 1, 0, 0])
    }

    func testOISMatchesProtocolExample() throws {
        let packet = try CcuCommand.opticalImageStabilisation(true)
        XCTAssertEqual(Array(packet.bytes), [255, 5, 0, 0, 0, 6, 0, 0, 1, 0, 0, 0])
    }

    func testExposureMatchesProtocolExampleShape() throws {
        let packet = try CcuCommand.exposureMicroseconds(10_000)
        XCTAssertEqual(Array(packet.bytes), [255, 8, 0, 0, 1, 5, 3, 0, 0x10, 0x27, 0x00, 0x00])
    }

    func testWhiteBalancePacket() throws {
        let packet = try CcuCommand.whiteBalance(kelvin: 5600, tint: 10)
        XCTAssertEqual(Array(packet.bytes), [255, 8, 0, 0, 1, 2, 2, 0, 0xE0, 0x15, 0x0A, 0x00])
    }

    func testRecordStartUsesTransportMode() throws {
        let packet = try CcuCommand.record(true)
        XCTAssertEqual(Array(packet.bytes), [255, 9, 0, 0, 10, 1, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0])
    }

    func testRecordStopReturnsToPreview() throws {
        let packet = try CcuCommand.record(false)
        XCTAssertEqual(Array(packet.bytes)[8], 0)
    }

    func testShutterAnglePacketScalesByHundred() throws {
        let packet = try CcuCommand.shutterAngle(hundredths: 17280)
        // 172.8° = 17280 = 0x4380
        XCTAssertEqual(Array(packet.bytes), [255, 8, 0, 0, 1, 11, 3, 0, 0x80, 0x43, 0x00, 0x00])
    }

    func testOverlayPacketEncodesFourElements() throws {
        var overlays = OverlayState()
        overlays.frameGuideStyle = 5
        overlays.frameGuideOpacity = 75
        overlays.safeAreaPercentage = 90
        overlays.gridFlags = [.thirds, .centerDot]

        let packet = try CcuCommand.overlays(overlays)
        XCTAssertEqual(Array(packet.bytes), [255, 8, 0, 0, 3, 3, 1, 0, 5, 75, 90, 0b101])
    }

    func testExposureToolsPacketEncodesBitFields() throws {
        var tools = ExposureToolsState()
        tools.tools = [.zebra, .falseColor]
        tools.displays = [.lcd, .hdmi]

        let packet = try CcuCommand.exposureTools(tools)
        XCTAssertEqual(Array(packet.bytes), [255, 8, 0, 0, 4, 1, 2, 0, 0b101, 0, 0b11, 0])
    }

    func testRecordingFormatPacket() throws {
        let format = RecordingFormat(
            fileFrameRate: 24,
            sensorFrameRate: 0,
            width: 4096,
            height: 2160,
            flags: [.fileMRate]
        )
        let packet = try CcuCommand.recordingFormat(format)
        XCTAssertEqual(
            Array(packet.bytes),
            [255, 14, 0, 0, 1, 9, 2, 0,
             24, 0, 0, 0, 0x00, 0x10, 0x70, 0x08, 1, 0, 0, 0]
        )
    }

    func testGainPacketEncodesNegativeDecibels() throws {
        let packet = try CcuCommand.gain(decibels: -6)
        XCTAssertEqual(Array(packet.bytes), [255, 5, 0, 0, 1, 13, 1, 0, 0xFA, 0, 0, 0])
    }

    func testCodecPacket() throws {
        let packet = try CcuCommand.codec(CodecInfo(codec: .blackmagicRaw, variant: 3))
        XCTAssertEqual(Array(packet.bytes), [255, 6, 0, 0, 10, 0, 1, 0, 3, 3, 0, 0])
    }

    func testColorLiftEncodesFourChannels() throws {
        let packet = try CcuCommand.colorLift(ColorWheel(red: 0, green: -0.3, blue: -0.3, luma: 0))
        XCTAssertEqual(
            Array(packet.bytes),
            [255, 12, 0, 0, 8, 0, 128, 0, 0, 0, 0x9A, 0xFD, 0x9A, 0xFD, 0, 0]
        )
    }

    func testRealTimeClockEncodesBCD() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 6
        components.hour = 15
        components.minute = 42
        components.second = 30
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: components)!

        let packet = try CcuCommand.realTimeClock(date: date, calendar: calendar)
        let bytes = Array(packet.bytes)

        // time BCD 0x15423000 little-endian
        XCTAssertEqual(Array(bytes[8...11]), [0x00, 0x30, 0x42, 0x15])
        // date BCD 0x20260706 little-endian
        XCTAssertEqual(Array(bytes[12...15]), [0x06, 0x07, 0x26, 0x20])
    }
}
