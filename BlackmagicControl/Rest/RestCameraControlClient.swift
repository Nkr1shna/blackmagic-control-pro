import Foundation

final class RestCameraControlClient: CameraControlClient {
    let transport: CameraControlTransport = .rest

    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func connect() async throws -> CameraState {
        try await refreshState()
    }

    func disconnect() async {}

    func refreshState() async throws -> CameraState {
        async let record: RestTransportRecordResponse = get(
            RestTransportRecordResponse.self,
            path: "/control/api/v1/transports/0/record"
        )
        async let timecode: RestTimecodeResponse = get(
            RestTimecodeResponse.self,
            path: "/control/api/v1/transports/0/timecode"
        )
        async let power: RestPowerResponse? = getOptional(
            RestPowerResponse.self,
            path: "/control/api/v1/camera/power"
        )
        async let activeMedia: RestActiveMediaResponse? = getOptional(
            RestActiveMediaResponse.self,
            path: "/control/api/v1/media/active"
        )
        async let workingSet: RestMediaWorkingSetResponse? = getOptional(
            RestMediaWorkingSetResponse.self,
            path: "/control/api/v1/media/workingset"
        )
        async let iso: RestISOResponse? = getOptional(
            RestISOResponse.self,
            path: "/control/api/v1/video/iso"
        )
        async let supportedISOs: RestSupportedISOsResponse? = getOptional(
            RestSupportedISOsResponse.self,
            path: "/control/api/v1/video/supportedISOs"
        )
        async let shutter: RestShutterBody? = getOptional(
            RestShutterBody.self,
            path: "/control/api/v1/video/shutter"
        )
        async let shutterMeasurement: RestShutterMeasurementResponse? = getOptional(
            RestShutterMeasurementResponse.self,
            path: "/control/api/v1/video/shutter/measurement"
        )
        async let whiteBalance: RestWhiteBalanceResponse? = getOptional(
            RestWhiteBalanceResponse.self,
            path: "/control/api/v1/video/whiteBalance"
        )
        async let whiteBalanceTint: RestWhiteBalanceTintResponse? = getOptional(
            RestWhiteBalanceTintResponse.self,
            path: "/control/api/v1/video/whiteBalanceTint"
        )
        async let iris: RestLensIrisResponse? = getOptional(
            RestLensIrisResponse.self,
            path: "/control/api/v1/lens/iris"
        )
        async let focus: RestLensFocusResponse? = getOptional(
            RestLensFocusResponse.self,
            path: "/control/api/v1/lens/focus"
        )
        async let focusDescription: RestLensFocusDescriptionResponse? = getOptional(
            RestLensFocusDescriptionResponse.self,
            path: "/control/api/v1/lens/focus/description"
        )

        var state = CameraState()
        state.controlTransport = .rest
        state.connectionStatus = "Connected"

        let recordResponse = try await record
        state.isRecording = CameraValue(
            value: recordResponse.recording,
            availability: .available(source: .rest)
        )

        let timecodeResponse = try await timecode
        state.timecode = CameraValue(
            value: timecodeResponse.display ?? timecodeResponse.timeline,
            availability: .available(source: .rest)
        )

        if let powerResponse = await power {
            let powerState = CameraState(restPower: powerResponse)
            state.powerSource = powerState.powerSource
            state.battery = powerState.battery
        }

        let active = await activeMedia
        if let active {
            state.activeMedia = CameraValue(value: active.deviceName, availability: .available(source: .rest))
        }

        if let workingSetResponse = await workingSet {
            let activeDeviceName = active?.deviceName ?? resolvedActiveDeviceName(
                from: active,
                workingSet: workingSetResponse
            )
            let slots = workingSetResponse.toMediaSlots(activeDeviceName: activeDeviceName)
            state.mediaSlots = CameraValue(value: slots, availability: .available(source: .rest))
            state.activeMedia = CameraValue(value: activeDeviceName, availability: .available(source: .rest))
            state.remainingRecordTime = CameraValue(
                value: slots.first(where: { $0.isActive })?.remainingRecordTimeSeconds,
                availability: .available(source: .rest)
            )
        }

        let isoResponse = await iso
        if let isoValue = isoResponse?.iso {
            state.iso = CameraValue(value: isoValue, availability: .available(source: .rest))
        }

        let supportedISOsResponse = await supportedISOs
        if let supportedISOValues = supportedISOsResponse?.supportedISOs {
            state.supportedISOs = CameraValue(value: supportedISOValues, availability: .available(source: .rest))
        }

        let shutterResponse = await shutter
        if let shutterResponse,
           let shutterValue = shutterValue(from: shutterResponse) {
            state.shutter = CameraValue(value: shutterValue, availability: .available(source: .rest))
        }

        let shutterMeasurementResponse = await shutterMeasurement
        if let shutterMode = shutterMeasurementResponse?.measurement ?? shutterMeasurementResponse?.mode {
            state.shutterMode = CameraValue(value: shutterMode, availability: .available(source: .rest))
        }

        let whiteBalanceResponse = await whiteBalance
        if let whiteBalanceValue = whiteBalanceResponse?.whiteBalance {
            state.whiteBalance = CameraValue(value: whiteBalanceValue, availability: .available(source: .rest))
        }

        let whiteBalanceTintResponse = await whiteBalanceTint
        if let tintValue = whiteBalanceTintResponse?.whiteBalanceTint {
            state.tint = CameraValue(value: tintValue, availability: .available(source: .rest))
        }

        let irisResponse = await iris
        if let irisValue = irisResponse?.normalised ?? irisResponse?.apertureStop {
            state.iris = CameraValue(value: irisValue, availability: .available(source: .rest))
        }

        let focusResponse = await focus
        if let focusValue = focusResponse?.normalised {
            state.focus = CameraValue(value: focusValue, availability: .available(source: .rest))
        }

        let focusDescriptionResponse = await focusDescription
        if let canAutoFocus = focusDescriptionResponse?.controllable {
            state.canAutoFocus = CameraValue(value: canAutoFocus, availability: .available(source: .rest))
        }

        return state
    }

