# BMPCC 4K iPad Control App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a v1 SwiftUI iPadOS app that previews the BMPCC 4K direct USB-C UVC feed and controls the camera through a REST-first, BLE-fallback control layer.

**Architecture:** The app has separate preview, control, transport, state, and UI layers. The UI depends only on normalized camera state and the `CameraControlClient` protocol, so REST-over-USB-Ethernet can be removed if iPadOS cannot expose UVC and USB Ethernet at the same time.

**Tech Stack:** Swift 5.10+, SwiftUI, AVFoundation, CoreBluetooth, Foundation `URLSession`, Network framework where needed, XCTest, XcodeGen for reproducible project generation.

---

## Prerequisites

- Xcode must be installed and its license accepted. Verify with `xcodebuild -version`.
- XcodeGen must be available. Verify with `xcodegen --version`; install with `brew install xcodegen` if missing.
- Physical-device validation requires the M1 iPad Pro, BMPCC 4K firmware 9.8 beta or newer, and a USB-C cable.

## File Structure

Create this source structure:

- `project.yml`: XcodeGen project definition.
- `.gitignore`: Swift/Xcode ignores.
- `BlackmagicControl/App/BlackmagicControlApp.swift`: app entry point.
- `BlackmagicControl/App/AppContainer.swift`: constructs app dependencies.
- `BlackmagicControl/App/Info.plist`: iPadOS permissions.
- `BlackmagicControl/Domain/CameraAvailability.swift`: availability wrapper for optional features.
- `BlackmagicControl/Domain/CameraState.swift`: normalized state model.
- `BlackmagicControl/Domain/CameraControlClient.swift`: transport-neutral control protocol.
- `BlackmagicControl/Rest/RestCameraDiscovery.swift`: REST endpoint probing. Removable.
- `BlackmagicControl/Rest/RestCameraControlClient.swift`: REST control implementation. Removable.
- `BlackmagicControl/Rest/RestEventStream.swift`: REST websocket event stream. Removable.
- `BlackmagicControl/Rest/RestModels.swift`: REST DTOs. Removable.
- `BlackmagicControl/BLE/BlackmagicBleConstants.swift`: BLE service and characteristic UUIDs.
- `BlackmagicControl/BLE/BlackmagicCcuPacket.swift`: Blackmagic Camera Control packet encoding.
- `BlackmagicControl/BLE/BleCameraControlClient.swift`: BLE control implementation.
- `BlackmagicControl/Preview/ExternalCameraPreviewModel.swift`: AVFoundation UVC session management.
- `BlackmagicControl/Preview/CameraPreviewView.swift`: preview layer bridge.
- `BlackmagicControl/State/CameraStateStore.swift`: app state and command orchestration.
- `BlackmagicControl/UI/MonitorView.swift`: monitor-first camera UI.
- `BlackmagicControl/UI/ControlPanelView.swift`: compact camera controls.
- `BlackmagicControl/UI/StatusStripView.swift`: connection, transport, timecode, battery, media status.
- `BlackmagicControlTests/CameraStateTests.swift`: normalized-state tests.
- `BlackmagicControlTests/RestCameraControlClientTests.swift`: REST decoding and command tests.
- `BlackmagicControlTests/BlackmagicCcuPacketTests.swift`: BLE packet byte tests.

## Task 1: Project Scaffold

**Files:**
- Create: `.gitignore`
- Create: `project.yml`
- Create: `BlackmagicControl/App/Info.plist`
- Create: `BlackmagicControl/App/BlackmagicControlApp.swift`

- [ ] **Step 1: Create the project files**

Use this patch:

