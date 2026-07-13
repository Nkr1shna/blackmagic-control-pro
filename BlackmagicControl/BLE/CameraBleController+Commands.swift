import Foundation
import UIKit

extension CameraBleController {
    // MARK: - Commands

    /// Record state is NOT applied optimistically: the button reflects only
    /// what the camera confirms via its transport-mode notification. If no
    /// confirmation arrives (no media, full card, …) a warning is surfaced.
    func setRecording(_ recording: Bool) {
        guard send({ try CcuCommand.record(recording) }) else { return }
        pendingRecordRequest = recording

        recordConfirmationTask?.cancel()
        recordConfirmationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            guard self.pendingRecordRequest == recording else { return }

            self.pendingRecordRequest = nil
            if self.camera.isRecording != recording {
                self.reportError(recording
                    ? "The camera did not start recording. Check its media and storage."
                    : "The camera did not confirm the recording stopped.")
            }
        }
    }

    func setISO(_ iso: Int) {
        sendApplying({ try CcuCommand.iso(Int32(clamping: iso)) }) { $0.iso = iso }
    }

    func setGain(decibels: Int) {
        sendApplying({ try CcuCommand.gain(decibels: Int8(clamping: decibels)) }) {
            $0.gainDb = decibels
        }
    }

    func setShutterAngle(degrees: Double) {
        let hundredths = Int32((degrees * 100).rounded())
        sendApplying({ try CcuCommand.shutterAngle(hundredths: hundredths) }) {
            $0.shutterAngleHundredths = hundredths
            $0.shutterSpeedFraction = nil
        }
    }

    func setShutterSpeed(fraction: Int) {
        sendApplying({ try CcuCommand.shutterSpeed(fraction: Int32(clamping: fraction)) }) {
            $0.shutterSpeedFraction = Int32(clamping: fraction)
            $0.shutterAngleHundredths = nil
        }
    }

    func setWhiteBalance(kelvin: Int, tint: Int) {
        sendApplying({
            try CcuCommand.whiteBalance(
                kelvin: Int16(clamping: kelvin),
                tint: Int16(clamping: tint)
            )
        }) {
            $0.whiteBalanceKelvin = kelvin
            $0.tint = tint
        }
    }

    func triggerAutoWhiteBalance() {
        send { try CcuCommand.autoWhiteBalance() }
    }

    func restoreAutoWhiteBalance() {
        send { try CcuCommand.restoreAutoWhiteBalance() }
    }

    func setFocus(_ normalised: Double) {
        sendApplying({ try CcuCommand.focus(normalised) }) { $0.focusNormalised = normalised }
    }

    func nudgeFocus(by delta: Double) {
        send { try CcuCommand.focusOffset(delta) }
    }

    func triggerAutoFocus() {
        send { try CcuCommand.instantaneousAutoFocus() }
    }

    func setApertureNormalised(_ normalised: Double) {
        sendApplying({ try CcuCommand.apertureNormalised(normalised) }) {
            $0.apertureNormalised = normalised
        }
    }

    func triggerAutoAperture() {
        send { try CcuCommand.instantaneousAutoAperture() }
    }

    func setOpticalImageStabilisation(_ enabled: Bool) {
        sendApplying({ try CcuCommand.opticalImageStabilisation(enabled) }) {
            $0.opticalImageStabilisation = enabled
        }
    }

    func setFrameRate(fps: Int, mRate: Bool) {
        guard var format = camera.recordingFormat else {
            reportError("Waiting for the camera to report its recording format.")
            return
        }
        format.fileFrameRate = fps
        format.sensorFrameRate = 0 // 0 = leave sensor rate unchanged
        if mRate {
            format.flags.insert(.fileMRate)
        } else {
            format.flags.remove(.fileMRate)
        }
        let sensorFrameRate = camera.recordingFormat?.sensorFrameRate ?? 0
        sendApplying({ try CcuCommand.recordingFormat(format) }) {
            format.sensorFrameRate = sensorFrameRate
            $0.recordingFormat = format
        }
    }

    func setResolution(width: Int, height: Int) {
        guard var format = camera.recordingFormat else {
            reportError("Waiting for the camera to report its recording format.")
            return
        }
        format.width = width
        format.height = height
        if width < 3800 {
            format.flags.insert(.windowed)
        } else {
            format.flags.remove(.windowed)
        }
        sendApplying({ try CcuCommand.recordingFormat(format) }) { $0.recordingFormat = format }
    }

    func setSensorAreaWindowed(_ windowed: Bool) {
        guard var format = camera.recordingFormat else {
            reportError("Waiting for the camera to report its recording format.")
            return
        }
        if windowed {
            format.flags.insert(.windowed)
        } else {
            format.flags.remove(.windowed)
        }
        sendApplying({ try CcuCommand.recordingFormat(format) }) { $0.recordingFormat = format }
    }

    func setOffSpeedRecording(_ enabled: Bool) {
        guard var format = camera.recordingFormat else {
            reportError("Waiting for the camera to report its recording format.")
            return
        }
        if enabled {
            format.flags.insert(.sensorOffSpeed)
            if format.sensorFrameRate <= 0 {
                format.sensorFrameRate = format.fileFrameRate
            }
        } else {
            format.flags.remove(.sensorOffSpeed)
        }
        sendApplying({ try CcuCommand.recordingFormat(format) }) { $0.recordingFormat = format }
    }

    func setOffSpeedFrameRate(fps: Int) {
        guard var format = camera.recordingFormat else {
            reportError("Waiting for the camera to report its recording format.")
            return
        }
        format.sensorFrameRate = fps
        format.flags.remove(.sensorMRate)
        sendApplying({ try CcuCommand.recordingFormat(format) }) { $0.recordingFormat = format }
    }

    func setCodec(_ codec: BasicCodec, variant: UInt8) {
        let info = CodecInfo(codec: codec, variant: variant)
        sendApplying({ try CcuCommand.codec(info) }) { $0.codec = info }
    }

    func setTimelapseRecording(_ enabled: Bool) {
        guard var transport = camera.transport else {
            reportError("Waiting for the camera to report its transport state.")
            return
        }
        if enabled {
            transport.flags.insert(.timeLapse)
        } else {
            transport.flags.remove(.timeLapse)
        }
        sendApplying({
            try CcuCommand.transportMode(
                transport.mode,
                speed: transport.speed,
                flags: transport.flags,
                slot1: transport.slot1Medium,
                slot2: transport.slot2Medium
            )
        }) {
            $0.transport = transport
        }
    }

    func setDynamicRange(_ mode: DynamicRangeMode) {
        sendApplying({ try CcuCommand.dynamicRange(mode) }) { $0.dynamicRange = mode }
    }

    func setSharpening(_ level: SharpeningLevel) {
        sendApplying({ try CcuCommand.sharpening(level) }) { $0.sharpening = level }
    }

    func setAutoExposureMode(_ mode: AutoExposureMode) {
        sendApplying({ try CcuCommand.autoExposureMode(mode) }) { $0.autoExposureMode = mode }
    }

    /// Deliberately not applied optimistically: the row highlights only what
    /// the camera echoes back, so an ignored command is visible to the user.
    func setDisplayLut(selected: Int, enabled: Bool) {
        send { try CcuCommand.displayLut(selected: Int8(clamping: selected), enabled: enabled) }
    }

    func setOverlays(_ overlays: OverlayState) {
        sendApplying({ try CcuCommand.overlays(overlays) }) { $0.overlays = overlays }
    }

    /// Selecting a frame guide style also enables frame guide drawing on the
    /// camera outputs (3.0), because the style alone (3.3) never turns
    /// guides on. Style 0 turns them off both ways.
    func setFrameGuideStyle(_ style: Int8) {
        var overlays = camera.overlays
        overlays.frameGuideStyle = style
        setOverlays(overlays)

        var enables = camera.overlayEnables ?? OverlayEnables()
        if style > 0 {
            enables.overlays.insert(.frameGuides)
        } else {
            enables.overlays.remove(.frameGuides)
        }
        enables.displays.formUnion([.lcd, .hdmi])
        setOverlayEnables(enables)
    }

    func setSafeAreaPercentage(_ percentage: Int) {
        var overlays = camera.overlays
        overlays.safeAreaPercentage = Int8(clamping: percentage)
        setOverlays(overlays)
    }

    func setOverlayEnables(_ enables: OverlayEnables) {
        sendApplying({ try CcuCommand.overlayEnables(enables) }) { $0.overlayEnables = enables }
    }

    func setExposureTools(_ tools: ExposureToolsState) {
        sendApplying({ try CcuCommand.exposureTools(tools) }) { $0.exposureTools = tools }
    }

    func toggleExposureTool(_ tool: ExposureToolsState.Tools) {
        var state = camera.exposureTools
        if state.tools.contains(tool) {
            state.tools.remove(tool)
        } else {
            state.tools.insert(tool)
        }
        if state.displays.isEmpty {
            state.displays = [.lcd, .hdmi]
        }
        setExposureTools(state)
    }

    func setZebraLevel(_ level: Double) {
        sendApplying({ try CcuCommand.zebraLevel(level) }) { $0.zebraLevel = level }
    }

    func setPeakingLevel(_ level: Double) {
        sendApplying({ try CcuCommand.peakingLevel(level) }) { $0.peakingLevel = level }
    }

    func setFocusAssist(_ style: FocusAssistStyle) {
        sendApplying({ try CcuCommand.focusAssist(style) }) { $0.focusAssist = style }
    }

    func setColorBars(seconds: Int) {
        let duration = Int8(clamping: seconds)
        sendApplying({ try CcuCommand.colorBars(seconds: duration) }) { $0.colorBarsSeconds = duration }
    }

    func setAudio(_ update: (inout AudioState) -> Void) {
        let current = camera.audio
        var audio = current
        var applied = current
        update(&audio)

        if audio.micLevel != current.micLevel, let value = audio.micLevel,
           send({ try CcuCommand.micLevel(value) }) {
            applied.micLevel = value
        }
        if audio.headphoneLevel != current.headphoneLevel, let value = audio.headphoneLevel,
           send({ try CcuCommand.headphoneLevel(value) }) {
            applied.headphoneLevel = value
        }
        if audio.headphoneProgramMix != current.headphoneProgramMix, let value = audio.headphoneProgramMix,
           send({ try CcuCommand.headphoneProgramMix(value) }) {
            applied.headphoneProgramMix = value
        }
        if audio.speakerLevel != current.speakerLevel, let value = audio.speakerLevel,
           send({ try CcuCommand.speakerLevel(value) }) {
            applied.speakerLevel = value
        }
        if audio.inputType != current.inputType, let value = audio.inputType,
           send({ try CcuCommand.audioInputType(value) }) {
            applied.inputType = value
        }
        if audio.inputLevelCh0 != current.inputLevelCh0 || audio.inputLevelCh1 != current.inputLevelCh1 {
            if send({
                try CcuCommand.audioInputLevels(
                    ch0: audio.inputLevelCh0 ?? 0,
                    ch1: audio.inputLevelCh1 ?? 0
                )
            }) {
                applied.inputLevelCh0 = audio.inputLevelCh0
                applied.inputLevelCh1 = audio.inputLevelCh1
            }
        }
        if audio.phantomPower != current.phantomPower, let value = audio.phantomPower,
           send({ try CcuCommand.phantomPower(value) }) {
            applied.phantomPower = value
        }

        if applied != current {
            camera.audio = applied
        }
    }

    func setTallyBrightness(front: Double?, rear: Double?) {
        if let front {
            sendApplying({ try CcuCommand.tallyFrontBrightness(front) }) {
                $0.tallyFrontBrightness = front
            }
        }
        if let rear {
            sendApplying({ try CcuCommand.tallyRearBrightness(rear) }) {
                $0.tallyRearBrightness = rear
            }
        }
    }

    func setColorCorrection(_ update: (inout ColorCorrectionState) -> Void) {
        let current = camera.colorCorrection
        var color = current
        var applied = current
        update(&color)

        if color.lift != current.lift, send({ try CcuCommand.colorLift(color.lift) }) {
            applied.lift = color.lift
        }
        if color.gamma != current.gamma, send({ try CcuCommand.colorGamma(color.gamma) }) {
            applied.gamma = color.gamma
        }
        if color.gain != current.gain, send({ try CcuCommand.colorGain(color.gain) }) {
            applied.gain = color.gain
        }
        if color.offset != current.offset, send({ try CcuCommand.colorOffset(color.offset) }) {
            applied.offset = color.offset
        }
        if color.contrastPivot != current.contrastPivot || color.contrastAdjust != current.contrastAdjust,
           send({ try CcuCommand.contrast(pivot: color.contrastPivot, adjust: color.contrastAdjust) }) {
            applied.contrastPivot = color.contrastPivot
            applied.contrastAdjust = color.contrastAdjust
        }
        if color.lumaMix != current.lumaMix, send({ try CcuCommand.lumaMix(color.lumaMix) }) {
            applied.lumaMix = color.lumaMix
        }
        if color.hue != current.hue || color.saturation != current.saturation,
           send({ try CcuCommand.colorAdjust(hue: color.hue, saturation: color.saturation) }) {
            applied.hue = color.hue
            applied.saturation = color.saturation
        }

        if applied != current {
            camera.colorCorrection = applied
        }
    }

    func resetColorCorrection() {
        sendApplying({ try CcuCommand.colorCorrectionReset() }) {
            $0.colorCorrection = ColorCorrectionState()
        }
    }

    func setTimecodeSource(clip: Bool) {
        sendApplying({ try CcuCommand.timecodeSource(clip: clip) }) { $0.timecodeSourceClip = clip }
    }

    func setReferenceSource(_ source: Int) {
        let value = Int8(clamping: source)
        sendApplying({ try CcuCommand.referenceSource(value) }) { $0.referenceSource = value }
    }

    func syncCameraClock() {
        send { try CcuCommand.realTimeClock(date: Date()) }
        send { try CcuCommand.timezone(minutesFromUTC: Int32(TimeZone.current.secondsFromGMT() / 60)) }
    }

    func playbackClip(next: Bool) {
        send { try CcuCommand.playbackClip(next: next) }
    }

    func startPlayback() {
        send { try CcuCommand.transportMode(.play, speed: 1) }
    }

    func stopPlayback() {
        send { try CcuCommand.transportMode(.preview) }
    }

    func powerOffCamera() {
        do {
            try write(Data([0x00]), to: BlackmagicBleConstants.cameraStatus)
        } catch {
            reportError(friendlyMessage(for: error))
        }
    }

    func setCameraDisplayName(_ name: String) {
        let trimmed = String(name.prefix(32))
        guard let data = trimmed.data(using: .utf8) else { return }
        do {
            try write(data, to: BlackmagicBleConstants.deviceName)
        } catch {
            AppLog.ble.warning("Couldn't send iPad name to the camera: \(friendlyMessage(for: error))")
        }
    }
}
