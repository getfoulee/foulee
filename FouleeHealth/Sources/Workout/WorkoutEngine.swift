@preconcurrency import CoreLocation
import FouleeDomain
import Foundation
@preconcurrency import HealthKit

/// The HealthKit delegates a live session reports to.
public typealias WorkoutSessionDelegate = HKWorkoutSessionDelegate & HKLiveWorkoutBuilderDelegate

/// The one `HKWorkoutSession` engine the iPhone and the watch both run (#730).
///
/// A struct of closures so the stores' state machines are driven by stubs in
/// tests: an `HKWorkoutSession` needs a real device. `live(collecting:)` is the
/// real one; the sequences built on the closures — finishing an outing,
/// changing sport — are methods, so a stub exercises them too.
///
/// The two devices differ by what their builder records, not by code:
/// `WorkoutCollection` says which. Everything else — the configuration a sport
/// gets, the order a leg is closed in, the route, the recovery — is this file.
nonisolated public struct WorkoutEngine: Sendable {
    public var isAvailable: @MainActor () -> Bool
    /// Throws only when the request itself fails — denial is silent, by
    /// HealthKit design.
    public var requestAuthorization: @MainActor (
        _ toShare: Set<HKSampleType>,
        _ read: Set<HKObjectType>
    ) async throws -> Void
    /// Creates, wires and starts a live session, returning a handle to it.
    /// The delegate keeps receiving session and builder callbacks directly.
    /// - Parameter at: when the leg begins. **May be in the past** (#265): a
    ///   leg opened at a detected boundary starts when the wearer changed
    ///   sport, not when it was noticed.
    /// - Parameter leg: stamped on the workout as soon as collection begins
    ///   (#316), so every path that saves it carries it, recovery included.
    ///   `nil` for an outing of a single workout.
    public var startSession: @MainActor (
        _ configuration: HKWorkoutConfiguration,
        _ at: Date,
        _ leg: OutingLeg?,
        _ delegate: (any WorkoutSessionDelegate)?
    ) async throws -> WorkoutSessionHandle
    /// The session the system kept running while the app was gone — a crash,
    /// a relaunch for memory, a reboot — wired to `delegate`, or `nil` when
    /// there is none (#554, #729).
    public var recoverSession: @MainActor (
        _ delegate: (any WorkoutSessionDelegate)?
    ) async -> RecoveredWorkoutSession? = { _ in nil }

    public init(
        isAvailable: @escaping @MainActor () -> Bool,
        requestAuthorization: @escaping @MainActor (Set<HKSampleType>, Set<HKObjectType>) async throws -> Void,
        startSession: @escaping @MainActor (
            HKWorkoutConfiguration, Date, OutingLeg?, (any WorkoutSessionDelegate)?
        ) async throws -> WorkoutSessionHandle,
        recoverSession: @escaping @MainActor ((any WorkoutSessionDelegate)?) async -> RecoveredWorkoutSession? = { _ in nil }
    ) {
        self.isAvailable = isAvailable
        self.requestAuthorization = requestAuthorization
        self.startSession = startSession
        self.recoverSession = recoverSession
    }
}

/// What a device's builder records.
nonisolated public enum WorkoutCollection: Sendable {
    /// The watch: the authoritative source during an outing. Its heart rate,
    /// energy, steps and distance are saved with the workout and don't
    /// double-count the day's totals.
    case measured
    /// The iPhone: iOS already writes the phone's steps and distance, so
    /// samples from the builder would count the day twice. The session is
    /// there for what it gives the outing — surviving the app, the Lock
    /// Screen, Siri — not to measure.
    case nothing
}

/// A session found running at launch, and what the store needs to pick it up
/// where it was (#554, #729).
nonisolated public struct RecoveredWorkoutSession: Sendable {
    public var handle: WorkoutSessionHandle
    public var activity: SessionActivity
    /// When the leg began: its builder's start.
    public var startedAt: Date
    /// The stamp the leg was opened with (#316); `nil` for a session opened
    /// without one, which then starts an outing of its own.
    public var leg: OutingLeg?
    /// The builder's own clock, paused stretches left out.
    public var elapsed: TimeInterval
    public var isPaused: Bool

    public init(
        handle: WorkoutSessionHandle,
        activity: SessionActivity,
        startedAt: Date,
        leg: OutingLeg?,
        elapsed: TimeInterval,
        isPaused: Bool
    ) {
        self.handle = handle
        self.activity = activity
        self.startedAt = startedAt
        self.leg = leg
        self.elapsed = elapsed
        self.isPaused = isPaused
    }
}

/// One live session and builder pair, reduced to the operations an outing
/// needs. The closures are the only strong references to the HealthKit
/// objects, so releasing the handle releases the builder — a store's
/// save-and-retry logic relies on exactly that.
nonisolated public struct WorkoutSessionHandle: Sendable {
    /// Identifies the underlying `HKWorkoutSession`, and its builder.
    ///
    /// A store is the delegate of every session it opens, and an outing opens
    /// one per leg (#265). HealthKit hands the delegate the calling object and
    /// nothing else, so these are how a callback about the leg in flight is
    /// told from one about a leg closed a moment ago (#290).
    public var sessionID: ObjectIdentifier
    public var builderID: ObjectIdentifier
    /// The sport the session was opened as: what Santé will stamp.
    public var activity: SessionActivity
    /// Offer this session to the paired iPhone (#277). Only the watch can: on
    /// the iPhone it throws, and a store never calls it there.
    public var startMirroring: @MainActor () async throws -> Void
    /// Hand data to the mirrored session on the other device (#278). Throws
    /// in the ordinary case of nobody mirroring.
    public var sendToRemote: @MainActor (Data) async throws -> Void
    public var end: @MainActor () -> Void
    public var endCollection: @MainActor (_ at: Date) async throws -> Void
    /// Save the workout, then its slice of `route` (#312).
    ///
    /// Throws only for the workout. A route that will not save is logged and
    /// dropped: never a reason to lose the outing.
    public var finishWorkout: @MainActor (_ route: [CLLocation]) async throws -> Void
    /// `HKLiveWorkoutBuilder.endDate`: non-nil once collection has ended, so
    /// a retry knows not to end it twice.
    public var collectionEndDate: @MainActor () -> Date?
    /// HealthKit leaves the paused stretch out of the duration (#384).
    public var pause: @MainActor () -> Void
    public var resume: @MainActor () -> Void
    /// Stamp the workout, before `finishWorkout` seals it.
    public var addMetadata: @MainActor (_ metadata: [String: Any]) async throws -> Void
    /// Drop the workout without saving it.
    public var discard: @MainActor () -> Void

    public init(
        sessionID: ObjectIdentifier,
        builderID: ObjectIdentifier,
        activity: SessionActivity = .walking,
        startMirroring: @escaping @MainActor () async throws -> Void = {},
        sendToRemote: @escaping @MainActor (Data) async throws -> Void = { _ in },
        end: @escaping @MainActor () -> Void,
        endCollection: @escaping @MainActor (Date) async throws -> Void,
        finishWorkout: @escaping @MainActor ([CLLocation]) async throws -> Void,
        collectionEndDate: @escaping @MainActor () -> Date?,
        pause: @escaping @MainActor () -> Void = {},
        resume: @escaping @MainActor () -> Void = {},
        addMetadata: @escaping @MainActor ([String: Any]) async throws -> Void = { _ in },
        discard: @escaping @MainActor () -> Void = {}
    ) {
        self.sessionID = sessionID
        self.builderID = builderID
        self.activity = activity
        self.startMirroring = startMirroring
        self.sendToRemote = sendToRemote
        self.end = end
        self.endCollection = endCollection
        self.finishWorkout = finishWorkout
        self.collectionEndDate = collectionEndDate
        self.pause = pause
        self.resume = resume
        self.addMetadata = addMetadata
        self.discard = discard
    }

    /// End the session at `end` and save its workout with its slice of
    /// `route`: the order every leg and every outing is closed in, proven on
    /// the wrist since #265.
    @MainActor public func finish(at end: Date, route: [CLLocation]) async throws {
        self.end()
        try await endCollection(end)
        try await finishWorkout(route)
    }
}

// MARK: - Changing sport