```diff
*** Begin Patch
*** Add File: .gitignore
+DerivedData/
+.build/
+*.xcworkspace/xcuserdata/
+*.xcodeproj/xcuserdata/
+*.xcuserstate
+*.moved-aside
+.DS_Store
+build/
*** Add File: project.yml
+name: BlackmagicControl
+options:
+  deploymentTarget:
+    iOS: "17.0"
+  bundleIdPrefix: com.local
+settings:
+  base:
+    SWIFT_VERSION: 5.0
+targets:
+  BlackmagicControl:
+    type: application
+    platform: iOS
+    sources:
+      - BlackmagicControl
+    settings:
+      base:
+        PRODUCT_BUNDLE_IDENTIFIER: com.local.BlackmagicControl
+        INFOPLIST_FILE: BlackmagicControl/App/Info.plist
+        TARGETED_DEVICE_FAMILY: 2
+        SUPPORTS_MACCATALYST: false
+    info:
+      path: BlackmagicControl/App/Info.plist
+  BlackmagicControlTests:
+    type: bundle.unit-test
+    platform: iOS
+    sources:
+      - BlackmagicControlTests
+    dependencies:
+      - target: BlackmagicControl
*** Add File: BlackmagicControl/App/Info.plist
+<?xml version="1.0" encoding="UTF-8"?>
+<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
+<plist version="1.0">
+<dict>
+  <key>CFBundleDevelopmentRegion</key>
+  <string>$(DEVELOPMENT_LANGUAGE)</string>
+  <key>CFBundleExecutable</key>
+  <string>$(EXECUTABLE_NAME)</string>
+  <key>CFBundleIdentifier</key>
+  <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
+  <key>CFBundleInfoDictionaryVersion</key>
+  <string>6.0</string>
+  <key>CFBundleName</key>
+  <string>Blackmagic Control</string>
+  <key>CFBundlePackageType</key>
+  <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
+  <key>CFBundleShortVersionString</key>
+  <string>1.0</string>
+  <key>CFBundleVersion</key>
+  <string>1</string>
+  <key>LSRequiresIPhoneOS</key>
+  <true/>
+  <key>NSCameraUsageDescription</key>
+  <string>Camera access is required to preview the connected Blackmagic camera feed.</string>
+  <key>NSBluetoothAlwaysUsageDescription</key>
+  <string>Bluetooth access is required to pair with and control the Blackmagic camera.</string>
+  <key>NSBluetoothPeripheralUsageDescription</key>
+  <string>Bluetooth access is required to pair with and control the Blackmagic camera.</string>
+  <key>NSLocalNetworkUsageDescription</key>
+  <string>Local network access is required to control the Blackmagic camera over its REST API.</string>
+  <key>NSBonjourServices</key>
+  <array>
+    <string>_http._tcp</string>
+  </array>
+  <key>UISupportedInterfaceOrientations~ipad</key>
+  <array>
+    <string>UIInterfaceOrientationLandscapeLeft</string>
+    <string>UIInterfaceOrientationLandscapeRight</string>
+    <string>UIInterfaceOrientationPortrait</string>
+    <string>UIInterfaceOrientationPortraitUpsideDown</string>
+  </array>
+</dict>
+</plist>
*** Add File: BlackmagicControl/App/BlackmagicControlApp.swift
+import SwiftUI
+
+@main
+struct BlackmagicControlApp: App {
+    var body: some Scene {
+        WindowGroup {
+            Text("Blackmagic Control")
+                .font(.system(size: 28, weight: .bold))
+                .foregroundStyle(.white)
+                .frame(maxWidth: .infinity, maxHeight: .infinity)
+                .background(Color.black)
+        }
+    }
+}
*** End Patch
```

- [ ] **Step 2: Generate the Xcode project**

Run:

```bash
xcodegen generate
```

Expected: `BlackmagicControl.xcodeproj` is created without errors.

- [ ] **Step 3: Commit the scaffold**

Run:

```bash
git add .gitignore project.yml BlackmagicControl/App
git commit -m "feat: scaffold iPad camera control app"
```

Expected: commit succeeds.

## Task 2: Domain State And Control Protocol

**Files:**
- Create: `BlackmagicControl/Domain/CameraAvailability.swift`
- Create: `BlackmagicControl/Domain/CameraState.swift`
- Create: `BlackmagicControl/Domain/CameraControlClient.swift`
- Create: `BlackmagicControlTests/CameraStateTests.swift`

- [ ] **Step 1: Write the failing normalized-state test**

Create `BlackmagicControlTests/CameraStateTests.swift`:

```swift
import XCTest
@testable import BlackmagicControl

final class CameraStateTests: XCTestCase {
    func testUnavailableFieldsAreDisabledForUI() {
        let state = CameraState()

        XCTAssertEqual(state.controlTransport, .disconnected)
        XCTAssertFalse(state.iso.isAvailable)
        XCTAssertFalse(state.remainingRecordTime.isAvailable)
        XCTAssertEqual(state.errors, [])
    }

    func testAvailableValueCarriesSource() {
        let iso = CameraValue(value: 800, availability: .available(source: .rest))

        XCTAssertTrue(iso.isAvailable)
        XCTAssertEqual(iso.value, 800)
        XCTAssertEqual(iso.availability, .available(source: .rest))
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
xcodebuild test -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)'
```

Expected: FAIL because `CameraState`, `CameraValue`, and related types do not exist.

- [ ] **Step 3: Add the domain types**

Create `BlackmagicControl/Domain/CameraAvailability.swift`:

```swift
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
```

Create `BlackmagicControl/Domain/CameraState.swift`:

```swift
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
```

Create `BlackmagicControl/Domain/CameraControlClient.swift`:

```swift
import Foundation

protocol CameraControlClient: AnyObject {
    var transport: CameraControlTransport { get }

    func connect() async throws -> CameraState
    func disconnect() async
    func refreshState() async throws -> CameraState

    func setRecording(_ recording: Bool) async throws -> CameraState
    func setISO(_ iso: Int) async throws -> CameraState
    func setShutter(_ shutter: String) async throws -> CameraState
    func setWhiteBalance(kelvin: Int, tint: Int) async throws -> CameraState
    func triggerAutoWhiteBalance() async throws -> CameraState
    func setIris(_ iris: Double) async throws -> CameraState
    func setFocus(_ focus: Double) async throws -> CameraState
    func triggerAutoFocus() async throws -> CameraState
}
```

- [ ] **Step 4: Run the domain tests**

Run:

```bash
xcodebuild test -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)' -only-testing:BlackmagicControlTests/CameraStateTests
```

Expected: PASS.

- [ ] **Step 5: Commit the domain layer**

Run:

```bash
git add BlackmagicControl/Domain BlackmagicControlTests/CameraStateTests.swift
git commit -m "feat: add normalized camera state model"
```

Expected: commit succeeds.

## Task 3: REST Discovery And Control Client

