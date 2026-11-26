import FouleeDomain
import SwiftUI
import WidgetKit

// The Live Activity for a walk, a run and a sport without a distance (#732),
// on the Lock Screen and in the expanded Dynamic Island.

private extension SessionActivityState {
    static let halfway = SessionActivityState(
        timerBasis: .now.addingTimeInterval(-1_104),
        pausedAt: nil,
        elapsed: 1_104,
        steps: 2_480,
        distanceKm: 1.83,
        activeCalories: 108,
        climbMeters: 24,
        descentMeters: 12
    )
}

private extension SessionActivityAttributes {
    /// No sport records this yet: strength or a rower, whose only figure is
    /// the calories.
    static let withoutDistance = SessionActivityAttributes(
        goalMinutes: 30,
        activity: nil,
        metrics: [.calories],
        showsElevation: false
    )
}

#Preview("Marche", as: .content, using: SessionActivityAttributes(goalMinutes: 30, activity: .walking)) {
    SessionLiveActivity<SessionActivityAttributes>()
} contentStates: {
    SessionActivityState.halfway
}

#Preview("Course", as: .dynamicIsland(.expanded), using: SessionActivityAttributes(goalMinutes: 30, activity: .running)) {
    SessionLiveActivity<SessionActivityAttributes>()
} contentStates: {
    SessionActivityState.halfway
}

#Preview("Sans distance", as: .content, using: SessionActivityAttributes.withoutDistance) {
    SessionLiveActivity<SessionActivityAttributes>()
} contentStates: {
    SessionActivityState.halfway
}

#Preview("Sans distance, île", as: .dynamicIsland(.expanded), using: SessionActivityAttributes.withoutDistance) {
    SessionLiveActivity<SessionActivityAttributes>()
} contentStates: {
    SessionActivityState.halfway
}
