import SwiftUI

enum HUDParameter: String, Identifiable {
    case fps
    case shutter
    case iris
    case whiteBalance
    case iso

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fps: return "FPS"
        case .shutter: return "Shutter"
        case .iris: return "Iris"
        case .whiteBalance: return "WB"
        case .iso: return "ISO"
        }
    }
}

struct TopBarView: View {
    @ObservedObject var controller: CameraBleController
    @Binding var selectedParameter: HUDParameter?
    let onShowPairing: () -> Void
    let onShowSettings: () -> Void

    private var state: CameraState { controller.camera }
    private var isReady: Bool { controller.phase.isConnected }

    var body: some View {
        HStack(spacing: 4) {
            connectionChip

            Spacer(minLength: 8)

            tile(.fps, value: state.fpsLabel)
            divider
            tile(.shutter, value: state.shutterLabel)
            divider
            tile(.iris, value: state.irisLabel)

            Spacer(minLength: 10)

            timecodeView

            Spacer(minLength: 10)

            tile(.whiteBalance, value: state.whiteBalanceLabel)
            divider
            HUDParameterTile(
                label: "Tint",
                value: state.tintLabel,
                isSelected: false,
                isEnabled: isReady
            ) {
                toggle(.whiteBalance)
            }
            divider
            tile(.iso, value: state.isoLabel)

            Spacer(minLength: 8)

            Button(action: onShowSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(HUD.value)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Camera settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(HUD.barBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(HUD.divider).frame(height: 0.5)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(HUD.divider)
            .frame(width: 0.5, height: 32)
    }

    private func tile(_ parameter: HUDParameter, value: String) -> some View {
        HUDParameterTile(
            label: parameter.title,
            value: value,
            isSelected: selectedParameter == parameter,
            isEnabled: isReady
        ) {
            toggle(parameter)
        }
    }

    private func toggle(_ parameter: HUDParameter) {
        withAnimation(.easeOut(duration: 0.18)) {
            selectedParameter = selectedParameter == parameter ? nil : parameter
        }
    }

    /// Tapping the timecode toggles the camera between clip duration and
    /// timecode, mirroring a tap on the camera's own display.
    private var timecodeView: some View {
        Button {
            controller.setTimecodeSource(clip: !(state.timecodeSourceClip ?? false))
        } label: {
            VStack(spacing: 1) {
                Text(state.timecode ?? "00:00:00:00")
                    .font(.system(size: 27, weight: .medium).monospacedDigit())
                    .foregroundStyle(state.isRecording ? HUD.record : HUD.value)

                if !state.formatLabel.isEmpty {
                    Text(state.formatLabel)
                        .font(HUD.labelFont(10))
                        .foregroundStyle(HUD.label)
                        .tracking(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isReady)
        .accessibilityLabel("Timecode")
        .accessibilityHint("Switches between timecode and clip duration")
    }

    private var connectionChip: some View {
        Button(action: onShowPairing) {
            HStack(spacing: 7) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 0) {
                    Text(controller.connectedName ?? controller.savedCameraName ?? "Camera")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HUD.value)
                        .lineLimit(1)

                    Text(controller.phase.label.uppercased())
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(HUD.label)
                        .tracking(0.8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: 150, alignment: .leading)
            .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Camera connection")
        .accessibilityValue(controller.phase.label)
    }

    private var connectionColor: Color {
        switch controller.phase {
        case .connected: return HUD.ok
        case .connecting, .pairing, .scanning, .reconnecting: return HUD.accent
        case .idle, .bluetoothOff, .bluetoothUnauthorized: return .gray
        }
    }
}
