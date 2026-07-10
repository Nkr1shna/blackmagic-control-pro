import SwiftUI

/// Local (iPad-side) monitoring preferences.
struct LocalMonitorPrefs: Equatable, Codable {
    var frameGuideStyle: Int8 = 0
    var showThirds = false
    var showCrosshair = false
    var showCenterDot = false
    var safeAreaPercentage: Int = 0

    private static let defaultsKey = "LocalMonitorPrefs"

    static func load(from defaults: UserDefaults = .standard) -> LocalMonitorPrefs {
        guard let data = defaults.data(forKey: defaultsKey),
              let prefs = try? JSONDecoder().decode(LocalMonitorPrefs.self, from: data)
        else { return LocalMonitorPrefs() }
        return prefs
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}

struct BottomBarView: View {
    @ObservedObject var controller: CameraBleController
    @ObservedObject var previewModel: ExternalCameraPreviewModel
    @Binding var monitorPrefs: LocalMonitorPrefs
    @Binding var showFocusPanel: Bool

    private var state: CameraState { controller.camera }
    private var isReady: Bool { controller.phase.isConnected }

    var body: some View {
        HStack(spacing: 10) {
            // Monitoring tools: guides are drawn locally; zebra / focus
            // assist / false color are sent to the camera's own displays.
            HStack(spacing: 6) {
                HUDToolButton(
                    title: "Guides",
                    systemImage: "rectangle.dashed",
                    isActive: monitorPrefs.frameGuideStyle != 0
                ) {
                    cycleFrameGuides()
                }

                HUDToolButton(
                    title: "Grid",
                    systemImage: "grid",
                    isActive: monitorPrefs.showThirds
                ) {
                    monitorPrefs.showThirds.toggle()
                }

                HUDToolButton(
                    title: "Zebra",
                    systemImage: "line.diagonal",
                    isActive: state.exposureTools.tools.contains(.zebra),
                    isEnabled: isReady
                ) {
                    controller.toggleExposureTool(.zebra)
                }

                HUDToolButton(
                    title: "Focus",
                    systemImage: "circle.dashed",
                    isActive: state.exposureTools.tools.contains(.focusAssist),
                    isEnabled: isReady
                ) {
                    controller.toggleExposureTool(.focusAssist)
                }

                HUDToolButton(
                    title: "F. Color",
                    systemImage: "paintpalette",
                    isActive: state.exposureTools.tools.contains(.falseColor),
                    isEnabled: isReady
                ) {
                    controller.toggleExposureTool(.falseColor)
                }
            }

            Spacer(minLength: 6)

            playbackControls

            recordButton

            transportStatus

            localRecordButton

            Spacer(minLength: 6)

            lensControls
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(HUD.barBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(HUD.divider).frame(height: 0.5)
        }
    }

    private func cycleFrameGuides() {
        let styles = OverlayState.frameGuideStyles
        guard let index = styles.firstIndex(where: { $0.value == monitorPrefs.frameGuideStyle }) else {
            monitorPrefs.frameGuideStyle = 0
            return
        }
        monitorPrefs.frameGuideStyle = styles[(index + 1) % styles.count].value
    }

    private var playbackControls: some View {
        HStack(spacing: 2) {
            Button {
                controller.playbackClip(next: false)
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isReady ? HUD.value : HUD.dimValue)
                    .frame(width: 36, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isReady)
            .accessibilityLabel("Previous clip")

            Button {
                if state.transport?.mode == .play {
                    controller.stopPlayback()
                } else {
                    controller.startPlayback()
                }
            } label: {
                Image(systemName: state.transport?.mode == .play ? "stop.fill" : "play.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(isReady ? HUD.value : HUD.dimValue)
                    .frame(width: 36, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isReady)
            .accessibilityLabel(state.transport?.mode == .play ? "Stop playback" : "Play")

            Button {
                controller.playbackClip(next: true)
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isReady ? HUD.value : HUD.dimValue)
                    .frame(width: 36, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isReady)
            .accessibilityLabel("Next clip")
        }
    }

    private var recordButton: some View {
        Button {
            controller.setRecording(!state.isRecording)
        } label: {
            ZStack {
                Circle()
                    .stroke(recordRingColor, lineWidth: 2.5)
                    .frame(width: 54, height: 54)

                if state.isRecording {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(HUD.record)
                        .frame(width: 22, height: 22)
                } else {
                    Circle()
                        .fill(HUD.record)
                        .frame(width: 42, height: 42)
                }
            }
            .opacity(isReady ? 1 : 0.35)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isReady)
        .accessibilityLabel(state.isRecording ? "Stop recording" : "Start recording")
    }

    private var recordRingColor: Color {
        if controller.pendingRecordRequest != nil { return HUD.accent }
        return state.isRecording ? HUD.record : Color.white.opacity(0.85)
    }

    private var localRecordButton: some View {
        Button {
            if previewModel.isRecordingLocally {
                previewModel.stopLocalRecording()
            } else {
                Task {
                    await previewModel.startLocalRecording()
                }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: previewModel.isRecordingLocally
                      ? "stop.circle.fill"
                      : "arrow.down.circle")
                    .font(.system(size: 17, weight: .medium))

                if previewModel.isRecordingLocally, let start = previewModel.localRecordingStart {
                    TimelineView(.periodic(from: start, by: 1)) { context in
                        Text(Self.durationLabel(from: start, to: context.date))
                            .font(.system(size: 8, weight: .semibold).monospacedDigit())
                    }
                } else {
                    Text("IPAD")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.6)
                }
            }
            .foregroundStyle(previewModel.isRecordingLocally
                             ? HUD.record
                             : (previewModel.isActive ? HUD.value : HUD.dimValue))
            .frame(width: 56, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(previewModel.isRecordingLocally ? HUD.record.opacity(0.16) : HUD.tileHighlight)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!previewModel.isActive)
        .accessibilityLabel(previewModel.isRecordingLocally ? "Stop iPad recording" : "Record feed to iPad")
    }

    static func durationLabel(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var transportStatus: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(transportLabel)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(state.isRecording ? HUD.record : HUD.label)
                .tracking(1.2)

            if let medium = state.transport?.activeMediumLabel {
                Text(medium)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(HUD.label)
                    .tracking(1)
            }

            if let battery = state.battery?.percent {
                HStack(spacing: 3) {
                    Image(systemName: "battery.75percent")
                        .font(.system(size: 9))
                    Text("\(battery)%")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                }
                .foregroundStyle(battery < 20 ? HUD.record : HUD.label)
            }
        }
        .frame(width: 64, alignment: .leading)
    }

    private var transportLabel: String {
        switch state.transport?.mode {
        case .record: return "REC"
        case .play: return "PLAY"
        case .preview: return "STBY"
        case nil: return isReady ? "STBY" : "—"
        }
    }

    private var lensControls: some View {
        HStack(spacing: 6) {
            VStack(spacing: 2) {
                Text("FOCUS")
                    .font(HUD.labelFont(9))
                    .foregroundStyle(HUD.label)
                    .tracking(1)

                HStack(spacing: 4) {
                    Button {
                        controller.nudgeFocus(by: -0.02)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isReady ? HUD.value : HUD.dimValue)
                            .frame(width: 28, height: 30)
                            .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isReady)
                    .accessibilityLabel("Focus nearer")

                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            showFocusPanel.toggle()
                        }
                    } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(showFocusPanel ? HUD.accent : (isReady ? HUD.value : HUD.dimValue))
                            .frame(width: 34, height: 30)
                            .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isReady)
                    .accessibilityLabel("Focus controls")

                    Button {
                        controller.nudgeFocus(by: 0.02)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isReady ? HUD.value : HUD.dimValue)
                            .frame(width: 28, height: 30)
                            .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isReady)
                    .accessibilityLabel("Focus farther")
                }
            }

            Button {
                controller.triggerAutoFocus()
            } label: {
                Text("AF")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isReady ? HUD.value : HUD.dimValue)
                    .frame(width: 46, height: 46)
                    .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isReady)
            .accessibilityLabel("Auto focus")
        }
    }
}
