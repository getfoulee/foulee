import FouleeDomain
@preconcurrency import HealthKit

/// The legs of an outing Santé already holds, read back when a session left
/// running is picked up (issue #554), and the builder reads `ingest` makes.
///
/// The session itself is `WorkoutEngine`'s, shared with the iPhone (#730);
/// what is here only the watch does, because only the watch splits an outing
/// into legs.
extension WatchWorkoutSegment {
    /// The legs Santé already holds for `outingID`, oldest first, with the
    /// totals the screen sums. Nothing on a failed read: the outing goes on
    /// from the leg in flight.
    static func saved(of outingID: UUID) async -> [WatchWorkoutSegment] {
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: FouleeWorkoutMetadata.outingID,
            allowedValues: [outingID.uuidString]
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let workouts = try? await descriptor.result(for: HKHealthStore()) else { return [] }
        return workouts.map(segment(of:))
    }

    /// One saved leg as the store counts it.
    nonisolated static func segment(of workout: HKWorkout) -> WatchWorkoutSegment {
        func sum(_ identifier: HKQuantityTypeIdentifier, in unit: HKUnit) -> Double {
            workout.statistics(for: HKQuantityType(identifier))?.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
        let activity = SessionActivity(workout.workoutActivityType) ?? .walking
        return WatchWorkoutSegment(
            id: workout.uuid,
            activity: activity,
            start: workout.startDate,
            end: workout.endDate,
            steps: Int(sum(.stepCount, in: .count())),
            distanceMeters: sum(activity.sport.distanceTypeIdentifier, in: .meter()),
            activeCalories: Int(sum(.activeEnergyBurned, in: .kilocalorie())),
            pausedDuration: max(0, workout.endDate.timeIntervalSince(workout.startDate) - workout.duration)
        )
    }
}

nonisolated extension HKWorkoutBuilder {
    /// What the builder has summed for `identifier` so far, or 0 before the
    /// first sample.
    func sum(of identifier: HKQuantityTypeIdentifier, in unit: HKUnit) -> Double {
        statistics(for: HKQuantityType(identifier))?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    /// The latest discrete sample for `identifier` — `nil` until the sensor has
    /// spoken, which the screen shows as a dash rather than a zero.
    func mostRecent(of identifier: HKQuantityTypeIdentifier, in unit: HKUnit) -> Double? {
        statistics(for: HKQuantityType(identifier))?.mostRecentQuantity()?.doubleValue(for: unit)
    }
}
