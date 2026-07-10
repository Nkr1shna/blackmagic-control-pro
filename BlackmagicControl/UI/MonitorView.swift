import SwiftUI

struct MonitorView: View {
    @ObservedObject var controller: CameraBleController
    @ObservedObject var previewModel: ExternalCameraPreviewModel
    @ObservedObject var diagnosticsHub: DiagnosticsHub

    @State private var selectedParameter: HUDParameter?
    @State private var showFocusPanel = false
    @State private var showPairing = false
    @State private var showSettings = false
    @State private var monitorPrefs = LocalMonitorPrefs.load()
    @State private var hudHidden = false
    @State private var startedPreview = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            CameraPreviewView(session: previewModel.session)
                .ignoresSafeArea()

            if !previewModel.isActive {
                noVideoPlaceholder
            }

            FrameGuideOverlay(
                guideRatio: guideRatio,
                safeAreaPercentage: monitorPrefs.safeAreaPercentage,
                showThirds: monitorPrefs.showThirds,
                showCrosshair: monitorPrefs.showCrosshair,
                showCenterDot: monitorPrefs.showCenterDot
            )
            .ignoresSafeArea()

            // Tap the video to hide/show the HUD (clean monitor mode).
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if selectedParameter != nil || showFocusPanel {
                            selectedParameter = nil
                            showFocusPanel = false
                        } else {
                            hudHidden.toggle()
                        }
                    }
                }

            if !hudHidden {
                VStack(spacing: 0) {
                    TopBarView(
                        controller: controller,
                        selectedParameter: $selectedParameter,
                        onShowPairing: { showPairing = true },
                        onShowSettings: { showSettings = true }
                    )

                    Spacer(minLength: 0)

                    if let parameter = selectedParameter {
                        ParameterPanelView(
                            parameter: parameter,
                            controller: controller
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                selectedParameter = nil
                            }
                        }
                        .padding(.bottom, 8)
                    } else if showFocusPanel {
                        FocusPanelView(controller: controller) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showFocusPanel = false
                            }
                        }
                        .padding(.bottom, 8)
                    }

                    BottomBarView(
                        controller: controller,
                        previewModel: previewModel,
                        monitorPrefs: $monitorPrefs,
                        showFocusPanel: $showFocusPanel
                    )
                }
            } else {
                // Minimal indicators stay visible in clean mode.
                VStack {
                    HStack {
                        Spacer()
                        if controller.camera.isRecording {
                            HStack(spacing: 6) {
                                Circle().fill(HUD.record).frame(width: 9, height: 9)
                                Text(controller.camera.timecode ?? "REC")
                                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(HUD.record)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                        }
                    }
                    .padding(12)
                    Spacer()
                }
            }

            // Error toast
            if let error = controller.lastError {
                VStack {
                    Spacer()
                    HUDToast(message: error) {
                        controller.lastError = nil
                    }
                    .padding(.bottom, hudHidden ? 24 : 86)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .animation(.easeOut(duration: 0.2), value: controller.lastError)
        .sheet(isPresented: $showPairing) {
            PairingView(controller: controller)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                controller: controller,
                previewModel: previewModel,
                diagnosticsHub: diagnosticsHub
            )
        }
        .task {
            guard !startedPreview else { return }
            startedPreview = true
            UIApplication.shared.isIdleTimerDisabled = true

            // First run with no camera configured: lead with pairing.
            if !controller.hasSavedCamera {
                showPairing = true
            }

            await previewModel.start()
        }
        .onChange(of: controller.phase) { _, newPhase in
            // Surface the pairing sheet automatically the first time the
            // app runs with no camera configured.
            if newPhase == .idle, !controller.hasSavedCamera, !showPairing {
                showPairing = true
            }
        }
        .onChange(of: controller.lastError) { _, newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(6))
                if controller.lastError == newValue {
                    controller.lastError = nil
                }
            }
        }
        .onChange(of: monitorPrefs) { _, newValue in
            newValue.save()
        }
    }

    private var guideRatio: Double? {
        OverlayState.frameGuideStyles
            .first { $0.value == monitorPrefs.frameGuideStyle }?
            .ratio
    }

    private var noVideoPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.slash")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(HUD.label)

            Text(previewModel.errorMessage ?? "No Video Feed")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HUD.value)

            Text("Connect the camera's USB-C port to this iPad and enable webcam output. The feed starts automatically.")
                .font(.system(size: 13))
                .foregroundStyle(HUD.label)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
    }
}