**Files:**
- Create: `BlackmagicControl/Rest/RestModels.swift`
- Create: `BlackmagicControl/Rest/RestCameraDiscovery.swift`
- Create: `BlackmagicControl/Rest/RestCameraControlClient.swift`
- Create: `BlackmagicControlTests/RestCameraControlClientTests.swift`

- [ ] **Step 1: Write failing REST mapping tests**

Create `BlackmagicControlTests/RestCameraControlClientTests.swift`:

```swift
import XCTest
@testable import BlackmagicControl

final class RestCameraControlClientTests: XCTestCase {
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
}
```

- [ ] **Step 2: Run the REST tests and verify they fail**

Run:

```bash
xcodebuild test -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)' -only-testing:BlackmagicControlTests/RestCameraControlClientTests
```

Expected: FAIL because REST DTOs do not exist.

- [ ] **Step 3: Add REST DTOs and state mapping**

Create `BlackmagicControl/Rest/RestModels.swift`:

```swift
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

extension CameraState {
    init(restPower: RestPowerResponse) {
        self.init()
        let battery = restPower.batteries?.first
        self.powerSource = CameraValue(
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
```

- [ ] **Step 4: Add REST discovery and client**

Create `BlackmagicControl/Rest/RestCameraDiscovery.swift`:

```swift
import Foundation

struct RestCameraEndpoint: Equatable {
    let baseURL: URL
}

final class RestCameraDiscovery {
    private let session: URLSession
    private let candidates: [URL]

    init(
        session: URLSession = .shared,
        candidates: [URL] = [
            URL(string: "http://192.168.7.1")!,
            URL(string: "http://192.168.6.1")!,
            URL(string: "http://10.0.0.1")!,
            URL(string: "http://blackmagic.local")!
        ]
    ) {
        self.session = session
        self.candidates = candidates
    }

    func discover() async -> RestCameraEndpoint? {
        for candidate in candidates {
            if await responds(candidate) {
                return RestCameraEndpoint(baseURL: candidate)
            }
        }
        return nil
    }

    private func responds(_ baseURL: URL) async -> Bool {
        let url = Self.url(baseURL: baseURL, path: "/control/api/v1/system/product")
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<500).contains(http.statusCode)
        } catch {
            return false
        }
    }

    private static func url(baseURL: URL, path: String) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        return components.url!
    }
}
```

Create `BlackmagicControl/Rest/RestCameraControlClient.swift`:

```swift
import Foundation

final class RestCameraControlClient: CameraControlClient {
    let transport: CameraControlTransport = .rest

    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func connect() async throws -> CameraState {
        try await refreshState()
    }

    func disconnect() async {}

    func refreshState() async throws -> CameraState {
        async let record = get(RestTransportRecordResponse.self, path: "/control/api/v1/transports/0/record")
        async let timecode = get(RestTimecodeResponse.self, path: "/control/api/v1/transports/0/timecode")
        async let power = getOptional(RestPowerResponse.self, path: "/control/api/v1/camera/power")
        async let activeMedia = getOptional(RestActiveMediaResponse.self, path: "/control/api/v1/media/active")
        async let workingSet = getOptional(RestMediaWorkingSetResponse.self, path: "/control/api/v1/media/workingset")

        var state = CameraState()
        state.controlTransport = .rest
        state.connectionStatus = "Connected"

        let recordResponse = try await record
        state.isRecording = CameraValue(value: recordResponse.recording, availability: .available(source: .rest))

        let timecodeResponse = try await timecode
        state.timecode = CameraValue(value: timecodeResponse.display ?? timecodeResponse.timeline, availability: .available(source: .rest))

        if let powerResponse = try await power {
            let powerState = CameraState(restPower: powerResponse)
            state.powerSource = powerState.powerSource
            state.battery = powerState.battery
        }

        let active = try await activeMedia
        if let workingSetResponse = try await workingSet {
            let slots = workingSetResponse.toMediaSlots(activeDeviceName: active?.deviceName)
            state.mediaSlots = CameraValue(value: slots, availability: .available(source: .rest))
            state.activeMedia = CameraValue(value: active?.deviceName, availability: .available(source: .rest))
            state.remainingRecordTime = CameraValue(value: slots.first(where: { $0.isActive })?.remainingRecordTimeSeconds, availability: .available(source: .rest))
        }

        return state
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
        try await put(path: "/control/api/v1/video/shutter", body: ["shutter": shutter])
        return try await refreshState()
    }

    func setWhiteBalance(kelvin: Int, tint: Int) async throws -> CameraState {
        try await put(path: "/control/api/v1/video/whiteBalance", body: ["whiteBalance": kelvin])
        try await put(path: "/control/api/v1/video/whiteBalanceTint", body: ["tint": tint])
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
        let (data, _) = try await session.data(for: URLRequest(url: makeURL(path: path)))
        return try decoder.decode(T.self, from: data)
    }

    private func getOptional<T: Decodable>(_ type: T.Type, path: String) async throws -> T? {
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
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func makeURL(path: String) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        return components.url!
    }
}

private struct EmptyBody: Encodable {}
```

- [ ] **Step 5: Run REST tests**

Run:

```bash
xcodebuild test -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)' -only-testing:BlackmagicControlTests/RestCameraControlClientTests
```

Expected: PASS.

- [ ] **Step 6: Commit REST core**

Run:

```bash
git add BlackmagicControl/Rest BlackmagicControlTests/RestCameraControlClientTests.swift
git commit -m "feat: add REST camera control core"
```

Expected: commit succeeds.

## Task 4: BLE Packet Encoding

**Files:**
- Create: `BlackmagicControl/BLE/BlackmagicBleConstants.swift`
- Create: `BlackmagicControl/BLE/BlackmagicCcuPacket.swift`
- Create: `BlackmagicControlTests/BlackmagicCcuPacketTests.swift`

- [ ] **Step 1: Write BLE packet tests**

Create `BlackmagicControlTests/BlackmagicCcuPacketTests.swift`:

```swift
import XCTest
@testable import BlackmagicControl

final class BlackmagicCcuPacketTests: XCTestCase {
    func testInstantAutofocusPacketMatchesProtocolExample() {
        let packet = BlackmagicCcuPacket.changeConfiguration(
            destination: 4,
            category: 0,
            parameter: 1,
            dataType: .void,
            operation: .assign,
            payload: Data()
        )

        XCTAssertEqual(Array(packet.bytes), [4, 4, 0, 0, 0, 1, 0, 0])
    }

    func testSetExposurePacketMatchesProtocolExample() {
        let payload = BlackmagicCcuPacket.int32Payload(10000)
        let packet = BlackmagicCcuPacket.changeConfiguration(
            destination: 4,
            category: 1,
            parameter: 5,
            dataType: .int32,
            operation: .assign,
            payload: payload
        )

        XCTAssertEqual(Array(packet.bytes), [4, 8, 0, 0, 1, 5, 3, 0, 0x10, 0x27, 0x00, 0x00])
    }
}
```

- [ ] **Step 2: Run packet tests and verify they fail**

Run:

```bash
xcodebuild test -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)' -only-testing:BlackmagicControlTests/BlackmagicCcuPacketTests
```

Expected: FAIL because `BlackmagicCcuPacket` does not exist.

- [ ] **Step 3: Add BLE constants and packet encoder**

Create `BlackmagicControl/BLE/BlackmagicBleConstants.swift`:

```swift
import CoreBluetooth

enum BlackmagicBleConstants {
    static let deviceInformationService = CBUUID(string: "180A")
    static let manufacturerCharacteristic = CBUUID(string: "2A29")
    static let modelCharacteristic = CBUUID(string: "2A24")

    static let cameraService = CBUUID(string: "291D567A-6D75-11E6-8B77-86F30CA893D3")
    static let outgoingCameraControl = CBUUID(string: "5DD3465F-1AEE-4299-8493-D2ECA2F8E1BB")
    static let incomingCameraControl = CBUUID(string: "B864E140-76A0-416A-BF30-5876504537D9")
    static let timecode = CBUUID(string: "6D8F2110-86F1-41BF-9AFB-451D87E976C8")
    static let cameraStatus = CBUUID(string: "7FE8691D-95DC-4FC5-8ABD-CA74339B51B9")
    static let deviceName = CBUUID(string: "FFAC0C52-C9FB-41A0-B063-CC76282EB89C")
    static let protocolVersion = CBUUID(string: "8F1FD018-B508-456F-8F82-3D392BEE2706")
}
```

Create `BlackmagicControl/BLE/BlackmagicCcuPacket.swift`:

```swift
import Foundation

struct BlackmagicCcuPacket: Equatable {
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

    let bytes: Data

    static func changeConfiguration(
        destination: UInt8,
        category: UInt8,
        parameter: UInt8,
        dataType: DataType,
        operation: Operation,
        payload: Data
    ) -> BlackmagicCcuPacket {
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
        let scaled = Int16((value * 2048.0).rounded())
        return int16Payload(scaled)
    }
}
```

- [ ] **Step 4: Run BLE packet tests**

Run:

```bash
xcodebuild test -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)' -only-testing:BlackmagicControlTests/BlackmagicCcuPacketTests
```

Expected: PASS.

- [ ] **Step 5: Commit BLE packet encoding**

Run:

```bash
git add BlackmagicControl/BLE BlackmagicControlTests/BlackmagicCcuPacketTests.swift
git commit -m "feat: add Blackmagic BLE packet encoder"
```

Expected: commit succeeds.

## Task 5: BLE Control Client Skeleton

**Files:**
- Create: `BlackmagicControl/BLE/BleCameraControlClient.swift`

- [ ] **Step 1: Add a compile-safe BLE client**

Create `BlackmagicControl/BLE/BleCameraControlClient.swift`:

```swift
import CoreBluetooth
import Foundation

final class BleCameraControlClient: NSObject, CameraControlClient {
    let transport: CameraControlTransport = .ble

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var outgoingCharacteristic: CBCharacteristic?

    override init() {
        super.init()
    }

    func connect() async throws -> CameraState {
        await MainActor.run {
            if central == nil {
                central = CBCentralManager(delegate: self, queue: nil)
            }
        }

        var state = CameraState()
        state.controlTransport = .ble
        state.connectionStatus = "BLE scanning"
        return state
    }

    func disconnect() async {
        guard let peripheral else { return }
        central?.cancelPeripheralConnection(peripheral)
    }

    func refreshState() async throws -> CameraState {
        var state = CameraState()
        state.controlTransport = .ble
        state.connectionStatus = peripheral == nil ? "BLE disconnected" : "BLE connected"
        return state
    }

    func setRecording(_ recording: Bool) async throws -> CameraState {
        let mode: UInt8 = recording ? 2 : 0
        let packet = BlackmagicCcuPacket.changeConfiguration(
            destination: 255,
            category: 10,
            parameter: 1,
            dataType: .int8,
            operation: .assign,
            payload: Data([mode])
        )
        write(packet)
        return try await refreshState()
    }

    func setISO(_ iso: Int) async throws -> CameraState {
        let packet = BlackmagicCcuPacket.changeConfiguration(
            destination: 255,
            category: 1,
            parameter: 14,
            dataType: .int32,
            operation: .assign,
            payload: BlackmagicCcuPacket.int32Payload(Int32(iso))
        )
        write(packet)
        return try await refreshState()
    }

    func setShutter(_ shutter: String) async throws -> CameraState {
        let numeric = Int32(shutter) ?? 18000
        let packet = BlackmagicCcuPacket.changeConfiguration(
            destination: 255,
            category: 1,
            parameter: 11,
            dataType: .int32,
            operation: .assign,
            payload: BlackmagicCcuPacket.int32Payload(numeric)
        )
        write(packet)
        return try await refreshState()
    }

    func setWhiteBalance(kelvin: Int, tint: Int) async throws -> CameraState {
        var payload = Data()
        payload.append(BlackmagicCcuPacket.int16Payload(Int16(kelvin)))
        payload.append(BlackmagicCcuPacket.int16Payload(Int16(tint)))
        let packet = BlackmagicCcuPacket.changeConfiguration(
            destination: 255,
            category: 1,
            parameter: 2,
            dataType: .int16,
            operation: .assign,
            payload: payload
        )
        write(packet)
        return try await refreshState()
    }

    func triggerAutoWhiteBalance() async throws -> CameraState {
        write(.changeConfiguration(destination: 255, category: 1, parameter: 3, dataType: .void, operation: .assign, payload: Data()))
        return try await refreshState()
    }

    func setIris(_ iris: Double) async throws -> CameraState {
        write(.changeConfiguration(destination: 255, category: 0, parameter: 3, dataType: .fixed16, operation: .assign, payload: BlackmagicCcuPacket.fixed16Payload(iris)))
        return try await refreshState()
    }

    func setFocus(_ focus: Double) async throws -> CameraState {
        write(.changeConfiguration(destination: 255, category: 0, parameter: 0, dataType: .fixed16, operation: .assign, payload: BlackmagicCcuPacket.fixed16Payload(focus)))
        return try await refreshState()
    }

    func triggerAutoFocus() async throws -> CameraState {
        write(.changeConfiguration(destination: 255, category: 0, parameter: 1, dataType: .void, operation: .assign, payload: Data()))
        return try await refreshState()
    }

    private func write(_ packet: BlackmagicCcuPacket) {
        guard let peripheral, let outgoingCharacteristic else { return }
        peripheral.writeValue(packet.bytes, for: outgoingCharacteristic, type: .withResponse)
    }
}

extension BleCameraControlClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: [BlackmagicBleConstants.cameraService])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([BlackmagicBleConstants.cameraService, BlackmagicBleConstants.deviceInformationService])
    }
}

extension BleCameraControlClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        service.characteristics?.forEach { characteristic in
            if characteristic.uuid == BlackmagicBleConstants.outgoingCameraControl {
                outgoingCharacteristic = characteristic
            }
            if characteristic.uuid == BlackmagicBleConstants.incomingCameraControl ||
                characteristic.uuid == BlackmagicBleConstants.timecode ||
                characteristic.uuid == BlackmagicBleConstants.cameraStatus {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
}
```

- [ ] **Step 2: Build the BLE client**

Run:

```bash
xcodebuild build -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)'
```

Expected: build succeeds. Simulator cannot validate physical BLE pairing.

- [ ] **Step 3: Commit BLE client skeleton**

Run:

```bash
git add BlackmagicControl/BLE/BleCameraControlClient.swift
git commit -m "feat: add BLE control client skeleton"
```

Expected: commit succeeds.

## Task 6: UVC Preview Layer

**Files:**
- Create: `BlackmagicControl/Preview/ExternalCameraPreviewModel.swift`
- Create: `BlackmagicControl/Preview/CameraPreviewView.swift`

- [ ] **Step 1: Add the external-camera preview model**

Create `BlackmagicControl/Preview/ExternalCameraPreviewModel.swift`:

```swift
import AVFoundation
import Combine
import Foundation

@MainActor
final class ExternalCameraPreviewModel: ObservableObject {
    @Published private(set) var session = AVCaptureSession()
    @Published private(set) var status: String = "Preview stopped"
    @Published private(set) var errorMessage: String?

    func start() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            errorMessage = "Camera permission denied"
            status = "Preview unavailable"
            return
        }

        guard let device = discoverExternalCamera() else {
            errorMessage = "No external UVC camera found"
            status = "Preview unavailable"
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            if session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()
            session.startRunning()
            status = "Preview active"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            status = "Preview unavailable"
        }
    }

    func stop() {
        session.stopRunning()
        status = "Preview stopped"
    }

    private func discoverExternalCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first { device in
            device.localizedName.localizedCaseInsensitiveContains("blackmagic")
        } ?? discovery.devices.first
    }
}
```

