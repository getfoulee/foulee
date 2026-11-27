import FouleeDesignSystem
import FouleeDomain
import SwiftUI

extension RecordedActivity {
    /// This activity's colour, from the table every surface shares (#318).
    var tint: Color {
        switch self {
        case .walking: ActivityPalette.walk
        case .running, .trailRunning, .indoorRunning: ActivityPalette.run
        case .hiking: ActivityPalette.hike
        case .cycling, .indoorCycling: ActivityPalette.ride
        case .poolSwimming, .openWaterSwimming: ActivityPalette.swim
        case .strength, .hiit, .yoga, .rowing, .elliptical: ActivityPalette.training
        case .other: ActivityPalette.neutral
        }
    }
}