    private func resolvedActiveDeviceName(
        from activeMedia: RestActiveMediaResponse?,
        workingSet: RestMediaWorkingSetResponse
    ) -> String? {
        guard let index = activeMedia?.workingsetIndex,
              workingSet.workingset.indices.contains(index) else {
            return nil
        }

        return workingSet.workingset[index]?.deviceName
    }

    func setRecording(_ recording: Bool) async throws -> CameraState {
        if recording {
            try await post(path: "/control/api/v1/transports/0/record", body: EmptyBody())
        } else {
            try await post(path: "/control/api/v1/transports/0/stop", body: EmptyBody())
        }

        return try await refreshState()
    }

    func setISO(_ iso: Int) async throws -> CameraState {
        try await put(path: "/control/api/v1/video/iso", body: ["iso": iso])
        return try await refreshState()
    }

    func setShutter(_ shutter: String) async throws -> CameraState {
        let body = try shutterBody(from: shutter)
        try await put(path: "/control/api/v1/video/shutter", body: body)
        return try await refreshState()
    }

    func setWhiteBalance(kelvin: Int, tint: Int) async throws -> CameraState {
        try await put(path: "/control/api/v1/video/whiteBalance", body: ["whiteBalance": kelvin])
        try await put(path: "/control/api/v1/video/whiteBalanceTint", body: ["whiteBalanceTint": tint])
        return try await refreshState()
    }

    func triggerAutoWhiteBalance() async throws -> CameraState {
        try await put(path: "/control/api/v1/video/whiteBalance/doAuto", body: EmptyBody())
        return try await refreshState()
    }

    func setIris(_ iris: Double) async throws -> CameraState {
        try await put(path: "/control/api/v1/lens/iris", body: ["normalised": iris])
        return try await refreshState()
    }

    func setFocus(_ focus: Double) async throws -> CameraState {
        try await put(path: "/control/api/v1/lens/focus", body: ["normalised": focus])
        return try await refreshState()
    }

    func triggerAutoFocus() async throws -> CameraState {
        try await put(path: "/control/api/v1/lens/focus/doAutoFocus", body: EmptyBody())
        return try await refreshState()
    }

    private func get<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        var request = URLRequest(url: makeURL(path: path))
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try validateSuccessfulStatus(response)
        return try decoder.decode(type, from: data)
    }

    private func getOptional<T: Decodable>(_ type: T.Type, path: String) async -> T? {
        do {
            return try await get(type, path: path)
        } catch {
            return nil
        }
    }

    private func put<T: Encodable>(path: String, body: T) async throws {
        try await send(method: "PUT", path: path, body: body)
    }

    private func post<T: Encodable>(path: String, body: T) async throws {
        try await send(method: "POST", path: path, body: body)
    }

    private func send<T: Encodable>(method: String, path: String, body: T) async throws {
        var request = URLRequest(url: makeURL(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (_, response) = try await session.data(for: request)
        try validateSuccessfulStatus(response)
    }

    private func validateSuccessfulStatus(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func makeURL(path: String) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.query = nil
        return components.url!
    }

    private func shutterBody(from shutter: String) throws -> RestShutterBody {
        let trimmed = shutter.trimmingCharacters(in: .whitespacesAndNewlines)
        if let denominator = shutterSpeedDenominator(from: trimmed) {
            return RestShutterBody(shutterSpeed: denominator, shutterAngle: nil)
        }

        if let numericValue = Double(trimmed) {
            let shutterAngle = numericValue > 360 ? numericValue / 100 : numericValue
            return RestShutterBody(shutterSpeed: nil, shutterAngle: shutterAngle)
        }

        throw RestCameraControlClientError.invalidShutter(shutter)
    }

    private func shutterSpeedDenominator(from shutter: String) -> Int? {
        let parts = shutter.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let denominatorText = parts.last,
              let denominator = Int(denominatorText),
              denominator > 0 else {
            return nil
        }

        return denominator
    }

    private func shutterValue(from shutter: RestShutterBody) -> String? {
        if let shutterSpeed = shutter.shutterSpeed {
            return "1/\(shutterSpeed)"
        }

        if let shutterAngle = shutter.shutterAngle {
            return String(shutterAngle)
        }

        return nil
    }
}

private enum RestCameraControlClientError: Error {
    case invalidShutter(String)
}

private struct EmptyBody: Encodable {}
