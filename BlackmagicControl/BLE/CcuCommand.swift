import Foundation

/// Builders for every outgoing CCU "change configuration" command documented
/// in the Blackmagic SDI/Bluetooth Camera Control protocol. All commands are
/// broadcast (destination 255) since the BLE link is point-to-point.
enum CcuCommand {
    static let broadcast: UInt8 = 255

    private static func make(
        category: UInt8,
        parameter: UInt8,
        dataType: BlackmagicCcuPacket.DataType,
        operation: BlackmagicCcuPacket.Operation = .assign,
        payload: Data
    ) throws -> BlackmagicCcuPacket {
        try BlackmagicCcuPacket.changeConfiguration(
            destination: broadcast,
            category: category,
            parameter: parameter,
            dataType: dataType,
            operation: operation,
            payload: payload
        )
    }

    private static func boolPayload(_ value: Bool) -> Data {
        Data([value ? 1 : 0])
    }

    // MARK: - Category 0: Lens

    static func focus(_ normalised: Double) throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 0, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(normalised))
    }

    static func focusOffset(_ delta: Double) throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 0, dataType: .fixed16, operation: .offset,
                 payload: BlackmagicCcuPacket.fixed16Payload(delta))
    }

    static func instantaneousAutoFocus() throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 1, dataType: .void, payload: Data())
    }

    static func apertureStop(_ apertureValue: Double) throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 2, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(apertureValue))
    }

    static func apertureNormalised(_ normalised: Double) throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 3, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(normalised))
    }

    static func apertureOrdinal(_ step: Int16) throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 4, dataType: .int16,
                 payload: BlackmagicCcuPacket.int16Payload(step))
    }

    static func instantaneousAutoAperture() throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 5, dataType: .void, payload: Data())
    }

    static func opticalImageStabilisation(_ enabled: Bool) throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 6, dataType: .void, payload: boolPayload(enabled))
    }

    static func zoomMillimetres(_ mm: Int16) throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 7, dataType: .int16,
                 payload: BlackmagicCcuPacket.int16Payload(mm))
    }

    static func zoomNormalised(_ normalised: Double) throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 8, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(normalised))
    }

    static func zoomSpeed(_ speed: Double) throws -> BlackmagicCcuPacket {
        try make(category: 0, parameter: 9, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(speed))
    }

    // MARK: - Category 1: Video

    static func whiteBalance(kelvin: Int16, tint: Int16) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 2, dataType: .int16,
                 payload: BlackmagicCcuPacket.int16Payload([kelvin, tint]))
    }

    static func autoWhiteBalance() throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 3, dataType: .void, payload: Data())
    }

    static func restoreAutoWhiteBalance() throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 4, dataType: .void, payload: Data())
    }

    static func exposureMicroseconds(_ us: Int32) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 5, dataType: .int32,
                 payload: BlackmagicCcuPacket.int32Payload(us))
    }

    static func dynamicRange(_ mode: DynamicRangeMode) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 7, dataType: .int8, payload: Data([mode.rawValue]))
    }

    static func sharpening(_ level: SharpeningLevel) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 8, dataType: .int8, payload: Data([level.rawValue]))
    }

    static func recordingFormat(_ format: RecordingFormat) throws -> BlackmagicCcuPacket {
        let values: [Int16] = [
            Int16(clamping: format.fileFrameRate),
            Int16(clamping: format.sensorFrameRate),
            Int16(clamping: format.width),
            Int16(clamping: format.height),
            Int16(bitPattern: format.flags.rawValue)
        ]
        return try make(category: 1, parameter: 9, dataType: .int16,
                        payload: BlackmagicCcuPacket.int16Payload(values))
    }

    static func autoExposureMode(_ mode: AutoExposureMode) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 10, dataType: .int8, payload: Data([mode.rawValue]))
    }

    static func shutterAngle(hundredths: Int32) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 11, dataType: .int32,
                 payload: BlackmagicCcuPacket.int32Payload(hundredths))
    }

    static func shutterSpeed(fraction: Int32) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 12, dataType: .int32,
                 payload: BlackmagicCcuPacket.int32Payload(fraction))
    }

    static func gain(decibels: Int8) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 13, dataType: .int8,
                 payload: Data([UInt8(bitPattern: decibels)]))
    }

    static func iso(_ value: Int32) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 14, dataType: .int32,
                 payload: BlackmagicCcuPacket.int32Payload(value))
    }

    static func displayLut(selected: Int8, enabled: Bool) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 15, dataType: .int8,
                 payload: Data([UInt8(bitPattern: selected), enabled ? 1 : 0]))
    }

    static func ndFilterStop(_ stop: Double) throws -> BlackmagicCcuPacket {
        try make(category: 1, parameter: 16, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(stop))
    }

    // MARK: - Category 2: Audio

    static func micLevel(_ level: Double) throws -> BlackmagicCcuPacket {
        try make(category: 2, parameter: 0, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(level))
    }

    static func headphoneLevel(_ level: Double) throws -> BlackmagicCcuPacket {
        try make(category: 2, parameter: 1, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(level))
    }

    static func headphoneProgramMix(_ level: Double) throws -> BlackmagicCcuPacket {
        try make(category: 2, parameter: 2, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(level))
    }

    static func speakerLevel(_ level: Double) throws -> BlackmagicCcuPacket {
        try make(category: 2, parameter: 3, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(level))
    }

    static func audioInputType(_ type: Int8) throws -> BlackmagicCcuPacket {
        try make(category: 2, parameter: 4, dataType: .int8,
                 payload: Data([UInt8(bitPattern: type)]))
    }

    static func audioInputLevels(ch0: Double, ch1: Double) throws -> BlackmagicCcuPacket {
        try make(category: 2, parameter: 5, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload([ch0, ch1]))
    }

    static func phantomPower(_ enabled: Bool) throws -> BlackmagicCcuPacket {
        try make(category: 2, parameter: 6, dataType: .void, payload: boolPayload(enabled))
    }

    // MARK: - Category 3: Output overlays (Cameras 4.0+)

    /// 3.0 "Overlay enables": which overlays are drawn and on which outputs.
    static func overlayEnables(_ state: OverlayEnables) throws -> BlackmagicCcuPacket {
        let values: [Int16] = [
            Int16(bitPattern: state.overlays.rawValue),
            Int16(bitPattern: state.displays.rawValue)
        ]
        return try make(category: 3, parameter: 0, dataType: .int16,
                        payload: BlackmagicCcuPacket.int16Payload(values))
    }

    static func overlays(_ state: OverlayState) throws -> BlackmagicCcuPacket {
        try make(category: 3, parameter: 3, dataType: .int8, payload: Data([
            UInt8(bitPattern: state.frameGuideStyle),
            UInt8(bitPattern: state.frameGuideOpacity),
            UInt8(bitPattern: state.safeAreaPercentage),
            UInt8(bitPattern: state.gridFlags.rawValue)
        ]))
    }

    // MARK: - Category 4: Display

    static func displayBrightness(_ level: Double) throws -> BlackmagicCcuPacket {
        try make(category: 4, parameter: 0, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(level))
    }

    static func exposureTools(_ state: ExposureToolsState) throws -> BlackmagicCcuPacket {
        let values: [Int16] = [
            Int16(bitPattern: state.tools.rawValue),
            Int16(bitPattern: state.displays.rawValue)
        ]
        return try make(category: 4, parameter: 1, dataType: .int16,
                        payload: BlackmagicCcuPacket.int16Payload(values))
    }

    static func zebraLevel(_ level: Double) throws -> BlackmagicCcuPacket {
        try make(category: 4, parameter: 2, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(level))
    }

    static func peakingLevel(_ level: Double) throws -> BlackmagicCcuPacket {
        try make(category: 4, parameter: 3, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(level))
    }

    static func colorBars(seconds: Int8) throws -> BlackmagicCcuPacket {
        try make(category: 4, parameter: 4, dataType: .int8,
                 payload: Data([UInt8(bitPattern: seconds)]))
    }

    static func focusAssist(_ style: FocusAssistStyle) throws -> BlackmagicCcuPacket {
        try make(category: 4, parameter: 5, dataType: .int8, payload: Data([
            UInt8(bitPattern: style.method),
            UInt8(bitPattern: style.lineColor)
        ]))
    }

    static func programReturnFeed(seconds: Int8) throws -> BlackmagicCcuPacket {
        try make(category: 4, parameter: 6, dataType: .int8,
                 payload: Data([UInt8(bitPattern: seconds)]))
    }

    static func timecodeSource(clip: Bool) throws -> BlackmagicCcuPacket {
        try make(category: 4, parameter: 7, dataType: .int8,
                 payload: Data([clip ? 0 : 1]))
    }

    // MARK: - Category 5: Tally

    static func tallyBrightness(_ level: Double) throws -> BlackmagicCcuPacket {
        try make(category: 5, parameter: 0, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(level))
    }

    static func tallyFrontBrightness(_ level: Double) throws -> BlackmagicCcuPacket {
        try make(category: 5, parameter: 1, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(level))
    }

    static func tallyRearBrightness(_ level: Double) throws -> BlackmagicCcuPacket {
        try make(category: 5, parameter: 2, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(level))
    }

    // MARK: - Category 6: Reference

    static func referenceSource(_ source: Int8) throws -> BlackmagicCcuPacket {
        try make(category: 6, parameter: 0, dataType: .int8,
                 payload: Data([UInt8(bitPattern: source)]))
    }

    static func referenceOffset(pixels: Int32) throws -> BlackmagicCcuPacket {
        try make(category: 6, parameter: 1, dataType: .int32,
                 payload: BlackmagicCcuPacket.int32Payload(pixels))
    }

    // MARK: - Category 7: Configuration

    /// Sets the camera's real time clock. Time and date are BCD encoded
    /// (HHMMSSFF / YYYYMMDD) per the protocol.
    static func realTimeClock(date: Date, calendar: Calendar = .current) throws -> BlackmagicCcuPacket {
        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        func bcd(_ value: Int, digits: Int) -> UInt32 {
            var result: UInt32 = 0
            var remaining = value
            for position in 0..<digits {
                result |= UInt32(remaining % 10) << (position * 4)
                remaining /= 10
            }
            return result
        }

        let time = (bcd(parts.hour ?? 0, digits: 2) << 24)
            | (bcd(parts.minute ?? 0, digits: 2) << 16)
            | (bcd(parts.second ?? 0, digits: 2) << 8)
        let dateBcd = (bcd(parts.year ?? 2000, digits: 4) << 16)
            | (bcd(parts.month ?? 1, digits: 2) << 8)
            | bcd(parts.day ?? 1, digits: 2)

        return try make(category: 7, parameter: 0, dataType: .int32,
                        payload: BlackmagicCcuPacket.int32Payload([
                            Int32(bitPattern: time),
                            Int32(bitPattern: dateBcd)
                        ]))
    }

    static func timezone(minutesFromUTC: Int32) throws -> BlackmagicCcuPacket {
        try make(category: 7, parameter: 2, dataType: .int32,
                 payload: BlackmagicCcuPacket.int32Payload(minutesFromUTC))
    }

    // MARK: - Category 8: Color correction

    static func colorLift(_ wheel: ColorWheel) throws -> BlackmagicCcuPacket {
        try colorWheel(parameter: 0, wheel)
    }

    static func colorGamma(_ wheel: ColorWheel) throws -> BlackmagicCcuPacket {
        try colorWheel(parameter: 1, wheel)
    }

    static func colorGain(_ wheel: ColorWheel) throws -> BlackmagicCcuPacket {
        try colorWheel(parameter: 2, wheel)
    }

    static func colorOffset(_ wheel: ColorWheel) throws -> BlackmagicCcuPacket {
        try colorWheel(parameter: 3, wheel)
    }

    private static func colorWheel(parameter: UInt8, _ wheel: ColorWheel) throws -> BlackmagicCcuPacket {
        try make(category: 8, parameter: parameter, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload([wheel.red, wheel.green, wheel.blue, wheel.luma]))
    }

    static func contrast(pivot: Double, adjust: Double) throws -> BlackmagicCcuPacket {
        try make(category: 8, parameter: 4, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload([pivot, adjust]))
    }

    static func lumaMix(_ value: Double) throws -> BlackmagicCcuPacket {
        try make(category: 8, parameter: 5, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload(value))
    }

    static func colorAdjust(hue: Double, saturation: Double) throws -> BlackmagicCcuPacket {
        try make(category: 8, parameter: 6, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload([hue, saturation]))
    }

    static func colorCorrectionReset() throws -> BlackmagicCcuPacket {
        try make(category: 8, parameter: 7, dataType: .void, payload: Data())
    }

    // MARK: - Category 10: Media

    static func codec(_ codec: CodecInfo) throws -> BlackmagicCcuPacket {
        try make(category: 10, parameter: 0, dataType: .int8,
                 payload: Data([codec.codec.rawValue, codec.variant]))
    }

    static func transportMode(
        _ mode: TransportMode,
        speed: Int8 = 0,
        flags: TransportState.Flags = [],
        slot1: StorageMedium? = nil,
        slot2: StorageMedium? = nil
    ) throws -> BlackmagicCcuPacket {
        try make(category: 10, parameter: 1, dataType: .int8, payload: Data([
            UInt8(bitPattern: mode.rawValue),
            UInt8(bitPattern: speed),
            flags.rawValue,
            UInt8(bitPattern: slot1?.rawValue ?? 0),
            UInt8(bitPattern: slot2?.rawValue ?? 0)
        ]))
    }

    static func record(_ recording: Bool) throws -> BlackmagicCcuPacket {
        try transportMode(recording ? .record : .preview)
    }

    static func playbackClip(next: Bool) throws -> BlackmagicCcuPacket {
        try make(category: 10, parameter: 2, dataType: .int8,
                 payload: Data([next ? 1 : 0]))
    }

    // MARK: - Category 11: PTZ

    static func panTiltVelocity(pan: Double, tilt: Double) throws -> BlackmagicCcuPacket {
        try make(category: 11, parameter: 0, dataType: .fixed16,
                 payload: BlackmagicCcuPacket.fixed16Payload([pan, tilt]))
    }

    static func ptzMemoryPreset(command: Int8, slot: Int8) throws -> BlackmagicCcuPacket {
        try make(category: 11, parameter: 1, dataType: .int8, payload: Data([
            UInt8(bitPattern: command),
            UInt8(bitPattern: slot)
        ]))
    }
}
