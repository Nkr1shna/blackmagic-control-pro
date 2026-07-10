# BMPCC 4K iPad Hardware Test Checklist

Date:
Camera firmware:
iPad model:
iPadOS version:
Cable or hub:

## UVC Preview

- App sees an external camera.
- Preview starts at launch when the camera is already connected.
- Plugging the camera in **after** launch starts the preview automatically.
- Preview remains stable for five minutes.
- Disconnecting the USB-C cable shows the "waiting for video" placeholder without crashing; replugging restores the feed.
- Backgrounding and foregrounding the app restores the feed.

## Pairing UX

- First launch (no saved camera) opens the pairing sheet automatically.
- Camera appears in the nearby-cameras list with a signal indicator.
- Tapping the camera prompts for the camera-displayed 6-digit PIN.
- After pairing, the connection chip in the top bar shows Connected (green).
- The camera's Bluetooth menu shows this iPad's name.
- Relaunching the app reconnects to the saved camera without the pairing sheet.
- Turning the camera on *after* opening the app connects automatically.
- Power-cycling the camera mid-session shows "Reconnecting…" and recovers.
- Forget Camera clears the saved camera and returns to the pairing flow.

## Live State (incoming notifications)

- Timecode in the top bar ticks and matches the camera.
- Timecode turns red while recording.
- Top-bar FPS / Shutter / Iris / WB / Tint / ISO populate after connecting.
- Changing a value on the camera body updates the app within ~1 s.
- Starting a recording on the camera body updates the record button and REC label.

## Control (outgoing commands)

- Record starts and stops from the app.
- ISO changes (preset chips in ISO panel).
- Shutter angle changes (presets and slider).
- White balance and tint change (presets, sliders, AWB).
- Iris slider moves the lens aperture; Auto Iris works.
- Focus slider, +/- nudges, and AF button drive the lens.
- Frame rate change applies (23.98 ↔ 25 etc.).
- Codec and quality change (BRAW quality, ProRes variants).
- Zebra / focus assist / false color toggles affect the camera LCD/HDMI.
- Monitor settings (guides, safe area, grids, zebra level, peaking) apply to camera outputs.
- Audio: input type, levels, phantom power.
- Color corrector: lift/gamma/gain/offset, contrast, saturation, hue; reset restores defaults.
- Setup: device name appears on camera, clock sync sets camera time, tally brightness changes.
- Playback: play/stop and previous/next clip work.
- Power Off Camera (Setup tab) shuts the camera down after confirmation.

## Record confirmation

- Hitting record with no media in the camera shows a warning toast within ~3 s and the button does NOT turn red.
- The record ring shows orange while waiting for the camera to confirm, then red once recording actually starts.
- Enabling/disabling the display LUT on the camera body reflects in Settings → Monitor (if the firmware broadcasts parameter 1.15).

## iPad Recording (local proxy)

- Settings → iPad shows the incoming feed resolution/frame rate.
- IPAD button in the bottom bar starts a local recording; elapsed time counts up.
- Stopping saves the file to Files → On My iPad → Blackmagic Control → Recordings.
- First local recording asks for microphone permission; the file has audio from the USB camera (or iPad mic as fallback).
- Choosing a folder on a connected USB drive (Settings → iPad) moves finished recordings there.
- Unplugging the camera during a local recording finalises the file without crashing.

## Monitor UX (local)

- GUIDES button cycles frame-guide ratios drawn over the iPad preview.
- GRID toggles thirds overlay.
- Tapping the video hides the HUD; tapping again restores it.
- While recording with the HUD hidden, the red REC/timecode pill stays visible.
- Errors appear as a toast and auto-dismiss.
- Screen never auto-locks while the app is open.

Notes:
