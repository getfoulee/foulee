import Dependencies
import FouleeDomain
import Foundation
import Testing
@testable import Foulee

/// The phone's half of issue #223: what a session started from the Today
/// screen is stamped with, and how that choice reaches the wrist.
///
/// Every hop below could be reverted with the whole suite green before these
/// existed — the preference resolving to an activity, the activity mode riding
/// in the Watch payload, and the settings change being noticed at all. The one
/// hop no test can hold is the `HKWorkoutConfiguration` itself
/// (`HealthKitClient.liveValue` builds a real `HKWorkoutBuilder`); it is
/// covered by `SessionActivityTests.healthKitMapping` on one side and
/// `ActiveSessionStoreTests.stopSavesTheStartedActivity` on the other, which meet
/// at `SessionRecord.activity`.
@Suite("TodayStore activity")
struct TodayStoreActivityTests {
    /// Runs `body` with preferences backed by a throwaway suite, so nothing
    /// leaks into `.standard` or between suites running in parallel.
    private func withPreferences(_ body: (UserPreferences) async throws -> Void) async throws {
        let suiteName = "TodayStoreActivityTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try await body(UserPreferences(defaults: defaults))
    }

    @Test("« Démarrer » starts the first favourite until a sport was started")
    func startActivityFollowsTheFavourites() async throws {
        try await withPreferences { preferences in
            let store = TodayStore()

            // One gesture, no question: the favourites already answer it
            // (issues #224, #743). This is what `TodayScreen` hands
            // `ActiveSessionScreen`, which the live client turns into
            // `HKWorkoutConfiguration.activityType`.
            preferences.activityMode = .walking
            store.apply(preferences: preferences)
            #expect(store.startActivity == .walking)

            preferences.activityMode = .running
            store.apply(preferences: preferences)
            #expect(store.startActivity == .running)

            // « Les deux » no longer asks (#743): walking comes first.
            preferences.activityMode = .both
            store.apply(preferences: preferences)
            #expect(store.startActivity == .walking)
        }
    }

    @Test("« Démarrer » starts the last sport started, without recomputing the streak")
    func startActivityFollowsTheLastSport() async throws {
        try await withDependencies {
            $0.date = .constant(Date(timeIntervalSince1970: 1_800_000_000))
        } operation: {
            try await withPreferences { preferences in
                preferences.activityMode = .both
                let store = TodayStore()
                store.apply(preferences: preferences)

                preferences.recordStart(of: .running)
                // A start moves no counter: no recompute, no widget reload.
                // The refresh after the outing carries it to the wrist.
                #expect(!store.hasChanged(preferences: preferences))
                store.apply(preferences: preferences)
                #expect(store.startActivity == .running)
                #expect(store.lastSport == LastSport(.running, at: Date(timeIntervalSince1970: 1_800_000_000)))
            }
        }
    }

