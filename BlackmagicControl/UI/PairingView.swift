import SwiftUI

/// Camera discovery and pairing sheet. Handles the whole Bluetooth UX:
/// radio state, scanning, connecting, PIN pairing guidance, and managing
/// the remembered camera.
struct PairingView: View {
    @ObservedObject var controller: CameraBleController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 12) {
                    switch controller.phase {
                    case .bluetoothOff:
                        messageCard(
                            icon: "antenna.radiowaves.left.and.right.slash",
                            title: "Bluetooth is Off",
                            message: "Turn on Bluetooth in the iPad's Control Center or Settings to connect to your camera."
                        )
                    case .bluetoothUnauthorized:
                        messageCard(
                            icon: "lock.shield",
                            title: "Bluetooth Access Denied",
                            message: "Allow Bluetooth for this app in Settings → Privacy & Security → Bluetooth."
                        )
                    case .connected, .pairing, .connecting:
                        connectedCard
                    case .idle, .scanning, .reconnecting:
                        if controller.hasSavedCamera {
                            savedCameraCard
                        }
                        discoveryList
                    }

                    pairingHelp
                }
                .padding(16)
            }
        }
        .background(Color(white: 0.04))
        .preferredColorScheme(.dark)
        .onAppear {
            if !controller.phase.isConnected {
                controller.startScan()
            }
        }
        .onDisappear {
            controller.stopScan()
        }
    }

    private var header: some View {
        HStack {
            Text("Camera Connection")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HUD.value)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(HUD.label)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(16)
    }

    // MARK: Connected / connecting card

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(controller.phase.isConnected ? HUD.ok : HUD.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.connectedName ?? "Blackmagic Camera")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HUD.value)

                    Text(controller.phase.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(controller.phase.isConnected ? HUD.ok : HUD.accent)
                }

                Spacer()

                if !controller.phase.isConnected {
                    ProgressView()
                        .tint(HUD.accent)
                }
            }

            if controller.phase == .pairing {
                Label {
                    Text("If the camera shows a 6-digit PIN, enter it in the pairing dialog on this iPad.")
                        .font(.system(size: 13))
                        .foregroundStyle(HUD.value)
                } icon: {
                    Image(systemName: "number.circle.fill")
                        .foregroundStyle(HUD.accent)
                }
            }

            if let model = controller.camera.modelName {
                HUDInfoRow(title: "Model", value: model)
            }
            if let version = controller.camera.protocolVersion {
                HUDInfoRow(title: "Protocol", value: version)
            }

            HStack(spacing: 10) {
                Button {
                    controller.disconnect()
                } label: {
                    Text("Disconnect")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HUD.value)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    controller.forgetCamera()
                } label: {
                    Text("Forget Camera")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HUD.record)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(HUD.record.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(HUD.panelBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Saved camera

    private var savedCameraCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SAVED CAMERA")
                .font(HUD.labelFont(10))
                .foregroundStyle(HUD.accent)
                .tracking(1.6)

            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(HUD.label)

                Text(controller.savedCameraName ?? "Blackmagic Camera")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HUD.value)

                Spacer()

                Button {
                    controller.connectToSavedCamera()
                } label: {
                    Text(controller.phase == .reconnecting ? "Waiting…" : "Connect")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(HUD.accent, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)

                Button {
                    controller.forgetCamera()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(HUD.record)
                        .frame(width: 34, height: 34)
                        .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Forget saved camera")
            }
        }
        .padding(16)
        .background(HUD.panelBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Discovery

    private var discoveryList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NEARBY CAMERAS")
                    .font(HUD.labelFont(10))
                    .foregroundStyle(HUD.accent)
                    .tracking(1.6)

                Spacer()

                ProgressView()
                    .tint(HUD.label)
                    .scaleEffect(0.8)
            }

            if controller.discoveredCameras.isEmpty {
                Text("Searching for cameras…")
                    .font(.system(size: 13))
                    .foregroundStyle(HUD.label)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(controller.discoveredCameras) { camera in
                    Button {
                        controller.connect(to: camera.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(HUD.label)

                            Text(camera.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(HUD.value)

                            Spacer()

                            signalBars(rssi: camera.rssi)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(HUD.label)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(HUD.panelBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func signalBars(rssi: Int) -> some View {
        let strength = max(0, min(3, (rssi + 90) / 15)) // -90 dBm → 0 bars, -45 → 3 bars
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index <= strength ? HUD.ok : Color.white.opacity(0.15))
                    .frame(width: 3, height: CGFloat(4 + index * 3))
            }
        }
        .accessibilityLabel("Signal strength")
    }

    // MARK: Help

    private var pairingHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW TO PAIR")
                .font(HUD.labelFont(10))
                .foregroundStyle(HUD.label)
                .tracking(1.6)

            helpStep(1, "On the camera, open Setup and turn Bluetooth on.")
            helpStep(2, "Select the camera above.")
            helpStep(3, "Enter the 6-digit PIN from the camera's screen when the iPad asks for it.")
            helpStep(4, "For the video feed, connect the camera's USB-C port to the iPad and set it as a webcam source.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HUD.panelBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    private func helpStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(HUD.accent, in: Circle())

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(HUD.value)
        }
    }

    private func messageCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(HUD.accent)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HUD.value)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(HUD.label)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(HUD.panelBackground, in: RoundedRectangle(cornerRadius: 12))
    }

}
