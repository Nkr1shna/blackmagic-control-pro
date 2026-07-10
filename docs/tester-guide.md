# Blackmagic Control Pro - Alpha Tester Guide

This guide is for first-time testers. You do not need to know anything about software development.

> Blackmagic Control Pro is an early alpha build and an unofficial hobby project. It is not made by or affiliated with Blackmagic Design.

## What you need

- An iPad with a passcode and iPadOS 17 or newer
- A Mac with an internet connection
- A USB data cable that connects the Mac to the iPad
- An Apple Account (Apple ID) with two-factor authentication
- The Blackmagic Control Pro file provided by the developer; its name ends in `.ipa`
- About 10 minutes

You only install **iLoader on the Mac**. Nothing extra needs to be installed on the iPad, and AirDrop is not used.

## 1. Install iLoader on the Mac

1. On the **Mac**, open the SideStore prerequisites and download page:
   **https://docs.sidestore.io/docs/installation/prerequisites**
2. On that page, choose the **macOS** instructions and download **iLoader** for macOS. The DMG installer is the simplest choice.
3. Open the downloaded DMG file.
4. Drag **iLoader** into the **Applications** folder if the installer asks you to.
5. Open **Applications**, then open **iLoader**.

If the Mac blocks iLoader, open **System Settings > Privacy & Security**, scroll down, choose **Open Anyway**, and confirm only if the blocked app is named iLoader.

## 2. Connect the iPad and sign in to iLoader

1. Connect the iPad to the Mac with the USB cable.
2. Unlock the iPad and keep its screen awake.
3. If the iPad asks **Trust This Computer?**, tap **Trust** and enter the iPad passcode.
4. Open **iLoader** on the Mac.
5. Sign in with an Apple Account. The email address is case-sensitive.
6. Complete the Apple two-factor authentication prompt if one appears.
7. In iLoader, select the iPad entry marked **USB**.

A spare Apple Account is fine.

### Apple Account and privacy note

- iLoader uses Apple's sign-in system to send the password and verification code securely to Apple.
- iLoader also contacts an **anisette service** to create a temporary Mac identity needed for Apple developer signing. An extra Mac may appear in the Apple Account device list. This is expected.
- The Blackmagic Control Pro IPA is transferred from the Mac to the connected iPad.
- iLoader does not contact only Apple. If this setup is uncomfortable, use a spare Apple Account rather than a primary one.

## 3. Install Blackmagic Control Pro with iLoader

Do not use AirDrop. Keep the `.ipa` file on the Mac and install it directly with iLoader.

1. On the Mac, find the Blackmagic Control Pro file ending in `.ipa`.
2. In iLoader, confirm that the correct iPad is selected and marked **USB**.
3. Under **Installers**, click **Import IPA**.
4. Select the Blackmagic Control Pro `.ipa` file and click **Open**.
5. Keep the iPad unlocked and the cable connected until iLoader reports success.
6. Find **Blackmagic Control Pro** on the iPad Home Screen. Complete section 4 before opening it.

## 4. Trust the developer and turn on Developer Mode

Apple requires both settings before an alpha app can open.

### Trust the developer

1. On the iPad, open **Settings**.
2. Tap **General > VPN & Device Management**.
3. Under **Developer App**, tap the entry showing the Apple Account used in iLoader.
4. Tap **Trust [Apple Account]**, then **Trust** again.
5. On newer iPadOS versions, the button may say **Allow & Restart**. Tap it, enter the passcode, and let the iPad restart.

### Turn on Developer Mode

1. Open **Settings > Privacy & Security**.
2. Scroll to the bottom and tap **Developer Mode**.
3. Turn it on and confirm the restart.
4. After the iPad restarts, unlock it, tap **Turn On**, and enter the passcode.

If Developer Mode is not visible, confirm that iLoader finished installing Blackmagic Control Pro, restart the iPad, and check again.

## 5. Open the app

1. On the iPad Home Screen, tap **Blackmagic Control Pro**.
2. Allow Bluetooth access when asked. The app needs Bluetooth to control the camera.
3. Connect the camera and begin testing.

## The 7-day alpha limit

With a free Apple Account, this alpha app works for seven days after installation. **It is intended to stop opening when the seven days end.** This is not an app failure, and there is no automatic refresh step.

If the developer asks you to continue testing, install the provided `.ipa` again with iLoader. Do not delete the existing app first; installing over it preserves its settings.

This process is only for alpha testing. After Blackmagic Control Pro is released on the App Store, install it normally from the App Store. iLoader, the USB setup, developer trust, and Developer Mode will not be needed.

## Installing an updated alpha build

1. Save the new `.ipa` file on the Mac.
2. Connect and unlock the iPad.
3. Open iLoader and sign in if needed.
4. Select the iPad marked **USB**, then click **Import IPA**.
5. Choose the new file and wait for success.
6. Do not delete the old app before installing the update.

## If something goes wrong

### The iPad does not appear in iLoader

- Unlock the iPad and keep its screen awake.
- Unplug and reconnect the USB cable.
- Tap **Trust** on the iPad and enter its passcode.
- In iLoader, click **Refresh Devices**.
- Try a different USB port or a cable that supports data, not charging only.

### Blackmagic Control Pro will not open

- Repeat **Settings > General > VPN & Device Management > Developer App > Trust**.
- Confirm **Settings > Privacy & Security > Developer Mode** is on.
- If seven days have passed, the alpha has expired as intended. Reinstall only if the developer sends or requests another test build.

## Quick setup check

Before asking for help, confirm all of these:

- iLoader is installed on the Mac.
- Blackmagic Control Pro appears on the iPad Home Screen.
- The Apple Account is trusted under **VPN & Device Management**.
- **Developer Mode** is on.
- The iPad stayed unlocked and connected until iLoader reported success.
- The alpha was installed less than seven days ago.

## Send a problem report

1. Open **Blackmagic Control Pro**.
2. Open **Settings > About**.
3. Tap **Send Diagnostics** — an email opens with everything attached and addressed. Add one sentence describing what happened and tap the send arrow.
4. If no email window opens (no account in Apple Mail), tap **Share** instead and send the file to **krishnanelloore@gmail.com** with any app.

The diagnostic file contains app logs and technical details. It does not contain recordings or photos, and the device name is removed automatically.

## Camera connection reminders

- Turn on Bluetooth on the Blackmagic camera and keep the camera awake. The first connection may take more than one attempt.
- If the live preview is black, unplug and reconnect the camera's USB cable.

Thank you for testing Blackmagic Control Pro.
