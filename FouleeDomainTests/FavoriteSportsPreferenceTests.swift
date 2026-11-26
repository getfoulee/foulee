import Foundation
import Testing
@testable import FouleeDomain

/// The walk / run / both mode becomes a set of favourite sports (#731).
@Suite("Favourite sports preference")
struct FavoriteSportsPreferenceTests {
    /// A key-value store that counts its writes, so idempotence is observable.
    private final class Store: SettingsKeyValueStore {
        var values: [String: Any] = [:]
        var writes = 0

        func object(forKey key: String) -> Any? { values[key] }
        func set(_ value: Any?, forKey key: String) {
            writes += 1
            values[key] = value
        }
        func removeObject(forKey key: String) {
            writes += 1
            values[key] = nil
        }
    }

    private typealias Preference = FavoriteSportsPreference

    private func store(mode: String?) -> Store {
        let store = Store()
        if let mode { store.values[Preference.modeKey] = mode }
        return store
    }

    /// Spelled out rather than read from `ActivityMode.favoriteSports`, which
    /// the migration itself uses.
    private static let expectedSports: [String: Set<SportID>] = [
        "walking": [.walking],
        "running": [.running],
        "both": [.walking, .running],
    ]

    @Test("Each stored mode migrates to the sports it stands for", arguments: ["walking", "running", "both"])
    func migratesEveryMode(mode: String) throws {
        let expected = try #require(Self.expectedSports[mode])
        let store = store(mode: mode)
        Preference.migrate(store)
        #expect(Preference.favoriteSports(in: store) == expected)
        #expect(store.values[Preference.schemaVersionKey] as? Int == Preference.schemaVersion)
        // The mode itself is left as it was: older builds still read it.
        #expect(store.values[Preference.modeKey] as? String == mode)
    }

    @Test("A store that never chose, or holds a mode no build wrote, migrates to walking", arguments: [nil, "swimming"])
    func migratesMissingModeToWalking(mode: String?) {
        let store = store(mode: mode)
        Preference.migrate(store)
        #expect(store.values[Preference.key] as? [String] == ["walking"])
        #expect(store.values[Preference.schemaVersionKey] as? Int == 1)
    }

    @Test("Migrating twice writes nothing the second time")
    func idempotent() {
        let store = store(mode: "both")
        Preference.migrate(store)
        let writes = store.writes
        Preference.migrate(store)
        #expect(store.writes == writes)
        #expect(store.values[Preference.key] as? [String] == ["running", "walking"])
    }

    @Test("A mode an older build changed through iCloud wins over the stale favourites")
    func olderBuildChangeWins() {
        let store = store(mode: "both")
        Preference.migrate(store)
        store.values[Preference.modeKey] = "running"
        Preference.migrate(store)
        #expect(Preference.favoriteSports(in: store) == [.running])
    }

    @Test("A sport this build does not know is skipped; none left reads as walking")
    func tolerantRead() {
        let store = Store()
        store.values[Preference.key] = ["running", "cycling"]
        #expect(Preference.favoriteSports(in: store) == [.running])
        store.values[Preference.key] = ["cycling"]
        #expect(Preference.favoriteSports(in: store) == [.walking])
    }

    @Test("A newer build's unknown sport survives the migration")
    func keepsUnknownSportOnAgreement() {
        let store = Store()
        store.values[Preference.key] = ["cycling", "running"]
        store.values[Preference.modeKey] = "running"
        store.values[Preference.schemaVersionKey] = 1
        Preference.migrate(store)
        #expect(store.values[Preference.key] as? [String] == ["cycling", "running"])
    }

    @Test("Mode and favourites read back as each other", arguments: ActivityMode.allCases)
    func roundTrip(mode: ActivityMode) {
        #expect(ActivityMode(favorites: mode.favoriteSports) == mode)
    }

    @Test("A sport the mode cannot name falls back to the mode of the others")
    func modeOfWiderSets() {
        #expect(ActivityMode(favorites: [.hiking]) == .walking)
        #expect(ActivityMode(favorites: [.running, .hiking]) == .running)
        #expect(ActivityMode(favorites: []) == .walking)
    }

    @Test("The stored array is sorted, so one set always stores the same value")
    func sortedRawValues() {
        #expect(Preference.rawValues(of: [.running, .walking, .hiking]) == ["hiking", "running", "walking"])
    }

    @Test("Writing the favourites keeps a sport only a newer build knows")
    func writeKeepsUnknownSports() {
        let store = Store()
        store.values[Preference.key] = ["cycling", "walking"]
        Preference.write([.running], to: store)
        #expect(store.values[Preference.key] as? [String] == ["cycling", "running"])
    }

    @Test("The favourites are offered to a background reader only once migrated")
    func migratedFavouritesOnly() {
        let store = store(mode: "running")
        // Before the first launch of a build that migrates, the mode is the
        // only answer: reading the favourites would say walking.
        #expect(Preference.migratedFavoriteSports(in: store) == nil)
        Preference.migrate(store)
        #expect(Preference.migratedFavoriteSports(in: store) == [.running])
    }
}
