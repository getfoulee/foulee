import Clocks
import Dependencies
import FouleeHealth
import FouleeDomain
import Foundation
import Testing
@testable import Foulee

/// The outing on the iPhone's `HKWorkoutSession` (#729): who saves it, and
/// how one that outlived the app comes back.
@Suite("ActiveSessionStore session")
struct ActiveSessionStoreSessionTests {
    private let frozen = Date(timeIntervalSince1970: 1_700_000_000)

    /// A session double recording what it was asked, finishing with `saves`.
    private func session(
        saves: Bool,
        started: LockedRef<[String]>,
        finished: LockedRef<SessionRecord?>,
        recovered: RecoveredPhoneWorkout? = nil
    ) -> PhoneWorkoutSessionClient {
        PhoneWorkoutSessionClient(
            start: { activity, _ in started.set(started.value + [activity.rawValue]) },
            pause: {},
            resume: {},
            finish: { outing in
                finished.set(outing)
                return saves
            },
            recover: { recovered }
        )
    }

    private func healthKit(saved: LockedRef<SessionRecord?>) -> HealthKitClient {
        var client = HealthKitClient.testValue
        client.saveWorkout = { saved.set($0) }
        return client
    }

    @Test("The session opens with the sport the outing starts with")
    func startOpensTheSession() async {
        let started = LockedRef<[String]>([])
        let finished = LockedRef<SessionRecord?>(nil)
        await withDependencies {
            $0.date = .constant(frozen)
            $0.pedometer = .testValue
            $0.healthKit = .testValue
            $0.continuousClock = TestClock()
            $0.phoneWorkoutSession = session(saves: true, started: started, finished: finished)
        } operation: {
            let store = ActiveSessionStore()
            store.start(activity: .running)
            await store.stop()
            #expect(started.value == ["running"])
        }
    }

    @Test("An indoor session never touches the location, a walk does (#745)")
    func indoorSessionAsksNoLocation() async {
        let asked = LockedRef<[String]>([])
        let finished = LockedRef<SessionRecord?>(nil)
        await withDependencies {
            $0.date = .constant(frozen)
            $0.pedometer = .testValue
            $0.healthKit = .testValue
            $0.continuousClock = TestClock()
            $0.phoneWorkoutSession = session(saves: true, started: LockedRef([]), finished: finished)
            $0.location = LocationClient(
                requestWhenInUse: { asked.set(asked.value + ["request"]); return true },
                currentLocation: { nil },
                routeUpdates: {
                    asked.set(asked.value + ["route"])
                    return AsyncStream { $0.finish() }
                },
                access: { asked.set(asked.value + ["access"]); return .granted }
            )
        } operation: {
            let yoga = ActiveSessionStore()
            yoga.start(activity: .yoga)
            await yoga.stop()
            #expect(asked.value.isEmpty)
            #expect(yoga.degradedStates.isEmpty)

            let walk = ActiveSessionStore()
            walk.start(activity: .walking)
            #expect(asked.value.contains("route"))
            await walk.stop()
        }
    }

    @Test("When the session's builder saves the outing, it is not saved a second time")
    func sessionSavesOnce() async {
        let saved = LockedRef<SessionRecord?>(nil)
        let finished = LockedRef<SessionRecord?>(nil)
        await withDependencies {
            $0.date = .constant(frozen)
            $0.pedometer = .testValue
            $0.healthKit = healthKit(saved: saved)
            $0.continuousClock = TestClock()
            $0.phoneWorkoutSession = session(saves: true, started: LockedRef([]), finished: finished)
        } operation: {
            let store = ActiveSessionStore()
            store.start()
            await store.stop()
            #expect(finished.value?.startedAt == frozen)
            #expect(saved.value == nil)
            #expect(store.lastError == nil)
        }
    }

    @Test("Without a session that saved it, the outing is saved as before")
    func fallbackSave() async {
        let saved = LockedRef<SessionRecord?>(nil)
        await withDependencies {
            $0.date = .constant(frozen)
            $0.pedometer = .testValue
            $0.healthKit = healthKit(saved: saved)
            $0.continuousClock = TestClock()
            $0.phoneWorkoutSession = session(saves: false, started: LockedRef([]), finished: LockedRef(nil))
        } operation: {
            let store = ActiveSessionStore()
            store.start(activity: .running)
            await store.stop()
            #expect(saved.value?.activity == .running)
        }
    }

    @Test("A session that outlived the app comes back with its clock and steps")
    func adoptRecoveredSession() async throws {
        let recovered = RecoveredPhoneWorkout(
            startedAt: frozen.addingTimeInterval(-600),
            activity: .running,
            elapsed: 540,
            isPaused: false
        )
        await withDependencies {
            $0.date = .constant(frozen)
            var pedometer = PedometerClient.testValue
            pedometer.steps = { _, _ in 1_200 }
            $0.pedometer = pedometer
            $0.healthKit = .testValue
            $0.continuousClock = TestClock()
            $0.phoneWorkoutSession = session(
                saves: true, started: LockedRef([]), finished: LockedRef(nil), recovered: recovered
            )
        } operation: {
            let store = await ActiveSessionStore.recovered(minutesGoal: 20)
            guard case .active(let session) = store?.state else {
                Issue.record("expected an active outing, got \(String(describing: store?.state))")
                return
            }
            #expect(session.startedAt == recovered.startedAt)
            #expect(session.activity == .running)
            #expect(session.elapsed == 540)
            #expect(session.steps == 1_200)
        }
    }

    @Test("A session recovered while paused comes back paused")
    func adoptPausedSession() async {
        let recovered = RecoveredPhoneWorkout(
            startedAt: frozen.addingTimeInterval(-600),
            activity: .walking,
            elapsed: 300,
            isPaused: true
        )
        await withDependencies {
            $0.date = .constant(frozen)
            $0.pedometer = .testValue
            $0.healthKit = .testValue
            $0.continuousClock = TestClock()
            $0.phoneWorkoutSession = session(
                saves: true, started: LockedRef([]), finished: LockedRef(nil), recovered: recovered
            )
        } operation: {
            let store = await ActiveSessionStore.recovered(minutesGoal: 20)
            guard case .paused(let session) = store?.state else {
                Issue.record("expected a paused outing, got \(String(describing: store?.state))")
                return
            }
            #expect(session.elapsed == 300)
        }
    }

    @Test("No session to recover, no outing")
    func nothingToRecover() async {
        await withDependencies {
            $0.phoneWorkoutSession = .testValue
        } operation: {
            #expect(await ActiveSessionStore.recovered(minutesGoal: 20) == nil)
        }
    }
}
