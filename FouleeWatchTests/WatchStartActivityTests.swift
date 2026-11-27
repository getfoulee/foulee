import FouleeDomain
import Foundation
import Testing
@testable import FouleeWatch

/// The watch's half of the phone→wrist wire (issue #223).
///
/// `WatchWorkoutStoreTests` proves the `activity` argument is honoured once
/// passed; these prove the watch actually *reads* the mode the phone synced.
/// Without them the watch could ignore the phone entirely — replacing the read
/// with a plain `.walking` left the watch suite green.
///
/// What the start *button* does with it is one hop further out, in
/// `WatchActivityPickerTests` (issues #224, #743).
@Suite("Watch start activity")
struct WatchStartActivityTests {
    /// Runs `body` against a throwaway suite, like `WatchSyncStoreTests`: the
    /// real one is the shared app group, which every other suite reads.
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "watch-start-activity-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    private static let earlier = Date(timeIntervalSince1970: 1_800_000_000)
    private static let later = earlier.addingTimeInterval(3_600)

    private func payload(_ mode: ActivityMode, last: LastSport? = nil) -> WatchSyncPayload {
        WatchSyncPayload(streak: 3, minutesGoal: 20, stepsGoal: 6_000, activityMode: mode, lastSport: last)
    }

    @Test("A synced running mode starts a run, in one gesture")
    func runningModeStartsARun() throws {
        try withDefaults { defaults in
            // The full wire, through `WatchSyncStore`'s own storage: what the
            // receiver persists on a phone push is what the start button reads.
            WatchSyncStore.write(payload(.running), to: defaults)
            #expect(WatchRootView.sportChoice(syncedTo: defaults).activity == .running)
        }
    }

    @Test("« Les deux » starts a walk until a sport was started, and asks nothing")
    func bothStartsTheFirstFavourite() throws {
        try withDefaults { defaults in
            WatchSyncStore.write(payload(.both), to: defaults)
            let choice = WatchRootView.sportChoice(syncedTo: defaults)
            #expect(choice.activity == .walking)
            #expect(choice.sections.favorites == [.walking, .running])
        }
    }

    @Test("The iPhone's last sport starts on the wrist")
    func thePhonesLastSportStarts() throws {
        try withDefaults { defaults in
            WatchSyncStore.write(payload(.walking, last: LastSport(sport: .running, startedAt: Self.earlier)), to: defaults)
            #expect(WatchRootView.sportChoice(syncedTo: defaults).activity == .running)
        }
    }

    @Test("The newer of the wrist's last sport and the iPhone's starts")
    func theNewerLastSportWins() throws {
        try withDefaults { defaults in
            WatchSyncStore.write(payload(.both, last: LastSport(sport: .running, startedAt: Self.earlier)), to: defaults)
            WatchRootView.recordStart(of: .walking, at: Self.later, in: defaults)
            #expect(WatchRootView.sportChoice(syncedTo: defaults).activity == .walking)

            let newer = LastSport(sport: .running, startedAt: Self.later.addingTimeInterval(60))
            WatchSyncStore.write(payload(.both, last: newer), to: defaults)
            #expect(WatchRootView.sportChoice(syncedTo: defaults).activity == .running)
        }
    }

    @Test("The favourites sent win over the mode")
    func theFavouritesSentWin() throws {
        try withDefaults { defaults in
            // A mode that disagrees, as an iPhone writes for a third sport the
            // mode cannot name: the favourites are what the wrist offers.
            var sent = payload(.walking)
            sent.favoriteSports = [.running]
            WatchSyncStore.write(sent, to: defaults)
            let choice = WatchRootView.sportChoice(syncedTo: defaults)
            #expect(choice.activity == .running)
            #expect(choice.sections.favorites == [.running])
            #expect(choice.sections.others == [
                .walking, .hiking, .trailRunning, .strength, .hiit, .yoga, .rowing, .elliptical, .indoorRunning,
            ])
        }
    }

    @Test("A watch that never received a payload starts a walk")
    func freshPairingStartsAWalk() throws {
        try withDefaults { defaults in
            // Fresh pairing, or a phone not opened since the update. Walking is
            // the app's historical behaviour, and a wrong stamp is permanent.
            #expect(WatchSyncStore.read(from: defaults) == nil)
            #expect(WatchRootView.sportChoice(syncedTo: defaults).activity == .walking)
        }
    }

    @Test("A newer mode from the phone wins")
    func laterPushWins() throws {
        try withDefaults { defaults in
            // Read at tap time, not at view build: the phone can push while the
            // home screen sits on the wrist.
            WatchSyncStore.write(payload(.walking), to: defaults)
            WatchSyncStore.write(payload(.running), to: defaults)
            #expect(WatchRootView.sportChoice(syncedTo: defaults).activity == .running)
        }
    }
}
