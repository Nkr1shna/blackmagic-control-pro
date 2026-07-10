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

    func testFocusMarksRoundTrip() {
        let prefs = LocalMonitorPrefs(
            focusMarks: [FocusMark(position: 0.25), FocusMark(position: 0.8)]
        )

        prefs.save(to: defaults)

        XCTAssertEqual(LocalMonitorPrefs.load(from: defaults), prefs)
    }

    func testFocusMarkClampsPositionToUnitRange() {
        XCTAssertEqual(FocusMark(position: 1.7).position, 1)
        XCTAssertEqual(FocusMark(position: -0.4).position, 0)
    }

    // A payload written before focus marks existed must still decode, keeping
    // its other fields and defaulting the new list to empty rather than wiping
    // every preference.
    func testDecodesLegacyPayloadWithoutFocusMarks() throws {
        let legacy = """
        {"frameGuideStyle":3,"showThirds":true,"showCrosshair":false,"showCenterDot":true,"safeAreaPercentage":90}
        """
        defaults.set(Data(legacy.utf8), forKey: "LocalMonitorPrefs")

        let loaded = LocalMonitorPrefs.load(from: defaults)

        XCTAssertEqual(loaded.frameGuideStyle, 3)
        XCTAssertTrue(loaded.showThirds)
        XCTAssertEqual(loaded.safeAreaPercentage, 90)
        XCTAssertTrue(loaded.focusMarks.isEmpty)
    }
}
