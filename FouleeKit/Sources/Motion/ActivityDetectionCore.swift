import Foundation

/// What the watch does with each reading during an outing, without the
/// streams around it (issues #267, #727): a pedometer update or a CoreMotion
/// estimate becomes an observation, and the detector says whether the sport
/// changed.
///
/// Pure, so the live detection on the wrist (`WatchActivityDetection`) and the
/// replay of a recorded trace (`DetectionReplay`) take exactly the same path.
nonisolated public struct ActivityDetectionCore: Sendable {
    /// One reading, as the detector read it.
    public struct Step: Sendable {
        public var observation: ActivityObservation
        /// The change of sport this reading confirmed, if it did.
        public var confirmed: ActivitySwitchDetector.Switch?
    }

    private var detector: ActivitySwitchDetector
    /// The pedometer's latest reading: its date dates the next one's boundary,
    /// and the screen reads its cadence.
    public private(set) var lastPedometerReading: PedometerReading?

    /// - Parameter runningNeedsPedometer: a run waits for the pedometer's word
    ///   (issue #390) — unless there is no pedometer to give it, where that
    ///   rule would silence runs altogether.
    public init(
        startedAs activity: SessionActivity,
        at date: Date,
        confirmations: Int = ActivitySwitchDetector.defaultConfirmations,
        runningNeedsPedometer: Bool
    ) {
        detector = ActivitySwitchDetector(
            startedAs: activity,
            at: date,
            confirmations: confirmations,
            runningNeedsPedometer: runningNeedsPedometer
        )
    }

    public mutating func ingest(_ estimate: MotionActivityEstimate) -> Step {
        observe(estimate.observation(minimumConfidence: detector.minimumConfidence))
    }

    /// `nil` for a reading that carries no rhythm at all: nothing was measured.
    public mutating func ingest(_ reading: PedometerReading) -> Step? {
        let previous = lastPedometerReading?.date
        lastPedometerReading = reading
        guard let observation = MovementClassifier.observation(reading, since: previous) else { return nil }
        return observe(observation)
    }

    private mutating func observe(_ observation: ActivityObservation) -> Step {
        Step(observation: observation, confirmed: detector.observe(observation))
    }
}
