import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let diagnosticsHub: DiagnosticsHub
    let previewModel: ExternalCameraPreviewModel
    let cameraController: CameraBleController

    init() {
        diagnosticsHub = DiagnosticsHub()

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Unknown"
        AppLog.lifecycle.info("app launched version \(version)")

        previewModel = ExternalCameraPreviewModel()
        cameraController = CameraBleController()
    }
}
