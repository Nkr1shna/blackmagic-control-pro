import XCTest
@testable import BlackmagicControl

final class CcuProtocolTests: XCTestCase {
    // MARK: - Incoming message parsing

    func testParsesSingleMessage() {
        // ISO 800 on camera 1: header [1, 8, 0, 0], command [1, 14, 3, 0], data 800 LE
        let data = Data([1, 8, 0, 0, 1, 14, 3, 0, 0x20, 0x03, 0x00, 0x00])
        let messages = BlackmagicCcuPacket.parseMessages(from: data)

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].destination, 1)
        XCTAssertEqual(messages[0].category, 1)
        XCTAssertEqual(messages[0].parameter, 14)
        XCTAssertEqual(messages[0].dataType, 3)
        XCTAssertEqual(messages[0].operation, 0)
        XCTAssertEqual(messages[0].int32Values, [800])
    }

    func testParsesConcatenatedMessagesWithPadding() {
        // White balance (int16 pair, 8-byte command, no padding) followed by
        // a bool OIS message (5-byte command, padded to 8).
        var data = Data([255, 8, 0, 0, 1, 2, 2, 0, 0xE0, 0x15, 0x0A, 0x00])
        data.append(Data([255, 5, 0, 0, 0, 6, 0, 0, 1, 0, 0, 0]))

        let messages = BlackmagicCcuPacket.parseMessages(from: data)

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].int16Values, [5600, 10])
        XCTAssertEqual(messages[1].category, 0)
        XCTAssertEqual(messages[1].parameter, 6)
        XCTAssertEqual(messages[1].boolValue, true)
    }

    func testParsingIgnoresTruncatedTrailingData() {
        let data = Data([1, 8, 0, 0, 1, 14, 3, 0, 0x20, 0x03, 0x00, 0x00, 255, 60, 0])
        let messages = BlackmagicCcuPacket.parseMessages(from: data)
        XCTAssertEqual(messages.count, 1)
    }

    func testParsingIgnoresOversizedLengthClaim() {
        // Claims 60 bytes of command data but only 4 are present.
        let data = Data([1, 60, 0, 0, 1, 14, 3, 0])
        XCTAssertEqual(BlackmagicCcuPacket.parseMessages(from: data), [])
    }

    func testFixed16RoundTrip() {
        let payload = BlackmagicCcuPacket.fixed16Payload(0.15)
        let raw = Int16(payload[0]) | (Int16(payload[1]) << 8)
        XCTAssertEqual(BlackmagicCcuPacket.fixed16Value(raw), 0.15, accuracy: 0.001)
    }

    func testNegativeFixed16Decoding() {
        let message = CcuMessage(
            destination: 255, category: 8, parameter: 1, dataType: 128, operation: 0,
            payload: Data([0x9A, 0xFD]) // -0.3 from the protocol example
        )
        XCTAssertEqual(message.fixed16Values[0], -0.3, accuracy: 0.001)
    }

    // MARK: - Timecode characteristic

    func testTimecodeDecodesBCDLittleEndian() {
        // 09:12:53:10 = BCD 0x09125310, little-endian on the wire.
        let data = Data([0, 0, 0, 0, 0, 0, 0, 0, 0x10, 0x53, 0x12, 0x09])
        XCTAssertEqual(BlackmagicCcuPacket.timecodeString(from: data), "09:12:53:10")
    }

    func testTimecodeMasksDropFrameFlag()  {
        // Same timecode with the drop-frame top bit set on the hours byte.
        let data = Data([0x10, 0x53, 0x12, 0x89])
        XCTAssertEqual(BlackmagicCcuPacket.timecodeString(from: data), "09:12:53:10")
    }

    func testTimecodeRejectsShortData() {
        XCTAssertNil(BlackmagicCcuPacket.timecodeString(from: Data([1, 2])))
    }
}