nonisolated public extension WorkoutEngine {
    /// How a change of sport went.
    enum SportChange: Sendable {
        /// The leg before is saved, and `next` records the new sport from the
        /// boundary on.
        case changed(next: WorkoutSessionHandle)
        /// The leg before could not be saved. Its builder is still alive, so
        /// finishing the outing can try again; nothing was opened.
        case notClosed(any Error)
        /// The leg before is saved, but the next one could not open: nothing
        /// more is recorded until the outing ends.
        case notOpened(any Error)
    }

    /// Change the sport of an outing at `boundary` (#730).
    ///
    /// HealthKit records one sport per session and refuses a sub-activity of
    /// another one (« Cannot add subactivity of type
    /// HKWorkoutActivityTypeRunning », #256). So a change of sport saves the
    /// leg in flight up to the boundary and opens a session of the new sport
    /// from it, the way Forme does (ADR 0002, D7): Santé gets a walk and a
    /// run, each typed right, with no gap between them.
    ///
    /// **A failure never costs what came before**: the leg in flight is saved
    /// before the next one is tried.
    /// - Parameter next: the sport from `boundary` on, and the leg it is
    ///   stamped as (#316).
    @MainActor func changeSport(
        of handle: WorkoutSessionHandle,
        at boundary: Date,
        route: [CLLocation],
        to next: (activity: SessionActivity, leg: OutingLeg),
        delegate: (any WorkoutSessionDelegate)?
    ) async -> SportChange {
        do {
            try await handle.finish(at: boundary, route: route)
        } catch {
            return .notClosed(error)
        }
        do {
            let next = try await startSession(Self.configuration(for: next.activity), boundary, next.leg, delegate)
            return .changed(next: next)
        } catch {
            return .notOpened(error)
        }
    }
}

// MARK: - Configuration and collection

nonisolated public extension WorkoutEngine {
    /// The configuration HealthKit stamps a session of `activity` with: its
    /// type and where it happens, both from the sport's descriptor (ADR 0018).
    static func configuration(for activity: SessionActivity) -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity.hkActivityType
        switch activity.sport.descriptor.location {
        case .outdoor: configuration.locationType = .outdoor
        }
        return configuration
    }

    /// The quantity types a measuring session of `sport` collects, from the
    /// sensors its descriptor names.
    ///
    /// The single list a measuring path is built from: the data source
    /// enables exactly these, the store asks to share and read exactly these,
    /// and reads back exactly these. A type collected but not shareable makes
    /// `finishWorkout()` fail with an authorization error; a type read back
    /// but never collected is a counter frozen at 0 (#223).
    static func collectedTypes(for sport: SportID) -> [HKQuantityType] {
        let capabilities = sport.descriptor.capabilities
        var types: [HKQuantityType] = []
        if capabilities.contains(.steps) { types.append(HKQuantityType(.stepCount)) }
        if capabilities.contains(.route) { types.append(HKQuantityType(.distanceWalkingRunning)) }
        types.append(HKQuantityType(.activeEnergyBurned))
        types.append(HKQuantityType(.heartRate))
        return types
    }

    /// The live data source for `configuration`, collecting what `collection`
    /// says.
    ///
    /// `.measured` force-enables `collectedTypes`. The source infers its types
    /// from the configuration, and for a walk it leaves step count out: the
    /// live « pas » counter stayed at 0 while distance and heart rate moved
    /// (#223). Enabling a type it would have inferred is a no-op; missing one
    /// silently zeroes a counter for a whole outing.
    ///
    /// `.nothing` turns off every type it would collect, which also keeps the
    /// workout from carrying a type the app was never allowed to share.
    @MainActor static func makeDataSource(
        healthStore: HKHealthStore,
        configuration: HKWorkoutConfiguration,
        collecting collection: WorkoutCollection
    ) -> HKLiveWorkoutDataSource {
        let source = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        switch collection {
        case .measured:
            let sport = SportID(configuration.activityType) ?? .walking
            for type in collectedTypes(for: sport) {
                source.enableCollection(for: type, predicate: nil)
            }
        case .nothing:
            for type in source.typesToCollect {
                source.disableCollection(for: type)
            }
        }
        return source
    }

    /// The fixes that belong to a workout spanning `start...end`.
    static func routeFixes(_ fixes: [CLLocation], from start: Date, to end: Date) -> [CLLocation] {
        fixes.filter { $0.timestamp >= start && $0.timestamp <= end }
    }
}

// MARK: - Live