    @Test("A sport started on the wrist becomes the iPhone's « Démarrer », an older one does not (#830)")
    func watchLastSportReachesTheHome() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try await withDependencies {
            $0.date = .constant(now)
        } operation: {
            let suiteName = "TodayStoreActivityTests-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let preferences = UserPreferences(defaults: defaults)
            preferences.activityMode = .both
            preferences.recordStart(of: .walking)
            let store = TodayStore()

            // What `PhoneWatchSync` does with the watch's user info.
            let run = LastSport(sport: .running, startedAt: now.addingTimeInterval(600))
            #expect(LastSportPreference.keep(run, in: defaults))
            preferences.reloadLastSport()
            store.apply(preferences: preferences)
            #expect(store.startActivity == .running)

            let older = LastSport(sport: .yoga, startedAt: now.addingTimeInterval(-600))
            #expect(LastSportPreference.keep(older, in: defaults) == false)
            preferences.reloadLastSport()
            store.apply(preferences: preferences)
            #expect(store.startActivity == .running)
        }
    }

    @Test("Choosing a sport in « Quel sport ? » names it on the buttons and starts nothing (#832)")
    func choosingNamesTheSport() async throws {
        try await withDependencies {
            $0.date = .constant(Date(timeIntervalSince1970: 1_800_000_000))
        } operation: {
            try await withPreferences { preferences in
                preferences.activityMode = .walking
                let store = TodayStore()
                store.apply(preferences: preferences)

                store.chosenSport = .yoga
                #expect(store.startActivity == .yoga)
                // Not the last sport until an outing starts.
                #expect(preferences.lastSport == nil)
                store.apply(preferences: preferences)
                #expect(store.startActivity == .yoga)
            }
        }
    }

    @Test("A start, on the iPhone or the watch, records the sport once and forgets the pick (#832)")
    func oneStartRecordsOnce() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try await withDependencies {
            $0.date = .constant(now)
        } operation: {
            try await withPreferences { preferences in
                preferences.activityMode = .walking
                let store = TodayStore()
                store.apply(preferences: preferences)
                store.chosenSport = .rowing

                #expect(store.beginStart(requested: nil, preferences: preferences) == .rowing)
                #expect(preferences.lastSport == LastSport(.rowing, at: now))
                #expect(store.chosenSport == nil)
                // The last sport now names it on the buttons.
                #expect(store.startActivity == .rowing)

                // A shortcut's sport wins over a pick, and is the one recorded.
                store.chosenSport = .yoga
                #expect(store.beginStart(requested: .running, preferences: preferences) == .running)
                #expect(preferences.lastSport == LastSport(.running, at: now))
                #expect(store.startActivity == .running)
            }
        }
    }

    @Test("A shortcut starts the sport it names, else what the home button would")
    func shortcutStartActivity() async throws {
        try await withPreferences { preferences in
            let store = TodayStore()
            preferences.activityMode = .walking
            store.apply(preferences: preferences)

            // Issue #604: « Commence une course » from a walker records a run.
            #expect(store.startActivity(requested: .running) == .running)
            // No sport named, or « Dernier sport »: the home button's.
            #expect(store.startActivity(requested: nil) == .walking)
            #expect(store.startActivity(requested: OutingActivity.automatic.activity) == .walking)
        }
    }

    @Test("« Dernier sport » in Raccourcis names no sport, the others theirs")
    func outingActivities() {
        #expect(OutingActivity.walking.activity == .walking)
        #expect(OutingActivity.running.activity == .running)
        #expect(OutingActivity.automatic.activity == nil)
    }

    @Test("Raccourcis names every sport Foulée records, by its own raw value (#747)")
    func everySportHasAShortcutValue() {
        let named = OutingActivity.allCases.compactMap(\.activity)
        // The iPhone's sports: an outdoor ride since #750, an indoor one never.
        #expect(named == SportChoice.recordable(on: .phone))
        #expect(named.contains(.cycling) && !named.contains(.indoorCycling))
        // Shortcuts saved before #747 keep the values they were saved with.
        #expect(OutingActivity(rawValue: "walking") == .walking)
        #expect(OutingActivity(rawValue: "running") == .running)
        #expect(OutingActivity(rawValue: "automatic") == .automatic)
    }

    @Test("The Watch payload carries the mode, not a default")
    func watchPayloadCarriesTheActivityMode() async throws {
        try await withDependencies {
            // Publication reads the clock unconditionally since #214.
            $0.date = .constant(.now)
            $0.healthKit.dailyMinutes = StreakTestSupport.windowed {
                StreakTestSupport.walkedDays([0])
            }
        } operation: {
            try await withPreferences { preferences in
                preferences.activeDays = Set(Weekday.allCases)
                preferences.activityMode = .running
                let store = TodayStore()
                store.apply(preferences: preferences)
                await store.refresh()

                // The only channel the watch has: it owns no settings screen,
                // so a payload that defaulted this field leaves the wrist
                // stamping walks forever, whatever the phone is set to.
                let publication = try #require(store.widgetPublication(stored: nil))
                #expect(publication.watchPayload?.activityMode == .running)
                // And the favourites themselves, which the mode cannot all name (#831).
                #expect(publication.watchPayload?.favoriteSports == [.running])
            }
        }
    }

    @Test("The app-group snapshot carries the mode, so the widgets can draw it")
    func widgetSnapshotCarriesTheActivityMode() async throws {
        try await withDependencies {
            $0.date = .constant(.now)
            $0.healthKit.dailyMinutes = StreakTestSupport.windowed {
                StreakTestSupport.walkedDays([0])
            }
        } operation: {
            try await withPreferences { preferences in
                preferences.activeDays = Set(Weekday.allCases)
                preferences.activityMode = .running
                let store = TodayStore()
                store.apply(preferences: preferences)
                await store.refresh()

                // Same argument as the watch payload above, for the iPhone
                // widgets: the widget process cannot read `UserDefaults
                // .standard`, so this snapshot is its only sight of the
                // preference. Without the field, a runner's Home Screen keeps
                // showing whatever glyph was hardcoded (issue #222).
                let publication = try #require(store.widgetPublication(stored: nil))
                #expect(publication.snapshot.activityMode == .running)

                // And it is not carried forward from what was there before: a
                // mode is mirrored, never measured, so a stored snapshot from
                // an older preference must not win.
                let stale = WidgetSnapshot.placeholder
                #expect(stale.activityMode == .walking)
                let republished = try #require(store.widgetPublication(stored: stale))
                #expect(republished.snapshot.activityMode == .running)
            }
        }
    }

    @Test("Switching only the activity mode re-syncs the Today screen")
    func theModeIsPartOfTheTodayScreenTaskKey() async throws {
        try await withPreferences { preferences in
            // `TodayScreen` calls `apply` from `.task(id: todayPreferencesKey(…))`,
            // so this key is what decides whether a settings change is seen at
            // all in the session it was made. Without the mode in it, a user
            // who turns « les deux » on in Réglages taps start and is *not*
            // asked — the store still mirrors the mode it read at mount — and
            // every refresh re-publishes that stale mode to the wrist, so the
            // watch does not ask either (issue #224).
            var keys: Set<String> = []
            for mode in ActivityMode.allCases {
                preferences.activityMode = mode
                keys.insert(todayPreferencesKey(preferences))
            }
            // One distinct key per mode: two modes sharing one means the
            // switch between them is invisible to `.task(id:)`.
            #expect(keys.count == ActivityMode.allCases.count)
        }
    }

    @Test("Switching only the activity mode counts as a change worth publishing")
    func changingOnlyTheActivityModeIsNoticed() async throws {
        try await withPreferences { preferences in
            preferences.activityMode = .walking
            let store = TodayStore()
            store.apply(preferences: preferences)
            #expect(store.activityMode == .walking)

            // Nothing else moves: same goals, same days, same window, same
            // hydration. The mode moves no counter — it only picks the glyph
            // and the session's activity type — so a publish is the only
            // effect a change of it can have, and `hasChanged` is what allows
            // one. Without this clause the user switches to "course" in
            // Réglages, taps start on the watch, and still records a walk
            // until some unrelated refresh happens to push a payload.
            preferences.activityMode = .running
            #expect(store.hasChanged(preferences: preferences))

            store.apply(preferences: preferences)
            #expect(store.activityMode == .running)
            #expect(store.startActivity == .running)
            // And it settles: a preference set that already matches publishes
            // nothing.
            #expect(!store.hasChanged(preferences: preferences))
        }
    }
}
