# Backdrop

Menu bar video wallpaper for macOS 16 Tahoe+. Pick a folder of videos, select one, and it loops as your desktop wallpaper.

## Features

- **Library folder** — choose a folder of `mp4` / `mov` / `m4v` (and a few other) videos
- **Single-video loop** — the selected clip repeats forever until you pick another
- **Menu bar controls** — play/pause, choose video, change folder, speed (0.25×–2×), settings, quit
- **Energy saving** — optionally pause on battery and/or Low Power Mode (freezes the current frame)
- **Multi-display** — one desktop-level player window per screen
- **Open at Login** — optional via Settings

Lock Screen wallpaper is **not** included in this version.

## Requirements

- macOS 16.0 (Tahoe) or later
- Xcode 16+ (to build)

## Build & run

```bash
cd Backdrop
open Backdrop.xcodeproj
```

Or from the command line:

```bash
cd Backdrop
xcodebuild -scheme Backdrop -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Backdrop.app
```

The app is a menu bar agent (`LSUIElement`) — it does not show a Dock icon. Look for the play/photo rectangle icon in the menu bar.

## Usage

1. Click the menu bar icon → **Change Folder…** and pick a folder of videos
2. Use **Choose Video** (or Settings → Wallpaper) to select which clip loops
3. Adjust **Speed** as needed
4. In **Settings → Playback**, enable:
   - **Pause playback on battery**
   - **Pause playback in Low Power Mode**

When paused for energy saving, the last frame stays on the desktop. Lock Screen and screensaver behavior are unchanged (system defaults).

## Project layout

```
Backdrop/
  Backdrop/
    App.swift / AppState.swift
    Wallpaper/   # desktop windows + AVPlayer loop
    Library/     # folder scan
    Power/       # battery + Low Power Mode
    Settings/    # menu bar + settings UI
  Backdrop.xcodeproj
```
