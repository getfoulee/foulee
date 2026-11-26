import Dependencies
import FouleeDomain
import Foundation

/// A session that outlived the app, as HealthKit gives it back (#729).
nonisolated struct RecoveredPhoneWorkout: Equatable, Sendable {
    var startedAt: Date
    var activity: SessionActivity
    /// Time the builder counted, pauses left out.
    var elapsed: TimeInterval
    var isPaused: Bool
}

/// The iPhone's `HKWorkoutSession` (iOS 26, #729), as a struct of closures.
///
/// The session gives the outing what a home-made recorder could not: it
/// survives the app being killed (`recover`), and it is a real workout to the
/// system — Lock Screen, Siri. It measures nothing itself: the pedometer, the
/// altimeter and the GPS stay the store's, and the builder collects no sample,
/// because iOS already writes the phone's steps and distance and ours would
/// double-count the day's totals.
nonisolated struct PhoneWorkoutSessionClient: Sendable {
    /// Open the session and start collecting at `date`. Throws when HealthKit
    /// refuses; the outing then goes on without one and is saved as before.
    var start: @Sendable (_ activity: SessionActivity, _ date: Date) async throws -> Void
    var pause: @Sendable () async -> Void
    var resume: @Sendable () async -> Void
    /// Save the outing with the session's builder, and say whether it did.
    ///
    /// `false` without saving when there is no session: the caller then saves
    /// the outing itself.
    var finish: @Sendable (SessionRecord) async throws -> Bool
    /// Take back the session iOS kept running while the app was gone.
    var recover: @Sendable () async -> RecoveredPhoneWorkout?
}

nonisolated extension PhoneWorkoutSessionClient: DependencyKey {
    /// No session: every outing is saved the way it was before #729.
    static let testValue = none

    static let previewValue = none

    private static let none = PhoneWorkoutSessionClient(
        start: { _, _ in },
        pause: {},
        resume: {},
        finish: { _ in false },
        recover: { nil }
    )
}

nonisolated extension DependencyValues {
    var phoneWorkoutSession: PhoneWorkoutSessionClient {
        get { self[PhoneWorkoutSessionClient.self] }
        set { self[PhoneWorkoutSessionClient.self] = newValue }
    }
}
