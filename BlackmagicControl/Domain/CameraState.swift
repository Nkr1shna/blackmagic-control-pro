import Foundation

// MARK: - Camera status characteristic flags

struct CameraStatusFlags: OptionSet, Equatable {
    let rawValue: UInt8

    static let powerOn = CameraStatusFlags(rawValue: 0x01)
    static let connected = CameraStatusFlags(rawValue: 0x02)
    static let paired = CameraStatusFlags(rawValue: 0x04)
    static let versionsVerified = CameraStatusFlags(rawValue: 0x08)
    static let initialPayloadReceived = CameraStatusFlags(rawValue: 0x10)
    static let cameraReady = CameraStatusFlags(rawValue: 0x20)
}

// MARK: - Video

enum DynamicRangeMode: UInt8, CaseIterable, Identifiable {
    case film = 0
    case video = 1
    case extendedVideo = 2

    var id: UInt8 { rawValue }

    var label: String {
        switch self {
        case .film: return "Film"
        case .video: return "Video"
        case .extendedVideo: return "Extended Video"
        }
    }
}

enum SharpeningLevel: UInt8, CaseIterable, Identifiable {
    case off = 0
    case low = 1
    case medium = 2
    case high = 3

    var id: UInt8 { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

enum AutoExposureMode: UInt8, CaseIterable, Identifiable {
    case manual = 0
    case iris = 1
    case shutter = 2
    case irisAndShutter = 3
    case shutterAndIris = 4

    var id: UInt8 { rawValue }

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .iris: return "Iris"
        case .shutter: return "Shutter"
        case .irisAndShutter: return "Iris + Shutter"
        case .shutterAndIris: return "Shutter + Iris"
        }
    }
}

struct RecordingFormat: Equatable {
    struct Flags: OptionSet, Equatable {
        let rawValue: UInt16

        static let fileMRate = Flags(rawValue: 1 << 0)
        static let sensorMRate = Flags(rawValue: 1 << 1)
        static let sensorOffSpeed = Flags(rawValue: 1 << 2)
        static let interlaced = Flags(rawValue: 1 << 3)
        static let windowed = Flags(rawValue: 1 << 4)
    }

    var fileFrameRate: Int
    var sensorFrameRate: Int
    var width: Int
    var height: Int
    var flags: Flags

    /// "23.98" for 24 fps M-rate, "24" otherwise, etc.
    var fileFrameRateLabel: String {
        Self.frameRateLabel(fps: fileFrameRate, mRate: flags.contains(.fileMRate))
    }

    var resolutionLabel: String {
        switch (width, height) {
        case (4096, 2160): return "4K DCI"
        case (4096, 1720): return "4K 2.4:1"
        case (3840, 2160): return "UHD"
        case (2880, 2160): return "2.8K Anamorphic"
        case (2688, 1512): return "2.6K"
        case (2048, 1080): return "2K DCI"
        case (1920, 1080): return "HD"
        case (0, 0): return ""
        default: return "\(width)×\(height)"
        }
    }

    static func frameRateLabel(fps: Int, mRate: Bool) -> String {
        guard mRate else { return "\(fps)" }
        switch fps {
        case 24: return "23.98"
        case 30: return "29.97"
        case 60: return "59.94"
        default: return String(format: "%.2f", Double(fps) / 1.001)
        }
    }
}

struct DisplayLutState: Equatable {
    var selectedLut: Int
    var isEnabled: Bool

    var label: String {
        switch selectedLut {
        case 0: return "None"
        case 1: return "Custom"
        case 2: return "Film to Video"
        case 3: return "Film to Ext. Video"
        default: return "LUT \(selectedLut)"
        }
    }
}

// MARK: - Media / transport

enum BasicCodec: UInt8, CaseIterable, Identifiable {
    case cinemaDNG = 0
    case dnxHD = 1
    case proRes = 2
    case blackmagicRaw = 3

    var id: UInt8 { rawValue }

    var label: String {
        switch self {
        case .cinemaDNG: return "CinemaDNG"
        case .dnxHD: return "DNxHD"
        case .proRes: return "ProRes"
        case .blackmagicRaw: return "BRAW"
        }
    }
}

struct CodecInfo: Equatable {
    var codec: BasicCodec
    var variant: UInt8

