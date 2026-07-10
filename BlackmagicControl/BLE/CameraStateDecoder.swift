import Foundation

/// Applies decoded incoming CCU messages to the camera state. The camera
/// broadcasts its full configuration after pairing (the "initial payload")
/// and then streams incremental changes, so this is the single source of
/// truth for what the camera is actually doing.
enum CameraStateDecoder {
    static func apply(_ messages: [CcuMessage], to state: inout CameraState) {
        for message in messages {
            apply(message, to: &state)
        }
    }

    static func apply(_ message: CcuMessage, to state: inout CameraState) {
        switch (message.category, message.parameter) {
        // MARK: Lens
        case (0, 0):
            if let value = message.fixed16Values.first { state.focusNormalised = value }
        case (0, 2):
            if let value = message.fixed16Values.first { state.apertureStop = value }
        case (0, 3):
            if let value = message.fixed16Values.first { state.apertureNormalised = value }
        case (0, 6):
            if let value = message.boolValue { state.opticalImageStabilisation = value }
        case (0, 7):
            if let value = message.int16Values.first { state.zoomMillimetres = Int(value) }
        case (0, 8):
            if let value = message.fixed16Values.first { state.zoomNormalised = value }

        // MARK: Video
        case (1, 2):
            let values = message.int16Values
            if values.count >= 2 {
                state.whiteBalanceKelvin = Int(values[0])
                state.tint = Int(values[1])
            }
        case (1, 5):
            if let value = message.int32Values.first { state.exposureMicroseconds = value }
        case (1, 7):
            if let raw = message.payload.first { state.dynamicRange = DynamicRangeMode(rawValue: raw) }
        case (1, 8):
            if let raw = message.payload.first { state.sharpening = SharpeningLevel(rawValue: raw) }
        case (1, 9):
            let values = message.int16Values
            if values.count >= 5 {
                state.recordingFormat = RecordingFormat(
                    fileFrameRate: Int(values[0]),
                    sensorFrameRate: Int(values[1]),
                    width: Int(values[2]),
                    height: Int(values[3]),
                    flags: RecordingFormat.Flags(rawValue: UInt16(bitPattern: values[4]))
                )
            }
        case (1, 10):
            if let raw = message.payload.first { state.autoExposureMode = AutoExposureMode(rawValue: raw) }
        case (1, 11):
            if let value = message.int32Values.first {
                state.shutterAngleHundredths = value
                state.shutterSpeedFraction = nil
            }
        case (1, 12):
            if let value = message.int32Values.first {
                state.shutterSpeedFraction = value
                state.shutterAngleHundredths = nil
            }
        case (1, 13):
            if let value = message.int8Values.first { state.gainDb = Int(value) }
        case (1, 14):
            if let value = message.int32Values.first { state.iso = Int(value) }
        case (1, 15):
            // Some firmwares send both elements, some only the selection —
            // accept either so camera-side changes always reflect here.
            let values = message.int8Values
            if values.count >= 2 {
                state.displayLut = DisplayLutState(selectedLut: Int(values[0]), isEnabled: values[1] != 0)
            } else if let selected = values.first {
                state.displayLut = DisplayLutState(
                    selectedLut: Int(selected),
                    isEnabled: state.displayLut?.isEnabled ?? (selected != 0)
                )
            }
        case (1, 16):
            if let value = message.fixed16Values.first { state.ndStop = value }

        // MARK: Audio
        case (2, 0):
            if let value = message.fixed16Values.first { state.audio.micLevel = value }
        case (2, 1):
            if let value = message.fixed16Values.first { state.audio.headphoneLevel = value }
        case (2, 2):
            if let value = message.fixed16Values.first { state.audio.headphoneProgramMix = value }
        case (2, 3):
            if let value = message.fixed16Values.first { state.audio.speakerLevel = value }
        case (2, 4):
            if let value = message.int8Values.first { state.audio.inputType = value }
        case (2, 5):
            let values = message.fixed16Values
            if values.count >= 2 {
                state.audio.inputLevelCh0 = values[0]
                state.audio.inputLevelCh1 = values[1]
            }
        case (2, 6):
            if let value = message.boolValue { state.audio.phantomPower = value }

        // MARK: Output overlays
        case (3, 3):
            let values = message.int8Values
            if values.count >= 4 {
                state.overlays = OverlayState(
                    frameGuideStyle: values[0],
                    frameGuideOpacity: values[1],
                    safeAreaPercentage: values[2],
                    gridFlags: OverlayState.GridFlags(rawValue: values[3])
                )
            }

        // MARK: Display
        case (4, 0):
            if let value = message.fixed16Values.first { state.displayBrightness = value }
        case (4, 1):
            let values = message.uint16Values
            if values.count >= 2 {
                state.exposureTools = ExposureToolsState(
                    tools: ExposureToolsState.Tools(rawValue: values[0]),
                    displays: ExposureToolsState.Displays(rawValue: values[1])
                )
            }
        case (4, 2):
            if let value = message.fixed16Values.first { state.zebraLevel = value }
        case (4, 3):
            if let value = message.fixed16Values.first { state.peakingLevel = value }
        case (4, 4):
            if let value = message.int8Values.first { state.colorBarsSeconds = value }
        case (4, 5):
            let values = message.int8Values
            if values.count >= 2 {
                state.focusAssist = FocusAssistStyle(method: values[0], lineColor: values[1])
            }
        case (4, 7):
            if let value = message.int8Values.first { state.timecodeSourceClip = value == 0 }

        // MARK: Tally
        case (5, 0):
            if let value = message.fixed16Values.first {
                state.tallyFrontBrightness = value
                state.tallyRearBrightness = value
            }
        case (5, 1):
            if let value = message.fixed16Values.first { state.tallyFrontBrightness = value }
        case (5, 2):
            if let value = message.fixed16Values.first { state.tallyRearBrightness = value }

        // MARK: Reference
        case (6, 0):
            if let value = message.int8Values.first { state.referenceSource = value }
        case (6, 1):
            if let value = message.int32Values.first { state.referenceOffset = value }

        // MARK: Color correction
        case (8, 0):
            if let wheel = colorWheel(from: message) { state.colorCorrection.lift = wheel }
        case (8, 1):
            if let wheel = colorWheel(from: message) { state.colorCorrection.gamma = wheel }
        case (8, 2):
            if let wheel = colorWheel(from: message) { state.colorCorrection.gain = wheel }
        case (8, 3):
            if let wheel = colorWheel(from: message) { state.colorCorrection.offset = wheel }
        case (8, 4):
            let values = message.fixed16Values
            if values.count >= 2 {
                state.colorCorrection.contrastPivot = values[0]
                state.colorCorrection.contrastAdjust = values[1]
            }
        case (8, 5):
            if let value = message.fixed16Values.first { state.colorCorrection.lumaMix = value }
        case (8, 6):
            let values = message.fixed16Values
            if values.count >= 2 {
                state.colorCorrection.hue = values[0]
                state.colorCorrection.saturation = values[1]
            }

        // MARK: Status (category 9 is undocumented; battery decode is best effort)
        case (9, 0):
            let values = message.int16Values
            if values.count >= 2 {
                let voltage = Int(values[0])
                let percent = Int(values[1])
                var info = BatteryInfo()
                if (1_000...30_000).contains(voltage) { info.voltageMillivolts = voltage }
                if (0...100).contains(percent) { info.percent = percent }
                if info.voltageMillivolts != nil || info.percent != nil {
                    state.battery = info
                }
            }

        // MARK: Media
        case (10, 0):
            let values = message.payload
            if values.count >= 2, let codec = BasicCodec(rawValue: values[values.startIndex]) {
                state.codec = CodecInfo(codec: codec, variant: values[values.index(after: values.startIndex)])
            }
        case (10, 1):
            let values = message.int8Values
            if values.count >= 5, let mode = TransportMode(rawValue: values[0]) {
                state.transport = TransportState(
                    mode: mode,
                    speed: values[1],
                    flags: TransportState.Flags(rawValue: UInt8(bitPattern: values[2])),
                    slot1Medium: StorageMedium(rawValue: values[3]),
                    slot2Medium: StorageMedium(rawValue: values[4])
                )
            }

        default:
            break
        }
    }

    private static func colorWheel(from message: CcuMessage) -> ColorWheel? {
        let values = message.fixed16Values
        guard values.count >= 4 else { return nil }
        return ColorWheel(red: values[0], green: values[1], blue: values[2], luma: values[3])
    }
}
