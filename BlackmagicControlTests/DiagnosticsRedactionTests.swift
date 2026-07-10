import XCTest
@testable import BlackmagicControl

final class DiagnosticsRedactionTests: XCTestCase {
    func testRedactionReplacesDeviceAndCameraNamesCaseInsensitively() {
        let text = "Studio iPad connected to URSA Mini. STUDIO IPAD is ready."

        let redacted = DiagnosticsExporter.redact(
            text,
            deviceName: "Studio iPad",
            cameraName: "ursa mini"
        )

        XCTAssertEqual(
            redacted,
            "[REDACTED] connected to [REDACTED]. [REDACTED] is ready."
        )
    }

    func testRedactionSkipsNamesShorterThanThreeCharacters() {
        let text = "Al connected to X."

        let redacted = DiagnosticsExporter.redact(
            text,
            deviceName: "Al",
            cameraName: "X"
        )

        XCTAssertEqual(redacted, text)
    }

    func testRedactionLeavesUnrelatedTextIntact() {
        let text = "Bluetooth denied while recording."

        let redacted = DiagnosticsExporter.redact(
            text,
            deviceName: "Test iPad",
            cameraName: "Pocket 6K"
        )

        XCTAssertEqual(redacted, text)
    }
}
