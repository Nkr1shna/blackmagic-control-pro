# Blackmagic Control Pro — Alpha Tester Guide

Thanks for trying the app! **This is an early alpha build.** Things will occasionally break, disconnect, or crash — that's expected, and your reports are what make it better.

> This is an unofficial hobby project. It is not made by or affiliated with Blackmagic Design.

## What it does

Blackmagic Control Pro turns your iPad into a monitor and remote control for a Blackmagic Pocket Cinema Camera: live preview over USB, and full camera control (record, ISO, shutter, white balance, and more) over Bluetooth.

## What you need

- An iPad running iPadOS 17 or newer
- A free Apple ID (your normal one works; a spare one is fine too)
- A Mac or Windows computer — **only once**, for setup
- The app file I sent you (ends in `.ipa`)

## Installing (one-time setup, ~15 minutes)

Apple doesn't allow installing apps outside the App Store directly, so we use a free tool called **SideStore**. You set it up once; after that, updates are easy.

1. On your computer, follow SideStore's official install guide: **https://docs.sidestore.io/docs/installation/install** — it walks you through everything, including enabling "Developer Mode" on the iPad and creating a "pairing file".
2. Once SideStore is on your iPad, open it and sign in with your Apple ID.
3. Copy the `.ipa` file I sent you onto the iPad (AirDrop is easiest — accept it and choose "Save to Files").
4. In SideStore, tap **+** (My Apps tab), pick the `.ipa` file, and wait for it to install.

That's it — Blackmagic Control Pro is now on your home screen.

### The 7-day rule (important!)

Apple limits free installs to 7 days at a time. SideStore renews this automatically in the background, but it needs your iPad to be on Wi-Fi now and then. **If the app ever refuses to open, just open SideStore and tap "Refresh"** — that fixes it in under a minute. Nothing is lost.

Also: a free Apple ID can only have 3 apps installed this way (SideStore itself counts as one).

## When something goes wrong

You don't need to write a detailed bug report. Just do this:

1. Open the app → **Settings** → **About** tab
2. Tap **Export Diagnostics**
3. Send the file to me: **krishnanelloore@gmail.com** (Mail, AirDrop, WhatsApp — whatever's easiest)

That file contains the app's logs and technical details about what happened. It does **not** contain your recordings, photos, or personal data, and your device name is removed automatically. A one-line note about what you were doing when it broke is a bonus.

## Updates

When there's a new version, I'll send you a new `.ipa`. Install it exactly like step 3–4 above — it replaces the old version and keeps your settings.

## Known rough edges

- Bluetooth pairing can take a couple of attempts the first time — make sure the camera's Bluetooth setting is ON and the camera is awake.
- If the preview goes black, unplug and replug the USB cable.

Happy shooting, and thank you! 🎬
