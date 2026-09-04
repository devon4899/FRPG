import Darwin
import XCTest

/// Drives a seeded build through the five App Store screenshot scenes
/// (Character, Session, Journey, Progress chart, Satchel) and
/// writes PNGs to `RPGFIT_SCREENSHOT_DIR` on the host (default:
/// /tmp/rpgfit-shots). Give each device run its own directory and disable
/// parallel testing. Run on an iPhone 16 Pro Max simulator for 1320×2868
/// (6.9") assets:
///
/// Set RPGFIT_SCREENSHOT_DIR in the scheme's Test environment, then run:
///
///   xcodebuild test -scheme RPGFitMVP \
///     -destination 'id=<16 Pro Max sim>' \
///     -parallel-testing-enabled NO \
///     -only-testing:RPGFitMVPUITests/ScreenshotHarness
///
/// The same harness on a 13-inch iPad simulator produces the required iPad
/// family assets. Use a different output directory for each device run.
/// Every run requires a freshly erased simulator (or a newly installed app):
/// the seed deliberately creates durable history and an in-progress session.
///
/// The five named scenes are the deliverable. In particular, the fourth shot
/// must be a real exercise-detail chart; a Skillbook fallback is not accepted.
final class ScreenshotHarness: XCTestCase {

    private var captureLockFD: Int32 = -1

    private var screenshotDirectory: URL {
        if let configured = ProcessInfo.processInfo.environment["RPGFIT_SCREENSHOT_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true).standardizedFileURL
        }
        return URL(fileURLWithPath: "/tmp/rpgfit-shots", isDirectory: true)
    }

    private let artifactNames = [
        "qa-ledgerstone.png", "qa-history-metrics.png",
        "qa-items.png", "qa-item-detail.png",
        "01-skills.png",
        "02-session.png", "02-train.png",
        "03-campaign.png", "03-quests.png",
        "04-charts.png", "04-skillbook.png",
        "05-inventory.png",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false

        let shots = screenshotDirectory
        try FileManager.default.createDirectory(
            at: shots,
            withIntermediateDirectories: true
        )

        // Xcode can clone a UI test onto multiple runners. Only one process may
        // own a given output directory; other clones skip before deleting or
        // writing artifacts. Separate device runs should use separate explicit
        // RPGFIT_SCREENSHOT_DIR values.
        let lockURL = shots.appendingPathComponent(".capture.lock")
        let fd = Darwin.open(
            lockURL.path,
            O_CREAT | O_RDWR,
            mode_t(S_IRUSR | S_IWUSR)
        )
        guard fd >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        guard Darwin.lockf(fd, F_TLOCK, 0) == 0 else {
            Darwin.close(fd)
            throw XCTSkip("Another ScreenshotHarness owns \(shots.path)")
        }
        captureLockFD = fd

        // Clear only files owned by this harness. Never recursively empty an
        // environment-provided path.
        for name in artifactNames {
            try? FileManager.default.removeItem(at: shots.appendingPathComponent(name))
        }
    }

    override func tearDownWithError() throws {
        if captureLockFD >= 0 {
            _ = Darwin.lockf(captureLockFD, F_ULOCK, 0)
            Darwin.close(captureLockFD)
            captureLockFD = -1
        }
    }

    /// Finds the first visible copy of a label. SwiftUI can leave hidden tab
    /// controls in the hierarchy under a sheet, so `.firstMatch` is not enough.
    private func firstHittable(_ text: String, in app: XCUIApplication) -> XCUIElement? {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        for query in [app.buttons, app.staticTexts, app.otherElements,
                      app.descendants(matching: .any)] {
            if let element = query.matching(predicate)
                .allElementsBoundByIndex
                .first(where: { $0.exists && $0.isHittable }) {
                return element
            }
        }
        return nil
    }

