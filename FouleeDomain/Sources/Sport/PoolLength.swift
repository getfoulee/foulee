import Foundation

/// The length of the pool a swim is counted in (#751): HealthKit counts a lap
/// each time the watch sees the wearer turn, and adds this distance for it.
nonisolated public struct PoolLength: Equatable, Hashable, Sendable {
    public var meters: Double

    public init(meters: Double) {
        self.meters = meters
    }

    /// The pools most swum, offered first: 25 m, 50 m, 33 m and 25 yards.
    public static let presets = [
        PoolLength(meters: 25), PoolLength(meters: 50), PoolLength(meters: 100.0 / 3), PoolLength(meters: 22.86)
    ]
    /// Any other pool, chosen to the metre.
    public static let customRange: ClosedRange<Double> = 10...100
    /// Before a first swim: the commonest pool.
    public static let standard = PoolLength(meters: 25)

    /// « 25 m », « 33 m », « 25 yd ».
    public var label: String {
        if abs(meters - 22.86) < 0.01 { return kitText("25\u{00A0}yd") }
        return kitText("\(Int(meters.rounded()))\u{00A0}m")
    }

    /// The lengths swum over `distanceMeters`, as HealthKit adds a whole
    /// length at each one.
    public func laps(over distanceMeters: Double) -> Int {
        guard meters > 0 else { return 0 }
        return Int((distanceMeters / meters).rounded())
    }
}

/// Where the watch keeps the last pool length chosen, so the next swim starts
/// on it (#751).
nonisolated public enum PoolLengthPreference {
    public static let key = "preferences.poolLengthMeters"

    public static func read(from store: SettingsKeyValueStore) -> PoolLength {
        guard let meters = store.object(forKey: key) as? Double, PoolLength.customRange.contains(meters) else {
            return .standard
        }
        return PoolLength(meters: meters)
    }

    public static func write(_ length: PoolLength, to store: SettingsKeyValueStore) {
        store.set(length.meters, forKey: key)
    }
}

/// SWOLF, a swim's efficiency (#751): the seconds and the strokes a length
/// takes, added. Lower is better. `nil` before a first length.
nonisolated public func swolf(duration: TimeInterval, strokes: Int, laps: Int) -> Int? {
    guard laps > 0 else { return nil }
    return Int(((duration + Double(strokes)) / Double(laps)).rounded())
}
