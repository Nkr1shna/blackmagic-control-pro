import Foundation

struct RestPowerResponse: Decodable, Equatable {
    struct Battery: Decodable, Equatable {
        let milliVolt: Int?
        let chargeRemainingPercent: Int?
        let statusFlags: [String]?
    }

    let source: String?
    let milliVolt: Int?
    let batteries: [Battery]?
}

struct RestTransportRecordResponse: Decodable, Equatable {
    let recording: Bool
}

struct RestTimecodeResponse: Decodable, Equatable {
    let display: String?
    let timeline: String?
}

struct RestMediaWorkingSetResponse: Decodable, Equatable {
    struct Device: Decodable, Equatable {
        let volume: String?
        let deviceName: String
        let remainingRecordTime: Int?
        let totalSpace: Int?
        let remainingSpace: Int?
        let clipCount: Int?
    }

    let size: Int
    let workingset: [Device?]

    func toMediaSlots(activeDeviceName: String?) -> [MediaSlotState] {
        workingset.enumerated().compactMap { index, device in
            guard let device else { return nil }

            return MediaSlotState(
                id: index,
                name: device.volume ?? device.deviceName,
                remainingRecordTimeSeconds: device.remainingRecordTime,
                remainingSpaceBytes: device.remainingSpace,
                isActive: device.deviceName == activeDeviceName
            )
        }
    }
}

struct RestActiveMediaResponse: Decodable, Equatable {
    let workingsetIndex: Int?
    let deviceName: String?
}

struct RestISOResponse: Decodable, Equatable {
    let iso: Int?
}

struct RestSupportedISOsResponse: Decodable, Equatable {
    let supportedISOs: [Int]?
}

struct RestShutterBody: Codable, Equatable {
    let shutterSpeed: Int?
    let shutterAngle: Double?
}

struct RestShutterMeasurementResponse: Decodable, Equatable {
    let measurement: String?
    let mode: String?
}

struct RestWhiteBalanceResponse: Decodable, Equatable {
    let whiteBalance: Int?
}

struct RestWhiteBalanceTintResponse: Decodable, Equatable {
    let whiteBalanceTint: Int?
}

struct RestLensIrisResponse: Decodable, Equatable {
    let normalised: Double?
    let apertureStop: Double?
}

struct RestLensFocusResponse: Decodable, Equatable {
    let normalised: Double?
}

struct RestLensFocusDescriptionResponse: Decodable, Equatable {
    let controllable: Bool?
}

extension CameraState {
    init(restPower: RestPowerResponse) {
        self.init()

        let battery = restPower.batteries?.first
        powerSource = CameraValue(
            value: restPower.source,
            availability: .available(source: .rest)
        )
        self.battery = CameraValue(
            value: BatteryState(
                percent: battery?.chargeRemainingPercent,
                voltageMillivolts: battery?.milliVolt ?? restPower.milliVolt,
                source: restPower.source
            ),
            availability: .available(source: .rest)
        )
    }
}
