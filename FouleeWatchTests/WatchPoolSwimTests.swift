import FouleeDomain
import Foundation
import HealthKit
import Testing
@testable import FouleeWatch

/// A swim in a pool on the wrist (#751): the pool HealthKit counts lengths in,
/// the water lock, and lengths and SWOLF from the measures.
@Suite("Pool swims on the watch")
struct WatchPoolSwimTests {
    @Test("A pool swim is a swim in a pool of the chosen length, and locks the water out")
    func configuredInThePool() async {
        let stub = WorkoutHealthKitStub()
        let store = stub.makeStore(route: WatchRouteStore(source: .inert))
        var locked = 0
        store.lockWater = { locked += 1 }
        await store.start(activity: .poolSwimming, pool: PoolLength(meters: 50))
        #expect(stub.startedConfiguration?.activityType == .swimming)
        #expect(stub.startedConfiguration?.swimmingLocationType == .pool)
        #expect(stub.startedConfiguration?.lapLength?.doubleValue(for: .meter()) == 50)
        #expect(locked == 1)
        guard case .active(let metrics) = store.state else {
            Issue.record("expected the swim under way, got \(store.state)")
            return
        }
        #expect(metrics.pool == PoolLength(meters: 50))
    }

    @Test("A walk locks nothing and has no pool")
    func aWalkIsDry() async {
        let stub = WorkoutHealthKitStub()
        let store = stub.makeStore()
        var locked = 0
        store.lockWater = { locked += 1 }
        await store.start(activity: .walking)
        #expect(locked == 0)
        #expect(stub.startedConfiguration?.lapLength == nil)
    }

    @Test("Lengths and SWOLF come from the distance, the strokes and the time")
    func lengthsAndSwolf() {
        var metrics = WatchWorkoutMetrics.empty(for: .poolSwimming)
        metrics.pool = PoolLength(meters: 25)
        metrics.distanceMeters = 500
        metrics.strokes = 300
        metrics.elapsed = 600
        #expect(metrics.laps == 20)
        #expect(metrics.swolf == 45)
    }

    @Test("An open-water swim is a swim in open water, with its route and the water locked out (#752)")
    func openWater() async {
        let stub = WorkoutHealthKitStub()
        let store = stub.makeStore()
        var locked = 0
        store.lockWater = { locked += 1 }
        await store.start(activity: .openWaterSwimming)
        #expect(stub.startedConfiguration?.activityType == .swimming)
        #expect(stub.startedConfiguration?.swimmingLocationType == .openWater)
        #expect(stub.startedConfiguration?.lapLength == nil)
        #expect(stub.sportTags == ["openWaterSwimming"])
        #expect(locked == 1)
        guard case .active(let metrics) = store.state else {
            Issue.record("expected the swim under way, got \(store.state)")
            return
        }
        #expect(metrics.pool == nil)
    }

    @Test("An open-water pace reads per 100 m, rounded to 5 seconds")
    func pacePer100m() {
        var metrics = WatchWorkoutMetrics.empty(for: .openWaterSwimming)
        metrics.recentPaceSecondsPerKm = WatchWorkoutStore.quantised(pace: 1_237, for: .openWaterSwimming)
        #expect(metrics.recentPace == "2'05\"/100\u{00A0}m")
    }
}
