import SwiftUI

/// Type ramp matching the design's `.t-largetitle … .t-caption` classes.
/// Every token is text-style relative, so it tracks the user's Dynamic Type
/// setting. Two weights, regular and medium: the hierarchy comes from the
/// size and the text colour, not from bold.
enum FouleeFont {
    static let largeTitle = Font.system(.largeTitle, weight: .medium)
    static let title2 = Font.system(.title2, weight: .medium)
    static let title3 = Font.system(.title3, weight: .medium)
    static let headline = Font.system(.headline, weight: .medium)
    static let body = Font.system(.body, weight: .regular)
    static let callout = Font.system(.callout, weight: .regular)
    static let footnote = Font.system(.footnote, weight: .regular)
    static let caption = Font.system(.caption, weight: .regular)

    /// Rounded design with tabular digits — for big counters and timers.
    /// Frozen at `size`: shipping views must go through `scaledNumericFont`
    /// so the counter tracks Dynamic Type.
    static func numeric(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}
