<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-lightgrey" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift" alt="Swift 6.0">
  <img src="https://img.shields.io/github/v/release/flashrod/LoveWidget" alt="Release">
  <img src="https://img.shields.io/github/downloads/flashrod/LoveWidget/total" alt="Downloads">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License">
</p>

<h1 align="center">LoveWidget</h1>

<p align="center">
  Share a drawing canvas with your partner — right in your menu bar.
</p>

## Install

### Homebrew

```bash
brew tap flashrod/tap
brew install --cask lovewidget
```

> **First launch:** Right-click `LoveWidget.app` in Applications → **Open** → click **Open**. This is needed once because the app is ad-hoc signed (no Apple Developer account).

### Manual

1. Download the latest `.dmg` from [releases](https://github.com/flashrod/LoveWidget/releases)
2. Mount the DMG and drag `LoveWidget.app` to your Applications folder
3. **Bypass Gatekeeper** (first launch only):

   **Option A:** Right-click `LoveWidget.app` in Finder → **Open** → click **Open**.

   **Option B:** Go to **System Settings → Privacy & Security** → click **Open Anyway**.

4. Launch LoveWidget — click the heart icon in your menu bar

## How It Works

You and your partner each run LoveWidget. One person creates a pairing code, the other joins with it. Now both of you share a canvas — draw something and it appears on their menu bar in real time.

- **Pairing** — Create or join a pair with a 7-character invite code
- **Draw** — Scribble on the 320×320 canvas with configurable brush size and color
- **See theirs** — Partner's drawing appears below yours, updated in real time
- **Menu bar** — Click the heart icon to open the popover with both drawings
- **History** — Your last 100 drawings are saved locally so you can revisit them

## Quick Start (from source)

```bash
git clone https://github.com/flashrod/LoveWidget.git
cd LoveWidget
cp Config.xcconfig.template Config.xcconfig
# Fill in SUPABASE_URL and SUPABASE_ANON_KEY
./build.sh
open LoveWidget.app
```

## Build from Source

```bash
# Build and run in-place
./build.sh

# Build a distributable DMG
./build-release.sh

# Build DMG + compute checksum + update cask + create GitHub release
./Scripts/release_homebrew.sh 1.0.1 --repo flashrod/LoveWidget
```

## Release Checklist (DMG + Homebrew)

```bash
# 1) Prepare release artifact and metadata
./Scripts/release_homebrew.sh 1.0.1 --repo flashrod/LoveWidget

# 2) Commit app repo changes (includes Casks/lovewidget.rb update)
git add build-release.sh Casks/lovewidget.rb README.md Scripts/release_homebrew.sh
git commit -m "release: v1.0.1"
git push
```

Then update the same cask change in your tap repository (for example `flashrod/homebrew-tap`) and push there. Once pushed, users can install via Homebrew:

```bash
brew tap flashrod/tap
brew install --cask lovewidget
```

Requires Swift 6.0+, macOS 14+. No Xcode needed.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ PairingView  │────→│  SyncEngine  │────→│ Supabase    │
│ (Create/Join)│     │  (poll+rt)   │     │ (REST+RT)   │
└─────────────┘     └──────┬───────┘     └─────────────┘
                           │
                    ┌──────▼───────┐
                    │ CanvasViewModel │
                    │ (main+partner)  │
                    └──────┬───────┘
                           │
              ┌────────────┴────────────┐
              ↓                         ↓
        ┌──────────┐            ┌──────────────┐
        │Main Canvas│            │Partner Section│
        │ 320×320  │            │   320×320     │
        └──────────┘            └──────────────┘
              │
              ↓
        ┌──────────────┐
        │ Menu Bar      │
        │ (NSPopover)   │
        │ 5s polling    │
        └──────────────┘
```

- **Supabase** handles auth (anonymous), pairing (custom RPC), and drawing sync (upsert + Realtime)
- **StrokeRenderer** renders both canvases with identical SplineSmoothing paths
- **AppGroupStorage** persists drawings to disk + UserDefaults for reliable menu bar access
- **HistoryView** replays your saved drawings offline

## License

MIT
