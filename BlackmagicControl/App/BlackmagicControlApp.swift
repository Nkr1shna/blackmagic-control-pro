import SwiftUI

@main
struct BlackmagicControlApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            MonitorView(
                controller: container.cameraController,
                previewModel: container.previewModel,
                diagnosticsHub: container.diagnosticsHub
            )
        }
    }
}