    var variantLabel: String {
        switch codec {
        case .proRes:
            switch variant {
            case 0: return "HQ"
            case 1: return "422"
            case 2: return "LT"
            case 3: return "Proxy"
            case 4: return "444"
            case 5: return "444 XQ"
            default: return ""
            }
        case .blackmagicRaw:
            switch variant {
            case 0: return "Q0"
            case 7: return "Q1"
            case 8: return "Q3"
            case 1: return "Q5"
            case 2: return "3:1"
            case 3: return "5:1"
            case 4: return "8:1"
            case 5: return "12:1"
            default: return ""
            }
        case .cinemaDNG:
            switch variant {
            case 0: return "Uncompressed"
            case 1: return "3:1"
            case 2: return "4:1"
            default: return ""
            }
        case .dnxHD:
            return ""
        }
    }

    var label: String {
        let variantText = variantLabel
        return variantText.isEmpty ? codec.label : "\(codec.label) \(variantText)"
    }
}

enum TransportMode: Int8, Equatable {
    case preview = 0
    case play = 1
    case record = 2
}

enum StorageMedium: Int8, Equatable {
    case cfast = 0
    case sd = 1
    case ssd = 2

    var label: String {
        switch self {
        case .cfast: return "CFAST"
        case .sd: return "SD"
        case .ssd: return "SSD"
        }
    }
}

struct TransportState: Equatable {
    struct Flags: OptionSet, Equatable {
        let rawValue: UInt8

        static let loop = Flags(rawValue: 1 << 0)
        static let playAll = Flags(rawValue: 1 << 1)
        static let disk1Active = Flags(rawValue: 1 << 5)
        static let disk2Active = Flags(rawValue: 1 << 6)
        static let timeLapse = Flags(rawValue: 1 << 7)
    }

    var mode: TransportMode
    var speed: Int8
    var flags: Flags
    var slot1Medium: StorageMedium?
    var slot2Medium: StorageMedium?

    var activeMediumLabel: String? {
        if flags.contains(.disk1Active) { return slot1Medium?.label ?? "SLOT 1" }
        if flags.contains(.disk2Active) { return slot2Medium?.label ?? "SLOT 2" }
        return nil
    }
}

// MARK: - Monitoring / overlays

/// Category 3.0 "Overlay enables": which overlays are drawn, and on which
/// outputs. Selecting a frame guide style (3.3) alone does not make guides
/// visible — the `frameGuides` bit here has to be set too.
struct OverlayEnables: Equatable {
    struct Overlays: OptionSet, Equatable {
        let rawValue: UInt16

        static let status = Overlays(rawValue: 1 << 0)
        static let frameGuides = Overlays(rawValue: 1 << 1)
        static let cleanFeed = Overlays(rawValue: 1 << 2)
    }

    struct Displays: OptionSet, Equatable {
        let rawValue: UInt16

        static let lcd = Displays(rawValue: 1 << 0)
        static let hdmi = Displays(rawValue: 1 << 1)
        static let evf = Displays(rawValue: 1 << 2)
        static let mainSDI = Displays(rawValue: 1 << 3)
        static let frontSDI = Displays(rawValue: 1 << 4)
    }

    var overlays: Overlays = [.status]
    var displays: Displays = [.lcd, .hdmi]
}

struct OverlayState: Equatable {
    struct GridFlags: OptionSet, Equatable {
        let rawValue: Int8

        static let thirds = GridFlags(rawValue: 1 << 0)
        static let crosshairs = GridFlags(rawValue: 1 << 1)
        static let centerDot = GridFlags(rawValue: 1 << 2)
        static let horizon = GridFlags(rawValue: 1 << 3)
    }

    var frameGuideStyle: Int8 = 0
    var frameGuideOpacity: Int8 = 50
    var safeAreaPercentage: Int8 = 0
    var gridFlags: GridFlags = []

    static let frameGuideStyles: [(value: Int8, label: String, ratio: Double?)] = [
        (0, "Off", nil),
        (1, "2.4:1", 2.4),
        (2, "2.39:1", 2.39),
        (3, "2.35:1", 2.35),
        (4, "1.85:1", 1.85),
        (5, "16:9", 16.0 / 9.0),
        (6, "14:9", 14.0 / 9.0),
        (7, "4:3", 4.0 / 3.0),
        (8, "2:1", 2.0),
        (9, "4:5", 0.8),
        (10, "1:1", 1.0)
    ]
}

struct ExposureToolsState: Equatable {
    struct Tools: OptionSet, Equatable {
        let rawValue: UInt16

