import SwiftUI

// MARK: - Monitor

struct MonitorSettings: View {
    @ObservedObject var controller: CameraBleController

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

            HUDCameraSlider(
                title: "Guide Opacity",
                value: Double(state.overlays.frameGuideOpacity),
                range: 0...100,
                step: 25,
                display: { "\(Int($0))%" }
            ) { value in
                var overlays = state.overlays
                overlays.frameGuideOpacity = Int8(clamping: Int(value))
                controller.setOverlays(overlays)
            }

            HUDCameraSlider(
                title: "Safe Area",
                value: Double(state.overlays.safeAreaPercentage),
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

            HUDCameraSlider(
                title: "Zebra Level",
                value: state.zebraLevel,
                range: 0...1,
                defaultValue: 0.75,
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

            HUDCameraSlider(
                title: "Focus Assist Level",
                value: state.peakingLevel,
                range: 0...1,
                defaultValue: 0.5,
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
}

