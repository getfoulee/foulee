import FouleeHealth
import FouleeKit
import HealthKit
import Testing
@testable import Foulee

/// The one mapping between a sport and HealthKit's activity type (#720).
@Suite("Sport ↔ HealthKit")
struct SportIDHealthKitTests {
    @Test("Every sport has a real HealthKit type and reads back as itself", arguments: SportID.allCases)
    func roundTrip(sport: SportID) {
        #expect(sport.hkActivityType != .other)
        #expect(SportID(sport.hkActivityType) == sport)
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
