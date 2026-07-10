import Foundation

struct BlackmagicCcuPacket: Equatable {
    enum PacketError: Error, Equatable {
        case payloadTooLarge(max: Int, actual: Int)
    }

    enum DataType: UInt8 {
        case void = 0
        case int8 = 1
        case int16 = 2
        case int32 = 3
        case int64 = 4
        case string = 5
        case fixed16 = 128
    }

    enum Operation: UInt8 {
        case assign = 0
        case offset = 1
    }

    private static let maxCommandDataLength = 60
    private static let commandHeaderLength = 4
    private static let maxPayloadLength = maxCommandDataLength - commandHeaderLength
    private static let fixed16Scale = 2048.0
    private static let fixed16Range = (-16.0)...15.99951171875

    let bytes: Data

    static func changeConfiguration(
        destination: UInt8,
        category: UInt8,
        parameter: UInt8,
        dataType: DataType,
        operation: Operation,
        payload: Data
    ) throws -> BlackmagicCcuPacket {
        guard payload.count <= maxPayloadLength else {
            throw PacketError.payloadTooLarge(max: maxPayloadLength, actual: payload.count)
        }

        var command = Data([category, parameter, dataType.rawValue, operation.rawValue])
        command.append(payload)

        var packet = Data([destination, UInt8(command.count), 0, 0])
        packet.append(command)

        while packet.count % 4 != 0 {
            packet.append(0)
        }

        return BlackmagicCcuPacket(bytes: packet)
    }

    static func int16Payload(_ value: Int16) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<Int16>.size)
    }

    static func int32Payload(_ value: Int32) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<Int32>.size)
    }

    static func fixed16Payload(_ value: Double) -> Data {
        let finiteValue = value.isFinite ? value : 0.0
        let clamped = min(max(finiteValue, fixed16Range.lowerBound), fixed16Range.upperBound)
        let scaled = Int16((clamped * fixed16Scale).rounded())
        return int16Payload(scaled)
    }

    static func fixed16Payload(_ values: [Double]) -> Data {
        values.reduce(into: Data()) { $0.append(fixed16Payload($1)) }
    }

    static func int16Payload(_ values: [Int16]) -> Data {
        values.reduce(into: Data()) { $0.append(int16Payload($1)) }
    }

    static func int32Payload(_ values: [Int32]) -> Data {
        values.reduce(into: Data()) { $0.append(int32Payload($1)) }
    }

    static func int64Payload(_ value: Int64) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: MemoryLayout<Int64>.size)
    }

    static func fixed16Value(_ raw: Int16) -> Double {
        Double(raw) / fixed16Scale
    }
}

// MARK: - Incoming message parsing

/// A single decoded CCU message (one command inside a packet stream).
struct CcuMessage: Equatable {
    let destination: UInt8
    let category: UInt8
    let parameter: UInt8
    let dataType: UInt8
    let operation: UInt8
    let payload: Data

    // MARK: payload readers (all little-endian per protocol)

    var int8Values: [Int8] {
        payload.map { Int8(bitPattern: $0) }
    }

    var int16Values: [Int16] {
        stride(from: 0, to: payload.count - 1, by: 2).map { offset in
            let bytes = Array(payload[payload.index(payload.startIndex, offsetBy: offset)...].prefix(2))
            return Int16(bitPattern: UInt16(bytes[0]) | (UInt16(bytes[1]) << 8))
        }
    }

    var uint16Values: [UInt16] {
        int16Values.map { UInt16(bitPattern: $0) }
    }

    var int32Values: [Int32] {
        stride(from: 0, to: payload.count - 3, by: 4).map { offset in
            let bytes = Array(payload[payload.index(payload.startIndex, offsetBy: offset)...].prefix(4))
            let raw = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
            return Int32(bitPattern: raw)
        }
    }

    var fixed16Values: [Double] {
        int16Values.map { BlackmagicCcuPacket.fixed16Value($0) }
    }

    var boolValue: Bool? {
        guard let first = payload.first else { return nil }
        return first != 0
    }

    var stringValue: String? {
        String(data: payload, encoding: .utf8)
    }
}

extension BlackmagicCcuPacket {
    /// Parses a BLE notification (which may contain several concatenated,
    /// padded messages) into individual CCU messages. Unknown or malformed
    /// trailing data is skipped safely.
    static func parseMessages(from data: Data) -> [CcuMessage] {
        var messages: [CcuMessage] = []
        let bytes = [UInt8](data)
        var offset = 0

        while offset + 4 <= bytes.count {
            let destination = bytes[offset]
            let commandLength = Int(bytes[offset + 1])
            let commandID = bytes[offset + 2]
            let commandStart = offset + 4

            guard commandLength > 0, commandStart + commandLength <= bytes.count else {
                break
            }

            // Command 0 = change configuration; ignore anything else.
            if commandID == 0, commandLength >= 4 {
                let payloadStart = commandStart + 4
                let payloadLength = commandLength - 4
                messages.append(
                    CcuMessage(
                        destination: destination,
                        category: bytes[commandStart],
                        parameter: bytes[commandStart + 1],
                        dataType: bytes[commandStart + 2],
                        operation: bytes[commandStart + 3],
                        payload: Data(bytes[payloadStart..<(payloadStart + payloadLength)])
                    )
                )
            }

            // Advance past the command data plus implicit 32-bit padding.
            let paddedLength = (commandLength + 3) / 4 * 4
            offset = commandStart + paddedLength
        }

        return messages
    }

    /// Decodes the BLE timecode characteristic: the last four bytes are a
    /// little-endian 32-bit BCD value (HH:MM:SS:FF).
    static func timecodeString(from data: Data) -> String? {
        guard data.count >= 4 else { return nil }
        let bytes = [UInt8](data.suffix(4))
        let bcd = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
        // Top bit of the hours byte flags drop-frame timecode; mask it off.
        let hours = (bcd >> 24) & 0x3F
        let minutes = (bcd >> 16) & 0xFF
        let seconds = (bcd >> 8) & 0xFF
        let frames = bcd & 0xFF
        return String(format: "%02X:%02X:%02X:%02X", hours, minutes, seconds, frames)
    }
}
