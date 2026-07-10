import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let previewModel = ExternalCameraPreviewModel()
    let cameraController = CameraBleController()
}
