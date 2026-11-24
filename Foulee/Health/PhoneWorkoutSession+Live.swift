import FouleeHealth
import FouleeKit
import Foundation
@preconcurrency import HealthKit

nonisolated extension PhoneWorkoutSessionClient {
    static let liveValue: PhoneWorkoutSessionClient = {
        let holder = PhoneWorkoutSessionHolder()
        return PhoneWorkoutSessionClient(
            start: { activity, isUndecided, date in
                try await holder.start(activity, isUndecided: isUndecided, at: date)
            },
            pause: { await holder.pause() },
            resume: { await holder.resume() },
            finish: { session in try await holder.finish(session) },
            recover: { await holder.recover() }
        )
    }()
}

/// Owns the one `HKWorkoutSession` the iPhone may run, between calls.
private actor PhoneWorkoutSessionHolder {
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    /// « Les deux » is not a property of the session HealthKit keeps, so it
    /// is kept here for a recovery after the app was killed. Removed when the
    /// session ends; never written into Santé.
    private static let undecidedKey = "phoneWorkoutSession.isActivityUndecided"

    func start(_ activity: SessionActivity, isUndecided: Bool, at date: Date) async throws {
        guard session == nil, HKHealthStore.isHealthDataAvailable() else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity.hkActivityType
        configuration.locationType = .outdoor
        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = Self.collectingNothing(store, configuration)
        UserDefaults.standard.set(isUndecided, forKey: Self.undecidedKey)
        self.session = session
        self.builder = builder
        session.prepare()
        session.startActivity(with: date)
        try await builder.beginCollection(at: date)
    }

    func pause() { session?.pause() }

    func resume() { session?.resume() }

    func finish(_ outing: SessionRecord) async throws -> Bool {
        guard let session, let builder, let endedAt = outing.endedAt else { return false }
        var saved = false
        defer {
            // A session must never outlive the outing: an error on the way,
            // or a sport that changed, leaves nothing running and nothing
            // half-saved, and the caller saves the outing itself.
            if !saved { builder.discardWorkout() }
            session.end()
            self.session = nil
            self.builder = nil
            UserDefaults.standard.removeObject(forKey: Self.undecidedKey)
        }
        guard SessionActivity(session.workoutConfiguration.activityType) == outing.activity else { return false }
        try await builder.addMetadata(outing.workoutMetadata)
        session.stopActivity(with: endedAt)
        try await builder.endCollection(at: endedAt)
        _ = try await builder.finishWorkout()
        saved = true
        return true
    }

    func recover() async -> RecoveredPhoneWorkout? {
        guard session == nil,
              HKHealthStore.isHealthDataAvailable(),
              let recovered = try? await store.recoverActiveWorkoutSession() else { return nil }
        let builder = recovered.associatedWorkoutBuilder()
        let configuration = recovered.workoutConfiguration
        guard let activity = SessionActivity(configuration.activityType) else {
            // Not a sport this app records: nothing to resume, and nothing to
            // stamp in its name.
            builder.discardWorkout()
            recovered.end()
            return nil
        }
        builder.dataSource = Self.collectingNothing(store, configuration)
        session = recovered
        self.builder = builder
        return RecoveredPhoneWorkout(
            startedAt: builder.startDate ?? recovered.startDate ?? .now,
            activity: activity,
            isActivityUndecided: UserDefaults.standard.bool(forKey: Self.undecidedKey),
            elapsed: builder.elapsedTime,
            isPaused: recovered.state == .paused
        )
    }

    /// The data source Apple's flow attaches, with every type it would
    /// collect turned off: the phone writes no steps, distance or energy
    /// samples (they would double-count the day), and no type it has not been
    /// allowed to share, which would make `finishWorkout()` fail.
    private static func collectingNothing(
        _ store: HKHealthStore,
        _ configuration: HKWorkoutConfiguration
    ) -> HKLiveWorkoutDataSource {
        let source = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
        for type in source.typesToCollect {
            source.disableCollection(for: type)
        }
        return source
    }
}
