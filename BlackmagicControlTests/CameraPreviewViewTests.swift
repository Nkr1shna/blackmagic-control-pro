import UIKit
import XCTest
@testable import BlackmagicControl

final class CameraPreviewViewTests: XCTestCase {
    func testPreviewRotationAnglesUseLandscapeCameraFeedAsDefault() {
        XCTAssertEqual(PreviewContainerView.previewRotationAngle(for: .landscapeRight), 0)
        XCTAssertEqual(PreviewContainerView.previewRotationAngle(for: .landscapeLeft), 180)
        XCTAssertEqual(PreviewContainerView.previewRotationAngle(for: .portrait), 0)
        XCTAssertEqual(PreviewContainerView.previewRotationAngle(for: .unknown), 0)
    }

    func testPreviewMirroringIsDisabledForExternalCameraFeed() {
        XCTAssertFalse(PreviewContainerView.isPreviewMirroringEnabled)
    }
}
