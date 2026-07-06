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
}
