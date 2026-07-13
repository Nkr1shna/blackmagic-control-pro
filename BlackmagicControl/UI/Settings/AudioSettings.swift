import SwiftUI

// MARK: - Audio

struct AudioSettings: View {
    @ObservedObject var controller: CameraBleController

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

            HUDCameraSlider(
                title: "Mic Level",
                value: state.audio.micLevel,
                range: 0...1,
                defaultValue: 0.5,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setAudio { $0.micLevel = value }
            }

            HUDCameraSlider(
                title: "Channel 1",
                value: state.audio.inputLevelCh0,
                range: 0...1,
                defaultValue: 0.5,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setAudio { $0.inputLevelCh0 = value }
            }

            HUDCameraSlider(
                title: "Channel 2",
                value: state.audio.inputLevelCh1,
                range: 0...1,
                defaultValue: 0.5,
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
            HUDCameraSlider(
                title: "Headphones",
                value: state.audio.headphoneLevel,
                range: 0...1,
                defaultValue: 0.5,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setAudio { $0.headphoneLevel = value }
            }

            HUDCameraSlider(
                title: "Speaker",
                value: state.audio.speakerLevel,
                range: 0...1,
                defaultValue: 0.5,
                display: { "\(Int($0 * 100))%" }
            ) { value in
                controller.setAudio { $0.speakerLevel = value }
            }
        }
    }
}

