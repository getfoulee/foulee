import FouleeHealth
import FouleeDomain
import Foundation

nonisolated extension SessionRecord {
    /// What a phone-recorded outing writes on its workout: its own measured
    /// steps, distance and calories, its climb under the standard keys, and
    /// its sport (#744).
    ///
    /// Metadata rather than samples: it is summed into no daily total, so it
    /// cannot double-count what iOS already records from the motion chip, yet
    /// the résumé and the detail read real figures from it (`WorkoutSummary`).
    /// One table for both writers — the session's builder (#729) and the
    /// plain builder that saves an outing without a session.
    var workoutMetadata: [String: Any] {
        [
            FouleeWorkoutMetadata.steps: steps,
            FouleeWorkoutMetadata.distanceMeters: distanceMeters,
            FouleeWorkoutMetadata.calories: estimatedCalories
        ].merging(
            Elevation(ascent: elevationGainMeters, descent: elevationLossMeters).metadata
        ) { own, _ in own }
            .merging(activity.sport.workoutMetadata) { own, _ in own }
    }
}
