import FouleeDomain
import FouleeHealth
import HealthKit
import SwiftUI
import Testing
@testable import FouleeWatch

/// Minimal stand-in for `WorkoutEngine.live` — just enough to record
/// the configuration a start produces. `WatchWorkoutStoreTests` has the full
/// scriptable stub for the state machine; this one exists so the picker can be
/// followed all the way to what Santé would be handed.
private final class ConfigurationRecorder {
    private(set) var startedConfiguration: HKWorkoutConfiguration?

    func makeStore() -> WatchWorkoutStore {
        WatchWorkoutStore(engine: WorkoutEngine(
            isAvailable: { true },
            requestAuthorization: { _, _ in },
            startSession: { configuration, _, _, _ in
                self.startedConfiguration = configuration
                let token = NSObject()
                return WorkoutSessionHandle(
                    sessionID: ObjectIdentifier(token),
                    builderID: ObjectIdentifier(token),
                    startMirroring: {},
                    sendToRemote: { _ in },
                    end: { _ = token },
                    endCollection: { _ in },
                    finishWorkout: { _ in },
                    collectionEndDate: { nil }
                )
            }
        ), detection: WatchActivityDetection(source: .inert, pedometer: .inert), route: WatchRouteStore(source: .inert))
    }
}

/// The watch's home and « Autre sport » (issues #224, #743): what the home
/// screen's « Démarrer » starts, and what the picker records.
///
/// `WatchStartActivityTests` covers how the sport is resolved and
/// `WatchWorkoutStoreTests` covers the configuration once an activity is
/// passed. The link between them is `WatchIdleScreen`, which is a `View` — so
/// it is walked with `ViewTreeProbe`, the real screen and its real closures,
/// rather than a stand-in that is not what ships.
@Suite("Watch sport picker")
struct WatchActivityPickerTests {
    /// What the screen's closures did — a reference type so the `struct`
    /// test's escaping closures can record into it.
    final class Taps {
        var started: [SessionActivity] = []
        var chose = 0
        var cancelled = 0
    }

    /// The idle route as `WatchRootView` builds it, with the synced choice
    /// stubbed and every outcome recorded.
    private func idle(
        last: SessionActivity = .walking,
        favorites: Set<SportID> = [.walking, .running],
        isChoosingActivity: Bool = false,
        into taps: Taps
    ) -> WatchIdleScreen {
        let choice = SportChoice.Resolved(activity: last, sections: SportChoice.sections(favorites: favorites))
        return WatchIdleScreen(
            today: WatchTodayStore(),
            isChoosingActivity: isChoosingActivity,
            choice: { choice },
            onStart: { taps.started.append($0) },
            onChooseSport: { taps.chose += 1 },
            onCancel: { taps.cancelled += 1 }
        )
    }

    @Test("« Démarrer » starts the last sport in one tap, with no question", arguments: SessionActivity.allCases)
    func startStartsTheLastSport(last: SessionActivity) throws {
        let box = Taps()
        let screen = idle(last: last, into: box)
        // The home screen's own CTA closure, pulled out of the tree it ships
        // in: this is the tap, not a re-implementation of it.
        let home = try #require(ViewTreeProbe.first(WatchTodayView.self, in: screen.body))
        #expect(home.sport == last)
        home.onStart()

        #expect(box.started == [last])
        #expect(box.chose == 0)
    }

    @Test("« Autre sport » opens the picker and starts nothing")
    func otherSportOpensThePicker() throws {
        let box = Taps()
        let home = try #require(ViewTreeProbe.first(WatchTodayView.self, in: idle(into: box).body))
        try #require(ViewTreeProbe.first(WatchOtherSportButton.self, in: home.body)).choose()

        #expect(box.chose == 1)
        #expect(box.started.isEmpty)
    }

    @Test("The home screen is untouched until the picker is opened")
    func thePickerIsNotOnTheHomeScreen() {
        let box = Taps()
        let home = idle(into: box).body
        #expect(ViewTreeProbe.contains(WatchTodayView.self, in: home))
        #expect(ViewTreeProbe.contains(WatchActivityChoiceView.self, in: home) == false)

        let choosing = idle(isChoosingActivity: true, into: box).body
        #expect(ViewTreeProbe.contains(WatchActivityChoiceView.self, in: choosing))
        #expect(ViewTreeProbe.contains(WatchTodayView.self, in: choosing) == false)
    }

