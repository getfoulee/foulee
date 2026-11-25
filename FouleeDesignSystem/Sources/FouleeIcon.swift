import FouleeDomain
import SwiftUI

/// SF Symbol names used across screens, mapped to the design's icon vocabulary
/// (`walk`, `timer`, `flame`, …). Centralised so a future swap is one-line.
nonisolated public enum FouleeIcon {
    // The activity figures are named by the kit's own types too
    // (`ActivityMode.icon`), so they live in its `ActivityGlyph`, which is
    // Foundation-only, and are re-exported here so screens keep one icon table. The
    // day metrics' symbols come from `MetricID.glyph` the same way (#721).
    //
    // Only the neutral one is re-exported: a screen that knows the mode reads
    // `ActivityMode.icon`, and one that doesn't draws this. Re-exporting `walk`
    // and `run` as well left two properties nobody called, which Periphery
    // rightly failed the build on.
    /// Walk *and* run — used wherever the activity isn't known at that point.
    public static let mixedCardio = ActivityGlyph.mixedCardio
    public static let timer = MetricID.minutes.glyph
    public static let check = "checkmark"
    public static let footsteps = MetricID.steps.glyph
    public static let distance = MetricID.distance.glyph
    public static let climb = "mountain.2.fill"
    public static let descent = "arrow.down.right"
    public static let flame = MetricID.calories.glyph
    public static let bell = "bell.fill"
    public static let sun = "sun.max.fill"
    public static let heart = "heart.fill"
    public static let play = "play.fill"
    public static let pause = "pause.fill"
    public static let stop = "stop.fill"
    public static let location = "location.fill"
    public static let sparkle = "sparkles"
    public static let target = "target"
    public static let watch = "applewatch"
    public static let merge = "arrow.triangle.merge"
    public static let separate = "arrow.triangle.branch"
}
