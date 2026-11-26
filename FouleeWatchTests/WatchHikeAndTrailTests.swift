import FouleeDomain
import Foundation
import HealthKit
import Testing
@testable import FouleeWatch

/// A hike and a trail on the wrist (#744): one sport from start to finish,
/// saved under the right type and stamped so that a trail reads back as one.
@Suite("Hike and trail on the watch")
struct WatchHikeAndTrailTests {
    private let base = ManualClock.origin

    @Test("A hike is saved as a hike, a trail as a run stamped trail")
    func savedUnderTheRightType() async {
        let hike = WorkoutHealthKitStub()
        await hike.makeStore().start(activity: .hiking)
        #expect(hike.startedConfiguration?.activityType == .hiking)
        #expect(hike.sportTags == ["hiking"])

        let trail = WorkoutHealthKitStub()
        await trail.makeStore().start(activity: .trailRunning)
        // HealthKit has no trail type: Santé records a run.
        #expect(trail.startedConfiguration?.activityType == .running)
        #expect(trail.sportTags == ["trailRunning"])
    }

    @Test("A hike that breaks into a run on the flat stays one hike")
    func aHikeIgnoresTheGait() async {
        let stub = WorkoutHealthKitStub()
        let motion = FakeMotionSource()
        motion.isAvailable = true
        let store = stub.makeStore(detection: WatchActivityDetection(source: motion.source, pedometer: .inert))
        await store.start(activity: .hiking)
        await waitUntil { motion.isStreaming }
        for offset in stride(from: 60.0, through: 240, by: 30) {
            motion.deliver(motionEstimate(startDate: base.addingTimeInterval(offset), running: true))
        }
        for _ in 0..<20 { await Task.yield() }
        await store.splitIfDue(at: base.addingTimeInterval(600))

        guard case .active(let metrics) = store.state else {
            Issue.record("expected the hike still under way, got \(store.state)")
            return
        }
        #expect(metrics.activity == .hiking)
        #expect(stub.startedLegs.count == 1)
    }

    @Test("A trail's pace is rounded like a run's, a hike's like a walk's")
    func paceRounding() {
        #expect(WatchWorkoutStore.quantised(pace: 303, for: .trailRunning) == 305)
        #expect(WatchWorkoutStore.quantised(pace: 303, for: .running) == 305)
        #expect(WatchWorkoutStore.quantised(pace: 303, for: .hiking) == 300)
    }
}
