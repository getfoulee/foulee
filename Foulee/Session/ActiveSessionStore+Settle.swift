import FouleeHealth
import FouleeDomain
import FouleeLiveActivityModel
import Foundation

/// How a finished session is settled before it is saved, and what the Lock
/// Screen is told it is. Apart from `ActiveSessionStore.swift`, which is at the
/// length SwiftLint allows.
extension ActiveSessionStore {
    /// The attributes ActivityKit is handed for the session in flight — what
    /// the Lock Screen and the Dynamic Island then draw (issue #225).
    ///
    /// Read off the *session*, so the Lock Screen cannot name the activity
    /// differently from what Santé will be stamped with. A member rather than
    /// three lines inside `startLiveActivity`, for the reason #234 pulled
    /// `ActiveSessionScreen.startSession()` out of its call site: inlined, the step
    /// that reads `session.activity` could be dropped — back to the hardcoded
    /// `.walking` this issue removes — with the whole suite green, because
    /// `Activity.request` needs a live ActivityKit and never runs in a test
    /// process. As a plain value it is assertable, and `ActiveSessionStoreTests`
    /// asserts it.
    ///
    /// `nil` activity only when nothing is in flight; the sole production
    /// caller runs immediately after `state` becomes `.active`.
    /// Read the session's own motion history and settle what the outing cost
    /// with it (issue #247).
    ///
    /// The sport is the one the user started (#743), and detection is not
    /// entitled to contradict it; the energy is a sum over the stretches. A
    /// user who started « Marche » and ran for ten minutes chose their label
    /// and still ran those ten minutes, and pricing them at 0.04 kcal/step
    /// rather than 0.09 is simply wrong.
    ///
    /// Runs **before** the workout is saved, because the stamp is permanent:
    /// `HKWorkout` is immutable, Foulée has no delete path, and the phone
    /// writes no energy samples — so this estimate is the only energy figure
    /// the session will ever carry.
    ///
    /// Internal so a test can drive it without a session in flight.
    func settled(_ session: SessionRecord) async -> SessionRecord {
        guard let endedAt = session.endedAt else { return session }
        let samples = await motionActivity.history(session.startedAt, endedAt)
        let segments = ActivitySegmentation.segments(samples, from: session.startedAt, to: endedAt)
        var settled = session
        settled.stepsByActivity = await stepsByActivity(over: segments)
        return settled
    }

    /// Steps taken during each activity's own stretches, or `nil` when the
    /// breakdown would be worse than none.
    ///
    /// Two ways it declines, both deliberate:
    ///
    /// * **One activity only.** A homogeneous outing prices identically with
    ///   and without a breakdown, so the queries would buy nothing.
    /// * **Any stretch the pedometer will not answer for.** A partial breakdown
    ///   is not a smaller truth, it is a wrong total — the missing stretch's
    ///   steps would silently vanish from the estimate. All or the old formula.
    private func stepsByActivity(over segments: [ActivitySegment]) async -> [SessionActivity: Int]? {
        guard Set(segments.map(\.activity)).count > 1 else { return nil }
        var total: [SessionActivity: Int] = [:]
        for segment in segments {
            guard let steps = await pedometer.steps(segment.start, segment.end) else { return nil }
            total[segment.activity, default: 0] += steps
        }
        return total
    }

    func liveActivityAttributes(minutesGoal: Int) -> SessionActivityAttributes {
        let activity: SessionActivity? = switch state {
        case .idle: nil
        case .active(let session), .paused(let session), .finished(let session):
            session.activity
        }
        return SessionActivityAttributes(goalMinutes: minutesGoal, activity: activity)
    }
}
