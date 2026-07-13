import SwiftUI

// MARK: - Color corrector

struct ColorSettings: View {
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

