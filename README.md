# Whispr 🎙️

**Open-source macOS voice-to-text. Speak anywhere, type nowhere.**

Whispr is a privacy-first, local-only voice transcription app for macOS. Press a hotkey, speak, and your words appear wherever you're typing — no cloud, no subscription, no data leaves your Mac.

Powered by [OpenAI's Whisper](https://github.com/openai/whisper) running locally via [whisper.cpp](https://github.com/ggerganov/whisper.cpp).

<!-- TODO: Add screenshot/demo GIF here -->
<!-- ![Whispr Demo](screenshots/demo.gif) -->

---

## ✨ Features

- **Global hotkey** — Press `⌥ Space` (Option+Space) to toggle recording from any app
- **100% local** — All transcription happens on-device using Whisper models
- **CoreML acceleration** — Blazing fast on Apple Silicon with automatic CoreML encoder
- **Smart text injection** — Types text via keystrokes, auto-falls back to clipboard paste for secure fields
- **Floating recording overlay** — Visual feedback with live audio meter, elapsed time, stop/cancel
- **Menu bar app** — Lives in your menu bar, always ready, never in the way
- **Model selection** — Choose from Tiny, Base, Small, or Medium English models
- **First-launch onboarding** — Guided setup for permissions and model download
- **Launch at login** — Optional auto-start with macOS

## 📋 Requirements

- **macOS 14.0** (Sonoma) or later
- **Apple Silicon recommended** (M1/M2/M3/M4) — CoreML acceleration makes transcription 3-5× faster
- Intel Macs supported (CPU-only, slower but functional)
- ~150 MB disk space for the default model (Base English)

## 📥 Installation

### Download DMG (Recommended)

1. Download the latest `Whispr-x.x.x.dmg` from [Releases](../../releases)
2. Open the DMG and drag **Whispr** to **Applications**
3. Launch Whispr from Applications
4. Follow the onboarding to grant permissions and download a model

### Build from Source

```bash
# Clone the repo
git clone https://github.com/your-org/whispr.git
cd whispr

# Build
swift build -c release

# Or build a DMG
./scripts/build-dmg.sh
```

## 🔐 Permissions

Whispr needs two permissions to work:

| Permission | Why | How to Grant |
|---|---|---|
| **Microphone** | Record your voice | macOS will prompt automatically on first use |
| **Accessibility** | Type transcribed text into apps | System Settings → Privacy & Security → Accessibility → Add Whispr |

> **No network access required** after the initial model download. Whispr never phones home.

## ⌨️ Usage

| Action | How |
|---|---|
| **Start recording** | Press `⌥ Space` or click the menu bar icon |
| **Stop & transcribe** | Press `⌥ Space` again, or click Stop in the overlay |
| **Cancel recording** | Click Cancel in the overlay |
| **Open settings** | Click the menu bar icon → Settings |

### Recording Flow

1. Press `⌥ Space` — recording starts, overlay appears
2. Speak naturally — the live meter shows audio levels
3. Press `⌥ Space` — recording stops, transcription begins
4. Text appears in your focused app ✨

## 🧠 Whisper Models

| Model | Size | Speed | Quality | Best For |
|---|---|---|---|---|
| Tiny (English) | 75 MB | ~10× realtime | Good | Quick notes, fast machines |
| **Base (English)** | **142 MB** | **~7× realtime** | **Better** | **Default — great balance** |
| Small (English) | 466 MB | ~3× realtime | Great | When accuracy matters more |
| Medium (English) | 1.5 GB | ~1× realtime | Excellent | Best quality, needs patience |

Speed estimates assume Apple Silicon with CoreML. Intel Macs will be slower.

Models are downloaded once and stored locally in `~/Library/Application Support/Whispr/Models/`.

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│            Whispr.app               │
│                                     │
│  Menu Bar Icon + Recording Overlay  │
│         ↕                           │
│  AVAudioEngine (16kHz mono PCM)     │
│         ↓                           │
│  whisper.cpp + CoreML encoder       │
│         ↓                           │
│  Text Injection (CGEvent / ⌘V)     │
└─────────────────────────────────────┘
```

- **SwiftUI** menu bar app with floating overlay panel
- **AVAudioEngine** for real-time audio capture
- **SwiftWhisper** (whisper.cpp Swift wrapper) for transcription
- **CGEvent** keystroke simulation with clipboard paste fallback
- **HotKey** package for global keyboard shortcut

## ⚙️ Settings

Access via menu bar icon → Settings:

- **General** — Hotkey display, launch at login, text injection mode
- **Models** — Download/select/delete Whisper models
- **Audio** — Select input device

## 📸 Screenshots

<!-- TODO: Add screenshots -->
<!--
![Menu Bar](screenshots/menubar.png)
![Recording](screenshots/recording.png)
![Settings](screenshots/settings.png)
![Onboarding](screenshots/onboarding.png)
-->

## 🛠️ Development

### Prerequisites

- Xcode 15+ (for Swift 5.9+)
- macOS 14.0+ SDK

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Package as DMG
./scripts/build-dmg.sh [version]

# Regenerate app icon
swift scripts/generate-icon.swift
```

### Project Structure

```
Whispr/
├── Sources/Whispr/
│   ├── WhisprApp.swift          # Entry point, menu bar, core flow
│   ├── AppState.swift           # Observable app state
│   ├── AudioEngine.swift        # Mic capture (16kHz mono PCM)
│   ├── WhisperEngine.swift      # whisper.cpp transcription wrapper
│   ├── ModelManager.swift       # Model download/management + CoreML
│   ├── TextInjector.swift       # CGEvent keystrokes + clipboard fallback
│   ├── HotkeyManager.swift      # Global ⌥Space shortcut
│   ├── RecordingOverlay.swift   # Floating HUD panel
│   ├── SettingsView.swift       # Settings window
│   └── OnboardingView.swift     # First-launch flow
├── Resources/
│   ├── AppIcon.icns             # App icon for DMG
│   └── Assets.xcassets/         # Icon asset catalog
├── scripts/
│   ├── build-dmg.sh             # DMG packaging script
│   └── generate-icon.swift      # Icon generator
├── Package.swift                # SPM manifest
├── PLAN.md                      # Project roadmap
└── README.md                    # You are here
```

## 📄 License

MIT — do whatever you want with it.

## 🙏 Credits

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov
- [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) — Swift wrapper for whisper.cpp
- [HotKey](https://github.com/soffes/HotKey) — Global keyboard shortcuts for macOS
- [OpenAI Whisper](https://github.com/openai/whisper) — The speech recognition model

---

*Built with 🌌 by [Whispr contributors](../../graphs/contributors)*