    @Test("Choosing « Course » on the wrist stamps the session as a run")
    func choosingRunningStampsARun() async throws {
        let box = Taps()
        let screen = idle(isChoosingActivity: true, into: box)
        let picker = try #require(ViewTreeProbe.first(WatchActivityChoiceView.self, in: screen.body))
        // The buttons live inside a `ForEach`, which keeps a closure instead
        // of its rows — building one is the only way to reach the real action.
        try #require(button(.running, picker)).select()
        #expect(box.started == [.running])

        // …and the end of the wire: the activity the button chose is what
        // HealthKit is configured with, which is verbatim what Santé keeps.
        let recorder = ConfigurationRecorder()
        let store = recorder.makeStore()
        await store.start(activity: try #require(box.started.first))
        #expect(recorder.startedConfiguration?.activityType == .running)
    }

    @Test("Choosing « Marche » stamps a walk, and the two buttons differ")
    func choosingWalkingStampsAWalk() async throws {
        let box = Taps()
        let screen = idle(isChoosingActivity: true, into: box)
        let picker = try #require(ViewTreeProbe.first(WatchActivityChoiceView.self, in: screen.body))
        try #require(button(.walking, picker)).select()
        #expect(box.started == [.walking])

        let recorder = ConfigurationRecorder()
        let store = recorder.makeStore()
        await store.start(activity: try #require(box.started.first))
        // Asserted separately from the run so a picker whose two buttons both
        // chose the same activity fails here rather than looking correct.
        #expect(recorder.startedConfiguration?.activityType == .walking)
    }

    @Test("The favourites come first, the other sports after, the last one marked")
    func favouritesFirst() throws {
        let box = Taps()
        let screen = idle(last: .running, favorites: [.running], isChoosingActivity: true, into: box)
        let picker = try #require(ViewTreeProbe.first(WatchActivityChoiceView.self, in: screen.body))

        #expect(picker.sections.favorites == [.running])
        #expect(picker.sections.others == [.walking, .hiking, .trailRunning])
        #expect(try #require(button(.running, picker)).isCurrent)
        #expect(try #require(button(.running, picker)).activity.label == "Course")
        #expect(try #require(button(.walking, picker)).isCurrent == false)
        #expect(try #require(button(.walking, picker)).activity.label == "Marche")
    }

    @Test("A mis-tap is recoverable: « Annuler » records nothing")
    func cancellingRecordsNothing() throws {
        let box = Taps()
        let screen = idle(isChoosingActivity: true, into: box)
        let picker = try #require(ViewTreeProbe.first(WatchActivityChoiceView.self, in: screen.body))
        // The button the screen builds, not the closure it was handed. On the
        // watch this is the only way back — there is nothing behind this screen
        // to swipe to.
        try #require(ViewTreeProbe.first(WatchActivityCancelButton.self, in: picker.body)).cancel()

        #expect(box.cancelled == 1)
        #expect(box.started.isEmpty)
    }

    @Test("The way out is the system's close button, not scrolled away with the answers")
    func cancelIsOutsideTheScrolledRegion() throws {
        let box = Taps()
        let screen = idle(isChoosingActivity: true, into: box)
        let picker = try #require(ViewTreeProbe.first(WatchActivityChoiceView.self, in: screen.body))
        let scrolled = try #require(scrolledRegion(of: picker.body))

        // The answers scroll: the crown is how the last ones are reached at
        // the larger Dynamic Type sizes.
        #expect(ViewTreeProbe.contains(
            ForEach<[SessionActivity], SessionActivity, WatchActivityChoiceButton>.self,
            in: scrolled
        ))
        // « Annuler » must not: it sits in the toolbar, as the system's close
        // button (ADR 0008).
        #expect(ViewTreeProbe.contains(WatchActivityCancelButton.self, in: scrolled) == false)
        #expect(ViewTreeProbe.contains(WatchActivityCancelButton.self, in: picker.body))
    }

    /// « Démarrer » is pinned below the scroll, on screen from the first
    /// glance (ADR 0008); « Autre sport », the secondary action, scrolls.
    @Test("« Démarrer » is pinned to the home, « Autre sport » scrolls with the figures")
    func startIsOutsideTheScrolledRegion() throws {
        let box = Taps()
        let screen = idle(into: box)
        let home = try #require(ViewTreeProbe.first(WatchTodayView.self, in: screen.body))
        let scrolled = try #require(scrolledRegion(of: home.body))

        #expect(ViewTreeProbe.contains(WatchStartButton.self, in: scrolled) == false)
        #expect(ViewTreeProbe.contains(WatchOtherSportButton.self, in: scrolled))
        let start = try #require(ViewTreeProbe.first(WatchStartButton.self, in: home.body))
        start.start()
        #expect(box.started == [.walking])
    }

    /// The part of the picker the crown can push off the screen.
    ///
    /// Matched on the type's name because a `ScrollView`'s type spells out the
    /// whole of its content — naming it would mean rewriting the layout inside
    /// the test on every tweak, which is how a structural pin stops pinning
    /// anything.
    private func scrolledRegion(of value: Any, depth: Int = 24) -> Any? {
        if String(describing: type(of: value)).hasPrefix("ScrollView<") { return value }
        guard depth > 0 else { return nil }
        for child in Mirror(reflecting: value).children {
            if let found = scrolledRegion(of: child.value, depth: depth - 1) { return found }
        }
        return nil
    }

    private func button(
        _ activity: SessionActivity,
        _ picker: WatchActivityChoiceView
    ) -> WatchActivityChoiceButton? {
        ViewTreeProbe.forEachRow(
            activity,
            of: ForEach<[SessionActivity], SessionActivity, WatchActivityChoiceButton>.self,
            in: picker.body
        )
    }
}
