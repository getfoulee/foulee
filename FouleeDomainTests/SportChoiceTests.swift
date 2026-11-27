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
        #expect(sections.others == [
            .walking, .trailRunning, .strength, .hiit, .yoga, .rowing, .elliptical, .indoorRunning,
            .cycling, .indoorCycling, .poolSwimming, .openWaterSwimming,
        ])
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

    @Test("The watch's last sport crosses to the iPhone as user info, and nothing else reads as one (#830)")
    func transferRoundTrip() {
        let last = LastSport(sport: .indoorRunning, startedAt: Self.later)
        #expect(LastSport(transferUserInfo: last.transferUserInfo) == last)
        #expect(LastSport(transferUserInfo: [:]) == nil)
        #expect(LastSport(transferUserInfo: ["lastSport": "running"]) == nil)
        let unknown = Data(#"{"sport":"curling","startedAt":0}"#.utf8)
        #expect(LastSport(transferUserInfo: ["lastSport": unknown]) == nil)
    }

    @Test("A newer last sport from the other device is kept, an older one never overwrites (#830)")
    func keepTheNewer() {
        let store = Store()
        let own = LastSport(sport: .walking, startedAt: Self.earlier)
        LastSportPreference.write(own, to: store)

        let older = LastSport(sport: .yoga, startedAt: Self.earlier.addingTimeInterval(-60))
        #expect(LastSportPreference.keep(older, in: store) == false)
        #expect(LastSportPreference.read(from: store) == own)
        #expect(LastSportPreference.keep(own, in: store) == false)

        let newer = LastSport(sport: .running, startedAt: Self.later)
        #expect(LastSportPreference.newest(newer, in: store) == newer)
        #expect(LastSportPreference.keep(newer, in: store))
        #expect(LastSportPreference.read(from: store) == newer)
        #expect(LastSportPreference.keep(LastSport(sport: .hiking, startedAt: Self.earlier), in: Store()))
    }

    @Test("Ticking adds a favourite, unticking removes it, but never the last one (#835)")
    func toggling() {
        #expect(SportChoice.toggling(.hiking, in: [.walking]) == [.walking, .hiking])
        #expect(SportChoice.toggling(.walking, in: [.walking, .hiking]) == [.hiking])
        #expect(SportChoice.toggling(.hiking, in: [.hiking]) == [.hiking])
    }

    @Test("The iPhone offers an outdoor ride but no indoor one (#749, #750)")
    func indoorRidesStayOnTheWatch() {
        let phone = SportChoice.sections(favorites: [.indoorCycling, .cycling, .running], on: .phone)
        #expect(phone.favorites == [.running, .cycling])
        #expect(!phone.others.contains(.indoorCycling))
        let indoor = LastSport(sport: .indoorCycling, startedAt: Self.later)
        #expect(SportChoice.defaultActivity(last: indoor, favorites: [.running], on: .phone) == .running)
        #expect(SportChoice.defaultActivity(last: indoor, favorites: [.running], on: .watch) == .indoorCycling)
    }
}