Create `BlackmagicControl/Preview/CameraPreviewView.swift`:

```swift
import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.videoPreviewLayer.videoGravity = .resizeAspect
        view.videoPreviewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
```

- [ ] **Step 2: Build preview code**

Run:

```bash
xcodebuild build -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)'
```

Expected: build succeeds. Simulator will not show the BMPCC UVC feed.

- [ ] **Step 3: Commit preview layer**

Run:

```bash
git add BlackmagicControl/Preview
git commit -m "feat: add external UVC preview layer"
```

Expected: commit succeeds.

## Task 7: State Store And Transport Selection

**Files:**
- Create: `BlackmagicControl/State/CameraStateStore.swift`
- Create: `BlackmagicControl/App/AppContainer.swift`

- [ ] **Step 1: Add the app container and state store**

Create `BlackmagicControl/App/AppContainer.swift`:

```swift
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let previewModel: ExternalCameraPreviewModel
    let store: CameraStateStore

    init() {
        let previewModel = ExternalCameraPreviewModel()
        let restDiscovery = RestCameraDiscovery()
        let bleClient = BleCameraControlClient()
        self.previewModel = previewModel
        self.store = CameraStateStore(
            restDiscovery: restDiscovery,
            bleClient: bleClient
        )
    }
}
```

Create `BlackmagicControl/State/CameraStateStore.swift`:

```swift
import Combine
import Foundation

@MainActor
final class CameraStateStore: ObservableObject {
    @Published private(set) var state = CameraState()
    @Published private(set) var isBusy = false

    private let restDiscovery: RestCameraDiscovery
    private let bleClient: BleCameraControlClient
    private var activeClient: CameraControlClient?

    init(restDiscovery: RestCameraDiscovery, bleClient: BleCameraControlClient) {
        self.restDiscovery = restDiscovery
        self.bleClient = bleClient
    }

    func connect() async {
        isBusy = true
        defer { isBusy = false }

        if let endpoint = await restDiscovery.discover() {
            let client = RestCameraControlClient(baseURL: endpoint.baseURL)
            activeClient = client
            await applyResult {
                try await client.connect()
            }
            return
        }

        activeClient = bleClient
        await applyResult {
            try await bleClient.connect()
        }
    }

    func refresh() async {
        guard let activeClient else { return }
        await applyResult {
            try await activeClient.refreshState()
        }
    }

    func setRecording(_ recording: Bool) async {
        await command { client in
            try await client.setRecording(recording)
        }
    }

    func setISO(_ iso: Int) async {
        await command { client in
            try await client.setISO(iso)
        }
    }

    func setShutter(_ shutter: String) async {
        await command { client in
            try await client.setShutter(shutter)
        }
    }

    func setWhiteBalance(kelvin: Int, tint: Int) async {
        await command { client in
            try await client.setWhiteBalance(kelvin: kelvin, tint: tint)
        }
    }

    func triggerAutoWhiteBalance() async {
        await command { client in
            try await client.triggerAutoWhiteBalance()
        }
    }

    func setIris(_ iris: Double) async {
        await command { client in
            try await client.setIris(iris)
        }
    }

    func setFocus(_ focus: Double) async {
        await command { client in
            try await client.setFocus(focus)
        }
    }

    func triggerAutoFocus() async {
        await command { client in
            try await client.triggerAutoFocus()
        }
    }

    private func command(_ action: (CameraControlClient) async throws -> CameraState) async {
        guard let activeClient else {
            state.errors.append(CameraError(subsystem: "Control", message: "No active camera control connection"))
            return
        }
        isBusy = true
        defer { isBusy = false }
        await applyResult {
            try await action(activeClient)
        }
    }

    private func applyResult(_ action: () async throws -> CameraState) async {
        do {
            state = try await action()
        } catch {
            state.errors.append(CameraError(subsystem: "Control", message: error.localizedDescription))
        }
    }
}
```

- [ ] **Step 2: Build the state store**

Run:

```bash
xcodebuild build -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)'
```

Expected: build succeeds.

- [ ] **Step 3: Commit state orchestration**

Run:

```bash
git add BlackmagicControl/State BlackmagicControl/App/AppContainer.swift
git commit -m "feat: add camera state orchestration"
```

Expected: commit succeeds.

## Task 8: Monitor UI

**Files:**
- Modify: `BlackmagicControl/App/BlackmagicControlApp.swift`
- Create: `BlackmagicControl/UI/MonitorView.swift`
- Create: `BlackmagicControl/UI/ControlPanelView.swift`
- Create: `BlackmagicControl/UI/StatusStripView.swift`

- [ ] **Step 1: Add the monitor screen**

Change `BlackmagicControl/App/BlackmagicControlApp.swift` to:

```swift
import SwiftUI

@main
struct BlackmagicControlApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            MonitorView(store: container.store, previewModel: container.previewModel)
        }
    }
}
```

Create `BlackmagicControl/UI/MonitorView.swift`:

```swift
import SwiftUI

struct MonitorView: View {
    @ObservedObject var store: CameraStateStore
    @ObservedObject var previewModel: ExternalCameraPreviewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: previewModel.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                StatusStripView(state: store.state, previewStatus: previewModel.status)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                Spacer()

                ControlPanelView(store: store)
                    .padding(16)
            }
        }
        .task {
            await previewModel.start()
            await store.connect()
        }
    }
}
```

