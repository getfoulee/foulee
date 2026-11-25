@preconcurrency import CoreMotion
import FouleeDomain
import Foundation

/// The app's only contact with `CMMotionActivityManager`, on the iPhone and
/// the watch alike (issue #726).
///
/// The watch opens the live stream during an outing (#249); the iPhone reads
/// the history once the outing ends (#246), because a phone in a pocket is
/// suspended within seconds and a live stream would miss most of a walk.
///
/// A seam because `CMMotionActivityManager.isActivityAvailable()` is `false`
/// on every simulator: through the real CoreMotion, everything downstream
/// would be reachable only on a device.
nonisolated public struct MotionActivityClient: Sendable {
    public var isAvailable: @MainActor () -> Bool
    /// Opens the live stream; `handler` is called once per estimate.
    ///
    /// There is deliberately no way to ask the stream for the authorization
    /// *status*: opening it is what raises the prompt, and a refusal simply
    /// means no estimates arrive.
    public var openStream: @MainActor (_ handler: @escaping @Sendable (MotionActivityEstimate) -> Void) -> Void
    public var closeStream: @MainActor () -> Void
    /// Every estimate the device kept for `[from, to]`, in no guaranteed order.
    ///
    /// Empty rather than throwing when the query fails or permission is
    /// refused: an outing must still be saved when its classification cannot
    /// be read, and « no samples » already means « fall back to walking » one
    /// level up (`ActivitySegmentation`).
    public var history: @Sendable (_ from: Date, _ to: Date) async -> [MotionHistorySample]
    /// What the system allows under « Mouvements et forme », which also gates
    /// the pedometer (issue #611). Granted by default so a double says nothing.
    public var access: @Sendable () -> Access

    public init(
        isAvailable: @escaping @MainActor () -> Bool,
        openStream: @escaping @MainActor (@escaping @Sendable (MotionActivityEstimate) -> Void) -> Void,
        closeStream: @escaping @MainActor () -> Void,
        history: @escaping @Sendable (Date, Date) async -> [MotionHistorySample] = { _, _ in [] },
        access: @escaping @Sendable () -> Access = { .granted }
    ) {
        self.isAvailable = isAvailable
        self.openStream = openStream
        self.closeStream = closeStream
        self.history = history
        self.access = access
    }

    /// The real one. Allocating the manager prompts nothing and starts
    /// nothing: the permission sheet only comes with the stream or the query.
    public static func live() -> MotionActivityClient {
        let manager = CMMotionActivityManager()
        return MotionActivityClient(
            isAvailable: { CMMotionActivityManager.isActivityAvailable() },
            openStream: { handler in
                // Delivered on the main queue, and converted to a value
                // immediately: `CMMotionActivity` is a reference type this app
                // must not hold on to.
                manager.startActivityUpdates(to: .main) { activity in
                    guard let activity else { return }
                    handler(MotionActivityEstimate(activity, receivedAt: .now))
                }
            },
            closeStream: { manager.stopActivityUpdates() },
            history: { from, to in
                // Apple documents the query as undefined when activity data is
                // unavailable, and it runs as an outing ends, where a crash
                // would cost the outing just finished.
                guard CMMotionActivityManager.isActivityAvailable() else { return [] }
                // A manager per query, kept alive by the handler that reads it:
                // one-shot, nothing subscribed, and away from the stream's.
                let historyManager = CMMotionActivityManager()
                return await withCheckedContinuation { continuation in
                    // A queue of its own rather than `.main`: the stop path is
                    // already saving a workout on the main actor.
                    let queue = OperationQueue()
                    queue.maxConcurrentOperationCount = 1
                    historyManager.queryActivityStarting(from: from, to: to, to: queue) { activities, _ in
                        _ = historyManager
                        continuation.resume(returning: (activities ?? []).map(MotionHistorySample.init))
                    }
                }
            },
            access: {
                switch CMMotionActivityManager.authorizationStatus() {
                case .notDetermined: .notDetermined
                case .denied, .restricted: .denied
                case .authorized: .granted
                @unknown default: .unknown
                }
            }
        )
    }
}

// The CoreMotion boundary, in full. The two flags are copied unreduced: they
// are not mutually exclusive and can both be false, so picking a winner here
// would hide the ambiguity from the one place equipped to judge it. The other
// four — stationary, unknown, cycling, automotive — are not read: Foulée records
// none of them, so they could only ever say « no evidence », which two clear
// booleans already say.

nonisolated extension MotionActivityEstimate {
    init(_ activity: CMMotionActivity, receivedAt: Date) {
        self.init(
            startDate: activity.startDate,
            receivedAt: receivedAt,
            confidence: MotionActivityConfidence(rawValue: activity.confidence.rawValue) ?? .unrecognised,
            walking: activity.walking,
            running: activity.running
        )
    }
}

nonisolated extension MotionHistorySample {
    init(_ activity: CMMotionActivity) {
        self.init(
            startDate: activity.startDate,
            confidence: MotionActivityConfidence(rawValue: activity.confidence.rawValue) ?? .unrecognised,
            walking: activity.walking,
            running: activity.running
        )
    }
}
