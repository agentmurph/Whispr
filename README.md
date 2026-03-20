# Whispr 🎙️

**Open-source macOS voice-to-text. Speak anywhere, type nowhere.**

Whispr is a privacy-first, menu bar app that uses OpenAI's Whisper models locally to transcribe your speech and inject text into any application. No cloud. No subscription. No data leaves your Mac.

![Screenshot placeholder](docs/screenshot.png)

## Features

- 🎤 **Toggle Recording** — Press `⌥ Space` to start, press again to stop and transcribe
- 🔒 **100% Local** — All processing happens on your Mac using Whisper models
- ⌨️ **Text Injection** — Transcribed text is typed directly into the focused app
- 📊 **Live Volume Meter** — Floating overlay with real-time audio level feedback
- 🧠 **Multiple Models** — Choose from Tiny, Base, Small, or Medium (English)
- 🍎 **Native macOS** — SwiftUI menu bar app, macOS 14.0+ (Sonoma)

## Install

### From Source

```bash
git clone https://github.com/agentmurph/Whispr.git
cd Whispr
swift build -c release
# Binary at .build/release/Whispr
```

### Requirements

- macOS 14.0+ (Sonoma)
- Apple Silicon or Intel Mac
- Microphone permission
- Accessibility permission (for typing text into apps)

## Usage

1. Launch Whispr — it lives in your menu bar
2. On first launch, grant permissions and download the default model
3. Press **⌥ Space** (Option + Space) to start recording
4. Speak naturally
5. Press **⌥ Space** again to stop — your words appear where you're typing

## Architecture

```
Sources/Whispr/
├── WhisprApp.swift        # @main entry, menu bar, orchestration
├── AppState.swift         # Observable app state
├── AudioEngine.swift      # AVAudioEngine mic capture → 16kHz PCM
├── WhisperEngine.swift    # SwiftWhisper transcription wrapper
├── ModelManager.swift     # Download & manage Whisper .bin models
├── TextInjector.swift     # CGEvent keystroke / clipboard injection
├── HotkeyManager.swift    # Global ⌥Space toggle via HotKey
├── RecordingOverlay.swift # Floating NSPanel with volume meter
├── SettingsView.swift     # Model picker, preferences
└── OnboardingView.swift   # First-launch permission & model setup
```

### Dependencies

| Package | Purpose |
|---|---|
| [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) | Swift wrapper for whisper.cpp |
| [HotKey](https://github.com/soffes/HotKey) | Global keyboard shortcuts |

### Models

Models are downloaded from [HuggingFace](https://huggingface.co/ggerganov/whisper.cpp) and stored in `~/Library/Application Support/Whispr/Models/`.

| Model | Size | Speed | Quality |
|---|---|---|---|
| Tiny (English) | 75 MB | ~10x realtime | Good |
| **Base (English)** | **142 MB** | **~7x realtime** | **Better** ← default |
| Small (English) | 466 MB | ~3x realtime | Great |
| Medium (English) | 1.5 GB | ~1x realtime | Excellent |

## Building from Source

```bash
# Clone
git clone https://github.com/agentmurph/Whispr.git
cd Whispr

# Build (debug)
swift build

# Build (release, optimized)
swift build -c release

# Run
swift run Whispr
```

## License

MIT

---

*Built with 🌌 by [Murph](https://github.com/agentmurph)*
