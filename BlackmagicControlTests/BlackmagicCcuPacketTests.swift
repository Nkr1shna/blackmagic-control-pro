import XCTest
@testable import BlackmagicControl

final class BlackmagicCcuPacketTests: XCTestCase {
    func testInstantAutofocusPacketMatchesProtocolExample() throws {
        let packet = try BlackmagicCcuPacket.changeConfiguration(
            destination: 4,
            category: 0,
            parameter: 1,
            dataType: .void,
            operation: .assign,
            payload: Data()
        )

        XCTAssertEqual(Array(packet.bytes), [4, 4, 0, 0, 0, 1, 0, 0])
    }

    func testSetExposurePacketMatchesProtocolExample() throws {
        let payload = BlackmagicCcuPacket.int32Payload(10000)
        let packet = try BlackmagicCcuPacket.changeConfiguration(
            destination: 4,
            category: 1,
            parameter: 5,
            dataType: .int32,
            operation: .assign,
            payload: payload
        )

        XCTAssertEqual(Array(packet.bytes), [4, 8, 0, 0, 1, 5, 3, 0, 0x10, 0x27, 0x00, 0x00])
    }

    func testMaximumPayloadLengthSucceeds() throws {
        let payload = Data(repeating: 0x7f, count: 56)
        let packet = try BlackmagicCcuPacket.changeConfiguration(
            destination: 4,
            category: 1,
            parameter: 2,
            dataType: .string,
            operation: .assign,
            payload: payload
        )

        XCTAssertEqual(packet.bytes.count, 64)
        XCTAssertEqual(Array(packet.bytes.prefix(4)), [4, 60, 0, 0])
    }

    func testPayloadOverMaximumLengthThrows() {
        XCTAssertThrowsError(
            try BlackmagicCcuPacket.changeConfiguration(
                destination: 4,
                category: 1,
                parameter: 2,
                dataType: .string,
                operation: .assign,
                payload: Data(repeating: 0x7f, count: 57)
            )
        ) { error in
            XCTAssertEqual(
                error as? BlackmagicCcuPacket.PacketError,
                .payloadTooLarge(max: 56, actual: 57)
            )
        }
    }

    func testOpticalImageStabilizationPacketIsPaddedToFourBytes() throws {
        let packet = try BlackmagicCcuPacket.changeConfiguration(
            destination: 255,
            category: 0,
            parameter: 6,
            dataType: .void,
            operation: .assign,
            payload: Data([1])
        )

        XCTAssertEqual(Array(packet.bytes), [255, 5, 0, 0, 0, 6, 0, 0, 1, 0, 0, 0])
    }

    func testFixed16PayloadUsesSignedFiveElevenEncoding() {
        XCTAssertEqual(Array(BlackmagicCcuPacket.fixed16Payload(0.15)), [0x33, 0x01])
        XCTAssertEqual(Array(BlackmagicCcuPacket.fixed16Payload(-0.3)), [0x9a, 0xfd])
    }

    func testFixed16PayloadClampsRangeAndZeroesNonFiniteValues() {
        XCTAssertEqual(Array(BlackmagicCcuPacket.fixed16Payload(16.0)), [0xff, 0x7f])
        XCTAssertEqual(Array(BlackmagicCcuPacket.fixed16Payload(-17.0)), [0x00, 0x80])
        XCTAssertEqual(Array(BlackmagicCcuPacket.fixed16Payload(.infinity)), [0x00, 0x00])
        XCTAssertEqual(Array(BlackmagicCcuPacket.fixed16Payload(.nan)), [0x00, 0x00])
    }
}
