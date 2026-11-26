import ActivityKit
import FouleeDomain
import Foundation

/// The Live Activity attributes of every build before #732, kept one release
/// so an activity a previous build left running is still drawn (as a walk or
/// a run, with their figures) and still reached by the two sweeps that end it:
/// `FouleeApp.endOrphanedWalkActivitiesOnce` and
/// `ActiveSessionStore.startLiveActivity`. No new activity uses it:
/// `SessionActivityAttributes` replaced it. Remove it in the release after.
///
/// It kept its « Walk » name when the other types became sport-neutral (#722):
/// ActivityKit finds a running activity by its attributes type, and renamed,
/// one left by the previous build would be out of reach of everything that can
/// end it.
nonisolated public struct WalkActivityAttributes: ActivityAttributes, SessionActivityContent, Sendable {
    public typealias ContentState = SessionActivityState
    public typealias SessionState = SessionActivityState

    public var goalMinutes: Int

    /// What the session in flight is, as the app started it — carried here so
    /// the Lock Screen stops announcing a run as a walk (issue #225).
    ///
    /// Optional, and the optionality is the compatibility story rather than a
    /// convenience. ActivityKit keeps an activity alive across app launches,
    /// and an app *update* is on that path, so the new extension binary may be
    /// handed an activity whose persisted attributes were written by a build
    /// that had no such field. `nil` is that payload: a session the app cannot
    /// name. It renders exactly what the build that started it rendered —
    /// « Ta sortie » and the neutral figure (#222) — rather than guessing
    /// `.walking`, which would resurrect the very bug this field exists to
    /// kill on the one payload that cannot answer.
    ///
    /// How far that scenario is *verified* rather than reasoned: see
    /// `init(from:)` below, which is explicit about it.
    ///
    /// Deliberately *not* defaulted: `init(goalMinutes:activity:)` below
    /// replaces the memberwise initializer (which would have handed an
    /// optional an implicit `nil`) so no production call site can drop the
    /// activity by omission. `nil` comes from a legacy decode, or from a
    /// mirrored outing (#275), which may switch sport after the attributes —
    /// fixed for the activity's life — are written.
    public var activity: SessionActivity?

    public init(goalMinutes: Int, activity: SessionActivity?) {
        self.goalMinutes = goalMinutes
        self.activity = activity
    }

    /// What every build before #732 drew.
    public var metrics: [MetricID] { [.steps, .distance, .calories] }
    public var showsElevation: Bool { true }
}

// MARK: - Tolerant decoding

nonisolated extension WalkActivityAttributes {
    /// Never fails on the `activity` field, whatever is (or isn't) in the
    /// persisted payload — the same discipline #214 and #222 applied to the
    /// widget snapshot, and here it is load-bearing rather than defensive.
    ///
    /// **What is verified, and what is not.** The tolerance itself is tested:
    /// this type decodes a pre-#225 payload, an unknown raw value and a type
    /// mismatch, under `JSONDecoder` *and* `PropertyListDecoder`
    /// (`WalkActivityAttributesTests`). What no test here can reach is the step
    /// upstream of the decoder — whether ActivityKit persists attributes
    /// through `Codable` at all, and whether `Activity.activities` surfaces an
    /// activity whose attributes type changed shape between two builds. The
    /// archive format is private and no test process can leave an activity in
    /// flight across a binary swap. #225 shipped without that being observed on
    /// a device, so the paragraph below is the *reason* the tolerance is worth
    /// its few lines, not an established failure mode.
    ///
    /// The failure it is insurance against: both sweeps that clean up a
    /// stranded activity — `FouleeApp.endOrphanedWalkActivitiesOnce` at
    /// process start and `ActiveSessionStore.startLiveActivity` before requesting
    /// a new one — reach an activity only by enumerating
    /// `Activity<WalkActivityAttributes>.activities`, and ActivityKit offers no
    /// documented way to end an activity whose attributes it cannot rebuild.
    /// *If* the rebuild does run through this initializer, then a type that
    /// throws on last version's payload would not just render wrong: it would
    /// put the stale activity out of reach of the only two things that can end
    /// it. Cheap to buy out; expensive and un-hotfixable to get wrong.
    ///
    /// Two ways the field can be unreadable, both mapped to `nil`:
    /// * **absent** — written by a build before #225. Swift's synthesized
    ///   decoder already tolerates this one (an optional property decodes a
    ///   missing key as `nil`); it is spelled out here so the tolerance is a
    ///   stated contract and not an artefact of how the property is typed.
    /// * **unrecognised** — a raw value this binary has no case for, which the
    ///   synthesized decoder does *not* tolerate: it throws `dataCorrupted`.
    ///   Reachable by installing an older build over a newer one (TestFlight
    ///   allows it) and by any later third activity.
    ///
    /// `goalMinutes` stays required on purpose: it has been in every payload
    /// ever written, so a payload missing it is corrupt rather than old, and
    /// swallowing that would hide a real bug behind a 0-minute ring.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goalMinutes = try container.decode(Int.self, forKey: .goalMinutes)
        activity = try? container.decode(SessionActivity.self, forKey: .activity)
    }
}
