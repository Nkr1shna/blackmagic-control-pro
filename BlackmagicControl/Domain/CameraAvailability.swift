import Foundation

enum CameraControlTransport: String, Equatable {
    case disconnected
    case rest
    case ble
    case degraded
}

enum CameraValueSource: String, Equatable {
    case rest
    case ble
    case local
}

enum CameraFeatureAvailability<Value: Equatable>: Equatable {
    case unavailable(reason: String)
    case available(source: CameraValueSource)
}

struct CameraValue<Value: Equatable>: Equatable {
    var value: Value?
    var availability: CameraFeatureAvailability<Value>

    init(value: Value? = nil, availability: CameraFeatureAvailability<Value> = .unavailable(reason: "Not connected")) {
        self.value = value
        self.availability = availability
    }

    var isAvailable: Bool {
        if case .available = availability {
            return true
        }
        return false
    }
}
