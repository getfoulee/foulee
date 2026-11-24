@preconcurrency import CoreMotion
import FouleeKit
import Foundation

/// The barometer during an outing, on the iPhone and the watch alike (issues
/// #535, #564, #726): the cumulative climb and descent in metres, each time
/// they change.
///
/// The one adapter of `CMAltimeter` in the repository. `ElevationAccumulator`
/// turns the relative altitude into a climb and a descent, the barometer's
/// noise left out. Needs `NSMotionUsageDescription`, which the pedometer
/// already declares.
nonisolated public struct AltitudeClient: Sendable {
    /// Opens the barometer for one outing. Ending the iteration closes it.
    public var updates: @Sendable () -> AsyncStream<Elevation>

    public init(updates: @escaping @Sendable () -> AsyncStream<Elevation>) {
        self.updates = updates
    }

    /// The real one. No barometer — an older device, a simulator — is no
    /// climb, not a failure: the outing records everything else.
    public static let live = AltitudeClient {
        AsyncStream { continuation in
            guard CMAltimeter.isRelativeAltitudeAvailable() else {
                continuation.finish()
                return
            }
            let altimeter = CMAltimeter()
            var accumulator = ElevationAccumulator()
            altimeter.startRelativeAltitudeUpdates(to: .main) { data, _ in
                guard let data else { return }
                continuation.yield(accumulator.add(relativeAltitude: data.relativeAltitude.doubleValue))
            }
            continuation.onTermination = { _ in altimeter.stopRelativeAltitudeUpdates() }
        }
    }

    /// No barometer at all: the tests, which date the climb themselves.
    public static let inert = AltitudeClient { AsyncStream { $0.finish() } }
}
