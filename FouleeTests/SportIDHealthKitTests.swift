import FouleeHealth
import FouleeDomain
import HealthKit
import Testing

/// The one mapping between a sport and HealthKit's activity type (#720).
@Suite("Sport ↔ HealthKit")
struct SportIDHealthKitTests {
    @Test("Every sport has a real HealthKit type and reads back as itself", arguments: SportID.allCases)
    func roundTrip(sport: SportID) {
        #expect(sport.hkActivityType != .other)
        // A trail or a treadmill run is a run in Santé; only Foulée's tag
        // tells it apart (#744, #746).
        let tag = sport.workoutMetadata[FouleeWorkoutMetadata.sport] as? String
        #expect(SportID(healthKitActivityRawValue: sport.hkActivityType.rawValue, tag: tag) == sport)
        #expect(SportID(sport.hkActivityType) == ([SportID.trailRunning, .indoorRunning].contains(sport) ? .running : sport))
    }

    @Test("The table stamps the types HealthKit has always had for walk, run and hike")
    func knownTypes() {
        #expect(SportID.walking.hkActivityType == .walking)
        #expect(SportID.running.hkActivityType == .running)
        #expect(SportID.hiking.hkActivityType == .hiking)
    }

    @Test("A type Foulée cannot name is no sport")
    func unknownType() {
        #expect(SportID(HKWorkoutActivityType.cycling) == nil)
    }
}
