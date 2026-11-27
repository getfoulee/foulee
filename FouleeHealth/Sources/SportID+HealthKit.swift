import FouleeDomain
import HealthKit

nonisolated extension SportID {
    /// The one mapping between a sport and HealthKit's activity type (#720).
    ///
    /// The kit keeps the raw values in `SportDescriptor` so it stays free of
    /// HealthKit (ADR 0007); every read and write in the apps goes through
    /// these two members, so a new sport is one descriptor and no `switch`.
    public var hkActivityType: HKWorkoutActivityType {
        // Every raw value in the table is a real case, pinned by
        // `SportIDHealthKitTests`; `.other` cannot be reached.
        HKWorkoutActivityType(rawValue: descriptor.healthKitActivityRawValue) ?? .other
    }

    public init?(_ hkActivityType: HKWorkoutActivityType) {
        self.init(healthKitActivityRawValue: hkActivityType.rawValue)
    }

    /// The quantity a workout of this sport sums its distance under: the
    /// cycling one for a ride (#749), walking and running otherwise.
    public var distanceTypeIdentifier: HKQuantityTypeIdentifier {
        descriptor.family == .cycling ? .distanceCycling : .distanceWalkingRunning
    }
}
