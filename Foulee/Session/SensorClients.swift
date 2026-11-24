import Dependencies
import FouleeHealth
import FouleeKit
import Foundation

// The shared CoreMotion clients (FouleeHealth, issue #726) as the phone's
// dependencies. The watch links no dependency container and takes them as
// arguments instead.

nonisolated extension PedometerClient: @retroactive DependencyKey {
    /// One `CMPedometer` for the app: the outing's stream and the queries of
    /// its steps share it.
    public static let liveValue = PedometerClient.live()

    public static let previewValue = PedometerClient(
        isRhythmAvailable: { true },
        openStream: { start, handler in
            Task {
                var steps = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    steps += 25
                    handler(PedometerReading(date: start, steps: steps, distanceMeters: Double(steps) * 0.78))
                }
            }
        },
        closeStream: {},
        steps: { from, to in Int(to.timeIntervalSince(from) * 1.8) }
    )

    public static let testValue = PedometerClient(isRhythmAvailable: { false }, openStream: { _, _ in }, closeStream: {})
}

nonisolated extension AltitudeClient: @retroactive DependencyKey {
    public static let liveValue = AltitudeClient.live

    public static let previewValue = AltitudeClient {
        AsyncStream { continuation in
            Task {
                var elevation = Elevation.zero
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    elevation.ascent += 1.5
                    elevation.descent += 0.5
                    continuation.yield(elevation)
                }
                continuation.finish()
            }
        }
    }

    public static let testValue = AltitudeClient.inert
}

nonisolated extension MotionActivityClient: @retroactive DependencyKey {
    public static let liveValue = MotionActivityClient.live()

    /// A mixed outing: walking, then a run in the middle, then walking again.
    /// Enough for a preview to show something other than a single block.
    public static let previewValue = MotionActivityClient(
        isAvailable: { true },
        openStream: { _ in },
        closeStream: {},
        history: { from, to in
            let third = to.timeIntervalSince(from) / 3
            return [
                MotionHistorySample(startDate: from, confidence: .high, walking: true, running: false),
                MotionHistorySample(startDate: from.addingTimeInterval(third), confidence: .high, walking: false, running: true),
                MotionHistorySample(startDate: from.addingTimeInterval(third * 2), confidence: .high, walking: true, running: false)
            ]
        }
    )

    /// Says nothing, the way an unavailable device does — so a test that has
    /// not opted in gets the fallback rather than an invented classification.
    public static let testValue = MotionActivityClient(isAvailable: { false }, openStream: { _ in }, closeStream: {})
}

nonisolated extension DependencyValues {
    var pedometer: PedometerClient {
        get { self[PedometerClient.self] }
        set { self[PedometerClient.self] = newValue }
    }

    var altitude: AltitudeClient {
        get { self[AltitudeClient.self] }
        set { self[AltitudeClient.self] = newValue }
    }

    var motionActivity: MotionActivityClient {
        get { self[MotionActivityClient.self] }
        set { self[MotionActivityClient.self] = newValue }
    }
}
