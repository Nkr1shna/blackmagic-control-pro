import SwiftUI

// MARK: - Setup

struct SetupSettings: View {
    @ObservedObject var controller: CameraBleController

    @State private var deviceName = UIDevice.current.name
    @State private var showPowerOffConfirmation = false

    private var state: CameraState { controller.camera }

    var body: some View {
        HUDSection(title: "Camera Info") {
            HUDInfoRow(title: "Model", value: state.modelName ?? "—")
            HUDInfoRow(title: "CCU Protocol", value: state.protocolVersion ?? "—")
            HUDInfoRow(title: "Status", value: statusDescription)
        }

        HUDSection(title: "Identity") {
            HStack(spacing: 8) {
                TextField("Device name shown on camera", text: $deviceName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(HUD.value)
                    .padding(10)
                    .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    controller.setCameraDisplayName(deviceName)
                } label: {
                    Text("Send")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HUD.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Text("Shown in the camera's Bluetooth setup menu.")
                .font(.system(size: 12))
                .foregroundStyle(HUD.label)
        }

        HUDSection(title: "Timecode & Clock") {
            HUDSegmentedRow(
                title: "Timecode Source",
                options: [(true, "Clip"), (false, "Timecode")],
                selection: state.timecodeSourceClip
            ) { clip in
                controller.setTimecodeSource(clip: clip)
            }

            Button {
                controller.syncCameraClock()
            } label: {
                Label("Sync Camera Clock to iPad", systemImage: "clock.arrow.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HUD.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }

        HUDSection(title: "Tally") {
            HUDCameraSlider(
                title: "Front Tally",
                value: state.tallyFrontBrightness,
                range: 0...1,
                defaultValue: 0.5,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setTallyBrightness(front: value, rear: nil)
            }

            HUDCameraSlider(
                title: "Rear Tally",
                value: state.tallyRearBrightness,
                range: 0...1,
                defaultValue: 0.5,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setTallyBrightness(front: nil, rear: value)
            }
        }

        HUDSection(title: "Reference") {
            HUDSegmentedRow(
                title: "Source",
                options: [(Int8(0), "Internal"), (Int8(1), "Program"), (Int8(2), "External")],
                selection: state.referenceSource
            ) { source in
                controller.setReferenceSource(Int(source))
            }
        }

        HUDSection(title: "Power") {
            Button {
                showPowerOffConfirmation = true
            } label: {
                Label("Power Off Camera", systemImage: "power")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HUD.record)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(HUD.record.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                "Power off the camera?",
                isPresented: $showPowerOffConfirmation,
                titleVisibility: .visible
            ) {
                Button("Power Off", role: .destructive) {
                    controller.powerOffCamera()
                }
            } message: {
                Text("You will need to power it back on with its physical switch or over Bluetooth.")
            }
        }
    }

    private var statusDescription: String {
        var parts: [String] = []
        if state.statusFlags.contains(.powerOn) { parts.append("Power") }
        if state.statusFlags.contains(.paired) { parts.append("Paired") }
        if state.statusFlags.contains(.cameraReady) { parts.append("Ready") }
        return parts.isEmpty ? controller.phase.label : parts.joined(separator: " · ")
    }

}
