import Foundation

/// The sport of the latest outing started from Foulée, and when (issue #743).
///
/// « Démarrer » starts it again in one tap. The iPhone and the watch each
/// remember their own and send it to the other (the watch's since #830);
/// each keeps the newer of the two, which is why the date travels with the
/// sport.
nonisolated public struct LastSport: Codable, Equatable, Sendable {
    public var sport: SportID
    public var startedAt: Date

    public init(sport: SportID, startedAt: Date) {
        self.sport = sport
        self.startedAt = startedAt
    }

    public init(_ activity: SessionActivity, at date: Date) {
        self.init(sport: activity.sport, startedAt: date)
    }

    /// The more recent of two, either of which may be missing.
    public static func newest(_ first: LastSport?, _ second: LastSport?) -> LastSport? {
        guard let first, let second else { return first ?? second }
        return second.startedAt > first.startedAt ? second : first
    }

    /// The key of the WatchConnectivity user info the watch sends the iPhone
    /// when a session starts on the wrist (#830).
    static let transferKey = "lastSport"

    /// What the watch hands `transferUserInfo`: the JSON under one key.
    public var transferUserInfo: [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return [Self.transferKey: data]
    }

    /// The last sport a user info carries; `nil` for any other user info, or
    /// for a sport a newer watch named and this iPhone cannot.
    public init?(transferUserInfo userInfo: [String: Any]) {
        guard let data = userInfo[Self.transferKey] as? Data,
              let last = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = last
    }
}

/// What « Démarrer » starts and how « Autre sport » lists the rest (issue
/// #743). Shared by the iPhone and the watch, so both offer the same sports
/// in the same order.
nonisolated public enum SportChoice {
    /// The sport « Démarrer » starts: the last one, when Foulée can still
    /// record it, or else the first favourite, or else walking, the app's
    /// original sport.
    public static func defaultActivity(last: LastSport?, favorites: Set<SportID>) -> SessionActivity {
        if let last, let activity = SessionActivity(sport: last.sport) { return activity }
        return SessionActivity.allCases.first { favorites.contains($0.sport) } ?? .walking
    }

    /// The recordable sports, favourites first, each group in the catalogue's
    /// order so a sport never moves between two visits.
    public static func sections(favorites: Set<SportID>) -> Sections {
        let sports = SessionActivity.allCases
        return Sections(
            favorites: sports.filter { favorites.contains($0.sport) },
            others: sports.filter { !favorites.contains($0.sport) }
        )
    }

    /// What « Démarrer » starts and what « Autre sport » lists, together.
    public static func resolve(last: LastSport?, favorites: Set<SportID>) -> Resolved {
        Resolved(activity: defaultActivity(last: last, favorites: favorites), sections: sections(favorites: favorites))
    }

    public struct Sections: Equatable, Sendable {
        public var favorites: [SessionActivity]
        public var others: [SessionActivity]
    }

    public struct Resolved: Equatable, Sendable {
        public var activity: SessionActivity
        public var sections: Sections

        public init(activity: SessionActivity, sections: Sections) {
            self.activity = activity
            self.sections = sections
        }
    }
}

/// Where a device keeps the last sport it started: JSON under one key, in the
/// iPhone's defaults or the watch's App Group. Never synced through iCloud.
nonisolated public enum LastSportPreference {
    public static let key = "preferences.lastSport"

    /// `nil` when nothing was stored, or when a newer build stored a sport
    /// this one cannot name.
    public static func read(from store: SettingsKeyValueStore) -> LastSport? {
        (store.object(forKey: key) as? Data).flatMap { try? JSONDecoder().decode(LastSport.self, from: $0) }
    }

    public static func write(_ last: LastSport, to store: SettingsKeyValueStore) {
        guard let data = try? JSONEncoder().encode(last) else { return }
        store.set(data, forKey: key)
    }

    /// The newer of `other`, the last sport the other device sent, and this
    /// device's own (#830). The one rule both sides apply.
    public static func newest(_ other: LastSport?, in store: SettingsKeyValueStore) -> LastSport? {
        LastSport.newest(read(from: store), other)
    }

    /// Keeps `other` when it is newer than this device's own; an older one
    /// never overwrites it (#830). Whether it was kept.
    @discardableResult
    public static func keep(_ other: LastSport, in store: SettingsKeyValueStore) -> Bool {
        let own = read(from: store)
        guard LastSport.newest(own, other) == other, own != other else { return false }
        write(other, to: store)
        return true
    }
}
