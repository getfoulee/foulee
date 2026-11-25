import SwiftUI

/// Brand palette and gradients shared across the app.
///
/// Brand colors (accent, success, warning, danger) live here; success and
/// warning deepen in light mode to stay readable (`ReadablePalette`, #599).
/// Theme-aware text/background uses SwiftUI's semantic colors directly
/// (`.primary`, `.secondary`, `Color(.systemBackground)`).
public enum FouleeColor {
    public static let accentStart = Color(hex: 0xD97AFF)
    public static let accentMid = Color(hex: 0xBF5AF2)
    public static let accentEnd = Color(hex: 0x7C3AED)
    public static let accentSecondary = Color(hex: 0x5E5CE6)
    /// Where `buttonGradient` starts, deeper than `accentStart`.
    public static let buttonStart = Color(hex: 0x9D4EDD)

    public static let success = ReadablePalette.green
    public static let warning = ReadablePalette.orange
    public static let danger = Color(hex: 0xFF453A)

    /// Water — the hydration card, screen, settings and Bilan block. A token
    /// here rather than on a view: a static on a `View` is main-actor
    /// isolated, and the Réglages page model reads it from a nonisolated
    /// context (issue #405).
    public static let water = Color.teal

    public static let accentGradient = LinearGradient(
        colors: [accentStart, accentMid, accentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Behind white text — the main buttons, the selected days (issue #658).
    /// It leaves out the light end of `accentGradient`, where white falls to
    /// 2.6:1: from here, it keeps 4.5:1 all the way.
    public static let buttonGradient = LinearGradient(
        colors: [buttonStart, accentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let streakGradient = LinearGradient(
        colors: [
            warning,
            Color.readable(dark: Color(hex: 0xFF6B00), light: 0xC85400, increasedContrast: 0x8F3D00)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Activity (midday-walk minutes) ring — green, distinct from the purple
    /// step ring, echoing the "exercise" colour language.
    public static let activityGradient = LinearGradient(
        colors: [
            Color.readable(dark: activityLight, light: 0x239F42, increasedContrast: 0x1C7F35),
            success,
            Color.readable(dark: activityDeep, light: 0x188A36, increasedContrast: 0x177030)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The widgets' background (#725): night purple in every mode, so what
    /// sits on it takes the bright shades (`MetricID.brightTint`).
    public static let nightGradient = LinearGradient(
        colors: [Color(hex: 0x2A0A4A), Color(hex: 0x1A0A3A)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// `activityGradient` on `nightGradient`: its dark-mode shades in every mode.
    public static let activityGradientOnNight = LinearGradient(
        colors: [activityLight, ReadablePalette.brightGreen, activityDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static let activityLight = Color(hex: 0x5BE36B)
    private static let activityDeep = Color(hex: 0x1FA845)
}

extension Color {
    /// Build a color from a 0xRRGGBB literal.
    public init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
