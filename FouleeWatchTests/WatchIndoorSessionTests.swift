import FouleeDomain
import Foundation
import HealthKit
import Testing
@testable import FouleeWatch

/// Strength, HIIT and yoga on the wrist (#745): an indoor workout, and no
/// location permission asked for.
@Suite("Indoor sessions on the watch")
struct WatchIndoorSessionTests {
    @Test("An indoor session is configured indoors under its own type", arguments: [
        (SessionActivity.strength, HKWorkoutActivityType.traditionalStrengthTraining),
        (.hiit, .highIntensityIntervalTraining),
        (.yoga, .yoga),
    ])
    func configuredIndoors(activity: SessionActivity, type: HKWorkoutActivityType) async {
        let stub = WorkoutHealthKitStub()
        await stub.makeStore(route: WatchRouteStore(source: .inert)).start(activity: activity)
        #expect(stub.startedConfiguration?.activityType == type)
        #expect(stub.startedConfiguration?.locationType == .indoor)
    }

    @Test("An indoor session never asks for the location, a walk does")
    func noLocationPrompt() async {
        let yogaRoute = FakeRouteSource()
        let yoga = WorkoutHealthKitStub().makeStore(route: WatchRouteStore(source: yogaRoute.source))
        await yoga.start(activity: .yoga)
        for _ in 0..<20 { await Task.yield() }
        #expect(yogaRoute.authorizationRequests == 0)
        #expect(yogaRoute.openedStreams == 0)

        let walkRoute = FakeRouteSource()
        let walk = WorkoutHealthKitStub().makeStore(route: WatchRouteStore(source: walkRoute.source))
        await walk.start(activity: .walking)
        await waitUntil { walkRoute.authorizationRequests == 1 }
        #expect(walkRoute.authorizationRequests == 1)
    }
}
