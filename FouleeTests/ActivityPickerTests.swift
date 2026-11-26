import Clocks
import Dependencies
import FouleeHealth
import FouleeDomain
import FouleeLiveActivityModel
import SwiftUI
import Testing
@testable import Foulee

/// What the phone records a session as (issues #224, #246, #743): the sport
/// the user started, never overruled by what the device measured, which only
/// prices the energy.
///
/// The tree is walked with `ViewTreeProbe` rather than testing a stand-in, so
/// what is asserted is the screen that ships, `@State` store and all.
@Suite("Session sport (iPhone)")
struct ActivityPickerTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func screen(
        _ activity: SessionActivity,
        store: ActiveSessionStore = ActiveSessionStore()
    ) -> ActiveSessionScreen {
        ActiveSessionScreen(minutesGoal: 20, activity: activity, store: store, onDismiss: { _ in })
    }

    private func session(of store: ActiveSessionStore) -> SessionRecord? {
        guard case .active(let session) = store.state else { return nil }
        return session
    }

    /// Runs `body` with every sensor the store touches on `start` stubbed —
    /// the same set `ActiveSessionStoreTests` uses, so nothing here reaches a
    /// real pedometer, altimeter or Santé.
    private func withStubbedSensors(
        history: MotionActivityClient = .testValue,
        pedometer: PedometerClient = .testValue,
        _ body: () async throws -> Void
    ) async rethrows {
        try await withDependencies {
            $0.date = .constant(start)
            $0.pedometer = pedometer
            $0.healthKit = .testValue
            $0.motionActivity = history
            $0.continuousClock = TestClock()
        } operation: {
            try await body()
        }
    }

    /// A pedometer that answers every interval with one step per second — so a
    /// stretch's step count *is* its duration, and the arithmetic below is
    /// readable.
    private var countingPedometer: PedometerClient {
        PedometerClient(
            isRhythmAvailable: { false },
            openStream: { _, _ in },
            closeStream: {},
            steps: { from, to in Int(to.timeIntervalSince(from)) }
        )
    }

    // MARK: - The sport started is the sport recorded

    @Test("The screen starts the sport it was handed, and names it on the Lock Screen")
    func theStartedSportIsRecorded() async {
        for activity in SessionActivity.allCases {
            let store = ActiveSessionStore()
            await withStubbedSensors {
                screen(activity, store: store).startSession()
            }
            #expect(session(of: store)?.activity == activity)
            #expect(store.liveActivityAttributes(minutesGoal: 20).activity == activity)
        }
    }

    // MARK: - What the device measured prices, never relabels

    /// A history the test writes: `walking` for the first `runningAfter`
    /// seconds, running from there to the end.
    private func history(runningAfter: TimeInterval) -> MotionActivityClient {
        MotionActivityClient(
            isAvailable: { true },
            openStream: { _ in },
            closeStream: {},
            history: { from, _ in
                [
                    MotionHistorySample(startDate: from, confidence: .high, walking: true, running: false),
                    MotionHistorySample(
                        startDate: from.addingTimeInterval(runningAfter),
                        confidence: .high,
                        walking: false,
                        running: true
                    )
                ]
            }
        )
    }

    private func walk(endingAfter seconds: TimeInterval) -> SessionRecord {
        var session = SessionRecord(startedAt: start, activity: .walking)
        session.endedAt = start.addingTimeInterval(seconds)
        return session
    }

    @Test("A session the user chose the sport of is handed back with that sport")
    func aChosenSessionIsNeverOverridden() async {
        let store = ActiveSessionStore()
        var decided: SessionRecord?
        // A history that screams « course » from end to end.
        await withStubbedSensors(history: history(runningAfter: 0)) {
            decided = await store.settled(walk(endingAfter: 1_800))
        }
        // « Marche » is an answer already given. Overriding it would also
        // over-credit: kcalPerStep is 0.09 running against 0.04.
        #expect(decided?.activity == .walking)
    }
}

extension ActivityPickerTests {
    // MARK: - What the outing cost (issue #247)

    @Test("A mixed outing is broken down stretch by stretch, and keeps its label")
    func aMixedOutingIsBrokenDown() async {
        let store = ActiveSessionStore()
        var settled: SessionRecord?
        await withStubbedSensors(history: history(runningAfter: 600), pedometer: countingPedometer) {
            settled = await store.settled(walk(endingAfter: 1_800))
        }
        // Ten minutes walking, twenty running — one step per second. « Marche »
        // stays the label: the user said so.
        #expect(settled?.stepsByActivity == [.walking: 600, .running: 1_200])
        #expect(settled?.activity == .walking)
    }

    @Test("A homogeneous outing is not broken down at all")
    func aHomogeneousOutingIsLeftAlone() async {
        let store = ActiveSessionStore()
        var settled: SessionRecord?
        // Running from the first second: one stretch, one rate.
        await withStubbedSensors(history: history(runningAfter: 0), pedometer: countingPedometer) {
            settled = await store.settled(walk(endingAfter: 1_800))
        }
        // The breakdown would price it identically, so the queries would buy
        // nothing — and `estimatedCalories` must land on exactly the figure it
        // always did.
        #expect(settled?.stepsByActivity == nil)
    }

    @Test("A pedometer that will not answer leaves the old estimate alone")
    func anUnanswerablePedometerDeclines() async {
        let store = ActiveSessionStore()
        var settled: SessionRecord?
        // `testValue`'s `steps` returns nil — no step counting on this device.
        await withStubbedSensors(history: history(runningAfter: 600)) {
            settled = await store.settled(walk(endingAfter: 1_800))
        }
        // A partial breakdown is not a smaller truth, it is a wrong total: the
        // unmeasured stretch's steps would vanish from the estimate.
        #expect(settled?.stepsByActivity == nil)
    }
}
