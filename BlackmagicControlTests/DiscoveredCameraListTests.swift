import XCTest
@testable import BlackmagicControl

final class DiscoveredCameraListTests: XCTestCase {
    func testUpdatingRSSIPreservesDiscoveryOrder() {
        let firstID = UUID()
        let secondID = UUID()
        let cameras = [
            DiscoveredCamera(id: firstID, name: "Camera A", rssi: -70),
            DiscoveredCamera(id: secondID, name: "Camera B", rssi: -50)
        ]

        let updated = DiscoveredCameraList.updating(
            cameras,
            with: DiscoveredCamera(id: firstID, name: "Camera A", rssi: -35)
        )

        XCTAssertEqual(updated.map(\.id), [firstID, secondID])
        XCTAssertEqual(updated[0].rssi, -35)
    }

    func testNewCameraAppendsInDiscoveryOrder() {
        let first = DiscoveredCamera(id: UUID(), name: "Camera A", rssi: -40)
        let second = DiscoveredCamera(id: UUID(), name: "Camera B", rssi: -80)

        let updated = DiscoveredCameraList.updating([first], with: second)

        XCTAssertEqual(updated, [first, second])
    }
}
