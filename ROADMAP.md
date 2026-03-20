# ROADMAP.md — Whispr Development Roadmap

## ✅ Completed

### V1.0 — Core Transcription
- Local whisper.cpp transcription via SwiftWhisper
- Global hotkey toggle (⌥ Space)
- Recording overlay with volume meter
- Text injection via CGEvent
- Menu bar app
- Model download manager

### V1.1 — Multi-Language
- Multilingual model support (8 models)
- Language auto-detection
- Language picker in Settings (30 languages)
- Language flash in overlay after transcription

### V1.2 — Voice Commands & Formatting
- Voice commands (new line, punctuation, ⌘ shortcuts)
- Smart quotes, number formatting, filler word removal
- Auto-paragraph on pauses
- Custom word replacements with Settings UI

### V1.3 — Real-Time Streaming
- StreamingTranscriber with chunked audio processing
- Live caption preview in recording overlay
- Word-by-word output (instant/natural/slow)
- Draft+Final mode (fast tiny.en → accurate selected model)

### V2.0 — Plugin System
- WhisprPlugin protocol with 10 hooks
- PluginManager with bundle discovery
- 3 built-in plugins (Markdown, Timestamp, Profanity)
- Plugin Settings UI with drag-to-reorder

---

## 🔧 V2.1 — AI Modes & LLM Integration (In Progress)
**Goal:** Optional AI post-processing that transforms raw transcription into polished text.

- [ ] LLM provider system (local MLX/llama.cpp + remote OpenAI/Anthropic/Ollama)
- [ ] API key management in Settings (optional, app works fine without)
- [ ] Custom system prompts per mode
- [ ] Built-in modes: Clean, Formal, Email, Code, Chat
- [ ] User-defined custom modes with prompt editor
- [ ] Context awareness (read active app, clipboard for smarter output)
- [ ] Translation via LLM (speak any language → output any language)
- [ ] Fallback: if no LLM configured, modes are disabled, raw transcription only

## 🔧 V2.2 — Input & Keybind Overhaul (In Progress)
**Goal:** Full keybind customization with multiple trigger modes.

- [ ] Custom keybind recorder (any key combo)
- [ ] Trigger modes: Toggle (press to start/stop), Hold (hold to record, release to transcribe), Both (configurable)
- [ ] Per-app trigger mode override
- [ ] Push-to-talk as first-class option
- [ ] Double-tap hotkey for quick mode switch
- [ ] Visual keybind indicator in menu bar tooltip

## 🔧 V2.3 — Personal Dictionary (In Progress)
**Goal:** Auto-learning vocabulary that improves over time.

- [ ] Personal dictionary stored locally (JSON/SQLite)
- [ ] Manual add/edit/delete words in Settings
- [ ] Auto-detect frequently corrected words → suggest additions
- [ ] Import vocabulary from contacts, text files, code repos
- [ ] Per-app dictionaries (medical terms for health apps, etc.)
- [ ] Dictionary applied as whisper initial_prompt for better recognition
- [ ] Export/import dictionary as JSON
- [ ] iCloud sync preparation (for future iOS app)

---

## 📋 V3.0 — File & Media Transcription
- [ ] Drag & drop audio/video files (.mp3, .m4a, .wav, .mp4, .mov)
- [ ] Batch transcription with progress
- [ ] Export formats: .txt, .srt (subtitles), .vtt, .md, .json
- [ ] Meeting recording mode (system audio + mic)
- [ ] Speaker diarization (who said what)
- [ ] Transcription history with search
- [ ] Re-listen to original audio for any transcription

## 📋 V3.1 — Per-App Tone Profiles
- [ ] Auto-adjust output tone based on focused app
- [ ] Built-in profiles: Slack (casual), Mail (formal), Notes (bullets), Terminal (commands)
- [ ] User-configurable per bundle ID
- [ ] Tone applied via LLM post-processing (requires V2.1)

## 📋 V3.2 — Audio Enhancements
- [ ] Noise suppression (RNNoise or Apple's built-in)
- [ ] Voice Activity Detection — auto-start/stop on speech
- [ ] Audio ducking — lower system volume while recording
- [ ] AirPods integration — use AirPods mic seamlessly

## 📋 V3.3 — Subtitle/Caption Mode
- [ ] Floating always-on-top caption window
- [ ] Live transcription as subtitles during calls/videos
- [ ] Customizable font size, position, opacity
- [ ] Accessibility mode for hearing-impaired users

---

## 📋 V4.0 — iOS Companion App
Architecture: Custom keyboard extension + standalone app

- [ ] Custom keyboard with mic button → speak → text appears in any text field
- [ ] Standalone transcription app (record, import files, transcribe)
- [ ] On-device whisper via CoreML (no cloud needed)
- [ ] iCloud sync: vocabulary, snippets, settings, word replacements
- [ ] Share sheet integration (transcribe audio from any app)
- [ ] Shortcuts app actions
- [ ] Widget for quick voice capture
- [ ] Apple Watch complication — tap to dictate

## 📋 V4.1 — Platform Integrations
- [ ] macOS Shortcuts app actions
- [ ] AppleScript/JXA support
- [ ] CLI tool (`whispr transcribe file.mp3`, `whispr record`)
- [ ] URL scheme (`whispr://record`, `whispr://transcribe`)
- [ ] API server mode (localhost HTTP for other apps)
- [ ] VS Code extension
- [ ] Obsidian plugin
- [ ] Raycast extension

## 📋 V4.2 — Analytics & Profiles
- [ ] Dictation analytics (WPM, words dictated, time saved)
- [ ] Voice profiles (multiple users, auto-detect speaker)
- [ ] Training mode with practice passages
- [ ] Transcription history search and export

---

## 🔮 Future / Moonshot
- [ ] Voice macros (voice-triggered automation sequences)
- [ ] Live meeting assistant (join calls, transcribe, generate notes)
- [ ] Voice journal with mood tagging and weekly summaries
- [ ] Whispr SDK (Swift Package for other apps to embed)
- [ ] Windows & Linux ports
- [ ] Homebrew cask in homebrew-core

---

*Updated: 2026-03-19 by Murph 🌌*