Create `BlackmagicControl/UI/StatusStripView.swift`:

```swift
import SwiftUI

struct StatusStripView: View {
    let state: CameraState
    let previewStatus: String

    var body: some View {
        HStack(spacing: 12) {
            Text(previewStatus)
            Text(state.connectionStatus)
            Text(state.controlTransport.rawValue.uppercased())

            Spacer()

            if let timecode = state.timecode.value {
                Text(timecode)
                    .monospacedDigit()
            }

            if let percent = state.battery.value?.percent {
                Text("\(percent)%")
            }

            if let seconds = state.remainingRecordTime.value {
                Text(formatRemaining(seconds))
                    .monospacedDigit()
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatRemaining(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return "\(minutes)m"
    }
}
```

Create `BlackmagicControl/UI/ControlPanelView.swift`:

```swift
import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var store: CameraStateStore
    @State private var isoText = "800"
    @State private var shutterText = "18000"
    @State private var whiteBalanceText = "5600"
    @State private var tintText = "10"
    @State private var focus: Double = 0.5
    @State private var iris: Double = 0.5

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {
                Task { await store.setRecording(!(store.state.isRecording.value ?? false)) }
            } label: {
                Circle()
                    .fill((store.state.isRecording.value ?? false) ? Color.red : Color.white)
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(Color.red, lineWidth: 4))
            }
            .accessibilityLabel("Record")

            controlField(title: "ISO", text: $isoText) {
                Task { await store.setISO(Int(isoText) ?? 800) }
            }

            controlField(title: "SHUTTER", text: $shutterText) {
                Task { await store.setShutter(shutterText) }
            }

            controlField(title: "WB", text: $whiteBalanceText) {
                Task {
                    await store.setWhiteBalance(
                        kelvin: Int(whiteBalanceText) ?? 5600,
                        tint: Int(tintText) ?? 10
                    )
                }
            }

            controlField(title: "TINT", text: $tintText) {
                Task {
                    await store.setWhiteBalance(
                        kelvin: Int(whiteBalanceText) ?? 5600,
                        tint: Int(tintText) ?? 10
                    )
                }
            }

            Button("AWB") {
                Task { await store.triggerAutoWhiteBalance() }
            }
            .buttonStyle(CameraButtonStyle())

            VStack(alignment: .leading) {
                Text("FOCUS")
                Slider(value: $focus, in: 0...1) { editing in
                    if !editing {
                        Task { await store.setFocus(focus) }
                    }
                }
                Button("AF") {
                    Task { await store.triggerAutoFocus() }
                }
                .buttonStyle(CameraButtonStyle())
            }
            .frame(width: 140)

            VStack(alignment: .leading) {
                Text("IRIS")
                Slider(value: $iris, in: 0...1) { editing in
                    if !editing {
                        Task { await store.setIris(iris) }
                    }
                }
            }
            .frame(width: 120)
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func controlField(title: String, text: Binding<String>, submit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            TextField(title, text: text)
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.plain)
                .frame(width: 82, height: 34)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onSubmit(submit)
        }
    }
}

struct CameraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(minWidth: 48, minHeight: 34)
            .background(configuration.isPressed ? Color.red.opacity(0.8) : Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
```

- [ ] **Step 2: Build the UI**

Run:

```bash
xcodebuild build -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)'
```

Expected: build succeeds.

- [ ] **Step 3: Commit monitor UI**

Run:

```bash
git add BlackmagicControl/App/BlackmagicControlApp.swift BlackmagicControl/UI
git commit -m "feat: add monitor-first camera UI"
```

Expected: commit succeeds.

## Task 9: REST Event Stream

**Files:**
- Create: `BlackmagicControl/Rest/RestEventStream.swift`

- [ ] **Step 1: Add a websocket event reader**

Create `BlackmagicControl/Rest/RestEventStream.swift`:

```swift
import Foundation

struct RestEventMessage: Decodable, Equatable {
    struct Payload: Decodable, Equatable {
        let action: String
        let property: String?
    }

    let data: Payload
    let type: String
}

final class RestEventStream {
    private let baseURL: URL
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func connect(onEvent: @escaping (RestEventMessage) -> Void) {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components?.path = "/control/api/v1/event/websocket"

        guard let url = components?.url else { return }
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        receive(onEvent: onEvent)
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receive(onEvent: @escaping (RestEventMessage) -> Void) {
        task?.receive { [weak self] result in
            guard let self else { return }
            if case let .success(message) = result,
               case let .string(text) = message,
               let data = text.data(using: .utf8),
               let event = try? JSONDecoder().decode(RestEventMessage.self, from: data) {
                onEvent(event)
            }
            self.receive(onEvent: onEvent)
        }
    }
}
```

- [ ] **Step 2: Build the event stream**

Run:

```bash
xcodebuild build -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)'
```

Expected: build succeeds.

- [ ] **Step 3: Commit REST events**

Run:

```bash
git add BlackmagicControl/Rest/RestEventStream.swift
git commit -m "feat: add REST event stream shell"
```

Expected: commit succeeds.

## Task 10: Verification And Hardware Checklist

