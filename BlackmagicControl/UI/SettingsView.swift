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

// MARK: - About

private struct AboutSettings: View {
    @ObservedObject var controller: CameraBleController
    @ObservedObject var previewModel: ExternalCameraPreviewModel
    @ObservedObject var diagnosticsHub: DiagnosticsHub

    @State private var isExporting = false
    @State private var diagnosticsURL: URL?
    @State private var exportError: String?

    private let legalDisclaimer = "Blackmagic Control Pro is an independent app. It is not affiliated with, endorsed by, sponsored by, or supported by Blackmagic Design Pty Ltd. “Blackmagic” and “Blackmagic Design” are trademarks of Blackmagic Design Pty Ltd, referenced only to describe camera compatibility. This app stores recordings and settings only on this iPad and sends no data anywhere. Alpha software — expect bugs; use at your own risk."

    var body: some View {
        HUDSection(title: "App") {
            infoRow("Version", bundleValue(for: "CFBundleShortVersionString"))
            infoRow("Build", buildDescription)
            channelRow
        }

        HUDSection(title: "Support") {
            infoRow("Contact", "krishnanelloore@gmail.com")

            Text("Found a bug? Export diagnostics and email them — it takes one tap.")
                .font(.system(size: 12))
                .foregroundStyle(HUD.label)

            HStack(spacing: 10) {
                Button(action: exportDiagnostics) {
                    Label("Export Diagnostics", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HUD.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isExporting)

                if isExporting {
                    ProgressView()
                        .tint(HUD.accent)
                }

                if let diagnosticsURL {
                    ShareLink(item: diagnosticsURL) {
                        Label("Share", systemImage: "paperplane")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HUD.value)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let exportError {
                Text(exportError)
                    .font(.system(size: 11))
                    .foregroundStyle(HUD.record)
            }
        }

        HUDSection(title: "Legal") {
            Text(legalDisclaimer)
                .font(.system(size: 11))
                .foregroundStyle(HUD.label)
                .fixedSize(horizontal: false, vertical: true)
        }

        HUDSection(title: "Compatibility") {
            infoRow(
                "Camera",
                "Designed for Blackmagic Pocket Cinema Camera 4K/6K over Bluetooth + USB monitor feed. Other models may work but are untested."
            )
        }
    }

    private var buildDescription: String {
        let build = bundleValue(for: "CFBundleVersion")
        guard let sha = Bundle.main.object(forInfoDictionaryKey: "KNBuildSHA") as? String,
              !sha.isEmpty else {
            return build
        }
        return "\(build) (\(sha))"
    }

    private func bundleValue(for key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "—"
    }

    private func exportDiagnostics() {
        isExporting = true
        diagnosticsURL = nil
        exportError = nil

        Task { @MainActor in
            await Task.yield()

            let snapshot = DiagnosticsSnapshot(
                blePhase: controller.phase.label,
                recentErrors: controller.errorHistory.map {
                    "\($0.date.formatted(.iso8601)) \($0.message)"
                },
                cameraModel: controller.camera.modelName,
                ccuProtocolVersion: controller.camera.protocolVersion,
                feedFormat: previewModel.feedDescription
            )

            do {
                diagnosticsURL = try diagnosticsHub.exportDiagnostics(snapshot: snapshot)
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(HUD.labelFont())
                .foregroundStyle(HUD.label)
                .tracking(1)

            Spacer(minLength: 16)

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HUD.value)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var channelRow: some View {
        HStack {
            Text("CHANNEL")
                .font(HUD.labelFont())
                .foregroundStyle(HUD.label)
                .tracking(1)

            Spacer()

            Text("Alpha")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(HUD.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

// MARK: - Record

private struct RecordSettings: View {
    @ObservedObject var controller: CameraBleController

    private var state: CameraState { controller.camera }

    var body: some View {
        HUDSection(title: "Codec") {
            HUDSegmentedRow(
                title: "Codec",
                options: [(BasicCodec.blackmagicRaw, "BRAW"), (BasicCodec.proRes, "ProRes")],
                selection: state.codec?.codec
            ) { codec in
                let defaultVariant: UInt8 = codec == .blackmagicRaw ? 3 : 1
                controller.setCodec(codec, variant: defaultVariant)
            }

            if state.codec?.codec == .proRes {
                HUDSegmentedRow(
                    title: "Quality",
                    options: CameraPresets.proResVariants.map { ($0.variant, $0.label) },
                    selection: state.codec?.variant
                ) { variant in
                    controller.setCodec(.proRes, variant: variant)
                }
            } else {
                HUDSegmentedRow(
                    title: "Quality",
                    options: CameraPresets.brawVariants.map { ($0.variant, $0.label) },
                    selection: state.codec?.variant
                ) { variant in
                    controller.setCodec(.blackmagicRaw, variant: variant)
                }
            }
        }

        HUDSection(title: "Format") {
            HUDSegmentedRow(
                title: "Resolution",
                options: CameraPresets.resolutions.map { preset in
                    ("\(preset.width)x\(preset.height)", preset.label)
                },
                selection: state.recordingFormat.map { "\($0.width)x\($0.height)" }
            ) { key in
                let parts = key.split(separator: "x").compactMap { Int($0) }
                if parts.count == 2 {
                    controller.setResolution(width: parts[0], height: parts[1])
                }
            }

            HUDSegmentedRow(
                title: "Frame Rate",
                options: CameraPresets.frameRates.map { ("\($0.fps)-\($0.mRate)", $0.label) },
                selection: state.recordingFormat.map {
                    "\($0.fileFrameRate)-\($0.flags.contains(.fileMRate))"
                }
            ) { key in
                let parts = key.split(separator: "-")
                if parts.count == 2, let fps = Int(parts[0]) {
                    controller.setFrameRate(fps: fps, mRate: parts[1] == "true")
                }
            }
        }

        HUDSection(title: "Image") {
            HUDSegmentedRow(
                title: "Dynamic Range",
                options: DynamicRangeMode.allCases.map { ($0, $0.label) },
                selection: state.dynamicRange
            ) { mode in
                controller.setDynamicRange(mode)
            }

            HUDSegmentedRow(
                title: "Sharpening",
                options: SharpeningLevel.allCases.map { ($0, $0.label) },
                selection: state.sharpening
            ) { level in
                controller.setSharpening(level)
            }

            HUDSegmentedRow(
                title: "Auto Exposure",
                options: AutoExposureMode.allCases.map { ($0, $0.label) },
                selection: state.autoExposureMode
            ) { mode in
                controller.setAutoExposureMode(mode)
            }
        }
    }
}

// MARK: - Monitor

private struct MonitorSettings: View {
    @ObservedObject var controller: CameraBleController

    @State private var zebraLevel = 0.75
    @State private var peakingLevel = 0.5
    @State private var brightness = 0.5
    @State private var guideOpacity = 50.0

    private var state: CameraState { controller.camera }

    var body: some View {
        HUDSection(title: "Camera Display Overlays") {
            Text("These affect the camera's LCD and HDMI outputs. Guides on the iPad preview are toggled from the bottom bar.")
                .font(.system(size: 12))
                .foregroundStyle(HUD.label)

            HUDSegmentedRow(
                title: "Frame Guides",
                options: OverlayState.frameGuideStyles.map { ($0.value, $0.label) },
                selection: state.overlays.frameGuideStyle
            ) { style in
                var overlays = state.overlays
                overlays.frameGuideStyle = style
                controller.setOverlays(overlays)
            }

            HUDSliderRow(
                title: "Guide Opacity",
                value: $guideOpacity,
                range: 0...100,
                display: { "\(Int($0))%" }
            ) { value in
                var overlays = state.overlays
                overlays.frameGuideOpacity = Int8(clamping: Int(value))
                controller.setOverlays(overlays)
            }

            HUDSegmentedRow(
                title: "Safe Area",
                options: [(Int8(0), "Off"), (Int8(80), "80%"), (Int8(90), "90%"), (Int8(95), "95%")],
                selection: state.overlays.safeAreaPercentage
            ) { percentage in
                var overlays = state.overlays
                overlays.safeAreaPercentage = percentage
                controller.setOverlays(overlays)
            }

            gridToggles
        }

        HUDSection(title: "Exposure & Focus Tools") {
            HStack(spacing: 8) {
                HUDPresetChip(label: "Zebra", isSelected: state.exposureTools.tools.contains(.zebra)) {
                    controller.toggleExposureTool(.zebra)
                }
                HUDPresetChip(label: "Focus Assist", isSelected: state.exposureTools.tools.contains(.focusAssist)) {
                    controller.toggleExposureTool(.focusAssist)
                }
                HUDPresetChip(label: "False Color", isSelected: state.exposureTools.tools.contains(.falseColor)) {
                    controller.toggleExposureTool(.falseColor)
                }
            }

            HUDSliderRow(
                title: "Zebra Level",
                value: $zebraLevel,
                range: 0...1,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setZebraLevel(value)
            }

            HUDSliderRow(
                title: "Peaking",
                value: $peakingLevel,
                range: 0...1,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setPeakingLevel(value)
            }

            HUDSegmentedRow(
                title: "Focus Assist",
                options: [(Int8(0), "Peak"), (Int8(1), "Colored Lines")],
                selection: state.focusAssist.method
            ) { method in
                controller.setFocusAssist(FocusAssistStyle(method: method, lineColor: state.focusAssist.lineColor))
            }

            HUDSegmentedRow(
                title: "Line Color",
                options: [(Int8(0), "Red"), (Int8(1), "Green"), (Int8(2), "Blue"), (Int8(3), "White"), (Int8(4), "Black")],
                selection: state.focusAssist.lineColor
            ) { color in
                controller.setFocusAssist(FocusAssistStyle(method: state.focusAssist.method, lineColor: color))
            }
        }

        HUDSection(title: "Display") {
            HUDSliderRow(
                title: "Brightness",
                value: $brightness,
                range: 0...1,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setDisplayBrightness(value)
            }

            HUDSegmentedRow(
                title: "Display LUT",
                options: [(0, "None"), (1, "Custom"), (2, "Film to Video"), (3, "Film to Ext. Video")],
                selection: state.displayLut?.selectedLut
            ) { lut in
                controller.setDisplayLut(selected: lut, enabled: lut != 0)
            }

            HStack(spacing: 8) {
                HUDPresetChip(
                    label: "LUT Enabled",
                    isSelected: state.displayLut?.isEnabled == true
                ) {
                    let current = state.displayLut ?? DisplayLutState(selectedLut: 0, isEnabled: false)
                    controller.setDisplayLut(selected: current.selectedLut, enabled: !current.isEnabled)
                }

                Text(state.displayLut.map { "Camera reports: \($0.label)\($0.isEnabled ? " (on)" : " (off)")" }
                     ?? "The camera has not reported a LUT state.")
                    .font(.system(size: 12))
                    .foregroundStyle(HUD.label)
            }

            HStack(spacing: 8) {
                HUDPresetChip(
                    label: "Color Bars",
                    isSelected: (state.colorBarsSeconds ?? 0) > 0
                ) {
                    let active = (state.colorBarsSeconds ?? 0) > 0
                    controller.setColorBars(seconds: active ? 0 : 30)
                }

                Text("Shows bars on camera outputs for 30 s")
                    .font(.system(size: 12))
                    .foregroundStyle(HUD.label)
            }
        }
        .onAppear(perform: syncFromCamera)
    }

    private var gridToggles: some View {
        HStack(spacing: 8) {
            HUDPresetChip(label: "Thirds", isSelected: state.overlays.gridFlags.contains(.thirds)) {
                toggleGrid(.thirds)
            }
            HUDPresetChip(label: "Crosshair", isSelected: state.overlays.gridFlags.contains(.crosshairs)) {
                toggleGrid(.crosshairs)
            }
            HUDPresetChip(label: "Center Dot", isSelected: state.overlays.gridFlags.contains(.centerDot)) {
                toggleGrid(.centerDot)
            }
            HUDPresetChip(label: "Horizon", isSelected: state.overlays.gridFlags.contains(.horizon)) {
                toggleGrid(.horizon)
            }
        }
    }

    private func toggleGrid(_ flag: OverlayState.GridFlags) {
        var overlays = state.overlays
        if overlays.gridFlags.contains(flag) {
            overlays.gridFlags.remove(flag)
        } else {
            overlays.gridFlags.insert(flag)
        }
        controller.setOverlays(overlays)
    }

    private func syncFromCamera() {
        if let value = state.zebraLevel { zebraLevel = value }
        if let value = state.peakingLevel { peakingLevel = value }
        if let value = state.displayBrightness { brightness = value }
        guideOpacity = Double(state.overlays.frameGuideOpacity)
    }
}

// MARK: - Audio

private struct AudioSettings: View {
    @ObservedObject var controller: CameraBleController

    @State private var micLevel = 0.5
    @State private var ch0Level = 0.5
    @State private var ch1Level = 0.5
    @State private var headphoneLevel = 0.5
    @State private var speakerLevel = 0.5

    private var state: CameraState { controller.camera }

    var body: some View {
        HUDSection(title: "Input") {
            HUDSegmentedRow(
                title: "Input Type",
                options: AudioState.inputTypes.map { ($0.value, $0.label) },
                selection: state.audio.inputType
            ) { type in
                controller.setAudio { $0.inputType = type }
            }

            HUDSliderRow(
                title: "Mic Level",
                value: $micLevel,
                range: 0...1,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setAudio { $0.micLevel = value }
            }

            HUDSliderRow(
                title: "Channel 1",
                value: $ch0Level,
                range: 0...1,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setAudio { $0.inputLevelCh0 = value }
            }

            HUDSliderRow(
                title: "Channel 2",
                value: $ch1Level,
                range: 0...1,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setAudio { $0.inputLevelCh1 = value }
            }

            HStack(spacing: 8) {
                HUDPresetChip(
                    label: "Phantom Power",
                    isSelected: state.audio.phantomPower == true
                ) {
                    controller.setAudio { $0.phantomPower = !(state.audio.phantomPower ?? false) }
                }

                Text("48V for external XLR microphones")
                    .font(.system(size: 12))
                    .foregroundStyle(HUD.label)
            }
        }

        HUDSection(title: "Output") {
            HUDSliderRow(
                title: "Headphones",
                value: $headphoneLevel,
                range: 0...1,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setAudio { $0.headphoneLevel = value }
            }

            HUDSliderRow(
                title: "Speaker",
                value: $speakerLevel,
                range: 0...1,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setAudio { $0.speakerLevel = value }
            }
        }
        .onAppear(perform: syncFromCamera)
    }

    private func syncFromCamera() {
        if let value = state.audio.micLevel { micLevel = value }
        if let value = state.audio.inputLevelCh0 { ch0Level = value }
        if let value = state.audio.inputLevelCh1 { ch1Level = value }
        if let value = state.audio.headphoneLevel { headphoneLevel = value }
        if let value = state.audio.speakerLevel { speakerLevel = value }
    }
}

// MARK: - Color corrector

private struct ColorSettings: View {
    @ObservedObject var controller: CameraBleController

    private var color: ColorCorrectionState { controller.camera.colorCorrection }

    var body: some View {
        HUDSection(title: "Color Corrector") {
            wheelEditor(title: "Lift", wheel: color.lift, range: -2...2) { wheel in
                controller.setColorCorrection { $0.lift = wheel }
            }
            wheelEditor(title: "Gamma", wheel: color.gamma, range: -4...4) { wheel in
                controller.setColorCorrection { $0.gamma = wheel }
            }
            wheelEditor(title: "Gain", wheel: color.gain, range: 0...16) { wheel in
                controller.setColorCorrection { $0.gain = wheel }
            }
            wheelEditor(title: "Offset", wheel: color.offset, range: -8...8) { wheel in
                controller.setColorCorrection { $0.offset = wheel }
            }
        }

        HUDSection(title: "Adjustments") {
            ColorScalarSlider(title: "Contrast", value: color.contrastAdjust, range: 0...2) { value in
                controller.setColorCorrection { $0.contrastAdjust = value }
            }
            ColorScalarSlider(title: "Pivot", value: color.contrastPivot, range: 0...1) { value in
                controller.setColorCorrection { $0.contrastPivot = value }
            }
            ColorScalarSlider(title: "Saturation", value: color.saturation, range: 0...2) { value in
                controller.setColorCorrection { $0.saturation = value }
            }
            ColorScalarSlider(title: "Hue", value: color.hue, range: -1...1) { value in
                controller.setColorCorrection { $0.hue = value }
            }
            ColorScalarSlider(title: "Luma Mix", value: color.lumaMix, range: 0...1) { value in
                controller.setColorCorrection { $0.lumaMix = value }
            }

            Button {
                controller.resetColorCorrection()
            } label: {
                Text("Reset to Defaults")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HUD.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    private func wheelEditor(
        title: String,
        wheel: ColorWheel,
        range: ClosedRange<Double>,
        onChange: @escaping (ColorWheel) -> Void
    ) -> some View {
        DisclosureGroup {
            VStack(spacing: 8) {
                ColorScalarSlider(title: "Red", value: wheel.red, range: range) { value in
                    var updated = wheel; updated.red = value; onChange(updated)
                }
                ColorScalarSlider(title: "Green", value: wheel.green, range: range) { value in
                    var updated = wheel; updated.green = value; onChange(updated)
                }
                ColorScalarSlider(title: "Blue", value: wheel.blue, range: range) { value in
                    var updated = wheel; updated.blue = value; onChange(updated)
                }
                ColorScalarSlider(title: "Luma", value: wheel.luma, range: range) { value in
                    var updated = wheel; updated.luma = value; onChange(updated)
                }
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text(title.uppercased())
                    .font(HUD.labelFont())
                    .foregroundStyle(HUD.label)
                    .tracking(1)

                Spacer()

                Text(String(format: "%.2f / %.2f / %.2f / %.2f", wheel.red, wheel.green, wheel.blue, wheel.luma))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(HUD.dimValue)
            }
        }
        .tint(HUD.label)
    }
}

/// Slider that stays in sync with camera-reported values but doesn't fight
/// the user mid-drag.
private struct ColorScalarSlider: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let onCommit: (Double) -> Void

    @State private var localValue: Double = 0
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 12) {
            Text(title.uppercased())
                .font(HUD.labelFont(9))
                .foregroundStyle(HUD.label)
                .tracking(1)
                .frame(width: 76, alignment: .leading)

            Slider(value: $localValue, in: range) { editing in
                isDragging = editing
                if !editing {
                    onCommit(localValue)
                }
            }
            .tint(HUD.accent)

            Text(localValue.formatted(.number.precision(.fractionLength(2))))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(HUD.value)
                .frame(width: 48, alignment: .trailing)
        }
        .onAppear { localValue = value }
        .onChange(of: value) { _, newValue in
            if !isDragging {
                localValue = newValue
            }
        }
    }
}

// MARK: - iPad (local recording)

private struct IpadSettings: View {
    @ObservedObject var previewModel: ExternalCameraPreviewModel
    @State private var showFolderPicker = false

    var body: some View {
        HUDSection(title: "Video Feed") {
            infoRow("Incoming Feed", previewModel.feedDescription ?? "No feed")
            infoRow("Status", previewModel.status)

            Text("The USB feed is the camera's fixed monitor output. It does not change with the recording format — 4K BRAW is recorded on the camera's own media, while the iPad receives a monitor-quality stream.")
                .font(.system(size: 12))
                .foregroundStyle(HUD.label)
        }

        HUDSection(title: "Record to iPad") {
            Text("The IPAD button in the bottom bar records the incoming feed as a video file. Use it for proxies, references or client copies — not as a replacement for the camera's internal recording.")
                .font(.system(size: 12))
                .foregroundStyle(HUD.label)

            infoRow(
                "Destination",
                previewModel.externalDestinationName ?? "On My iPad → Blackmagic Control → Recordings"
            )

            HStack(spacing: 10) {
                Button {
                    showFolderPicker = true
                } label: {
                    Label("Choose Folder / Drive", systemImage: "folder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HUD.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if previewModel.externalDestinationName != nil {
                    Button {
                        previewModel.clearExternalDestination()
                    } label: {
                        Text("Reset")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HUD.value)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Pick a folder on a USB drive connected to the iPad to move finished recordings there automatically.")
                .font(.system(size: 12))
                .foregroundStyle(HUD.label)

            if let message = previewModel.localRecordingMessage {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HUD.accent)
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                previewModel.setExternalDestination(url)
            }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(HUD.labelFont())
                .foregroundStyle(HUD.label)
                .tracking(1)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HUD.value)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Setup

private struct SetupSettings: View {
    @ObservedObject var controller: CameraBleController

    @State private var deviceName = UIDevice.current.name
    @State private var frontTally = 0.5
    @State private var rearTally = 0.5
    @State private var showPowerOffConfirmation = false

    private var state: CameraState { controller.camera }

    var body: some View {
        HUDSection(title: "Camera Info") {
            infoRow("Model", state.modelName ?? "—")
            infoRow("CCU Protocol", state.protocolVersion ?? "—")
            infoRow("Status", statusDescription)
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
            HUDSliderRow(
                title: "Front Tally",
                value: $frontTally,
                range: 0...1,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setTallyBrightness(front: value, rear: nil)
            }

            HUDSliderRow(
                title: "Rear Tally",
                value: $rearTally,
                range: 0...1,
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
        .onAppear {
            if let value = state.tallyFrontBrightness { frontTally = value }
            if let value = state.tallyRearBrightness { rearTally = value }
        }
    }

    private var statusDescription: String {
        var parts: [String] = []
        if state.statusFlags.contains(.powerOn) { parts.append("Power") }
        if state.statusFlags.contains(.paired) { parts.append("Paired") }
        if state.statusFlags.contains(.cameraReady) { parts.append("Ready") }
        return parts.isEmpty ? controller.phase.label : parts.joined(separator: " · ")
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(HUD.labelFont())
                .foregroundStyle(HUD.label)
                .tracking(1)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HUD.value)
        }
    }
}
