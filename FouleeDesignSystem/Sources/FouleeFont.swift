import SwiftUI

/// Type ramp matching the design's `.t-largetitle … .t-caption` classes.
/// Every token is text-style relative, so it tracks the user's Dynamic Type
/// setting; the weights mirror the original fixed-size design at the
/// default (Large) size.
public enum FouleeFont {
    public static let largeTitle = Font.system(.largeTitle, weight: .bold)
    public static let title2 = Font.system(.title2, weight: .bold)
    public static let title3 = Font.system(.title3, weight: .semibold)
    public static let headline = Font.system(.headline, weight: .semibold)
    public static let body = Font.system(.body, weight: .regular)
    public static let callout = Font.system(.callout, weight: .regular)
    public static let footnote = Font.system(.footnote, weight: .regular)
    public static let caption = Font.system(.caption, weight: .regular)

    /// Rounded design with tabular digits — for big counters and timers.
    /// Frozen at `size`: shipping views must go through `scaledNumericFont`
    /// so the counter tracks Dynamic Type.
    public static func numeric(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}
