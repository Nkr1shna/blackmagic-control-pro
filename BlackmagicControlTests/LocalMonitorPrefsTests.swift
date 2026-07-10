import XCTest
@testable import BlackmagicControl

final class LocalMonitorPrefsTests: XCTestCase {
    private let suiteName = "LocalMonitorPrefsTests.\(UUID().uuidString)"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() {
        let prefs = LocalMonitorPrefs(
            frameGuideStyle: 5,
            showThirds: true,
            showCrosshair: true,
            showCenterDot: true,
            safeAreaPercentage: 90
        )

        prefs.save(to: defaults)

        XCTAssertEqual(LocalMonitorPrefs.load(from: defaults), prefs)
    }

    func testLoadReturnsDefaultsWhenAbsent() {
        XCTAssertEqual(LocalMonitorPrefs.load(from: defaults), LocalMonitorPrefs())
    }
}
