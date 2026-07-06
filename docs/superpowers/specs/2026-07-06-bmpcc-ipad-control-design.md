# BMPCC 4K iPad Control App Design

Date: 2026-07-06

## Goal

Build an iPadOS app for an M1 iPad Pro that displays the Blackmagic Pocket Cinema Camera 4K webcam feed over direct USB-C UVC and controls the camera using Blackmagic camera-control APIs.

The app must avoid a capture card. The first implementation should try REST control over the same USB-C connection if iPadOS exposes USB Ethernet and UVC together. If that does not work reliably, the REST path must be removable without refactoring the app UI or preview layer.

## Hardware And Firmware Assumptions

- Camera: Blackmagic Pocket Cinema Camera 4K.
- Firmware: Blackmagic Camera 9.8 beta or newer with UVC webcam and REST API support.
- iPad: M1 iPad Pro, Wi-Fi-only acceptable.
- Connection target: direct USB-C between iPad and camera.
- No HDMI capture card.

The REST API support on BMPCC 4K 9.8 is not well documented yet. The implementation will use the documented Blackmagic REST API as the likely contract and probe the connected camera at runtime.

## Product Direction

The UI should be Blackmagic-inspired: dark, dense, monitor-first, fast to operate, and familiar to Blackmagic camera users. It should not be an exact clone of Blackmagic's app, because that creates unnecessary App Store and IP risk.

The first screen is the camera monitor, not a landing page. Controls should be close to the preview and optimized for repeated use during shooting.

## Architecture

The app is split into three independent layers:

1. Preview
   - Owns AVFoundation external camera discovery and UVC preview.
   - Does not know whether control is REST or BLE.

2. Control
   - Exposes a single `CameraControlClient` interface.
   - Provides `RestCameraControlClient` and `BleCameraControlClient`.
   - Normalizes camera responses into shared camera state.

3. UI
   - Binds to normalized state and command methods only.
   - Does not import REST, BLE, USB Ethernet, or protocol-packet code directly.

## Removable REST Boundary

REST-over-network is isolated in these components:

- `RestCameraDiscovery`
- `RestCameraControlClient`
- `RestEventStream`
- REST DTO/request models

If UVC and USB Ethernet cannot run together on iPadOS, those components can be deleted and the app can bind `BleCameraControlClient` to the same `CameraControlClient` protocol. The preview layer and UI should not need structural changes.

## Preview Design

Use AVFoundation to discover external UVC cameras and show the BMPCC 4K webcam stream.

Responsibilities:

- Request camera permission.
- Discover external/UVC video devices.
- Prefer a device whose name/model matches Blackmagic when available.
- Start and stop preview session.
- Surface preview errors separately from control errors.

Non-goals:

- No recording the UVC feed inside the iPad app for v1.
- No HDMI capture support.
- No NDI or streaming ingest.

## Control Selection

At startup:

1. Start UVC preview if available.
2. Probe REST over likely local camera addresses and discovered network services.
3. If REST responds, use `RestCameraControlClient`.
4. If REST does not respond, offer BLE pairing and use `BleCameraControlClient`.

The app should show which control transport is active: REST, BLE, disconnected, or degraded.

## REST Control Scope

Use the documented Blackmagic REST API where the BMPCC 4K exposes it.

Initial REST features:

- Product/system info.
- Supported codec and video formats.
- Current codec/video format.
- Record start/stop.
- Transport state, clip index, and timecode.
- ISO and supported ISO values.
- Gain and supported gain values.
- White balance, tint, auto white balance, and descriptions/ranges.
- Shutter value, shutter measurement mode, supported shutters, and flicker-free shutters.
- Auto exposure mode.
- Iris, focus, autofocus, zoom, OIS, and lens capability descriptions.
- Camera power and battery status if exposed.
- Media working set, active media, remaining record time, remaining space, and device state if exposed.
- Monitoring controls where useful later: LUT, zebra, focus assist, frame guides, safe area, false color.
- Websocket event subscription for live state changes.

The implementation should first try to load camera-hosted documentation at `/control/documentation.html` when reachable. Runtime availability should drive feature enablement.

## BLE Control Scope

Use CoreBluetooth and the Blackmagic Camera Service.

BLE service and characteristic capabilities:

- Device Information Service:
  - Manufacturer.
  - Camera model.
- Blackmagic Camera Service:
  - Outgoing encrypted Camera Control messages.
  - Incoming encrypted Camera Control messages.
  - Timecode notifications.
  - Camera status flags.
  - Device name write.
  - Protocol version read.

