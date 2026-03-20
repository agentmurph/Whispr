import SwiftUI

// MARK: - Sparkle Auto-Update Integration
//
// To enable Sparkle auto-updates:
// 1. Add Sparkle SPM dependency to Package.swift:
//      .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
//    And add "Sparkle" to the target dependencies.
//
// 2. Uncomment the `import Sparkle` and the SparkleUpdater class below.
//
// 3. Add to your Info.plist (or build settings):
//      SUFeedURL = https://raw.githubusercontent.com/agentmurph/Whispr/main/appcast.xml
//      SUPublicEDKey = <your ed25519 public key>
//
// 4. Generate signing keys with:
//      ./Sparkle.framework/bin/generate_keys
//
// 5. Wire up SparkleUpdater in WhisprApp (see comments in that file).
//
// Note: Sparkle 2.x requires an Xcode project with proper code signing and
// Info.plist. When building as a pure SPM executable (`swift build`), Sparkle
// won't fully work because it needs a bundled .app with an embedded framework.
// This integration is ready for when the project moves to Xcode-based builds.

/*
import Sparkle

/// Wraps Sparkle's SPUUpdater for SwiftUI integration.
@MainActor
final class SparkleUpdater: ObservableObject {

    private let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false

    init() {
        // Create the updater controller. Setting startingUpdater to true
        // will automatically check for updates on launch.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Bind canCheckForUpdates
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// Trigger a manual update check (for "Check for Updates" menu item).
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
*/

// MARK: - Placeholder for menu integration
//
// When Sparkle is enabled, add this to your MenuBarExtra content in WhisprApp:
//
//   if sparkleUpdater.canCheckForUpdates {
//       Button("Check for Updates…") {
//           sparkleUpdater.checkForUpdates()
//       }
//   }
//
// And add @StateObject private var sparkleUpdater = SparkleUpdater() to WhisprApp.
