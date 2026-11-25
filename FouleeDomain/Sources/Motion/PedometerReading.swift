import Foundation

/// What the pedometer reports, flattened into values (issues #331, #726):
/// the steps and the distance since the stream opened, and the wearer's rhythm
/// right now.
///
/// The rhythm is Apple's own estimate, not ours: `CMPedometerData.currentCadence`
/// and `currentPace` are computed by the system from the accelerometer and
/// calibrated against the GPS of past outings. They replace a cadence this app
/// used to derive by dividing two `HKLiveWorkoutBuilder` sums read at the
/// moment they were *delivered* — and HealthKit delivers steps in uneven
/// batches, so a three-second window could hold two seconds of strides and
/// read a run as a walk.
nonisolated public struct PedometerReading: Codable, Equatable, Sendable {
    /// The end of the interval the reading describes — the pedometer's own
    /// timestamp, never the moment this process was told.
    public var date: Date
    /// Steps since the stream opened.
    public var steps: Int
    /// Metres since the stream opened, 0 when the device estimates none.
    public var distanceMeters: Double
    /// Steps per second, or `nil` when the pedometer had no opinion.
    public var cadence: Double?
    /// Seconds per metre, or `nil` when the pedometer had no opinion.
    public var pace: Double?

    public init(date: Date, steps: Int = 0, distanceMeters: Double = 0, cadence: Double? = nil, pace: Double? = nil) {
        self.date = date
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.cadence = cadence
        self.pace = pace
    }

    /// Metres per second, derived from `pace`. `nil` for a missing or
    /// non-positive pace, which a division would turn into infinity.
    public var speed: Double? {
        guard let pace, pace > 0 else { return nil }
        return 1 / pace
    }
}
