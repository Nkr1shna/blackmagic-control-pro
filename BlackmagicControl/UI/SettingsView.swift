import MessageUI
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
    @State private var isPresentingMail = false
    @State private var mailAttachmentData: Data?
    @State private var mailAttachmentFileName = ""

    private let legalDisclaimer = "Blackmagic Control Pro is an independent app. It is not affiliated with, endorsed by, sponsored by, or supported by Blackmagic Design Pty Ltd. “Blackmagic” and “Blackmagic Design” are trademarks of Blackmagic Design Pty Ltd, referenced only to describe camera compatibility. This app stores recordings and settings only on this iPad and sends no data anywhere. Alpha software — expect bugs; use at your own risk."

    var body: some View {
        HUDSection(title: "App") {
            infoRow("Version", bundleValue(for: "CFBundleShortVersionString"))
            infoRow("Build", buildDescription)
            channelRow
        }

        HUDSection(title: "Support") {
            infoRow("Contact", "krishnanelloore@gmail.com")

            Text("Found a bug? Tap below — an email opens with the diagnostics attached. Just hit Send. (No Mail app? Use Share instead.)")
                .font(.system(size: 12))
                .foregroundStyle(HUD.label)

            HStack(spacing: 10) {
                Button(action: exportDiagnostics) {
                    Label("Send Diagnostics", systemImage: "paperplane")
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
                        Label("Share", systemImage: "square.and.arrow.up")
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
                "Blackmagic Pocket Cinema Camera 4K / 6K. Other models may work but are untested."
            )
        }
        .sheet(isPresented: $isPresentingMail) {
            if let mailAttachmentData {
                MailComposeView(
                    recipients: ["krishnanelloore@gmail.com"],
                    subject: mailSubject,
                    body: "Please describe what happened right before the problem:\n\n",
                    attachment: mailAttachmentData,
                    mimeType: "application/zip",
                    fileName: mailAttachmentFileName,
                    dismiss: { isPresentingMail = false }
                )
            }
        }
    }

    private var mailSubject: String {
        let version = bundleValue(for: "CFBundleShortVersionString")
        let build = bundleValue(for: "CFBundleVersion")
        return "Blackmagic Control Pro diagnostics — v\(version) (\(build))"
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
                let url = try diagnosticsHub.exportDiagnostics(snapshot: snapshot)
                diagnosticsURL = url

                if MFMailComposeViewController.canSendMail(),
                   let data = try? Data(contentsOf: url) {
                    mailAttachmentData = data
                    mailAttachmentFileName = url.lastPathComponent
                    isPresentingMail = true
                }
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

    @State private var offSpeedFps = 24.0

    private static let offSpeedRange =
        Double(CameraPresets.offSpeedFrameRateRange.lowerBound)...Double(CameraPresets.offSpeedFrameRateRange.upperBound)

    private var state: CameraState { controller.camera }

    private var selectedCodec: BasicCodec? { state.codec?.codec }

    /// BRAW quality selection mode, derived from the current variant the way
    /// the camera lays it out: Constant Bitrate (3:1…12:1) vs Constant
    /// Quality (Q0…Q5).
    private var brawIsConstantBitrate: Bool {
        guard let variant = state.codec?.variant else { return true }
        return CameraPresets.brawConstantBitrate.contains { $0.variant == variant }
    }

    private var availableResolutions: [(width: Int, height: Int, label: String)] {
        guard selectedCodec == .proRes else { return CameraPresets.resolutions }
        return CameraPresets.resolutions.filter {
            ($0.width, $0.height) == (4096, 2160)
                || ($0.width, $0.height) == (3840, 2160)
                || ($0.width, $0.height) == (1920, 1080)
        }
    }

    var body: some View {
        HUDSection(title: "Codec and Quality") {
            HStack(spacing: 6) {
                HUDOptionTile(
                    label: "Blackmagic RAW",
                    isSelected: selectedCodec == .blackmagicRaw
                ) {
                    controller.setCodec(.blackmagicRaw, variant: 3)
                }

                HUDOptionTile(label: "ProRes RAW", isEnabled: false) {}
                    .accessibilityHint("Not available over Bluetooth camera control")

                HUDOptionTile(
                    label: "ProRes",
                    isSelected: selectedCodec == .proRes
                ) {
                    controller.setCodec(.proRes, variant: 1)
                }
            }

            if selectedCodec == .proRes {
                HStack(spacing: 6) {
                    ForEach(CameraPresets.proResVariants, id: \.variant) { preset in
                        HUDOptionTile(
                            label: preset.label,
                            isSelected: state.codec?.variant == preset.variant
                        ) {
                            controller.setCodec(.proRes, variant: preset.variant)
                        }
                    }
                }
            } else {
                HStack(spacing: 6) {
                    HUDOptionTile(
                        label: "Constant Bitrate",
                        isSelected: brawIsConstantBitrate
                    ) {
                        controller.setCodec(.blackmagicRaw, variant: 3)
                    }

                    HUDOptionTile(
                        label: "Constant Quality",
                        isSelected: !brawIsConstantBitrate
                    ) {
                        controller.setCodec(.blackmagicRaw, variant: 0)
                    }
                }

                HStack(spacing: 6) {
                    let variants = brawIsConstantBitrate
                        ? CameraPresets.brawConstantBitrate
                        : CameraPresets.brawConstantQuality
                    ForEach(variants, id: \.variant) { preset in
                        HUDOptionTile(
                            label: preset.label,
                            isSelected: state.codec?.variant == preset.variant
                        ) {
                            controller.setCodec(.blackmagicRaw, variant: preset.variant)
                        }
                    }
                }
            }
        }

        HUDSection(title: "Resolution") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                spacing: 6
            ) {
                ForEach(availableResolutions, id: \.label) { preset in
                    HUDOptionTile(
                        label: preset.label,
                        sublabel: "\(preset.width) x \(preset.height)",
                        isSelected: state.recordingFormat.map {
                            ($0.width, $0.height) == (preset.width, preset.height)
                        } ?? false
                    ) {
                        controller.setResolution(width: preset.width, height: preset.height)
                    }
                }
            }
        }

        HUDSection(title: "Format") {
            HUDSegmentedRow(
                title: "Project Frame Rate",
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

            HUDSegmentedRow(
                title: "Sensor Area",
                options: [(false, "Full"), (true, "Windowed")],
                selection: state.recordingFormat.map { $0.flags.contains(.windowed) }
            ) { windowed in
                controller.setSensorAreaWindowed(windowed)
            }
        }

        HUDSection(title: "Off Speed Recording") {
            HStack(spacing: 8) {
                HUDPresetChip(
                    label: state.recordingFormat?.flags.contains(.sensorOffSpeed) == true ? "On" : "Off",
                    isSelected: state.recordingFormat?.flags.contains(.sensorOffSpeed) == true
                ) {
                    let enabled = state.recordingFormat?.flags.contains(.sensorOffSpeed) == true
                    controller.setOffSpeedRecording(!enabled)
                }
            }

            HUDSliderRow(
                title: "Frame Rate",
                value: $offSpeedFps,
                range: Self.offSpeedRange,
                step: 1,
                display: { "\(Int($0)) fps" }
            ) { value in
                controller.setOffSpeedFrameRate(fps: Int(value))
            }
        }

        HUDSection(title: "Timelapse") {
            HStack(spacing: 8) {
                HUDPresetChip(
                    label: "Timelapse",
                    isSelected: state.transport?.flags.contains(.timeLapse) == true
                ) {
                    let enabled = state.transport?.flags.contains(.timeLapse) == true
                    controller.setTimelapseRecording(!enabled)
                }

                Text("Interval is set on the camera.")
                    .font(.system(size: 12))
                    .foregroundStyle(HUD.label)
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
        .onAppear(perform: syncFromCamera)
        .onChange(of: state.recordingFormat?.sensorFrameRate) { _, newValue in
            if let newValue, newValue > 0 {
                offSpeedFps = Double(newValue)
            }
        }
    }

    private func syncFromCamera() {
        if let rate = state.recordingFormat?.sensorFrameRate, rate > 0 {
            offSpeedFps = Double(rate)
        } else if let rate = state.recordingFormat?.fileFrameRate, rate > 0 {
            offSpeedFps = Double(rate)
        }
        offSpeedFps = min(max(offSpeedFps, Self.offSpeedRange.lowerBound), Self.offSpeedRange.upperBound)
    }
}

// MARK: - Monitor

private struct MonitorSettings: View {
    @ObservedObject var controller: CameraBleController

    @State private var zebraLevel = 0.75
    @State private var focusAssistLevel = 0.5
    @State private var guideOpacity = 50.0
    @State private var safeArea = 0.0

    private var state: CameraState { controller.camera }

    /// A style is only "on" when the camera also draws frame guides (3.0).
    private var effectiveFrameGuideStyle: Int8 {
        if state.overlayEnables?.overlays.contains(.frameGuides) == false {
            return 0
        }
        return state.overlays.frameGuideStyle
    }

    var body: some View {
        HUDSection(title: "Frame Guides") {
            HUDSegmentedRow(
                title: "Frame Guides",
                options: OverlayState.frameGuideStyles.map { ($0.value, $0.label) },
                selection: effectiveFrameGuideStyle
            ) { style in
                controller.setFrameGuideStyle(style)
            }

            HUDSliderRow(
                title: "Guide Opacity",
                value: $guideOpacity,
                range: 0...100,
                step: 25,
                display: { "\(Int($0))%" }
            ) { value in
                var overlays = state.overlays
                overlays.frameGuideOpacity = Int8(clamping: Int(value))
                controller.setOverlays(overlays)
            }

            HUDSliderRow(
                title: "Safe Area",
                value: $safeArea,
                range: 0...100,
                step: 5,
                display: { $0 == 0 ? "Off" : "\(Int($0))%" }
            ) { value in
                controller.setSafeAreaPercentage(Int(value))
            }
        }

        HUDSection(title: "Grids") {
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

            HUDSliderRow(
                title: "Focus Assist Level",
                value: $focusAssistLevel,
                range: 0...1,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setPeakingLevel(value)
            }
        }

        HUDSection(title: "Display") {
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

                HUDPresetChip(
                    label: "Color Bars",
                    isSelected: (state.colorBarsSeconds ?? 0) > 0
                ) {
                    let active = (state.colorBarsSeconds ?? 0) > 0
                    controller.setColorBars(seconds: active ? 0 : 30)
                }
            }
        }
        .onAppear(perform: syncFromCamera)
        .onChange(of: state.overlays.safeAreaPercentage) { _, newValue in
            safeArea = Double(newValue)
        }
        .onChange(of: state.overlays.frameGuideOpacity) { _, newValue in
            guideOpacity = Double(newValue)
        }
        .onChange(of: state.zebraLevel) { _, newValue in
            if let newValue { zebraLevel = newValue }
        }
        .onChange(of: state.peakingLevel) { _, newValue in
            if let newValue { focusAssistLevel = newValue }
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
        if let value = state.peakingLevel { focusAssistLevel = value }
        guideOpacity = Double(state.overlays.frameGuideOpacity)
        safeArea = Double(state.overlays.safeAreaPercentage)
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
        .onChange(of: state.audio) { _, _ in
            syncFromCamera()
        }
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
        }

        HUDSection(title: "Record to iPad") {
            infoRow(
                "Destination",
                previewModel.externalDestinationName ?? "On My iPad → Blackmagic Control Pro → Recordings"
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
        .onChange(of: state.tallyFrontBrightness) { _, newValue in
            if let newValue { frontTally = newValue }
        }
        .onChange(of: state.tallyRearBrightness) { _, newValue in
            if let newValue { rearTally = newValue }
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
