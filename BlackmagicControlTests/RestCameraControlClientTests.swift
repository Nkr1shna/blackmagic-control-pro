import XCTest
@testable import BlackmagicControl

final class RestCameraControlClientTests: XCTestCase {
    override func tearDown() {
        RestTestURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testPowerResponseMapsBatteryAndPowerSource() throws {
        let json = """
        {
          "source": "Battery",
          "milliVolt": 7400,
          "batteries": [
            {
              "milliVolt": 7400,
              "chargeRemainingPercent": 83,
              "statusFlags": ["Present"]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RestPowerResponse.self, from: json)
        let state = CameraState(restPower: response)

        XCTAssertEqual(state.powerSource.value, "Battery")
        XCTAssertEqual(state.battery.value?.percent, 83)
        XCTAssertEqual(state.battery.value?.voltageMillivolts, 7400)
        XCTAssertEqual(state.battery.availability, .available(source: .rest))
    }

    func testMediaWorkingSetMapsRemainingTime() throws {
        let json = """
        {
          "size": 1,
          "workingset": [
            {
              "volume": "T7",
              "deviceName": "disk0",
              "remainingRecordTime": 1420,
              "totalSpace": 1000000,
              "remainingSpace": 500000,
              "clipCount": 3
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RestMediaWorkingSetResponse.self, from: json)
        let slots = response.toMediaSlots(activeDeviceName: "disk0")

        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].name, "T7")
        XCTAssertEqual(slots[0].remainingRecordTimeSeconds, 1420)
        XCTAssertTrue(slots[0].isActive)
    }

    func testSetShutterHundredthsSendsShutterAngle() async throws {
        var shutterBody: [String: Any]?
        let session = makeSession { request in
            if request.httpMethod == "PUT",
               request.url?.path == "/control/api/v1/video/shutter" {
                shutterBody = try Self.jsonBody(from: request)
                return Self.response(for: request, statusCode: 200, body: "{}")
            }

            return Self.refreshResponse(for: request)
        }

        let client = RestCameraControlClient(baseURL: URL(string: "http://camera.local")!, session: session)
        _ = try await client.setShutter("18000")

        XCTAssertEqual(shutterBody?["shutterAngle"] as? Double, 180.0)
        XCTAssertNil(shutterBody?["shutter"])
        XCTAssertNil(shutterBody?["shutterSpeed"])
    }

    func testSetWhiteBalanceSendsWhiteBalanceTintKey() async throws {
        var tintBody: [String: Any]?
        let session = makeSession { request in
            if request.httpMethod == "PUT",
               request.url?.path == "/control/api/v1/video/whiteBalanceTint" {
                tintBody = try Self.jsonBody(from: request)
                return Self.response(for: request, statusCode: 200, body: "{}")
            }

            if request.httpMethod == "PUT" {
                return Self.response(for: request, statusCode: 200, body: "{}")
            }

            return Self.refreshResponse(for: request)
        }

        let client = RestCameraControlClient(baseURL: URL(string: "http://camera.local")!, session: session)
        _ = try await client.setWhiteBalance(kelvin: 5600, tint: 12)

        XCTAssertEqual(tintBody?["whiteBalanceTint"] as? Int, 12)
        XCTAssertNil(tintBody?["tint"])
    }

    func testDiscoveryUsesDocumentationProbe() async {
        var probedPaths: [String] = []
        let session = makeSession { request in
            let path = request.url?.path ?? ""
            probedPaths.append(path)

            if path == "/control/documentation.html" {
                return Self.response(for: request, statusCode: 200, body: "<html></html>")
            }

            return Self.response(for: request, statusCode: 404, body: "{}")
        }

        let baseURL = URL(string: "http://camera.local")!
        let discovery = RestCameraDiscovery(session: session, candidates: [baseURL])
        let endpoint = await discovery.discover()

        XCTAssertEqual(endpoint?.baseURL, baseURL)
        XCTAssertTrue(probedPaths.contains("/control/documentation.html"))
    }

    func testNon2xxWriteThrows() async throws {
        let session = makeSession { request in
            if request.httpMethod == "PUT",
               request.url?.path == "/control/api/v1/video/iso" {
                return Self.response(for: request, statusCode: 500, body: "{}")
            }

            return Self.refreshResponse(for: request)
        }

        let client = RestCameraControlClient(baseURL: URL(string: "http://camera.local")!, session: session)

        do {
            _ = try await client.setISO(800)
            XCTFail("Expected non-2xx write to throw")
        } catch {
            XCTAssertTrue(true)
        }
    }

    func testRefreshStateMapsOptionalControlValues() async throws {
        let session = makeSession { request in
            switch request.url?.path {
            case "/control/api/v1/video/iso":
                return Self.response(for: request, statusCode: 200, body: #"{"iso":800}"#)
            case "/control/api/v1/video/supportedISOs":
                return Self.response(for: request, statusCode: 200, body: #"{"supportedISOs":[400,800,1250]}"#)
            case "/control/api/v1/video/shutter":
                return Self.response(for: request, statusCode: 200, body: #"{"shutterSpeed":50}"#)
            case "/control/api/v1/video/shutter/measurement":
                return Self.response(for: request, statusCode: 200, body: #"{"measurement":"speed"}"#)
            case "/control/api/v1/video/whiteBalance":
                return Self.response(for: request, statusCode: 200, body: #"{"whiteBalance":5600}"#)
            case "/control/api/v1/video/whiteBalanceTint":
                return Self.response(for: request, statusCode: 200, body: #"{"whiteBalanceTint":12}"#)
            case "/control/api/v1/lens/iris":
                return Self.response(for: request, statusCode: 200, body: #"{"normalised":0.7,"apertureStop":4.0}"#)
            case "/control/api/v1/lens/focus":
                return Self.response(for: request, statusCode: 200, body: #"{"normalised":0.4}"#)
            case "/control/api/v1/lens/focus/description":
                return Self.response(for: request, statusCode: 200, body: #"{"controllable":true}"#)
            default:
                return Self.refreshResponse(for: request)
            }
        }

        let client = RestCameraControlClient(baseURL: URL(string: "http://camera.local")!, session: session)
        let state = try await client.refreshState()

        XCTAssertEqual(state.iso.value, 800)
        XCTAssertEqual(state.supportedISOs.value, [400, 800, 1250])
        XCTAssertEqual(state.shutter.value, "1/50")
        XCTAssertEqual(state.shutterMode.value, "speed")
        XCTAssertEqual(state.whiteBalance.value, 5600)
        XCTAssertEqual(state.tint.value, 12)
        XCTAssertEqual(state.iris.value, 0.7)
        XCTAssertEqual(state.focus.value, 0.4)
        XCTAssertEqual(state.canAutoFocus.value, true)
    }

    private func makeSession(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        RestTestURLProtocol.requestHandler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RestTestURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func refreshResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
        switch request.url?.path {
        case "/control/api/v1/transports/0/record":
            return response(for: request, statusCode: 200, body: #"{"recording":false}"#)
        case "/control/api/v1/transports/0/timecode":
            return response(for: request, statusCode: 200, body: #"{"display":"01:02:03:04","timeline":"01:02:03:04"}"#)
        default:
            return response(for: request, statusCode: 404, body: "{}")
        }
    }

    private static func response(
        for request: URLRequest,
        statusCode: Int,
        body: String
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    private static func jsonBody(from request: URLRequest) throws -> [String: Any] {
        let data = try bodyData(from: request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func bodyData(from request: URLRequest) throws -> Data {
        if let httpBody = request.httpBody {
            return httpBody
        }

        guard let stream = request.httpBodyStream else {
            return try XCTUnwrap(request.httpBody)
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: buffer.count)
            if bytesRead < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeRawData)
            }
            if bytesRead == 0 { break }
            data.append(contentsOf: buffer.prefix(bytesRead))
        }

        return data
    }
}

private final class RestTestURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
