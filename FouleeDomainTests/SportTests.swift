import Foundation
import Testing
@testable import FouleeDomain

/// A sport is data (#720): these pin the walk and run descriptors to what the
/// app did before they existed, and demand every sport's answers.
@Suite("Sport")
struct SportTests {
    @Test("Raw values never change: they are stored and sent", arguments: SportID.allCases)
    func rawValuesAreStable(sport: SportID) {
        let expected: [SportID: String] = [
            .walking: "walking", .running: "running", .hiking: "hiking", .trailRunning: "trailRunning",
        ]
        #expect(sport.rawValue == expected[sport])
        #expect(sport.descriptor.id == sport)
    }

    @Test("Every sport has a label and a glyph of its own")
    func everySportIsDistinct() {
        let descriptors = SportID.allCases.map(\.descriptor)
        #expect(Set(descriptors.map(\.label)).count == descriptors.count)
        #expect(Set(descriptors.map(\.glyph)).count == descriptors.count)
        #expect(descriptors.allSatisfy { !$0.label.isEmpty })
    }

    @Test("A workout reads back as its sport through its type and Foulée's tag", arguments: SportID.allCases)
    func healthKitRoundTrip(sport: SportID) throws {
        let raw = sport.descriptor.healthKitActivityRawValue
        let tag = try #require(sport.workoutMetadata[FouleeWorkoutMetadata.sport] as? String)
        #expect(SportID(healthKitActivityRawValue: raw, tag: tag) == sport)
    }

    @Test("A trail is a run in Santé: without Foulée's tag it reads as a run")
    func trailWithoutTagIsARun() {
        #expect(SportID.trailRunning.descriptor.healthKitActivityRawValue == SportID.running.descriptor.healthKitActivityRawValue)
        #expect(SportID(healthKitActivityRawValue: 37) == .running)
        #expect(SportID(healthKitActivityRawValue: 37, tag: nil) == .running)
        // Another app's tag, or one naming a sport of another type, is ignored.
        #expect(SportID(healthKitActivityRawValue: 37, tag: "curling") == .running)
        #expect(SportID(healthKitActivityRawValue: 37, tag: "hiking") == .running)
    }

    @Test("Every other sport has a HealthKit type of its own")
    func healthKitTypesAreDistinctButForTrail() {
        let plain = SportID.allCases.filter { $0 != .trailRunning }.map(\.descriptor.healthKitActivityRawValue)
        #expect(Set(plain).count == plain.count)
        for sport in SportID.allCases where sport != .trailRunning {
            #expect(SportID(healthKitActivityRawValue: sport.descriptor.healthKitActivityRawValue) == sport)
        }
    }

    @Test("An unknown HealthKit type is no sport")
    func unknownHealthKitType() {
        #expect(SportID(healthKitActivityRawValue: 13) == nil) // cycling
    }

    @Test("A recordable sport has everything a session needs", arguments: SportID.allCases)
    func recordableSportsAreComplete(sport: SportID) {
        let descriptor = sport.descriptor
        guard descriptor.isRecordable else {
            #expect(SessionActivity(sport: sport) == nil)
            return
        }
        #expect(descriptor.sessionTitle != nil)
        #expect(descriptor.kcalPerStep != nil)
        #expect(SessionActivity(sport: sport)?.sport == sport)
    }

    @Test("Garmin names read back as their sport, and only recorded sports have one")
    func garminMapping() {
        #expect(SportID(garminSport: "walking") == .walking)
        #expect(SportID(garminSport: "running") == .running)
        // The Garmin app records walks and runs only (#748).
        #expect(SportID(garminSport: "hiking") == nil)
        #expect(SportID.hiking.descriptor.garminSport == nil)
        #expect(SportID.trailRunning.descriptor.garminSport == nil)
        #expect(SportID(garminSport: "cycling") == nil)
    }

    @Test("Walk and run keep the figures the app used before the descriptors")
    func walkAndRunUnchanged() {
        #expect(SessionActivity.walking.label == kitText("Marche"))
        #expect(SessionActivity.running.label == kitText("Course"))
        #expect(SessionActivity.walking.sessionTitle == kitText("Ta marche"))
        #expect(SessionActivity.running.sessionTitle == kitText("Ta course"))
        #expect(SessionActivity.walking.icon == ActivityGlyph.walk)
        #expect(SessionActivity.running.icon == ActivityGlyph.run)
        #expect(SessionActivity.walking.kcalPerStep == 0.04)
        #expect(SessionActivity.running.kcalPerStep == 0.09)
        for descriptor in [SportID.walking.descriptor, SportID.running.descriptor] {
            #expect(descriptor.family == .onFoot)
            #expect(descriptor.location == .outdoor)
            #expect(descriptor.speedDisplay == .pace)
            #expect(descriptor.capabilities == [.route, .steps, .elevation])
        }
    }

    @Test("Read-side names are unchanged, and .other is no sport")
    func recordedActivityUnchanged() {
        #expect(RecordedActivity.hiking.label == kitText("Randonnée"))
        #expect(RecordedActivity.hiking.icon == ActivityGlyph.hike)
        #expect(RecordedActivity.other.label == kitText("Séance"))
        #expect(RecordedActivity.other.icon == ActivityGlyph.mixedCardio)
        #expect(RecordedActivity.other.sport == nil)
        for sport in SportID.allCases {
            #expect(RecordedActivity(sport: sport).sport == sport)
        }
        #expect(RecordedActivity(sport: nil) == .other)
    }

    @Test("The benchmark rules come from the table: a hike leads with its climb and keeps its pace to itself")
    func benchmarkRules() {
        #expect(SportID.walking.descriptor.benchmarks == .paced)
        #expect(SportID.running.descriptor.benchmarks == .paced)
        #expect(SportID.hiking.descriptor.benchmarks == .climbing)
        #expect(RecordedActivity.other.benchmarks == .paced)
    }

    @Test("A hike and a trail are one sport from start to finish, told by their climb")
    func hikeAndTrailKeepOneSport() {
        for sport in [SportID.hiking, .trailRunning] {
            #expect(sport.descriptor.followsGaitChanges == false)
            #expect(sport.descriptor.benchmarks == .climbing)
            #expect(sport.descriptor.leadsWithClimb)
        }
        for sport in [SportID.walking, .running] {
            #expect(sport.descriptor.followsGaitChanges)
            #expect(sport.descriptor.leadsWithClimb == false)
        }
        #expect(SportID.hiking.descriptor.gait == .walk)
        #expect(SportID.trailRunning.descriptor.gait == .run)
    }

    @Test("Every sport has its own word inside a sentence")
    func nounsAreDistinct() {
        let nouns = SportID.allCases.map(\.descriptor.noun)
        #expect(Set(nouns).count == SportID.allCases.count)
        #expect(RecordedActivity.running.verb == "tu cours")
    }
}
