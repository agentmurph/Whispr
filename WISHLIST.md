# WISHLIST.md — Whispr Future Features

*Competitive research from Superwhisper, Wispr Flow, MacWhisper, and original ideas.*
*Features we don't have yet, ordered by impact.*

---

## 🔥 High Impact — Differentiators

### AI-Enhanced Modes (à la Superwhisper "Super Mode")
Whispr currently does raw transcription. Competitors use LLMs to **rewrite** speech into polished text. Add optional AI post-processing modes:
- **Clean mode** — Remove filler, fix grammar, add punctuation (local, no cloud)
- **Formal mode** — Rewrite casual speech into professional tone
- **Email mode** — Turn rambly speech into a clean email
- **Code mode** — Translate natural language into code comments, commit messages, or pseudocode
- **Custom modes** — User-defined prompt templates per mode
- Use local LLMs (llama.cpp/MLX) to keep the privacy promise, or optional cloud API keys

### Context-Aware Transcription
Read what's on screen (active app, selected text, clipboard) to give whisper context:
- Autocorrect technical terms based on the app you're in (Xcode → code terms, Slack → people names)
- "Reply to this email" → reads the email and drafts a response
- Cursor/VS Code integration — voice-driven coding with file context

### Push-to-Talk Mode
Currently toggle only. Add a **hold-to-talk** option:
- Hold hotkey → record
- Release → transcribe and inject
- More natural for quick dictations
- Configurable per-app (toggle for long dictation, push for quick replies)

### File & Meeting Transcription
Import audio/video files and transcribe them:
- Drag & drop .mp3, .m4a, .wav, .mp4 files
- Batch transcription with progress
- Export as .txt, .srt (subtitles), .vtt, .md
- Meeting recording mode — record system audio + mic, transcribe with speaker diarization

### Translation
- Speak in any language → output in English (or any target language)
- Real-time translation during streaming mode
- Powered by whisper's built-in translation capability

---

## 🎯 Medium Impact — Quality of Life

### Personal Dictionary / Vocabulary Learning
Wispr Flow auto-learns your unique words. We should too:
- Auto-detect frequently corrected words and suggest additions
- Import vocabulary from contacts, code repos, or text files
- Per-app dictionaries (medical terms for health apps, legal terms for docs)
- Sync vocabulary across devices (iCloud)

### Transcription History & Search
- Save all transcriptions with timestamps, app context, and audio
- Searchable history view
- Re-listen to original audio for any transcription
- Export history as CSV/JSON
- Pin/favorite important transcriptions

### Per-App Tone Profiles (à la Wispr Flow)
Auto-adjust output based on which app is focused:
- Slack → casual, short messages
- Mail → professional, complete sentences
- Notes → bullet points
- Terminal → commands only
- User-configurable per bundle ID

