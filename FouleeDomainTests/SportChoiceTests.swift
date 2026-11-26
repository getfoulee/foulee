import Foundation
import Testing
@testable import FouleeDomain

/// « Démarrer » restarts the last sport, « Autre sport » lists the rest (#743).
@Suite("Sport choice")
struct SportChoiceTests {
    private final class Store: SettingsKeyValueStore {
        var values: [String: Any] = [:]

        func object(forKey key: String) -> Any? { values[key] }
        func set(_ value: Any?, forKey key: String) { values[key] = value }
        func removeObject(forKey key: String) { values[key] = nil }
    }

    private static let earlier = Date(timeIntervalSince1970: 1_800_000_000)
    private static let later = earlier.addingTimeInterval(3_600)

    @Test("The last sport wins over the favourites")
    func lastSportWins() {
        let last = LastSport(sport: .running, startedAt: Self.earlier)
        #expect(SportChoice.defaultActivity(last: last, favorites: [.walking]) == .running)
    }

    @Test("Without a last sport, the first favourite starts")
    func firstFavourite() {
        #expect(SportChoice.defaultActivity(last: nil, favorites: [.running]) == .running)
        #expect(SportChoice.defaultActivity(last: nil, favorites: [.walking, .running]) == .walking)
    }

    @Test("No favourite starts a walk, a hike favourite a hike")
    func walkingFallback() {
        #expect(SportChoice.defaultActivity(last: nil, favorites: []) == .walking)
        #expect(SportChoice.defaultActivity(last: nil, favorites: [.hiking]) == .hiking)
    }

    @Test("Favourites come first, then every other recordable sport")
    func sections() {
        let sections = SportChoice.sections(favorites: [.running, .hiking])
        #expect(sections.favorites == [.running, .hiking])
        #expect(sections.others == [.walking, .trailRunning])
        let all = SportChoice.sections(favorites: Set(SportID.allCases))
        #expect(all.favorites == SessionActivity.allCases)
        #expect(all.others.isEmpty)
    }

    @Test("The newer of two last sports is kept, whichever side it comes from")
    func newest() throws {
        let old = LastSport(sport: .walking, startedAt: Self.earlier)
        let new = LastSport(sport: .running, startedAt: Self.later)
        #expect(LastSport.newest(old, new) == new)
        #expect(LastSport.newest(new, old) == new)
        #expect(LastSport.newest(nil, old) == old)
        #expect(LastSport.newest(old, nil) == old)
        #expect(LastSport.newest(nil, nil) == nil)
    }

    @Test("The stored last sport reads back")
    func roundTrip() throws {
        let store = Store()
        #expect(LastSportPreference.read(from: store) == nil)
        let last = LastSport(sport: .running, startedAt: Self.later)
        LastSportPreference.write(last, to: store)
        #expect(LastSportPreference.read(from: store) == last)
    }

    @Test("A sport only a newer build knows reads as none")
    func unknownSport() throws {
        let store = Store()
        store.values[LastSportPreference.key] = Data(#"{"sport":"curling","startedAt":0}"#.utf8)
        #expect(LastSportPreference.read(from: store) == nil)
    }
}
