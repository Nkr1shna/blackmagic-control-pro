import SwiftUI

// MARK: - Record

struct RecordSettings: View {
    @ObservedObject var controller: CameraBleController

    private static let offSpeedRange =
        Double(CameraPresets.offSpeedFrameRateRange.lowerBound)...Double(CameraPresets.offSpeedFrameRateRange.upperBound)

    private var state: CameraState { controller.camera }

    private var selectedCodec: BasicCodec? { state.codec?.codec }

    private var offSpeedFrameRate: Double? {
        if let rate = state.recordingFormat?.sensorFrameRate, rate > 0 {
            return Double(rate)
        }
        if let rate = state.recordingFormat?.fileFrameRate, rate > 0 {
            return Double(rate)
        }
        return nil
    }

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

            HUDCameraSlider(
                title: "Frame Rate",
                value: offSpeedFrameRate,
                range: Self.offSpeedRange,
                step: 1,
                defaultValue: 24,
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
    }
}

