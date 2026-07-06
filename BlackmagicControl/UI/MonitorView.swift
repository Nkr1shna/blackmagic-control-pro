import SwiftUI

struct MonitorView: View {
    @ObservedObject var store: CameraStateStore
    @ObservedObject var previewModel: ExternalCameraPreviewModel

    @State private var startupState = StartupState.notStarted

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            CameraPreviewView(session: previewModel.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                StatusStripView(store: store, previewModel: previewModel)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                Spacer(minLength: 0)

                ControlPanelView(store: store)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            guard startupState == .notStarted else {
                return
            }

            startupState = .starting

            async let previewStartup: Void = previewModel.start()
            async let controlStartup: Void = store.connect()

            await previewStartup
            await controlStartup

            startupState = Task.isCancelled ? .notStarted : .started
        }
    }
}

private enum StartupState {
    case notStarted
    case starting
    case started
}
