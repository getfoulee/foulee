import FouleeDomain
import SwiftUI

nonisolated extension SessionActivity {
    /// This activity's colour, from the table both devices draw with (#318,
    /// #320, #334): an outing must not change colours between the wrist, the
    /// mirrored map and the detail screen.
    public var tint: Color {
        switch self {
        case .walking: ActivityPalette.walk
        // A trail or a treadmill run is a run, and never sits beside a road
        // run in one outing.
        case .running, .trailRunning, .indoorRunning: ActivityPalette.run
        case .hiking: ActivityPalette.hike
        case .cycling, .indoorCycling: ActivityPalette.ride
        case .poolSwimming, .openWaterSwimming: ActivityPalette.swim
        case .strength, .hiit, .yoga, .rowing, .elliptical: ActivityPalette.training
        }
    }
}
