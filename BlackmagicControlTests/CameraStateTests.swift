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
