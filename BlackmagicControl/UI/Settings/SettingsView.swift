import SwiftUI

/// Camera settings sheet, organised like the on-camera menu: Record,
/// Monitor, Audio, Color, Setup and About tabs. Camera controls here send
/// CCU commands over Bluetooth and reflect the state reported by the camera.
struct SettingsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case record = "Record"
        case monitor = "Monitor"
        case audio = "Audio"
        case color = "Color"
        case setup = "Setup"
        case ipad = "iPad"
        case about = "About"

        var id: String { rawValue }
    }

    @ObservedObject var controller: CameraBleController
    @ObservedObject var previewModel: ExternalCameraPreviewModel
    @ObservedObject var diagnosticsHub: DiagnosticsHub
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .record

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("Section", selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 12) {
                    switch tab {
                    case .record: RecordSettings(controller: controller)
                    case .monitor: MonitorSettings(controller: controller)
                    case .audio: AudioSettings(controller: controller)
                    case .color: ColorSettings(controller: controller)
                    case .setup: SetupSettings(controller: controller)
                    case .ipad: IpadSettings(previewModel: previewModel)
                    case .about:
                        AboutSettings(
                            controller: controller,
                            previewModel: previewModel,
                            diagnosticsHub: diagnosticsHub
                        )
                    }
                }
                .padding(16)
            }
        }
        .background(Color(white: 0.04))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.connectedName ?? "Camera Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HUD.value)

                if let model = controller.camera.modelName {
                    Text(model)
                        .font(.system(size: 12))
                        .foregroundStyle(HUD.label)
                }
            }

            Spacer()

            if !controller.phase.isConnected {
                Text("NOT CONNECTED")
                    .font(HUD.labelFont(10))
                    .foregroundStyle(HUD.accent)
                    .tracking(1.2)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(HUD.label)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

