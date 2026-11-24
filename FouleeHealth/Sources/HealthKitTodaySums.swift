import FouleeKit
import Foundation
@preconcurrency import HealthKit

/// Today's HealthKit sums, read the same way by the app, its widgets, the
/// watch and its complications (issue #785). HealthKit stays out of the kit
/// (ADR 0007), so they live in FouleeHealth, which each of those targets links
/// (issue #725).
///
/// One error policy for every caller: "no samples yet" (`errorNoData`) is a
/// real 0; any other failure (locked device, no authorization) stays a failure
/// — thrown, or nil — and never turns into a 0 that would overwrite a known
/// value.
nonisolated public enum HealthKitTodaySums {
    /// Today's counters. A nil leg is a read HealthKit refused: the caller
    /// keeps the value it already has rather than publishing a zero.
    public struct Counters: Sendable {
        public var steps: Int?
        public var minutes: Int?
        public var distanceKm: Double?
        public var calories: Int?
        public var waterML: Int?

        public init() {}
    }

    /// Today's cumulative sum of `identifier`, from midnight to now.
    public static func sum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        store: HKHealthStore
    ) async throws -> Double {
        let start = Calendar.current.startOfDay(for: .now)
        return try await sum(identifier, unit: unit, in: DateInterval(start: start, end: .now), store: store)
    }

    /// The cumulative sum of `identifier` over the samples started in `window`.
    public static func sum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        in window: DateInterval,
        store: HKHealthStore
    ) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: window.start,
            end: window.end,
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: HKQuantityType(identifier),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if isNoDataAvailable(error) {
                    continuation.resume(returning: 0)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    /// `sum`, or nil when HealthKit can't answer.
    public static func sumIfAvailable(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        store: HKHealthStore
    ) async -> Double? {
        try? await sum(identifier, unit: unit, store: store)
    }

    /// Today's total of `metric`, from its HealthKit quantity and in its
    /// display unit.
    public static func sum(_ metric: MetricID, store: HKHealthStore) async throws -> Double {
        try await sum(metric.quantityIdentifier, unit: metric.healthKitUnit, store: store)
    }

    /// `sum(_:store:)`, or nil when HealthKit can't answer.
    public static func sumIfAvailable(_ metric: MetricID, store: HKHealthStore) async -> Double? {
        try? await sum(metric, store: store)
    }

    /// The five counters the rings and widgets draw, read concurrently so a
    /// widget provider or a background wake stays inside its time budget.
    ///
    /// The minutes take the same max() as the app (see `ActiveMinutes`), so a
    /// Garmin-only user's minutes match the hero ring. Both legs must answer:
    /// merging a failed workout read as 0 would overwrite that user's merged
    /// minutes with raw zeros. `workoutMinutes` lets the app add the Garmin
    /// outings Santé doesn't have yet, which only its process can read.
    public static func counters(
        store: HKHealthStore,
        workoutMinutes: @escaping @Sendable (HKHealthStore) async throws -> Int = {
            try await HealthKitTodaySums.todayWorkoutMinutes(store: $0)
        }
    ) async -> Counters {
        async let steps = sumIfAvailable(.steps, store: store)
        async let minutes = sumIfAvailable(.minutes, store: store)
        async let distanceKm = sumIfAvailable(.distance, store: store)
        async let kcal = sumIfAvailable(.calories, store: store)
        async let water = sumIfAvailable(.dietaryWater, unit: .literUnit(with: .milli), store: store)
        async let workouts = try? workoutMinutes(store)
        var counters = Counters()
        counters.steps = (await steps).map { Int($0) }
        if let minutes = await minutes, let workouts = await workouts {
            counters.minutes = ActiveMinutes.merged(appleMinutes: Int(minutes), workoutMinutes: workouts)
        }
        counters.distanceKm = await distanceKm
        counters.calories = (await kcal).map { Int($0) }
        counters.waterML = (await water).map { Int($0) }
        return counters
    }

    /// Today's workout minutes from Santé alone (any activity type, attributed
    /// by `startDate`).
    public static func todayWorkoutMinutes(store: HKHealthStore) async throws -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let intervals = try await workoutIntervals(store: store, start: start, end: .now)
        return ActiveMinutes.workoutMinutesByDay(intervals, calendar: calendar)[start] ?? 0
    }

    /// All `HKWorkout`s started in `start..<end`, any activity type, reduced to
    /// the pure `WorkoutInterval` shape. Workouts are sparse — a plain
    /// `HKSampleQuery` over a whole streak window is trivial.
    public static func workoutIntervals(
        store: HKHealthStore,
        start: Date,
        end: Date
    ) async throws -> [ActiveMinutes.WorkoutInterval] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if isNoDataAvailable(error) {
                    continuation.resume(returning: [])
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts.map {
                    ActiveMinutes.WorkoutInterval(start: $0.startDate, duration: $0.duration)
                })
            }
            store.execute(query)
        }
    }
}

/// `HKError.Code.noDataAvailable` (= 11) is the framework's way of saying
/// "your predicate matched zero samples". Empty result, not a real failure —
/// callers bubble it back as the type-appropriate zero value.
nonisolated public func isNoDataAvailable(_ error: (any Error)?) -> Bool {
    guard let hkError = error as? HKError else { return false }
    return hkError.code == .errorNoData
}

nonisolated extension MetricID {
    /// The one mapping between a day metric and HealthKit (#721).
    ///
    /// The kit keeps the raw strings in `healthKitSource` so it stays free of
    /// HealthKit (ADR 0007). The app's and the watch's day reads, the series, the
    /// widgets' sums and the watch complication all read through these members, in the display unit:
    /// a distance comes back in kilometres, never in metres to divide.
    public var quantityIdentifier: HKQuantityTypeIdentifier {
        HKQuantityTypeIdentifier(rawValue: healthKitSource.quantityIdentifier)
    }

    public var quantityType: HKQuantityType { HKQuantityType(quantityIdentifier) }

    public var healthKitUnit: HKUnit {
        HKUnit(from: healthKitSource.unit)
    }
}
