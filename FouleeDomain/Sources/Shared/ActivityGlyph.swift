import Foundation

/// The SF Symbol names that stand for an activity, in the one place every
/// target can compile.
///
/// Three surfaces outside the app draw an activity figure — the Série widget,
/// the Aujourd'hui widget and the Live Activity — and none of them compiles
/// `FouleeIcon`, which lives in `DesignSystem` and imports SwiftUI. Each had
/// its own `"figure.mixed.cardio"` literal, four copies of one symbol name
/// with nothing tying them together and no test pinning them: a typo in one of
/// them renders a blank box rather than failing the build, so the copies could
/// drift silently.
///
/// Foundation-only on purpose, so it lives in FouleeDomain with every target —
/// the same move `ActivityMode+Icon.swift` made in the other direction. It is
/// the *names* that are shared here, not the design vocabulary: `FouleeIcon`
/// stays the app's single icon table and re-exports the neutral figure from
/// this one (`FouleeIcon.mixedCardio`), so a future swap is still one line and
/// now propagates past the app target. The walk and run names are read through
/// `ActivityMode.icon` instead — a screen that knows the mode asks the mode.
nonisolated public enum ActivityGlyph {
    public static let walk = "figure.walk"
    public static let run = "figure.run"
    public static let hike = "figure.hiking"
    /// A run on trails (#744): HealthKit's figure for a run, in a circle, so
    /// it is not mistaken for a road run.
    public static let trail = "figure.run.circle"
    /// Indoor sessions (#745), HealthKit's own figures.
    public static let strength = "figure.strengthtraining.traditional"
    public static let hiit = "figure.highintensity.intervaltraining"
    public static let yoga = "figure.yoga"
    /// Indoor machines (#746), HealthKit's own figures.
    public static let rower = "figure.rower"
    public static let elliptical = "figure.elliptical"
    public static let treadmill = "figure.run.treadmill"
    /// Rides (#749).
    public static let cycling = "figure.outdoor.cycle"
    public static let indoorCycling = "figure.indoor.cycle"
    /// Laps of a pool (#751).
    public static let poolSwim = "figure.pool.swim"
    /// Walk *and* run — also the neutral stand-in wherever the surface knows a
    /// session is running but not which activity it is (the Live Activity, see
    /// issue #225).
    public static let mixedCardio = "figure.mixed.cardio"
}
