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