nonisolated public extension WorkoutEngine {
    /// The real engine, its builders collecting what `collection` says.
    @MainActor static func live(collecting collection: WorkoutCollection) -> WorkoutEngine {
        let store = HKHealthStore()
        return WorkoutEngine(
            isAvailable: { HKHealthStore.isHealthDataAvailable() },
            requestAuthorization: { toShare, read in
                try await store.requestAuthorization(toShare: toShare, read: read)
            },
            startSession: { configuration, startDate, leg, delegate in
                let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = makeDataSource(
                    healthStore: store,
                    configuration: configuration,
                    collecting: collection
                )
                session.delegate = delegate
                builder.delegate = delegate
                session.startActivity(with: startDate)
                try await builder.beginCollection(at: startDate)
                if let leg {
                    // Never a reason to lose the leg: without it the phone
                    // falls back to grouping by contiguity (#316).
                    do {
                        try await builder.addMetadata(leg.metadata)
                    } catch {
                        FouleeLog.session.error(
                            "jambe \(leg.index, privacy: .public) non reliée : \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }
                return handle(for: session, builder: builder, in: store)
            },
            recoverSession: { delegate in
                await recoverSession(in: store, collecting: collection, delegate: delegate)
            }
        )
    }

    @MainActor private static func handle(
        for session: HKWorkoutSession,
        builder: HKLiveWorkoutBuilder,
        in store: HKHealthStore
    ) -> WorkoutSessionHandle {
        WorkoutSessionHandle(
            sessionID: ObjectIdentifier(session),
            builderID: ObjectIdentifier(builder),
            activity: SessionActivity(session.workoutConfiguration.activityType) ?? .walking,
            startMirroring: {
                #if os(watchOS)
                try await session.startMirroringToCompanionDevice()
                #else
                throw HKError(.errorInvalidArgument)
                #endif
            },
            sendToRemote: { try await session.sendToRemoteWorkoutSession(data: $0) },
            end: { session.end() },
            endCollection: { try await builder.endCollection(at: $0) },
            finishWorkout: { route in
                guard let workout = try await builder.finishWorkout() else { return }
                await saveRoute(route, for: workout, in: store)
            },
            collectionEndDate: { builder.endDate },
            pause: { session.pause() },
            resume: { session.resume() },
            addMetadata: { try await builder.addMetadata($0) },
            discard: { builder.discardWorkout() }
        )
    }

    /// Attach the workout's slice of the route. Best effort: the workout is
    /// already saved, and nothing here may undo that.
    ///
    /// Built in one go once the leg is saved, not fix by fix: a leg's end is
    /// only known after the fact (dated at the detected boundary), and a fix
    /// inserted past it could not be taken back out.
    @MainActor private static func saveRoute(
        _ fixes: [CLLocation],
        for workout: HKWorkout,
        in store: HKHealthStore
    ) async {
        let leg = routeFixes(fixes, from: workout.startDate, to: workout.endDate)
        guard !leg.isEmpty else { return }
        let builder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
        do {
            try await builder.insertRouteData(leg)
            _ = try await builder.finishRoute(with: workout, metadata: nil)
            FouleeLog.route.notice("tracé enregistré : \(leg.count, privacy: .public) points")
        } catch {
            FouleeLog.route.error("tracé non enregistré : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Pick up the session the system kept running: the delegates and the
    /// data source go back on, collection never stopped.
    ///
    /// A session of a sport this app does not record cannot be shown. A
    /// measuring one is finished, so what it measured still lands in Santé; a
    /// session that measured nothing is dropped, with nothing to stamp in its
    /// name.
    @MainActor private static func recoverSession(
        in store: HKHealthStore,
        collecting collection: WorkoutCollection,
        delegate: (any WorkoutSessionDelegate)?
    ) async -> RecoveredWorkoutSession? {
        let session: HKWorkoutSession?
        do {
            session = try await store.recoverActiveWorkoutSession()
        } catch {
            FouleeLog.session.error("séance non retrouvée : \(error.localizedDescription, privacy: .public)")
            return nil
        }
        guard let session else { return nil }
        let builder = session.associatedWorkoutBuilder()
        session.delegate = delegate
        builder.delegate = delegate
        builder.dataSource = makeDataSource(
            healthStore: store,
            configuration: session.workoutConfiguration,
            collecting: collection
        )
        guard let activity = SessionActivity(session.workoutConfiguration.activityType),
              let startedAt = builder.startDate ?? session.startDate else {
            FouleeLog.session.error("séance retrouvée illisible")
            session.end()
            switch collection {
            case .measured:
                builder.endCollection(withEnd: .now) { _, _ in
                    builder.finishWorkout { _, _ in }
                }
            case .nothing:
                builder.discardWorkout()
            }
            return nil
        }
        FouleeLog.session.notice("séance retrouvée après relance : \(activity.label, privacy: .public)")
        return RecoveredWorkoutSession(
            handle: handle(for: session, builder: builder, in: store),
            activity: activity,
            startedAt: startedAt,
            leg: OutingLeg(metadata: builder.metadata),
            elapsed: builder.elapsedTime(at: .now),
            isPaused: session.state == .paused
        )
    }
}