        static let zebra = Tools(rawValue: 1 << 0)
        static let focusAssist = Tools(rawValue: 1 << 1)
        static let falseColor = Tools(rawValue: 1 << 2)
    }

    struct Displays: OptionSet, Equatable {
        let rawValue: UInt16

        static let lcd = Displays(rawValue: 1 << 0)
        static let hdmi = Displays(rawValue: 1 << 1)
        static let evf = Displays(rawValue: 1 << 2)
        static let mainSDI = Displays(rawValue: 1 << 3)
        static let frontSDI = Displays(rawValue: 1 << 4)
    }

    var tools: Tools = []
    var displays: Displays = [.lcd, .hdmi]
}

struct FocusAssistStyle: Equatable {
    var method: Int8 = 0 // 0 = peak, 1 = colored lines
    var lineColor: Int8 = 0 // 0 red, 1 green, 2 blue, 3 white, 4 black
}

// MARK: - Color correction

struct ColorWheel: Equatable {
    var red: Double = 0
    var green: Double = 0
    var blue: Double = 0
    var luma: Double = 0

    static let zero = ColorWheel()
    static let unity = ColorWheel(red: 1, green: 1, blue: 1, luma: 1)
}

struct ColorCorrectionState: Equatable {
    var lift: ColorWheel = .zero
    var gamma: ColorWheel = .zero
    var gain: ColorWheel = .unity
    var offset: ColorWheel = .zero
    var contrastPivot: Double = 0.5
    var contrastAdjust: Double = 1.0
    var hue: Double = 0
    var saturation: Double = 1.0
    var lumaMix: Double = 1.0
}

// MARK: - Audio

struct AudioState: Equatable {
    var micLevel: Double?
    var headphoneLevel: Double?
    var headphoneProgramMix: Double?
    var speakerLevel: Double?
    var inputType: Int8?
    var inputLevelCh0: Double?
    var inputLevelCh1: Double?
    var phantomPower: Bool?

    static let inputTypes: [(value: Int8, label: String)] = [
        (0, "Internal Mic"),
        (1, "Line Level"),
        (2, "Low Mic Level"),
        (3, "High Mic Level")
    ]
}

// MARK: - Battery (undocumented category 9, best effort)

struct BatteryInfo: Equatable {
    var voltageMillivolts: Int?
    var percent: Int?
}

// MARK: - Aggregate camera state

struct CameraState: Equatable {
    // Identity
    var modelName: String?
    var protocolVersion: String?

    // Video
    var iso: Int?
    var gainDb: Int?
    var whiteBalanceKelvin: Int?
    var tint: Int?
    var shutterAngleHundredths: Int32?
    var shutterSpeedFraction: Int32?
    var exposureMicroseconds: Int32?
    var dynamicRange: DynamicRangeMode?
    var sharpening: SharpeningLevel?
    var recordingFormat: RecordingFormat?
    var autoExposureMode: AutoExposureMode?
    var displayLut: DisplayLutState?
    var ndStop: Double?

    // Lens
    var focusNormalised: Double?
    var apertureStop: Double? // Aperture Value (AV); f-number = 2^(AV/2)
    var apertureNormalised: Double?
    var opticalImageStabilisation: Bool?
    var zoomMillimetres: Int?
    var zoomNormalised: Double?

    // Audio
    var audio = AudioState()

    // Monitoring
    var overlays = OverlayState()
    var overlayEnables: OverlayEnables?
    var exposureTools = ExposureToolsState()
    var focusAssist = FocusAssistStyle()
    var zebraLevel: Double?
    var peakingLevel: Double?
    var displayBrightness: Double?
    var colorBarsSeconds: Int8?
    var timecodeSourceClip: Bool?

    // Tally
    var tallyFrontBrightness: Double?
    var tallyRearBrightness: Double?

    // Reference
    var referenceSource: Int8?
    var referenceOffset: Int32?

    // Color correction
    var colorCorrection = ColorCorrectionState()

    // Media
    var codec: CodecInfo?
    var transport: TransportState?

    // Live status
    var timecode: String?
    var statusFlags: CameraStatusFlags = []
    var battery: BatteryInfo?

    var isRecording: Bool {
        transport?.mode == .record
    }

    // MARK: Display helpers

    var isoLabel: String {
        if let iso { return "\(iso)" }
        if let gainDb { return String(format: "%+d dB", gainDb) }
        return "—"
    }

