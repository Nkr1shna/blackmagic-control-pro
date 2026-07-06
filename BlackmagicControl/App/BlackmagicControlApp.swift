import SwiftUI

@main
struct BlackmagicControlApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            MonitorView(store: container.store, previewModel: container.previewModel)
        }
    }
}
