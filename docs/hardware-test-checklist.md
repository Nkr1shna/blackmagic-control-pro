# BMPCC 4K iPad Hardware Test Checklist

Date:
Camera firmware:
iPad model:
iPadOS version:
Cable or hub:

## UVC Preview

- App sees an external camera.
- Preview starts.
- Preview remains stable for five minutes.
- Disconnecting the USB-C cable shows a preview error without crashing.

## REST Over USB-C

- With UVC preview active, try candidate REST documentation URLs and record which one works.
- Candidate: `http://192.168.7.1/control/documentation.html`.
- Candidate: `http://192.168.6.1/control/documentation.html`.
- Candidate: `http://10.0.0.1/control/documentation.html`.
- Working candidate IP:
- REST reachability passes if at least one candidate loads `/control/documentation.html`.
- App shows REST as active transport.
- App can refresh camera state while preview is active.

## REST Commands

- Record starts.
- Record stops.
- ISO changes.
- Shutter changes.
- White balance changes.
- Tint changes.
- Timecode appears/updates.
- Auto white balance works.
- Focus changes when supported.
- Autofocus triggers when supported.
- Iris/aperture changes when supported.
- Battery/power status appears.
- Media remaining time appears.

## BLE Fallback

- Camera appears in BLE scan.
- Pairing prompts for the camera-displayed PIN.
- App shows BLE as active transport when REST is unavailable.
- Record starts through BLE.
- Record stops through BLE.
- ISO changes through BLE.
- Shutter changes through BLE.
- White balance changes through BLE.

## Decision

Keep REST primary:

Remove REST-over-USB-Ethernet from v1:

Notes:
