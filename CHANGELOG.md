# Changelog

All notable changes to Whispr will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-03-19

### Added

#### Core (M1)
- Global hotkey toggle recording (⌥ Space) with start/stop/transcribe flow
- Microphone audio capture via AVAudioEngine with PCM buffer management
- Local transcription via whisper.cpp (SwiftWhisper SPM package)
- Text injection into focused app via CGEvent keystroke simulation
- Menu bar app with recording state indicator

#### Usable App (M2)
- Model download manager with progress bar and cancel support
- Settings window: model selection, hotkey config, audio device picker, launch at login
- First-launch onboarding flow with permission guidance
- Recording overlay HUD with volume meter and stop/cancel buttons

#### Polish (M3)
- CoreML acceleration for Apple Silicon (auto-downloads encoder model)
- Smart clipboard paste fallback for secure text fields with clipboard restore
- DMG packaging script with app bundle, Info.plist, and Applications symlink
- App icon — microphone-themed icon with asset catalog and .icns
- README with install instructions, usage guide, model table, and dev docs

#### Extras (M4)
- Audio waveform visualization during recording
- Configurable text post-processing (capitalize, punctuate, trim silence)
- Per-app hotkey profiles with UI in Settings
- Homebrew cask formula (`brew install --cask whispr`)
- Sparkle auto-update integration (appcast.xml)
- Linear-style landing page with parallax, mockups, and roadmap

### Fixed
- MainActor isolation crash in button handlers and overlay

[1.0.0]: https://github.com/agentmurph/Whispr/releases/tag/v1.0.0