**Files:**
- Create: `docs/hardware-test-checklist.md`

- [ ] **Step 1: Add the manual test checklist**

Create `docs/hardware-test-checklist.md`:

```markdown
# BMPCC 4K iPad Hardware Test Checklist

Date:
Camera firmware:
iPad model:
iPadOS version:
Cable or hub:

## UVC Preview

- App sees an external camera.
- Preview starts.
- Preview remains stable for five minutes.
- Disconnecting the USB-C cable shows a preview error without crashing.

## REST Over USB-C

- Safari on iPad reaches `http://192.168.7.1/control/documentation.html`.
- Safari on iPad reaches `http://192.168.6.1/control/documentation.html`.
- Safari on iPad reaches `http://10.0.0.1/control/documentation.html`.
- App shows REST as active transport.
- App can refresh camera state while preview is active.

## REST Commands

- Record starts.
- Record stops.
- ISO changes.
- Shutter changes.
- White balance changes.
- Tint changes.
- Battery/power status appears.
- Media remaining time appears.

## BLE Fallback

- Camera appears in BLE scan.
- Pairing prompts for the camera-displayed PIN.
- App shows BLE as active transport when REST is unavailable.
- Record starts through BLE.
- Record stops through BLE.
- ISO changes through BLE.
- White balance changes through BLE.

## Decision

Keep REST primary:

Remove REST-over-USB-Ethernet from v1:

Notes:
```

- [ ] **Step 2: Run all automated tests**

Run:

```bash
xcodebuild test -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)'
```

Expected: all unit tests pass.

- [ ] **Step 3: Build for a physical iPad**

Run:

```bash
xcodebuild build -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'generic/platform=iOS'
```

Expected: build succeeds after a signing team is selected in Xcode or project settings.

- [ ] **Step 4: Commit verification docs**

Run:

```bash
git add docs/hardware-test-checklist.md
git commit -m "docs: add BMPCC hardware test checklist"
```

Expected: commit succeeds.

## Task 11: REST Removal Procedure If UVC Plus USB Ethernet Fails

**Files:**
- Delete if needed: `BlackmagicControl/Rest/RestCameraDiscovery.swift`
- Delete if needed: `BlackmagicControl/Rest/RestCameraControlClient.swift`
- Delete if needed: `BlackmagicControl/Rest/RestEventStream.swift`
- Delete if needed: `BlackmagicControl/Rest/RestModels.swift`
- Modify if needed: `BlackmagicControl/App/AppContainer.swift`
- Modify if needed: `BlackmagicControl/State/CameraStateStore.swift`
- Delete if needed: `BlackmagicControlTests/RestCameraControlClientTests.swift`

- [ ] **Step 1: Remove REST dependency injection**

Change `BlackmagicControl/App/AppContainer.swift` to:

```swift
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let previewModel: ExternalCameraPreviewModel
    let store: CameraStateStore

    init() {
        let previewModel = ExternalCameraPreviewModel()
        let bleClient = BleCameraControlClient()
        self.previewModel = previewModel
        self.store = CameraStateStore(bleClient: bleClient)
    }
}
```

- [ ] **Step 2: Make the store BLE-only**

Change `BlackmagicControl/State/CameraStateStore.swift` initializer and connect method to:

```swift
private let bleClient: BleCameraControlClient
private var activeClient: CameraControlClient?

init(bleClient: BleCameraControlClient) {
    self.bleClient = bleClient
}

func connect() async {
    isBusy = true
    defer { isBusy = false }

    activeClient = bleClient
    await applyResult {
        try await bleClient.connect()
    }
}
```

Leave the command methods unchanged.

- [ ] **Step 3: Delete REST files and tests**

Run:

```bash
rm BlackmagicControl/Rest/RestCameraDiscovery.swift
rm BlackmagicControl/Rest/RestCameraControlClient.swift
rm BlackmagicControl/Rest/RestEventStream.swift
rm BlackmagicControl/Rest/RestModels.swift
rm BlackmagicControlTests/RestCameraControlClientTests.swift
```

Expected: files are removed. Use this only after the hardware checklist proves REST cannot coexist with UVC on iPadOS.

- [ ] **Step 4: Build BLE-only app**

Run:

```bash
xcodebuild build -project BlackmagicControl.xcodeproj -scheme BlackmagicControl -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (M4)'
```

Expected: build succeeds.

- [ ] **Step 5: Commit BLE-only fallback**

Run:

```bash
git add BlackmagicControl/App/AppContainer.swift BlackmagicControl/State/CameraStateStore.swift BlackmagicControl/Rest BlackmagicControlTests
git commit -m "refactor: remove REST control path after hardware test"
```

Expected: commit succeeds.

## Self-Review Notes

- Spec coverage: preview, REST-first control, BLE fallback, removable REST boundary, v1 controls, battery/media via REST, BLE caveat, and hardware test gate are covered.
- Advanced features documented in the spec as v1 exclusions are not included in implementation tasks: clip browser, media formatting, preset management, slate editing, livestream setup, full monitoring controls, full color correction.
- Type consistency: `CameraControlClient`, `CameraState`, `CameraStateStore`, `RestCameraControlClient`, and `BleCameraControlClient` names are consistent across tasks.
- REST removal path preserves `CameraControlClient`, preview, UI, and command methods.