BLE Camera Control message categories available through the public protocol:

- Lens: focus, autofocus, aperture, auto aperture, OIS, zoom.
- Video: video mode, gain, ISO, white balance, tint, auto WB, exposure, shutter angle/speed, dynamic range, sharpening, recording format, auto exposure, LUT, ND where supported.
- Audio: mic/headphone/speaker levels, input type, channel levels, phantom power.
- Output/monitoring: overlays, frame guides, clean feed, grids.
- Display tools: brightness, zebra, focus assist, false color, peaking, color bars, program return, timecode source.
- Tally: front/rear/overall tally brightness.
- Reference: source and offset.
- Configuration: real-time clock, language, timezone, location.
- Color correction: lift, gamma, gain, offset, contrast, luma mix, hue/saturation, reset.
- Media/transport: codec, preview/play/record transport mode, playback flags, slot media type, previous/next clip, stream toggles.
- PTZ: pan/tilt and presets, likely irrelevant for BMPCC 4K.

BLE caveat:

Battery percentage, voltage, remaining media space, and remaining record time are not clearly documented in the BLE/SDI command table. Those should be treated as REST-only unless physical testing proves the BMPCC 4K emits usable BLE messages for them.

## V1 User Features

V1 includes:

- Live BMPCC UVC preview.
- Camera connection status.
- Active control transport status.
- REST probe result.
- BLE pairing flow.
- Record start/stop.
- ISO.
- Shutter angle/speed.
- White balance.
- Tint.
- Auto white balance.
- Iris/aperture when supported.
- Focus and autofocus when supported.
- Timecode.
- Battery/power status when REST exposes it.
- Media status when REST exposes it.

V1 excludes:

- In-app recording of preview.
- Clip browser/download.
- Media formatting.
- Preset management.
- Slate editing.
- Livestream configuration.
- Full monitoring controls.
- Full color correction controls.

These excluded features remain documented as later iterations.

## Normalized State

The UI reads a shared state model:

- `connectionStatus`
- `controlTransport`
- `cameraModel`
- `firmwareOrProtocolVersion`
- `isRecording`
- `timecode`
- `iso`
- `supportedISOs`
- `shutter`
- `shutterMode`
- `whiteBalance`
- `tint`
- `iris`
- `focus`
- `canAutoFocus`
- `battery`
- `powerSource`
- `mediaSlots`
- `activeMedia`
- `remainingRecordTime`
- `errors`

Each field includes availability metadata so the UI can disable unsupported controls without branching on REST or BLE.

## Error Handling

Separate failures by subsystem:

- Preview unavailable.
- REST unavailable.
- BLE unavailable.
- Camera disconnected.
- Feature unsupported.
- Command rejected.
- Permission denied.

The app should stay usable in degraded modes. For example, preview can continue if control disconnects, and BLE control can continue if REST is unavailable.

## Hardware Test Gate

The first physical-device test answers this question:

Can iPadOS use the BMPCC 4K as both a UVC external camera and a USB Ethernet/network device at the same time over one USB-C cable?

If yes:

- Keep REST as primary control.
- Keep BLE as fallback.

If no:

- Delete REST-over-USB-Ethernet discovery/control from v1.
- Use BLE as primary control.
- Keep the `CameraControlClient` interface and normalized state unchanged.

## Testing Strategy

Unit tests:

- REST DTO decoding.
- BLE packet encoding for core commands.
- Normalized state mapping.
- Unsupported feature handling.

Integration tests where possible:

- REST client against recorded JSON fixtures.
- BLE command builder byte-level tests against protocol examples.

Manual device tests:

- UVC preview appears on iPad.
- REST endpoint responds while UVC preview is active.
- `/control/documentation.html` loads when reachable.
- Record command toggles camera state.
- ISO, shutter, WB, tint, focus, and iris commands work on the physical camera/lens.
- Battery and media status appear when REST exposes them.
- BLE pairing works and can control record/ISO/shutter/WB if REST is unavailable.

## Open Risks

- BMPCC 4K 9.8 REST support is beta and may not match the public REST documentation exactly.
- iPadOS may not expose UVC and USB Ethernet simultaneously from the same camera connection.
- Lens controls depend on the attached lens and camera support.
- BLE pairing UX depends on iPadOS CoreBluetooth bonding behavior.
- Exact Blackmagic app UI cloning is avoided to reduce legal and review risk.

## Implementation Readiness

This design is ready for an implementation plan after review. The first implementation should scaffold the app around protocols and state normalization before filling out every command.
