import Foundation

struct CameraError: Identifiable, Equatable {
    let id: UUID
    let subsystem: String
    let message: String

    init(id: UUID = UUID(), subsystem: String, message: String) {
        self.id = id
        self.subsystem = subsystem
        self.message = message
    }
}

struct MediaSlotState: Identifiable, Equatable {
    let id: Int
    var name: String
    var remainingRecordTimeSeconds: Int?
    var remainingSpaceBytes: Int?
    var isActive: Bool
}

struct BatteryState: Equatable {
    var percent: Int?
    var voltageMillivolts: Int?
    var source: String?
}

struct CameraState: Equatable {
    var connectionStatus: String = "Disconnected"
    var controlTransport: CameraControlTransport = .disconnected
    var cameraModel: CameraValue<String> = CameraValue()
    var firmwareOrProtocolVersion: CameraValue<String> = CameraValue()
    var isRecording: CameraValue<Bool> = CameraValue(value: false)
    var timecode: CameraValue<String> = CameraValue()
    var iso: CameraValue<Int> = CameraValue()
    var supportedISOs: CameraValue<[Int]> = CameraValue(value: [])
    var shutter: CameraValue<String> = CameraValue()
    var shutterMode: CameraValue<String> = CameraValue()
    var whiteBalance: CameraValue<Int> = CameraValue()
    var tint: CameraValue<Int> = CameraValue()
    var iris: CameraValue<Double> = CameraValue()
    var focus: CameraValue<Double> = CameraValue()
    var canAutoFocus: CameraValue<Bool> = CameraValue(value: false)
    var battery: CameraValue<BatteryState> = CameraValue()
    var powerSource: CameraValue<String> = CameraValue()
    var mediaSlots: CameraValue<[MediaSlotState]> = CameraValue(value: [])
    var activeMedia: CameraValue<String> = CameraValue()
    var remainingRecordTime: CameraValue<Int> = CameraValue()
    var errors: [CameraError] = []
}
