import Foundation

/// Where the favourite sports are stored, and how a store written by an
/// earlier build is brought up to date (issue #731).
///
/// The favourite sports replace the walk / run / both mode, which cannot name
/// a third sport. The mode is still written beside them, derived, for the
/// readers that speak in modes and for an older build on another iPhone that
/// pulls these settings from iCloud.
nonisolated public enum FavoriteSportsPreference {
    /// The favourite sports, as an array of `SportID` raw values.
    public static let key = "preferences.favoriteSports"
    /// The mode every build before #731 read and wrote, kept up to date.
    public static let modeKey = "preferences.activityMode"
    /// The version of the stored preferences' layout.
    public static let schemaVersionKey = "preferences.schemaVersion"
    /// 1: favourite sports (#731). Absent: the mode alone.
    public static let schemaVersion = 1

    /// Brings `store` to `schemaVersion`. Idempotent: running it again on a
    /// store it already migrated writes nothing.
    ///
    /// It also catches an older build's change. That build writes the mode
    /// alone and, through iCloud, leaves the favourites it does not know as
    /// they were. A mode that disagrees with them is therefore newer, and the
    /// favourites follow it.
    public static func migrate(_ store: SettingsKeyValueStore) {
        let version = store.object(forKey: schemaVersionKey) as? Int ?? 0
        let mode = (store.object(forKey: modeKey) as? String).flatMap(ActivityMode.init(rawValue:))
        let stored = storedSports(in: store)
        if version < schemaVersion || stored == nil {
            store.set(rawValues(of: (mode ?? .walking).favoriteSports), forKey: key)
            store.set(schemaVersion, forKey: schemaVersionKey)
        } else if let mode, let stored, ActivityMode(favorites: stored) != mode {
            store.set(rawValues(of: mode.favoriteSports), forKey: key)
        }
    }

    /// The favourite sports in `store`. A sport this build does not know is
    /// skipped rather than failing the read; none left reads as walking.
    public static func favoriteSports(in store: SettingsKeyValueStore) -> Set<SportID> {
        let sports = storedSports(in: store) ?? []
        return sports.isEmpty ? [.walking] : sports
    }

    /// Writes `sports` under `key`, keeping any stored sport this build does
    /// not know: a newer build on another iPhone chose it, and this one must
    /// not erase it each time it applies what iCloud brought.
    public static func write(_ sports: Set<SportID>, to store: SettingsKeyValueStore) {
        let unknown = (store.object(forKey: key) as? [String] ?? []).filter { SportID(rawValue: $0) == nil }
        store.set(rawValues(of: sports, keeping: unknown), forKey: key)
    }

    /// Sorted, so the same set always stores the same array and iCloud sees no
    /// change where there is none.
    static func rawValues(of sports: Set<SportID>, keeping unknown: [String] = []) -> [String] {
        Set(sports.map(\.rawValue) + unknown).sorted()
    }

    private static func storedSports(in store: SettingsKeyValueStore) -> Set<SportID>? {
        (store.object(forKey: key) as? [String]).map { Set($0.compactMap(SportID.init(rawValue:))) }
    }
}
