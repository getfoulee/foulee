import FouleeDomain
import FouleeHealth
import Foundation
import HealthKit
import Testing
@testable import FouleeWatch

/// Rides on the wrist (#749): saved as rides, outdoors or indoors, told by a
/// speed in km/h rather than a pace.
@Suite("Rides on the watch")
struct WatchRideTests {
    @Test("A ride is saved as a ride, outdoors; an indoor one indoors, stamped as such")
    func savedUnderTheRightType() async {
        let ride = WorkoutHealthKitStub()
        await ride.makeStore().start(activity: .cycling)
        #expect(ride.startedConfiguration?.activityType == .cycling)
        #expect(ride.startedConfiguration?.locationType == .outdoor)
        #expect(ride.sportTags == ["cycling"])

        let indoor = WorkoutHealthKitStub()
        await indoor.makeStore(route: WatchRouteStore(source: .inert)).start(activity: .indoorCycling)
        #expect(indoor.startedConfiguration?.activityType == .cycling)
        #expect(indoor.startedConfiguration?.locationType == .indoor)
        #expect(indoor.sportTags == ["indoorCycling"])
    }

    @Test("A ride's live speed reads in km/h, and is not rounded like a pace")
    func speedNotPace() {
        var metrics = WatchWorkoutMetrics.empty(for: .cycling)
        metrics.recentPaceSecondsPerKm = 150
        #expect(metrics.activityHeadlineText == "\(SessionActivity.cycling.label) · 24\u{00A0}km/h")
        #expect(WatchWorkoutStore.quantised(pace: 147, for: .cycling) == 147)
        #expect(WatchWorkoutStore.quantised(pace: 303, for: .running) == 305)
    }

    @Test("A ride sums its distance under the cycling type")
    func cyclingDistance() {
        #expect(SportID.cycling.distanceTypeIdentifier == .distanceCycling)
        #expect(SportID.indoorCycling.distanceTypeIdentifier == .distanceCycling)
        #expect(SportID.running.distanceTypeIdentifier == .distanceWalkingRunning)
    }
}
