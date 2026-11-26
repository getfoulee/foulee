import FouleeDomain
import HealthKit

nonisolated extension RecordedActivity {
    /// Read `HKWorkout.workoutActivityType`.
    ///
    /// Total rather than optional, unlike `SessionActivity(_:)`: that one
    /// refuses to name a type Foulée does not record, because it feeds a
    /// *write* and a wrong stamp is permanent. This one feeds a label, and a
    /// session the app cannot classify still has to appear in the résumé — it
    /// happened, and hiding it would be a worse lie than calling it « Séance ».
    ///
    /// Separate file from the enum so `RecordedActivity` itself stays
    /// HealthKit-free, the same split `SessionActivity` / `SessionActivity+HealthKit`
    /// already uses.
    ///
    /// `metadata` carries Foulée's sport tag (#744): a trail run is a run in
    /// Santé, and only the tag tells it apart.
    init(_ type: HKWorkoutActivityType, metadata: [String: Any]?) {
        self.init(sport: SportID(
            healthKitActivityRawValue: type.rawValue,
            tag: metadata?[FouleeWorkoutMetadata.sport] as? String
        ))
    }
}
