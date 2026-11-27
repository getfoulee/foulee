import SwiftUI

/// The colour each activity is drawn in, wherever an outing is broken down by
/// sport — the detail's timeline and heart-rate chart (issue #318), and the
/// maps to come (#319, #320).
///
/// One table for every surface, the watch's included: a walk drawn cyan on the phone and green on the wrist would make the
/// two screens disagree about the same outing.
///
/// **Blue against orange** because it is the pair that stays apart under the
/// commonest colour-vision deficiencies, where red against green collapses.
/// Bright in dark mode, deeper in light mode so they stay readable on white
/// (`ReadablePalette`, #599). And never the colour alone: every place that
/// paints a sport also names it, with a glyph or a label.
nonisolated public enum ActivityPalette {
    public static let walk = ReadablePalette.cyan
    public static let run = ReadablePalette.orange
    public static let hike = ReadablePalette.green
    /// Strength, HIIT, yoga, rower, elliptical (#745, #746): one colour, they
    /// never share an outing.
    public static let training = ReadablePalette.indigoText
    /// A sport Foulée cannot name.
    public static let neutral = Color.gray
}
