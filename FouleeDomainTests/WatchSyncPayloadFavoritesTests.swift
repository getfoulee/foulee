import Foundation
import Testing
@testable import FouleeDomain

/// The favourite sports travel to the watch as themselves, not as the walk /
/// run / both mode, which turns every other sport into walking (#831).
@Suite("Watch payload favourite sports")
struct WatchSyncPayloadFavoritesTests {
    private func decode(_ json: String) throws -> WatchSyncPayload {
        try JSONDecoder().decode(WatchSyncPayload.self, from: Data(json.utf8))
    }

    @Test("The favourites round-trip, a sport the mode cannot name included")
    func roundTrip() throws {
        let payload = WatchSyncPayload(
            streak: 3,
            minutesGoal: 20,
            stepsGoal: 6_000,
            activityMode: .running,
            favoriteSports: [.hiking, .running]
        )
        let read = try JSONDecoder().decode(WatchSyncPayload.self, from: JSONEncoder().encode(payload))
        #expect(read.favoriteSports == [.hiking, .running])
        #expect(read.favorites == [.hiking, .running])
    }

    @Test("A payload from an iPhone older than #831 reads its favourites from the mode")
    func olderPayloadFallsBackToTheMode() throws {
        let read = try decode(#"{"streak":3,"minutesGoal":20,"stepsGoal":6000,"activityMode":"both"}"#)
        #expect(read.favoriteSports == nil)
        #expect(read.favorites == [.walking, .running])
    }

    @Test("A sport only a newer iPhone knows is skipped, not fatal")
    func unknownSportIsSkipped() throws {
        let read = try decode(
            #"{"streak":3,"minutesGoal":20,"stepsGoal":6000,"activityMode":"running","favoriteSports":["curling","running"]}"#
        )
        #expect(read.streak == 3)
        #expect(read.favorites == [.running])
    }

    @Test("Only unknown sports read as none, and the mode stands for them")
    func onlyUnknownSportsFallBack() throws {
        let read = try decode(
            #"{"streak":3,"minutesGoal":20,"stepsGoal":6000,"activityMode":"running","favoriteSports":["curling"]}"#
        )
        #expect(read.favoriteSports == nil)
        #expect(read.favorites == [.running])
    }
}
