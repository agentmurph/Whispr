# Contributing to Whispr

Thanks for your interest in contributing to Whispr! 🎙️

## Prerequisites

- macOS 14.0+ (Sonoma)
- Swift 5.9+
- Xcode 15+ or just the Swift toolchain

## Building

```bash
# Clone the repo
git clone https://github.com/agentmurph/Whispr.git
cd Whispr

# Debug build
swift build

# Release build
swift build -c release

# Build DMG (after release build)
bash scripts/build-dmg.sh
```

## Conventional Commits

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automatic versioning and changelog generation. **All commits must follow this format:**

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat` | New feature | Minor (0.x.0) |
| `fix` | Bug fix | Patch (0.0.x) |
| `docs` | Documentation only | None |
| `style` | Formatting, no code change | None |
| `refactor` | Code change, no new feature or fix | None |
| `perf` | Performance improvement | None |
| `test` | Adding or updating tests | None |
| `chore` | Maintenance, deps, CI | None |
| `ci` | CI/CD changes | None |
| `build` | Build system changes | None |

### Breaking Changes

For breaking changes, add `!` after the type or include `BREAKING CHANGE:` in the footer:

```
feat!: redesign hotkey system

BREAKING CHANGE: Hotkey configuration format has changed.
```

This triggers a **major** version bump.

### Examples

```
feat: add per-app hotkey profiles
fix: resolve MainActor isolation crash in overlay
docs: update README with new screenshots
chore: bump SwiftWhisper dependency to 1.2.0
ci: add build check workflow for PRs
```

## Pull Request Process

1. **Fork** the repo and create a feature branch from `main`
2. **Write code** — follow existing Swift style and conventions
3. **Test locally** — make sure `swift build -c release` succeeds
4. **Commit** using conventional commit messages
5. **Open a PR** against `main` with a clear description
6. **CI must pass** — the build check workflow runs automatically

### PR Title

Use the same conventional commit format for your PR title, since it becomes the merge commit message:

```
feat: add support for medium.en model
```

## Architecture

See `PLAN.md` for the full architecture overview. Key areas:

- `Sources/Whispr/` — all Swift source files
- `scripts/` — build and release scripts
- `Resources/` — app icon and assets
- `docs/` — landing page (GitHub Pages)

## Permissions

Whispr needs microphone and accessibility permissions during development. Grant these in System Settings → Privacy & Security when prompted.

## Questions?

Open an issue or check existing ones. We're happy to help!
