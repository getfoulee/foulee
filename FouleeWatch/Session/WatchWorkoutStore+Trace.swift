import FouleeDomain
import Foundation

/// The hidden recorder of #727: with the switch on, every reading the outing's
/// sensors give — the detection's, the barometer's, the GPS's — and every
/// pause goes into a `DetectionTrace`, sent to the iPhone when the outing ends.
///
/// Off for everyone but the person testing the detection: the switch is a
/// hidden one on the iPhone, carried by `WatchSyncPayload`.
extension WatchWorkoutStore {
    func startTrace(activity: SessionActivity, at date: Date) {
        finishTrace()
        guard recordsTraces() else { return }
        trace = DetectionTrace(
            title: "",
            startedAt: date,
            startedAs: activity,
            hasPedometerRhythm: detection.hasPedometerRhythm,
            events: []
        )
        detection.onReading = { [weak self] event in self?.trace?.record(event) }
        climb.onRecord = { [weak self] elevation, date in self?.trace?.record(.altitude(at: date, elevation)) }
        route.onFix = { [weak self] fix in
            self?.trace?.record(.location(at: fix.timestamp, horizontalAccuracy: fix.horizontalAccuracy))
        }
    }

    /// Send what was recorded, if anything, and stop listening. Idempotent.
    func finishTrace() {
        detection.onReading = nil
        climb.onRecord = nil
        route.onFix = nil
        guard let trace else { return }
        self.trace = nil
        sendTrace(trace)
    }
}
