import Foundation

/// What the phone pushes to the Watch. The streak is computed on the phone —
/// the single source of truth — because the watch's local HealthKit only keeps
/// a few days of history, so recomputing there undercounts long streaks. The
/// goals ride along for the watch UI. Sent via WatchConnectivity application
/// context; persisted on the watch so it survives relaunches.
nonisolated public struct WatchSyncPayload: Codable, Sendable {
    public var streak: Int
    public var minutesGoal: Int
    public var stepsGoal: Int
    // Hydration: whether the feature is on, and the goal / glass size so the
    // watch can show the same card.
    public var hydrationEnabled: Bool
    public var hydrationGoalML: Int
    public var hydrationGlassML: Int
    /// The user's walk/run choice. The watch has no settings screen of its
    /// own, so this is the only way it can know what to stamp a session with
    /// (issue #223) — without it every watch session stays a walk, whatever
    /// the phone is set to. Both producers push it, including the background
    /// one: a payload that defaulted it would silently reset the watch to
    /// walking on the first Health wake.
    ///
    /// Kept for a watch older than #831, which reads the favourites from it.
    public var activityMode: ActivityMode
    /// The favourite sports (#831), which the mode cannot all name: it turns
    /// any sport but walking and running into walking. `nil` from an iPhone
    /// older than #831, or from a background wake before the first launch
    /// migrated the preferences.
    public var favoriteSports: Set<SportID>?
    /// The iPhone's last sport (#743). The watch starts the newer of this one
    /// and its own. Both producers push it, for the same reason as the mode.
    public var lastSport: LastSport?
    /// Whether the watch records each outing's sensors for the detection
    /// tests (#727): a hidden switch on the iPhone, off for everyone else.
    public var recordsDetectionTraces: Bool

    public init(
        streak: Int,
        minutesGoal: Int,
        stepsGoal: Int,
        hydrationEnabled: Bool = false,
        hydrationGoalML: Int = 2_000,
        hydrationGlassML: Int = 250,
        activityMode: ActivityMode = .walking,
        favoriteSports: Set<SportID>? = nil,
        lastSport: LastSport? = nil,
        recordsDetectionTraces: Bool = false
    ) {
        self.streak = streak
        self.minutesGoal = minutesGoal
        self.stepsGoal = stepsGoal
        self.hydrationEnabled = hydrationEnabled
        self.hydrationGoalML = hydrationGoalML
        self.hydrationGlassML = hydrationGlassML
        self.activityMode = activityMode
        self.favoriteSports = favoriteSports
        self.lastSport = lastSport
        self.recordsDetectionTraces = recordsDetectionTraces
    }

    // Tolerant decoding: payloads written before hydration (or before the
    // activity mode) shipped lack those keys — fall back to defaults instead
    // of failing the whole decode (which would briefly blank the streak after
    // an update).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streak = try container.decode(Int.self, forKey: .streak)
        minutesGoal = try container.decode(Int.self, forKey: .minutesGoal)
        stepsGoal = try container.decode(Int.self, forKey: .stepsGoal)
        hydrationEnabled = try container.decodeIfPresent(Bool.self, forKey: .hydrationEnabled) ?? false
        hydrationGoalML = try container.decodeIfPresent(Int.self, forKey: .hydrationGoalML) ?? 2_000
        hydrationGlassML = try container.decodeIfPresent(Int.self, forKey: .hydrationGlassML) ?? 250
        activityMode = try container.decodeIfPresent(ActivityMode.self, forKey: .activityMode) ?? .walking
        // A sport only a newer build of the iPhone knows is skipped; none
        // left reads as absent, and the mode stands for the favourites.
        let sports = (try? container.decodeIfPresent([String].self, forKey: .favoriteSports))?
            .compactMap(SportID.init(rawValue:))
        favoriteSports = sports.flatMap { $0.isEmpty ? nil : Set($0) }
        // A sport only a newer build of the iPhone knows reads as none.
        lastSport = try? container.decodeIfPresent(LastSport.self, forKey: .lastSport)
        recordsDetectionTraces = try container.decodeIfPresent(Bool.self, forKey: .recordsDetectionTraces) ?? false
    }
}

nonisolated public extension WatchSyncPayload {
    /// The favourite sports the watch offers first: the ones sent, or the
    /// mode's for a payload without them.
    var favorites: Set<SportID> {
        favoriteSports ?? activityMode.favoriteSports
    }
}

/// Watch-side persistence of the last payload received from the phone. Stored
/// in the shared app group so both the watch app (which writes it on receipt)
/// and the watch widget extension (a separate process) read the same value.
nonisolated public enum WatchSyncStore {
    private static let key = "watch.sync.payload"
    private static let suiteName = "group.com.eno33.foulee"

    /// Not private: it is the default every call site below binds, and the
    /// value a caller that owns its own default argument has to name to keep
    /// production behaviour (see `WatchRootView.sportChoice`).
    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // The `defaults` parameter is a test seam: production call sites rely on
    // the default (the app-group suite); tests inject an isolated suite.
    public static func write(_ payload: WatchSyncPayload, to defaults: UserDefaults = Self.sharedDefaults) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    public static func read(from defaults: UserDefaults = Self.sharedDefaults) -> WatchSyncPayload? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WatchSyncPayload.self, from: data)
    }
}
