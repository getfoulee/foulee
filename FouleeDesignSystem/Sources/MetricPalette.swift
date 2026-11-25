import SwiftUI

/// The colour each daily metric is drawn in (issues #366, #372): steps purple
/// like the home's outer ring, minutes green like its inner one, distance
/// blue, calories orange — and the heart rate red, which only the watch's
/// session shows (issue #381).
///
/// One table for the phone, its widgets and the watch, like `ActivityPalette`:
/// the same figure must not change colour between the wrist and the phone.
/// Minutes and calories deepen in light mode (`ReadablePalette`, #599).
nonisolated public enum MetricPalette {
    public static let steps = FouleeColor.accentMid
    public static let minutes = ReadablePalette.green
    public static let distance = Color(.sRGB, red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    public static let calories = ReadablePalette.orange
    public static let heartRate = Color(.sRGB, red: 255 / 255, green: 69 / 255, blue: 58 / 255)
}
