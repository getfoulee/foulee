import Foundation

/// The value the streak surfaces draw — a date, the current streak, and which
/// activity to draw: the iPhone's Série widget and the watch's complication
/// (#818).
///
/// Plain data, so it lives in the kit both widget extensions link; each one
/// declares it a `TimelineEntry` itself, which keeps WidgetKit out of the kit.
nonisolated public struct StreakEntry: Sendable {
    public let date: Date
    public let streak: Int
    /// Which figure the surface should show (issue #222). Defaulted rather
    /// than required because the watch complication draws a flame and no
    /// activity figure at all: only the iPhone widget passes it, from the
    /// app-group snapshot.
    public var activityMode: ActivityMode

    public init(date: Date, streak: Int, activityMode: ActivityMode = .walking) {
        self.date = date
        self.streak = streak
        self.activityMode = activityMode
    }

    public static let placeholder = StreakEntry(date: .now, streak: 0)
}
