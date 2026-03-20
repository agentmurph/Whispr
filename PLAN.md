# Whispr — Project Plan

**Open-source macOS voice-to-text. Speak anywhere, type nowhere.**

An English-only, privacy-first, one-click-install macOS app that uses OpenAI's Whisper models locally to transcribe speech and inject text into any application. No cloud. No subscription. No data leaves your Mac.

---

## What It Does (MVP)

1. **Global hotkey toggle** (e.g., `⌥ Space`) — press once to start recording, press again to stop and transcribe
2. **Recording overlay** — when recording, shows a floating panel with:
   - Live audio activity/volume meter (waveform or level bar)
   - Stop button (same as pressing hotkey again)
   - Cancel button (discard recording)
   - Visual feedback: recording duration, pulsing indicator
3. **Transcribes locally** using whisper.cpp with CoreML acceleration on Apple Silicon
4. **Types the text** into whatever app has focus (simulated keystrokes via macOS Accessibility API)
5. **Menu bar app** — lives in the menu bar, minimal UI, always ready
6. **One-click install** — download DMG, drag to Applications, done. First launch downloads the Whisper model (~142MB for `base.en`)
7. **English only** — simpler, faster, smaller models, better accuracy for one language

## What Makes It Different from Wisprflow

| Feature | Wisprflow | Whispr |
|---|---|---|
| Price | $15/mo | Free & open source |
| Privacy | Cloud processing | 100% local |
| Languages | 100+ | English only (by design) |
| Platforms | Mac, Windows, iOS, Android | macOS only |
| AI editing/formatting | Yes (cloud AI) | No (raw transcription, clean) |
| Models | Proprietary | OpenAI Whisper (open) |
| Install | App + account | One DMG, no account |

## Architecture

```
┌─────────────────────────────────────────┐
│              Whispr.app                  │
│                                          │
│  ┌──────────┐  ┌───────────────────────┐ │
│  │ Menu Bar │  │  Settings Window      │ │
│  │  Icon    │  │  - Model selection    │ │
│  │  + HUD   │  │  - Hotkey config     │ │
│  └────┬─────┘  │  - Audio device      │ │
│       │        └───────────────────────┘ │
│  ┌────▼─────────────────────────────┐    │
│  │       Audio Capture Engine       │    │
│  │  (AVAudioEngine / CoreAudio)     │    │
│  └────┬─────────────────────────────┘    │
│       │                                  │
│  ┌────▼─────────────────────────────┐    │
│  │     whisper.cpp (via Swift)      │    │
│  │  - CoreML encoder acceleration   │    │
│  │  - Metal GPU fallback            │    │
│  │  - GGML model loading            │    │
│  └────┬─────────────────────────────┘    │
│       │                                  │
│  ┌────▼─────────────────────────────┐    │
│  │      Text Injection Engine       │    │
│  │  (CGEvent / Accessibility API)   │    │
│  └──────────────────────────────────┘    │
└──────────────────────────────────────────┘
```

## Tech Stack

| Component | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Whisper | whisper.cpp via SwiftWhisper SPM package |
| Audio | AVAudioEngine (microphone capture) |
| Text injection | CGEvent keyboard simulation |
| Hotkey | HotKey SPM package (global shortcuts) |
| Model download | URLSession + progress UI |
| Distribution | DMG via create-dmg |
| Min macOS | 14.0 (Sonoma) |

## Whisper Models (English-only)

| Model | Size | Speed | Quality | Default? |
|---|---|---|---|---|
| `tiny.en` | 75 MB | ~10x realtime | Good | No |
| `base.en` | 142 MB | ~7x realtime | Better | ✅ Yes |
| `small.en` | 466 MB | ~3x realtime | Great | No |
| `medium.en` | 1.5 GB | ~1x realtime | Excellent | No |

All models run locally with CoreML acceleration on Apple Silicon. Intel Macs fall back to CPU (slower but functional).

## UI / UX

### Menu Bar
- Microphone icon in menu bar (idle: gray, recording: red, processing: pulsing)
- Click to toggle recording (alternative to hotkey)
- Dropdown: Settings, About, Quit

### Recording Overlay (Toggle UI)
- Floating panel appears when recording starts (centered or near cursor):
  - 🔴 **Recording state**: pulsing red dot, elapsed time counter
  - 📊 **Live volume meter**: real-time audio level visualization (bar or waveform)
  - ⏹️ **Stop button**: stops recording and transcribes (same as pressing hotkey again)
  - ❌ **Cancel button**: discards recording, closes overlay
  - ⌨️ **Hotkey hint**: shows "Press ⌥Space to stop" reminder
  - ⏳ **Transcribing state**: spinner + "Transcribing..." after stop
  - ✅ **Done**: brief flash of transcribed text, then auto-injects and closes

