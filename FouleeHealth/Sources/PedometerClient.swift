@preconcurrency import CoreMotion
import FouleeDomain
import Foundation

/// The app's only contact with `CMPedometer`, on the iPhone and the watch
/// alike (issue #726).
///
/// A seam, not a convenience: neither `isCadenceAvailable()` nor
/// `isPaceAvailable()` is true on a simulator, so the real pedometer would
/// leave everything downstream reachable only on a device. It needs no
/// permission of its own — « Mouvements et forme » covers it.
nonisolated public struct PedometerClient: Sendable {
    /// Whether the live rhythm — cadence and pace — can be read.
    public var isRhythmAvailable: @MainActor () -> Bool
    /// Opens the stream from `start`; `handler` is called once per update, on
    /// whatever queue CoreMotion picks — never assume the main one (#338).
    public var openStream: @MainActor (_ start: Date, _ handler: @escaping @Sendable (PedometerReading) -> Void) -> Void
    public var closeStream: @MainActor () -> Void
    /// Steps recorded over a past interval, or `nil` when the device cannot
    /// say (issue #247).
    ///
    /// A **query**, not a second subscription: a second `startUpdates` on the
    /// same pedometer would replace the first's handler.
    ///
    /// `nil` rather than `0`, because the two mean opposite things: zero steps
    /// over a stretch is a measurement, and « the device would not answer » is
    /// not. One credits nothing; the other must fall back to an estimate.
    public var steps: @Sendable (_ from: Date, _ to: Date) async -> Int?

    public init(
        isRhythmAvailable: @escaping @MainActor () -> Bool,
        openStream: @escaping @MainActor (Date, @escaping @Sendable (PedometerReading) -> Void) -> Void,
        closeStream: @escaping @MainActor () -> Void,
        steps: @escaping @Sendable (Date, Date) async -> Int? = { _, _ in nil }
    ) {
        self.isRhythmAvailable = isRhythmAvailable
        self.openStream = openStream
        self.closeStream = closeStream
        self.steps = steps
    }

    /// The real one, around one `CMPedometer`: one per caller, so two callers
    /// never replace each other's handler.
    public static func live() -> PedometerClient {
        let pedometer = CMPedometer()
        return PedometerClient(
            isRhythmAvailable: { CMPedometer.isCadenceAvailable() && CMPedometer.isPaceAvailable() },
            openStream: { start, handler in
                pedometer.startUpdates(from: start, withHandler: updateHandler(forwardingTo: handler))
            },
            closeStream: { pedometer.stopUpdates() },
            steps: { from, to in
                guard CMPedometer.isStepCountingAvailable() else { return nil }
                return await withCheckedContinuation { continuation in
                    pedometer.queryPedometerData(from: from, to: to) { data, _ in
                        continuation.resume(returning: data?.numberOfSteps.intValue)
                    }
                }
            }
        )
    }

    /// CoreMotion's handler, built **outside** the main actor (issue #338).
    ///
    /// `CMPedometer` calls it on a queue of its own. A closure written inside
    /// `openStream` would inherit that closure's `@MainActor`, and Swift 6
    /// checks the isolation on entry: the first update — a few seconds into
    /// any outing on foot — killed the app. `@Sendable` and `nonisolated`
    /// make it callable from anywhere; the caller hops to the main actor
    /// itself.
    public static func updateHandler(
        forwardingTo handler: @escaping @Sendable (PedometerReading) -> Void
    ) -> @Sendable (CMPedometerData?, Error?) -> Void {
        { data, error in
            // Converted to a value at once: `CMPedometerData` is a reference
            // type this app must not hold on to.
            guard let data else {
                if let error {
                    FouleeLog.detection.error("podomètre muet : \(error.localizedDescription, privacy: .public)")
                }
                return
            }
            handler(PedometerReading(
                date: data.endDate,
                steps: data.numberOfSteps.intValue,
                distanceMeters: data.distance?.doubleValue ?? 0,
                cadence: data.currentCadence?.doubleValue,
                pace: data.currentPace?.doubleValue
            ))
        }
    }
}

public extension PedometerClient {
    /// The stream as an `AsyncStream`, for a caller that reads it with
    /// `for await`. Ending the iteration closes the stream.
    @MainActor
    func updates(from start: Date) -> AsyncStream<PedometerReading> {
        let (stream, continuation) = AsyncStream<PedometerReading>.makeStream()
        openStream(start) { continuation.yield($0) }
        let close = closeStream
        continuation.onTermination = { _ in Task { @MainActor in close() } }
        return stream
    }
}
