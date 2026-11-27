import FouleeDomain
import Foundation

extension WatchWorkoutStore {
    /// The water lock on for a swim (#751): the screen ignores the water, and
    /// the crown unlocks it at the end.
    func lockWaterIfSwimming(_ activity: SessionActivity) {
        guard activity.sport.descriptor.family == .swimming else { return }
        lockWater()
    }
}
