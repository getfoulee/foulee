import Foundation
import Testing
@testable import FouleeDomain

/// The Bilan sport by sport (#742).
@Suite("Recap sport by sport")
struct RecapSportTotalsTests {
    /// Wednesday 2024-05-29 12:00 UTC: mid-week in every time zone, so a test
    /// outing a few hours on stays in the same week.
    private static let anchor = Date(timeIntervalSince1970: 1_716_984_000)

    private func workout(
        _ activity: RecordedActivity,
        at startMinutes: Double,
        minutes: Double,
        km: Double,
        climb: Double = 0,
        legs: [WorkoutSummary] = []
    ) -> WorkoutSummary {
        let start = Self.anchor.addingTimeInterval(startMinutes * 60)
        return WorkoutSummary(
            id: UUID(),
            startedAt: start,
            endedAt: start.addingTimeInterval(minutes * 60),
            durationSeconds: minutes * 60,
            distanceKm: km,
            activeCalories: 0,
            elevationMeters: climb,
            sourceName: "Foulée",
            activity: activity,
            legs: legs
        )
    }

    @Test("One sport gives no breakdown: its totals are the period's")
    func singleSportIsEmpty() {
        let walks = [workout(.walking, at: 0, minutes: 30, km: 2.5), workout(.walking, at: 600, minutes: 40, km: 3)]
        #expect(Recap.sportTotals(of: walks).isEmpty)
    }

    @Test("Each sport adds up its outings, time, distance and climb, the most time first")
    func sportsAddUp() throws {
        let outings = [
            workout(.walking, at: 0, minutes: 30, km: 2.5),
            workout(.walking, at: 600, minutes: 40, km: 3),
            workout(.hiking, at: 1_400, minutes: 260, km: 12.5, climb: 640),
            workout(.running, at: 3_000, minutes: 35, km: 6),
        ]

        let sports = Recap.sportTotals(of: outings)

        #expect(sports.map(\.activity) == [.hiking, .walking, .running])
        let walking = try #require(sports.first { $0.activity == .walking })
        #expect(walking.outings == 2)
        #expect(walking.durationSeconds == 70 * 60)
        #expect(walking.distanceKm == 5.5)
        #expect(try #require(sports.first).climbMeters == 640)
    }

    @Test("A mixed outing counts for each of its sports and splits by its legs")
    func mixedOutingSplitsByLegs() throws {
        let walk = workout(.walking, at: 0, minutes: 10, km: 0.8)
        let run = workout(.running, at: 10, minutes: 20, km: 4)
        let mixed = workout(.walking, at: 0, minutes: 30, km: 4.8, legs: [walk, run])

        let sports = Recap.sportTotals(of: [mixed])

        let running = try #require(sports.first)
        #expect(running.activity == .running)
        #expect(running.outings == 1)
        #expect(running.durationSeconds == 20 * 60)
        #expect(running.distanceKm == 4)
        #expect(try #require(sports.last).outings == 1)
    }

    @Test("Recap.make fills the breakdown for the period alone")
    func makeKeepsThePeriod() {
        let calendar = Calendar.iso8601Monday
        let period = RecapPeriod.containing(Self.anchor, .week, calendar: calendar)
        let inside = [workout(.walking, at: 60, minutes: 30, km: 2.5), workout(.running, at: 120, minutes: 30, km: 5)]
        let before = workout(.hiking, at: -10_000, minutes: 200, km: 10)

        let recap = Recap.make(
            period: period,
            from: Recap.Inputs(workouts: inside + [before]),
            goalMinutes: 20,
            activeDays: [],
            calendar: calendar
        )

        #expect(Set(recap.sports.map(\.activity)) == [.walking, .running])
    }
}
