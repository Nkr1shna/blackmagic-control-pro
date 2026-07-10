import SwiftUI

/// Slide-up editor shown above the bottom bar when a parameter tile is
/// selected in the top bar.
struct ParameterPanelView: View {
    let parameter: HUDParameter
    @ObservedObject var controller: CameraBleController
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title.uppercased())
                    .font(HUD.labelFont(12))
                    .foregroundStyle(HUD.accent)
                    .tracking(2)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(HUD.label)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close panel")
            }

            content
        }
        .padding(14)
        .background(HUD.barBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HUD.divider, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var title: String {
        switch parameter {
        case .fps: return "Frame Rate"
        case .shutter: return "Shutter Angle"
        case .iris: return "Iris"
        case .whiteBalance: return "White Balance"
        case .iso: return "ISO"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch parameter {
        case .fps: FpsPanel(controller: controller)
        case .shutter: ShutterPanel(controller: controller)
        case .iris: IrisPanel(controller: controller)
        case .whiteBalance: WhiteBalancePanel(controller: controller)
        case .iso: IsoPanel(controller: controller)
        }
    }
}

// MARK: - ISO

private struct IsoPanel: View {
    @ObservedObject var controller: CameraBleController

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(CameraPresets.isoValues, id: \.self) { iso in
                    HUDPresetChip(
                        label: "\(iso)",
                        isSelected: controller.camera.iso == iso
                    ) {
                        controller.setISO(iso)
                    }
                }
            }
        }
    }
}

// MARK: - Shutter

private struct ShutterPanel: View {
    @ObservedObject var controller: CameraBleController
    @State private var angle: Double = 180

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CameraPresets.shutterAngles, id: \.self) { preset in
                        HUDPresetChip(
                            label: CameraState.shutterAngleLabel(hundredths: Int32(preset * 100)),
                            isSelected: isCurrent(preset)
                        ) {
                            angle = preset
                            controller.setShutterAngle(degrees: preset)
                        }
                    }
                }
            }

            HUDSliderRow(
                title: "Angle",
                value: $angle,
                range: 5...360,
                display: { String(format: "%.1f°", $0) }
            ) { value in
                controller.setShutterAngle(degrees: value)
            }
        }
        .onAppear {
            if let hundredths = controller.camera.shutterAngleHundredths {
                angle = Double(hundredths) / 100
            }
        }
    }

    private func isCurrent(_ preset: Double) -> Bool {
        guard let hundredths = controller.camera.shutterAngleHundredths else { return false }
        return abs(Double(hundredths) / 100 - preset) < 0.05
    }
}

// MARK: - Iris

private struct IrisPanel: View {
    @ObservedObject var controller: CameraBleController
    @State private var normalised: Double = 0.5

    var body: some View {
        VStack(spacing: 12) {
            HUDSliderRow(
                title: "Aperture",
                value: $normalised,
                range: 0...1,
                display: { _ in controller.camera.irisLabel }
            ) { value in
                controller.setApertureNormalised(value)
            }

            HStack(spacing: 8) {
                HUDPresetChip(label: "Auto Iris", isSelected: false) {
                    controller.triggerAutoAperture()
                }

                if let mode = controller.camera.autoExposureMode, mode != .manual {
                    Text("AE: \(mode.label)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HUD.accent)
                }

                Spacer()
            }
        }
        .onAppear {
            if let value = controller.camera.apertureNormalised {
                normalised = value
            }
        }
        .onChange(of: controller.camera.apertureNormalised) { _, newValue in
            if let newValue { normalised = newValue }
        }
    }
}

// MARK: - White balance

private struct WhiteBalancePanel: View {
    @ObservedObject var controller: CameraBleController
    @State private var kelvin: Double = 5600
    @State private var tint: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(CameraPresets.whiteBalancePresets, id: \.kelvin) { preset in
                    Button {
                        kelvin = Double(preset.kelvin)
                        tint = Double(preset.tint)
                        controller.setWhiteBalance(kelvin: preset.kelvin, tint: preset.tint)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 15))
                            Text("\(preset.kelvin)K")
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        }
                        .foregroundStyle(controller.camera.whiteBalanceKelvin == preset.kelvin ? HUD.accent : HUD.value)
                        .frame(width: 58, height: 46)
                        .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.label)
                }

                Spacer()

                HUDPresetChip(label: "AWB", isSelected: false) {
                    controller.triggerAutoWhiteBalance()
                }
            }

            HUDSliderRow(
                title: "Temp",
                value: $kelvin,
                range: 2500...10000,
                display: { "\(Int($0 / 50) * 50)K" }
            ) { value in
                controller.setWhiteBalance(kelvin: Int(value / 50) * 50, tint: Int(tint))
            }

            HUDSliderRow(
                title: "Tint",
                value: $tint,
                range: -50...50,
                display: { "\(Int($0))" }
            ) { value in
                controller.setWhiteBalance(kelvin: Int(kelvin / 50) * 50, tint: Int(value))
            }
        }
        .onAppear(perform: syncFromCamera)
        .onChange(of: controller.camera.whiteBalanceKelvin) { _, _ in syncFromCamera() }
    }

    private func syncFromCamera() {
        if let value = controller.camera.whiteBalanceKelvin { kelvin = Double(value) }
        if let value = controller.camera.tint { tint = Double(value) }
    }
}

