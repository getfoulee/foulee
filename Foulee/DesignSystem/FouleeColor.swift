import SwiftUI

/// The palette: one neutral ramp, one accent, and the colours that mean
/// something.
///
/// The chrome stays quiet — pages, cards, borders and text come from the ramp,
/// and text uses SwiftUI's semantic `.primary` / `.secondary`. Colour goes
/// where it carries a meaning: the day's two rings and the metrics they count
/// (`MetricPalette`), an outing's sports (`ActivityPalette`), the water, the
/// streak's flame. The accent is the icon's violet, flat, on the main action
/// and the selection — never as a gradient, a glow or a coloured shadow.
///
/// Success and warning deepen in light mode to stay readable
/// (`ReadablePalette`, #599).
enum FouleeColor {
    /// The accent behind white text — the main button, a selected day. White
    /// keeps 4.5:1 on it in both appearances.
    static let accent = Color(hex: 0x7C3AED)
    /// The accent as ink — a glyph, a link, a selected label — readable on the
    /// page and on a card in both appearances (issue #658).
    static let accentInk = ReadablePalette.purpleText

    static let success = ReadablePalette.green
    static let warning = ReadablePalette.orange
    static let danger = Color(hex: 0xFF453A)

    /// Water — the hydration card, screen, settings and Bilan block.
    static let water = Color.teal

    // MARK: Neutral ramp

    // Warm paper in light mode, graphite in dark: the outing happens outside,
    // in daylight, and the screen is read for a glance before going out —
    // neither surface may read as a colour of its own.

    /// Under every screen and sheet.
    static let page = Color.scheme(light: 0xF5F4F1, dark: 0x111112)
    /// A card on the page.
    static let card = Color.scheme(light: 0xFFFFFF, dark: 0x1C1C1E)
    /// One step above a card — a secondary button, a chip, a ring's track.
    static let raised = Color.scheme(light: 0xEDEBE7, dark: 0x2C2C2E)
    /// A card's border and a rule between figures: the text colour at 8 %.
    static let hairline = Color.primary.opacity(0.08)
}

extension Color {
    /// Build a color from a 0xRRGGBB literal.
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    /// `light` in light mode, `dark` in dark mode — a surface, which
    /// « Augmenter le contraste » leaves as it is.
    static func scheme(light: UInt32, dark: UInt32) -> Color {
        .readable(dark: Color(hex: dark), light: light, increasedContrast: light)
    }
}