### Settings Window
- **General**: Launch at login, menu bar icon style
- **Hotkey**: Configurable global shortcut (default: ⌥ Space)
- **Model**: Select/download Whisper model (with size + speed indicators)
- **Audio**: Select input device
- **About**: Version, GitHub link, licenses

### First Launch
1. Welcome screen: "Whispr needs microphone access and accessibility permissions"
2. Guide through granting permissions
3. Auto-download default model (`base.en`, ~142MB) with progress bar
4. Ready to go — show hotkey reminder

## Permissions Required

1. **Microphone** — for audio capture (standard macOS permission dialog)
2. **Accessibility** — for typing text into other apps (System Settings > Privacy > Accessibility)
3. **No network after setup** — model download is the only network call

## Project Structure

```
Whispr/
├── Whispr.xcodeproj
├── Whispr/
│   ├── App/
│   │   ├── WhisprApp.swift          # Entry point, menu bar setup
│   │   ├── AppDelegate.swift        # NSApplicationDelegate
│   │   └── AppState.swift           # Global state management
│   ├── Audio/
│   │   ├── AudioEngine.swift        # Mic capture via AVAudioEngine
│   │   └── AudioBuffer.swift        # PCM buffer management
│   ├── Transcription/
│   │   ├── WhisperEngine.swift      # whisper.cpp wrapper
│   │   ├── ModelManager.swift       # Download, cache, select models
│   │   └── ModelInfo.swift          # Model metadata
│   ├── TextInjection/
│   │   ├── TextInjector.swift       # CGEvent keystroke simulation
│   │   └── ClipboardFallback.swift  # Paste fallback for tricky apps
│   ├── Hotkey/
│   │   ├── HotkeyManager.swift      # Global shortcut registration
│   │   └── HotkeyRecorder.swift     # Custom shortcut picker
│   ├── UI/
│   │   ├── MenuBarView.swift        # Menu bar dropdown
│   │   ├── RecordingHUD.swift       # Floating overlay
│   │   ├── SettingsView.swift       # Settings window
│   │   ├── OnboardingView.swift     # First-launch flow
│   │   └── ModelDownloadView.swift  # Download progress
│   ├── Utilities/
│   │   ├── Permissions.swift        # Permission checking/requesting
│   │   └── Constants.swift          # App-wide constants
│   └── Resources/
│       └── Assets.xcassets
├── Package.swift                     # SPM dependencies (if hybrid)
└── README.md
```

## Milestones

### M1: Proof of Concept (Week 1)
- [ ] Xcode project with SwiftUI menu bar app
- [ ] Microphone capture → PCM buffer
- [ ] whisper.cpp integration via SwiftWhisper
- [ ] Basic transcription (record → text in console)
- [ ] Text injection via CGEvent into focused app

### M2: Usable App (Week 2)
- [ ] Global hotkey (hold-to-record)
- [ ] Recording HUD overlay
- [ ] Model download manager (with progress)
- [ ] Settings window (model, hotkey, audio device)
- [ ] First-launch onboarding flow
- [ ] Launch at login support

### M3: Polish & Ship (Week 3)
- [ ] CoreML acceleration for Apple Silicon
- [ ] Clipboard paste fallback for secure text fields
- [ ] DMG packaging with create-dmg
- [ ] App icon and branding
- [ ] README with screenshots and install instructions
- [ ] GitHub release with signed DMG

### M4: Nice-to-Haves (Future)
- [ ] Audio waveform visualization during recording
- [ ] Configurable text post-processing (capitalize, punctuate)
- [ ] Per-app hotkey profiles
- [ ] Homebrew cask (`brew install --cask whispr`)
- [ ] Auto-update via Sparkle
- [ ] Snippet/shortcut library

## Open Questions for Coop

1. **Name**: "Whispr" good? Or something else?
2. **Repo ownership**: Created under `agentmurph` since I can't push to `JamesWatling`. Want to transfer it, or fork from yours?
3. **Min macOS version**: Sonoma (14.0) keeps things modern. Support Ventura (13.0) too?
4. **Default hotkey**: `⌥ Space` (Option+Space)? Or `fn fn` (double-tap fn)?
5. **Model default**: `base.en` (142MB, good balance)? Or `tiny.en` (75MB, faster download)?
6. **Priority**: Start building immediately after review, or refine plan first?

---

*"Don't let me leave, Murph!" — I'm the one who types for you now.* 🌌