    /// iOS 18 renders the same TabView as a bottom tab bar on iPhone and a
    /// top `tab` element on iPad. Query the familiar tab-bar button first,
    /// then fall back to an exact visible descendant for the adapted form.
    private func visibleTab(_ label: String, in app: XCUIApplication) -> XCUIElement? {
        let button = app.tabBars.buttons[label]
        if button.exists && button.isHittable { return button }

        let exact = NSPredicate(format: "label ==[c] %@", label)
        return app.descendants(matching: .any)
            .matching(exact)
            .allElementsBoundByIndex
            .first(where: { $0.exists && $0.isHittable })
    }

    @discardableResult
    private func tapTab(_ label: String, in app: XCUIApplication,
                        timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let tab = visibleTab(label, in: app) {
                tab.tap()
                return true
            }
            usleep(200_000)
        } while Date() < deadline
        XCTFail("Visible \(label) tab was not found")
        return false
    }

    /// Taps the first hittable element whose label contains `text`,
    /// preferring real buttons, then text, then generic elements.
    @discardableResult
    private func tapAny(_ text: String, in app: XCUIApplication,
                        timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let element = firstHittable(text, in: app) {
                element.tap()
                return true
            }
            usleep(200_000)
        } while Date() < deadline
        return false
    }

    /// Polls until `condition` holds. Existence alone is not enough for
    /// anything behind onboarding's fullScreenCover, which leaves the tab
    /// bar in the hierarchy while covering it.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            usleep(200_000)
        } while Date() < deadline
        return false
    }

    /// Advances one onboarding page and proves that the destination actually
    /// arrived. Large iPad transitions can briefly expose a button while its
    /// card is still moving; retrying the tap is safer than letting the rest
    /// of the script act on a stale page.
    @discardableResult
    private func advanceOnboarding(
        from button: String,
        to destination: String,
        in app: XCUIApplication
    ) -> Bool {
        for _ in 0..<3 {
            if tapAny(button, in: app, timeout: 6),
               waitUntil(timeout: 6, {
                   self.firstHittable(destination, in: app) != nil
               }) {
                return true
            }
        }
        XCTFail("Onboarding did not advance from \(button) to \(destination)")
        return false
    }

    /// Filtering turns the seeded Bench Press session member into a standalone
    /// history card. Its title and metric badges are separate accessibility
    /// elements, so target the exact visible title only after scrolling the
    /// Signature Lifts summary above the viewport.
    private func benchHistoryTitle(in app: XCUIApplication) -> XCUIElement? {
        let predicate = NSPredicate(format: "label ==[c] %@", "Bench Press")
        return app.staticTexts
            .matching(predicate)
            .allElementsBoundByIndex
            .first(where: { $0.exists && $0.isHittable })
    }

    @MainActor
    func testCaptureAppStoreScreens() throws {
        let shots = screenshotDirectory

        func snap(_ name: String) throws {
            let png = XCUIScreen.main.screenshot().pngRepresentation
            try png.write(
                to: shots.appendingPathComponent("\(name).png"),
                options: .atomic
            )
        }

        var app = XCUIApplication()
        app.launchArguments.append("-rpgfit-screenshot-capture")
        app.launchArguments.append("-rpgfit-seed-screenshot-data")
        app.launch()

        // A fresh install is a hard precondition. Continuing from an older
        // state would append the deterministic seed a second time and could
        // produce plausible-looking but invalid release assets.
        guard app.buttons["Get Started"].waitForExistence(timeout: 6) else {
            XCTFail("ScreenshotHarness requires an erased simulator or fresh app install")
            return
        }

        // Seven-page onboarding. CTA labels in order:
        // Get Started → Continue → Reveal My Class → Continue →
        // Approach the Ledgerstone → Pass the Stone Unread → Start Your Journey
        guard advanceOnboarding(from: "Get Started", to: "Continue", in: app),
              advanceOnboarding(from: "Continue", to: "Get Stronger", in: app),
              tapAny("Get Stronger", in: app, timeout: 6),
              tapAny("Get Bigger", in: app, timeout: 6),
              advanceOnboarding(from: "Reveal My Class", to: "Your Class", in: app),
              advanceOnboarding(from: "Continue", to: "Approach the Ledgerstone", in: app),
              advanceOnboarding(from: "Approach the Ledgerstone",
                                to: "Pass the Stone Unread", in: app) else {
            return
        }
        // QA companion image: this is not one of the five App Store assets,
        // but keeps the Ledgerstone's semantic artwork under visual review.
        try snap("qa-ledgerstone")
        // Nothing on the Weighing is answered here, so the morphing CTA
        // stays on its skip wording.
        guard tapAny("Pass the Stone Unread", in: app, timeout: 6) else {
            XCTFail("The Weighing did not expose its unread path")
            return
        }
        // The Naming plays a rite; a tap lands it early and the CTA only
        // enables on the final frame.
        app.tap()
        let journey = app.buttons["Start Your Journey"]
        guard journey.waitForExistence(timeout: 8) else {
            XCTFail("The Naming never reached Start Your Journey")
            return
        }
        _ = waitUntil(timeout: 8) { journey.isEnabled && journey.isHittable }
        journey.tap()
        XCTAssertTrue(waitUntil(timeout: 10) {
            self.visibleTab("Character", in: app) != nil
        },
                      "never reached the main tab bar")

        // The DEBUG-only launch hook applies the same deterministic seed as
        // Developer Tools after onboarding commits. Prove it arrived before
        // testing the normal persistence lifecycle below.
        guard tapTab("Train", in: app),
              waitUntil(timeout: 15, {
                  self.firstHittable("Push & Pull", in: app) != nil
              }) else {
            XCTFail("screenshot seed did not create its Push & Pull routine")
            return
        }

        // The app deliberately serializes persistence off the main thread,
        // while @AppStorage also flushes independently. Killing the foreground
        // process on the same tick can lose either write. Drive the real
        // inactive/background lifecycle first so both stores reach disk.
        XCUIDevice.shared.press(.home)
        sleep(2)

        // Relaunch, then prove the persisted seed exists before writing any
        // image. This turns a missed seed/save into a hard failure rather than
        // a plausible set of stale Level 1 screenshots.
        app.terminate()
        app = XCUIApplication()
        app.launchArguments.append("-rpgfit-screenshot-capture")
        app.launch()
        guard waitUntil(timeout: 10, {
            self.visibleTab("Train", in: app) != nil
        }) else {
            XCTFail("seeded relaunch never reached the main tab bar")
            return
        }
        guard tapTab("Train", in: app) else { return }
        guard waitUntil(timeout: 8, {
            self.firstHittable("Push & Pull", in: app) != nil
        }) else {
            XCTFail("screenshot seed did not persist its Push & Pull routine")
            return
        }

        guard tapTab("Character", in: app) else { return }
        sleep(4) // level-up and XP animations settle
        try snap("01-skills")

        // Train cockpit: use a DEBUG-only presentation hook because iPadOS 18
        // drops synthesized taps that present a fullScreenCover from a button
        // nested under its adapted top TabView. The ordinary routine controls
        // are exercised separately; this path exists only for deterministic
        // release capture.
        app.terminate()
        app = XCUIApplication()
        app.launchArguments.append("-rpgfit-screenshot-capture")
        app.launchArguments.append("-rpgfit-open-screenshot-session")
        app.launch()
        let finishSession = app.buttons["Finish Session"]
        if !finishSession.waitForExistence(timeout: 3) {
            guard tapTab("Train", in: app) else { return }
        }
        guard finishSession.waitForExistence(timeout: 10) else {
            XCTFail("DEBUG capture hook did not open the active-session cockpit")
            return
        }
        for setIndex in 1...2 {
            let box = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Complete set \(setIndex)")
            ).firstMatch
            guard box.waitForExistence(timeout: 5), box.isHittable else {
                XCTFail("Active session did not expose set \(setIndex)")
                return
            }
            box.tap()
        }
        sleep(1)
        try snap("02-session")
        tapAny("Save & Exit", in: app, timeout: 3)

        // Campaign map from the Journey tab.
        guard tapTab("Journey", in: app) else { return }
        sleep(1)
        guard tapAny("Campaign Map", in: app, timeout: 5) else {
            XCTFail("Campaign Map entry point was not available")
            return
        }
        sleep(1)
        try snap("03-campaign")
        app.swipeDown(velocity: .fast)

        // Per-exercise charts via one exact seeded history card. Filtering first
        // removes every unrelated history card, then scrolling the Recent
        // Workouts header into view removes the identically named Signature
        // Lifts summary from hit-testing.
        guard tapTab("Progress", in: app) else { return }
        let search = app.searchFields["Search workouts or exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 6),
                      "Progress search field did not appear")
        search.tap()
        search.typeText("Bench Press")
        app.typeText("\n")

        let recentWorkouts = app.staticTexts["Recent Workouts"]
        var historyScrolls = 0
        while !(recentWorkouts.exists && recentWorkouts.isHittable) && historyScrolls < 10 {
            app.swipeUp(velocity: .fast)
            historyScrolls += 1
        }
        XCTAssertTrue(recentWorkouts.exists,
                      "Filtered Progress log never reached Recent Workouts")

        var benchRow: XCUIElement?
        var benchScrolls = 0
        while benchRow == nil && benchScrolls < 6 {
            benchRow = benchHistoryTitle(in: app)
            if benchRow == nil {
                app.swipeUp(velocity: .slow)
                benchScrolls += 1
            }
        }

        guard benchRow != nil else {
            XCTFail("Filtered Bench Press history row was not hittable")
            return
        }

        // QA companion image for the compact repetitions/load artwork. It is
        // not one of the five App Store assets.
        app.swipeUp(velocity: .fast)
        sleep(1)
        guard let visibleBenchRow = benchHistoryTitle(in: app) else {
            XCTFail("Filtered Bench Press history row did not remain visible")
            return
        }
        try snap("qa-history-metrics")

        visibleBenchRow.press(forDuration: 1.3)
        let viewProgress = app.buttons["View Progress"]
        guard viewProgress.waitForExistence(timeout: 4), viewProgress.isHittable else {
            XCTFail("Bench Press history context menu did not expose View Progress")
            return
        }
        viewProgress.tap()

        let chartTitle = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@", "Estimated 1RM")
        ).firstMatch
        guard app.navigationBars["Bench Press"].waitForExistence(timeout: 6),
              chartTitle.waitForExistence(timeout: 6) else {
            XCTFail("View Progress did not open the Bench Press chart screen")
            return
        }
        sleep(1)
        try snap("04-charts")

        // The Satchel with waiting chests, reached from the Character sheet's
        // "chests are waiting" row.
        // TabView remains visible on the pushed chart screen on both phone and
        // iPad. Switching directly avoids an iPad navigation-back transition
        // briefly removing the adapted top tabs from hit testing.
        guard tapTab("Character", in: app) else { return }
        sleep(1)
        guard tapAny("waiting", in: app, timeout: 6) else {
            XCTFail("Character sheet did not offer the waiting chests row")
            return
        }
        sleep(1)
        try snap("05-inventory")

        // QA companion image for the authored loot and equipment marks.
        guard tapAny("Items", in: app, timeout: 5),
              app.staticTexts["Tap an item to equip it. Long-press to discard."].waitForExistence(timeout: 5) else {
            XCTFail("Satchel did not expose its seeded item shelf")
            return
        }
        sleep(1)
        try snap("qa-items")

        // QA the semantic category and equip-slot marks together at their
        // largest dense-detail presentation.
        guard tapAny("Wand of Stars", in: app, timeout: 5),
              app.staticTexts["Wand of Stars"].waitForExistence(timeout: 5) else {
            XCTFail("Seeded item details did not open")
            return
        }
        sleep(1)
        try snap("qa-item-detail")
    }
}