### Audio Input Enhancements
- **Noise suppression** — Filter background noise before whisper (RNNoise or Apple's built-in)
- **Voice Activity Detection (VAD)** — Auto-start/stop recording when speech is detected (no hotkey needed)
- **Multiple mic support** — Switch between built-in, AirPods, external mic
- **Audio ducking** — Lower system audio while recording

### Subtitle/Caption Mode
- Floating always-on-top caption window
- Shows live transcription as subtitles during calls, videos, presentations
- Customizable font size, position, opacity
- Great for accessibility and hearing-impaired users

---

## 🛠️ Platform & Integration

### iOS Companion App
- Record on iPhone, transcribe on Mac (Handoff)
- Standalone iPhone transcription
- Share transcriptions between devices via iCloud
- Apple Watch complication — tap to dictate

### Windows & Linux Ports
- Cross-platform via whisper.cpp (already portable)
- Windows: system tray app, global hotkey
- Linux: Wayland/X11 support, system tray

### Shortcuts & Automation Integration
- macOS Shortcuts app actions (Transcribe Audio, Start Recording, etc.)
- AppleScript/JXA support
- CLI tool (`whispr transcribe file.mp3`, `whispr record --duration 30`)
- URL scheme (`whispr://record`, `whispr://transcribe?file=...`)

### Editor Integrations
- **VS Code extension** — voice coding, inline transcription
- **Obsidian plugin** — voice notes directly into vault
- **Raycast extension** — quick voice capture
- **Alfred workflow** — trigger from Alfred

### API Server Mode
- Run Whispr as a local HTTP API (`localhost:8080/transcribe`)
- Accept audio uploads, return text
- Useful for other apps to integrate voice-to-text
- WebSocket mode for streaming

---

## ✨ Nice-to-Have — Delight Features

### Dictation Analytics
- Words per minute tracker
- Total words dictated (daily/weekly/monthly)
- Time saved vs typing estimate
- Most used words/phrases cloud
- Streak tracking

### Voice Profiles
- Multiple user support (different voices, different settings)
- Auto-detect who's speaking (speaker diarization)
- Per-speaker vocabulary and preferences

### Sound Effects & Haptics
- Satisfying audio cues for start/stop/transcribe complete
- Haptic feedback on supported trackpads
- Customizable sound pack (minimal, mechanical, sci-fi, silent)

### Theming & Appearance
- Multiple overlay themes (minimal, glassmorphism, retro terminal, invisible)
- Custom accent colors
- Adjustable overlay position (center, corner, near cursor, follow cursor)
- Opacity control

### Training Mode
- Practice dictation with provided passages
- WPM benchmarks
- Tips for speaking clearly for better recognition
- "Did you mean?" corrections that learn over time

### Offline Model Management
- Pre-download all models for fully offline use
- Model size optimizer (quantized models for less disk space)
- Auto-update models when new versions release

### Clipboard History Integration
- Every transcription automatically added to clipboard history
- Quick re-paste any recent transcription
- Integration with Paste, Maccy, or built-in clipboard manager

### Smart Punctuation from Prosody
- Detect question intonation → add ?
- Detect emphasis → bold or italic
- Detect pauses → paragraph breaks (already partially done in V1.2)
- Detect lists ("first... second... third...") → auto-format as numbered list

---

## 🔮 Moonshot Ideas

### Voice Macros
Record a sequence of actions (open app, type text, click button) triggered by a voice command. Like Automator but voice-activated.

### Live Meeting Assistant
Join a Zoom/Meet/Teams call, transcribe in real-time, generate meeting notes and action items using local LLM. All local, no cloud.

### Voice Journal
Daily voice diary that auto-transcribes, tags entries by mood/topic, and generates weekly summaries. Stored locally, encrypted.

### Whispr SDK
Let other macOS apps embed Whispr's transcription engine. Ship as a Swift Package / framework.

---

## Competitive Gap Analysis

| Feature | Whispr | Superwhisper | Wispr Flow |
|---------|--------|-------------|------------|
| Local transcription | ✅ | ✅ | ❌ (cloud) |
| AI text rewriting | ❌ | ✅ | ✅ |
| Context awareness | ❌ | ✅ | ❌ |
| File transcription | ❌ | ✅ | ❌ |
| Push to talk | ❌ | ✅ | ✅ |
| Personal dictionary | ❌ | ❌ | ✅ (auto-learn) |
| Per-app tones | ❌ | ✅ (modes) | ✅ |
| Translation | ❌ | ✅ | ✅ |
| iOS app | ❌ | ✅ | ✅ |
| Windows | ❌ | ✅ | ✅ |
| Plugin system | ✅ | ❌ | ❌ |
| Open source | ✅ | ❌ | ❌ |
| Free | ✅ | Freemium ($8/mo) | Freemium ($8/mo) |
| Streaming transcription | ✅ | ❌ | ❌ |
| Voice commands | ✅ | ❌ | ❌ |
| Custom hotkeys per app | ✅ | ✅ | ❌ |

**Our biggest gaps:** AI rewriting modes, file transcription, push-to-talk, translation, iOS app.
**Our unique advantages:** Open source, free, plugin system, streaming, voice commands.

---

*Last updated: 2026-03-19 by Murph 🌌*
