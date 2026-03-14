# Tiler

> Snap macOS windows to a grid by drawing on an overlay.

[![Build](https://github.com/VlatkoMilisav/Tiler/actions/workflows/build.yml/badge.svg)](https://github.com/VlatkoMilisav/Tiler/actions/workflows/build.yml)
[![Download](https://img.shields.io/github/v/release/VlatkoMilisav/Tiler?label=Download&style=flat-square)](https://github.com/VlatkoMilisav/Tiler/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-13%2B-white?style=flat-square&logo=apple)](https://github.com/VlatkoMilisav/Tiler/releases/latest)
[![License](https://img.shields.io/github/license/VlatkoMilisav/Tiler?style=flat-square)](LICENSE)

<br />

<video src="https://github.com/VlatkoMilisav/Tiler/releases/download/v0.2.1/demo.mp4" width="100%" autoplay loop muted playsinline></video>

<br />

## How it works

1. Hold the left mouse button and **start dragging** a window
2. Press **Space** (or your chosen trigger) — the grid appears
3. **Draw** the area you want the window to fill
4. **Release** — the window snaps instantly

## Features

| | |
|---|---|
| **Grid profiles** | Preset and custom column/row layouts |
| **Live resize** | Window tracks your selection in real time |
| **Trigger options** | Space, Right-click, ⌥ ⌃ ⇧ ⌘ |
| **Multi-monitor** | Grid follows the cursor to the active screen |
| **Overlay blur** | Adjustable background blur |
| **Menu bar only** | No Dock icon, runs quietly in the background |

## Install

Download the latest [Tiler.dmg](https://github.com/VlatkoMilisav/Tiler/releases/latest), open it, and drag **Tiler** into **Applications**.

On first launch grant Accessibility access when prompted, or go to:

```
System Settings → Privacy & Security → Accessibility → enable Tiler
```

> **"Tiler" can't be opened?** macOS may block the app because it isn't from the App Store.
> Do **not** delete it — go to **System Settings → Privacy & Security**, scroll down, and click **"Open Anyway"**.

#### Build from source

```bash
git clone https://github.com/VlatkoMilisav/Tiler.git && cd Tiler && ./build.sh
```

## Support

If Tiler saves you time, a coffee is always appreciated. \
[![Donate via PayPal](https://img.shields.io/badge/Donate-PayPal-0070ba?style=flat-square&logo=paypal&logoColor=white)](https://paypal.me/VlatkoMilisav)

