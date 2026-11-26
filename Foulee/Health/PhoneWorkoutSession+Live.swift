import FouleeDomain
import FouleeHealth
import Foundation

nonisolated extension PhoneWorkoutSessionClient {
    static let liveValue: PhoneWorkoutSessionClient = {
        let holder = PhoneWorkoutSessionHolder()
        return PhoneWorkoutSessionClient(
            start: { activity, date in try await holder.start(activity, at: date) },
            pause: { await holder.pause() },
            resume: { await holder.resume() },
            finish: { session in try await holder.finish(session) },
            recover: { await holder.recover() }
        )
    }()
}

/// Owns the one session the iPhone may run, between calls. The session is
/// `WorkoutEngine`'s, the watch's own (#730), collecting nothing.
private final class PhoneWorkoutSessionHolder {
    private lazy var engine = WorkoutEngine.live(collecting: .nothing)
    private var handle: WorkoutSessionHandle?

    nonisolated init() {}

    func start(_ activity: SessionActivity, at date: Date) async throws {
        guard handle == nil, engine.isAvailable() else { return }
        handle = try await engine.startSession(WorkoutEngine.configuration(for: activity), date, nil, nil)
    }

    func pause() { handle?.pause() }

    func resume() { handle?.resume() }

    func finish(_ outing: SessionRecord) async throws -> Bool {
        guard let handle, let endedAt = outing.endedAt else { return false }
        var saved = false
        defer {
            // A session must never outlive the outing: an error on the way
            // leaves nothing running and nothing half-saved, and the caller
            // saves the outing itself.
            if !saved {
                handle.end()
                handle.discard()
            }
            self.handle = nil
        }
        try await handle.addMetadata(outing.workoutMetadata)
        // The phone saves no route: it never has, and its GPS stays on screen.
        try await handle.finish(at: endedAt, route: [])
        saved = true
        return true
    }

    func recover() async -> RecoveredPhoneWorkout? {
        guard handle == nil, engine.isAvailable(),
              let recovered = await engine.recoverSession(nil) else { return nil }
        handle = recovered.handle
        return RecoveredPhoneWorkout(
            startedAt: recovered.startedAt,
            activity: recovered.activity,
            elapsed: recovered.elapsed,
            isPaused: recovered.isPaused
        )
    }
}
