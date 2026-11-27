import FouleeDomain
import Foundation
import Testing
@testable import FouleeWatch

/// « Commencer une sortie » on the watch (issue #607): a named sport starts
/// it, and an empty one does what « Démarrer » does: the last sport (#743).
@Suite("Watch start outing intent")
struct WatchStartOutingIntentTests {
    /// A throwaway suite, like `WatchStartActivityTests`: the real one is the
    /// shared app group, which every other suite reads.
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "watch-start-outing-intent-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    private func payload(_ mode: ActivityMode) -> WatchSyncPayload {
        WatchSyncPayload(streak: 3, minutesGoal: 20, stepsGoal: 6_000, activityMode: mode)
    }

    @Test("A named sport wins over the synced mode")
    func aNamedSportWins() throws {
        try withDefaults { defaults in
            WatchSyncStore.write(payload(.walking), to: defaults)
            #expect(StartOutingIntent.activity(for: .running, syncedTo: defaults) == .running)
        }
    }

    @Test("No sport named, or « Dernier sport », starts what « Démarrer » would")
    func noSportFollowsTheHomeButton() throws {
        try withDefaults { defaults in
            WatchSyncStore.write(payload(.running), to: defaults)
            #expect(StartOutingIntent.activity(for: nil, syncedTo: defaults) == .running)
            #expect(StartOutingIntent.activity(for: .last, syncedTo: defaults) == .running)
        }
    }

    @Test("The Action button offers the last sport first, then one workout per sport")
    func theActionButtonOffersTheLastSportFirst() {
        let styles = StartWorkoutOutingIntent.suggestedWorkouts.map(\.workoutStyle)
        #expect(styles.first == .last)
        #expect(styles.dropFirst().compactMap(\.activity) == SessionActivity.allCases)
    }

    @Test("Every sport keeps its raw value, so saved shortcuts still resolve (#747)")
    func rawValuesFollowTheSports() {
        #expect(WatchOutingActivity(rawValue: "last") == .last)
        for activity in SessionActivity.allCases {
            #expect(WatchOutingActivity(rawValue: activity.rawValue)?.activity == activity)
        }
    }
}
