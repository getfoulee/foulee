import FouleeKit
import HealthKit

nonisolated extension SportID {
    /// The one mapping between a sport and HealthKit's activity type (#720).
    ///
    /// The kit keeps the raw values in `SportDescriptor` so it stays free of
    /// HealthKit (ADR 0007); every read and write in the apps goes through
    /// these two members, so a new sport is one descriptor and no `switch`.
    var hkActivityType: HKWorkoutActivityType {
        // Every raw value in the table is a real case, pinned by
        // `SportIDHealthKitTests`; `.other` cannot be reached.
        HKWorkoutActivityType(rawValue: descriptor.healthKitActivityRawValue) ?? .other
    }

    init?(_ hkActivityType: HKWorkoutActivityType) {
        self.init(healthKitActivityRawValue: hkActivityType.rawValue)
    }
}
