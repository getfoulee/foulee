import XCTest

/// How long the iPhone app takes to open, cold, until its home is on screen
/// (issue #613), measured against the runner it runs on (issue #795).
///
/// The app runs in capture mode (`ScreenshotCapture`), so every launch opens on
/// the same seeded home rather than on whatever the simulator's Health store
/// holds.
///
/// An absolute time said more about the CI machine than about the app: one
/// commit measured 12.6 s and then 10.3 s. Each round therefore also opens
/// Settings, a system app whose launch Foulée cannot change, right before
/// Foulée, on the same simulator: a slow runner slows both, a slow app only
/// one. `tools/launch_time.sh` compares the ratio of the two fastest launches
/// with `LaunchTimeBudget.json`.
///
/// A wall clock rather than `XCTApplicationLaunchMetric`: on CI's virtual
/// machines the launch metric launches the app and records nothing. The clock
/// also counts XCUITest setting up its session, which the reference counts too.
@MainActor
final class LaunchTimeTests: XCTestCase {
    /// Rounds of one reference launch and one Foulée launch.
    private let rounds = 7

    func testLaunch() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        for round in 1...rounds {
            let (reference, _) = timed {
                settings.launch()
                waitForScreen(settings.navigationBars.firstMatch, "Settings")
            }
            settings.terminate()
            let (foulee, app) = timed {
                let app = launchInCaptureMode()
                waitForScreen(app.buttons[ScreenshotCapture.Card.streak], "Home")
                return app
            }
            app.terminate()
            // Read by tools/launch_time.sh from the raw xcodebuild log.
            print(String(format: "LAUNCH_ROUND %d reference=%.3f foulee=%.3f", round, reference, foulee))
        }
    }

    /// Seconds `body` took, and what it returned.
    private func timed<T>(_ body: () -> T) -> (Double, T) {
        let start = ContinuousClock.now
        let value = body()
        let elapsed = ContinuousClock.now - start
        return (Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18, value)
    }
}
