cask "whispr" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/agentmurph/Whispr/releases/download/v#{version}/Whispr-#{version}.dmg"
  name "Whispr"
  desc "Privacy-first macOS voice-to-text using local Whisper models"
  homepage "https://github.com/agentmurph/Whispr"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Whispr.app"

  postflight do
    # Remind user about required permissions
    ohai "Whispr requires the following macOS permissions:"
    ohai "  1. Microphone access (granted via system prompt on first launch)"
    ohai "  2. Accessibility access (System Settings → Privacy & Security → Accessibility)"
    ohai ""
    ohai "On first launch, Whispr will download the Whisper base.en model (~142 MB)."
  end

  zap trash: [
    "~/Library/Application Support/Whispr",
    "~/Library/Preferences/com.whispr.app.plist",
    "~/Library/Caches/com.whispr.app",
  ]

  caveats <<~EOS
    Whispr requires two macOS permissions to function:

    1. Microphone Access — you'll be prompted automatically on first launch.

    2. Accessibility Access — required to type transcribed text into apps.
       Go to: System Settings → Privacy & Security → Accessibility
       Then add and enable Whispr.

    On first launch, Whispr downloads the Whisper base.en model (~142 MB).
    All transcription runs locally — no data leaves your Mac.
  EOS
end