    var whiteBalanceLabel: String {
        guard let whiteBalanceKelvin else { return "—" }
        return "\(whiteBalanceKelvin)K"
    }

    var tintLabel: String {
        guard let tint else { return "—" }
        return "\(tint)"
    }

    var shutterLabel: String {
        if let shutterAngleHundredths {
            return Self.shutterAngleLabel(hundredths: shutterAngleHundredths)
        }
        if let shutterSpeedFraction {
            return "1/\(shutterSpeedFraction)"
        }
        if let exposureMicroseconds, exposureMicroseconds > 0 {
            let fraction = (1_000_000.0 / Double(exposureMicroseconds)).rounded()
            return "1/\(Int(fraction))"
        }
        return "—"
    }

    var irisLabel: String {
        guard let fNumber else { return "—" }
        return String(format: "f%.1f", fNumber)
    }

    /// f-number derived from the aperture value: f = sqrt(2^AV)
    var fNumber: Double? {
        guard let apertureStop else { return nil }
        return pow(2.0, apertureStop / 2.0)
    }

    var fpsLabel: String {
        guard let recordingFormat, recordingFormat.fileFrameRate > 0 else { return "—" }
        return recordingFormat.fileFrameRateLabel
    }

    var formatLabel: String {
        var parts: [String] = []
        if let recordingFormat, !recordingFormat.resolutionLabel.isEmpty {
            parts.append(recordingFormat.resolutionLabel)
        }
        if let codec {
            parts.append(codec.label)
        }
        return parts.joined(separator: "  ")
    }

    static func shutterAngleLabel(hundredths: Int32) -> String {
        let angle = Double(hundredths) / 100.0
        if angle.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f°", angle)
        }
        return String(format: "%.1f°", angle)
    }
}

// MARK: - Presets (Pocket Cinema Camera oriented, harmless on other models)

enum CameraPresets {
    static let isoValues = [100, 125, 160, 200, 250, 320, 400, 500, 640, 800,
                            1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000,
                            6400, 8000, 10000, 12800, 16000, 20000, 25600]

    static let quickISOValues = [100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600]

    static let shutterAngles: [Double] = [11.2, 15, 22.5, 30, 37.5, 45, 60, 72, 75,
                                          90, 108, 120, 144, 150, 172.8, 180, 216,
                                          270, 324, 360]

    static let quickShutterAngles: [Double] = [45, 90, 120, 150, 172.8, 180, 270, 360]

    static let whiteBalancePresets: [(kelvin: Int, tint: Int, label: String, icon: String)] = [
        (3200, 0, "Tungsten", "lightbulb.fill"),
        (4000, 15, "Fluorescent", "light.panel.fill"),
        (4500, 15, "Mixed", "circle.lefthalf.filled"),
        (5600, 10, "Daylight", "sun.max.fill"),
        (6500, 10, "Cloudy", "cloud.fill"),
        (7500, 10, "Shade", "house.fill")
    ]

    static let frameRates: [(fps: Int, mRate: Bool, label: String)] = [
        (24, true, "23.98"),
        (24, false, "24"),
        (25, false, "25"),
        (30, true, "29.97"),
        (30, false, "30"),
        (50, false, "50"),
        (60, true, "59.94"),
        (60, false, "60")
    ]

    static let resolutions: [(width: Int, height: Int, label: String)] = [
        (4096, 2160, "4K DCI"),
        (4096, 1720, "4K 2.4:1"),
        (3840, 2160, "UHD"),
        (2880, 2160, "2.8K Anamorphic"),
        (2688, 1512, "2.6K 16:9"),
        (1920, 1080, "HD")
    ]

    static let proResVariants: [(variant: UInt8, label: String)] = [
        (0, "HQ"), (1, "422"), (2, "LT"), (3, "PXY")
    ]

    /// BRAW constant-bitrate variants, as laid out on the camera.
    static let brawConstantBitrate: [(variant: UInt8, label: String)] = [
        (2, "3:1"), (3, "5:1"), (4, "8:1"), (5, "12:1")
    ]

    /// BRAW constant-quality variants, as laid out on the camera.
    static let brawConstantQuality: [(variant: UInt8, label: String)] = [
        (0, "Q0"), (7, "Q1"), (8, "Q3"), (1, "Q5")
    ]

    static let offSpeedFrameRateRange = 5...60
}