// MARK: - Frame rate

private struct FpsPanel: View {
    @ObservedObject var controller: CameraBleController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Array(CameraPresets.frameRates.enumerated()), id: \.offset) { _, preset in
                    HUDPresetChip(
                        label: preset.label,
                        isSelected: isCurrent(preset.fps, preset.mRate)
                    ) {
                        controller.setFrameRate(fps: preset.fps, mRate: preset.mRate)
                    }
                }
            }

            if controller.camera.recordingFormat == nil {
                Text("Waiting for the camera to report its current format…")
                    .font(.system(size: 12))
                    .foregroundStyle(HUD.label)
            }
        }
    }

    private func isCurrent(_ fps: Int, _ mRate: Bool) -> Bool {
        guard let format = controller.camera.recordingFormat else { return false }
        return format.fileFrameRate == fps && format.flags.contains(.fileMRate) == mRate
    }
}

// MARK: - Focus (opened from the bottom bar)

struct FocusPanelView: View {
    @ObservedObject var controller: CameraBleController
    @Binding var focusMarks: [FocusMark]
    let onClose: () -> Void

    @State private var focus: Double = 0.5

    private var alreadyMarked: Bool {
        focusMarks.contains { abs($0.position - focus) < 0.01 }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("FOCUS")
                    .font(HUD.labelFont(12))
                    .foregroundStyle(HUD.accent)
                    .tracking(2)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(HUD.label)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close focus panel")
            }

            HUDSliderRow(
                title: "Near ⟷ Far",
                value: $focus,
                range: 0...1
            ) { value in
                controller.setFocus(value)
            }

            focusMarksSection

            HStack(spacing: 8) {
                HUDPresetChip(label: "Auto Focus", isSelected: false) {
                    controller.triggerAutoFocus()
                }

                if controller.camera.opticalImageStabilisation != nil {
                    HUDPresetChip(
                        label: "OIS",
                        isSelected: controller.camera.opticalImageStabilisation == true
                    ) {
                        controller.setOpticalImageStabilisation(
                            !(controller.camera.opticalImageStabilisation ?? false)
                        )
                    }
                }

                Spacer()
            }
        }
        .padding(14)
        .background(HUD.barBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HUD.divider, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            if let value = controller.camera.focusNormalised {
                focus = value
            }
        }
    }

    // MARK: Focus marks

    private var focusMarksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MARKS")
                    .font(HUD.labelFont(9))
                    .foregroundStyle(HUD.label)
                    .tracking(1.4)

                Spacer()

                Button {
                    addMark()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: alreadyMarked ? "checkmark" : "plus.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(alreadyMarked ? "Marked" : "Add Mark")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(alreadyMarked ? HUD.label : HUD.accent)
                }
                .buttonStyle(.plain)
                .disabled(alreadyMarked)
                .accessibilityLabel("Add focus mark at current position")
            }

            FocusMarksBar(
                marks: sortedMarks,
                current: focus,
                onRecall: recall,
                onDelete: deleteMark
            )
            .frame(height: 46)

            if focusMarks.isEmpty {
                Text("Tag a focus position with Add Mark, then tap a pin to snap the lens back to it.")
                    .font(.system(size: 10))
                    .foregroundStyle(HUD.dimValue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sortedMarks: [FocusMark] {
        focusMarks.sorted { $0.position < $1.position }
    }

    private func addMark() {
        guard !alreadyMarked else { return }
        focusMarks.append(FocusMark(position: focus))
    }

    private func recall(_ mark: FocusMark) {
        withAnimation(.easeInOut(duration: 0.2)) {
            focus = mark.position
        }
        controller.setFocus(mark.position)
    }

    private func deleteMark(_ mark: FocusMark) {
        focusMarks.removeAll { $0.id == mark.id }
    }
}

/// A thin track that shows the live focus position and every tagged mark as a
/// tappable pin, so the operator can snap the lens between rehearsed distances.
private struct FocusMarksBar: View {
    let marks: [FocusMark]
    let current: Double
    let onRecall: (FocusMark) -> Void
    let onDelete: (FocusMark) -> Void

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let trackY = geo.size.height - 8

            ZStack {
                Capsule()
                    .fill(HUD.tileHighlight)
                    .frame(width: width, height: 4)
                    .position(x: width / 2, y: trackY)

                Capsule()
                    .fill(HUD.accent.opacity(0.55))
                    .frame(width: max(2, current * width), height: 4)
                    .position(x: (current * width) / 2, y: trackY)

                Circle()
                    .fill(HUD.value)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(HUD.barBackground, lineWidth: 2))
                    .position(x: current * width, y: trackY)

                ForEach(marks) { mark in
                    pin(for: mark)
                        .position(x: mark.position * width, y: trackY - 18)
                }
            }
        }
    }

    private func pin(for mark: FocusMark) -> some View {
        Button {
            onRecall(mark)
        } label: {
            VStack(spacing: 0) {
                Text("\(Int((mark.position * 100).rounded()))")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(HUD.accent)
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(HUD.accent)
            }
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(mark)
            } label: {
                Label("Remove Mark", systemImage: "trash")
            }
        }
        .accessibilityLabel("Recall focus mark at \(Int((mark.position * 100).rounded())) percent")
    }
}
