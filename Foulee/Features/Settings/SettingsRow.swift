import SwiftUI

/// One line of the Réglages home: a glyph, the setting's name, its current
/// value, and a chevron — the iOS Settings grammar, without the coloured
/// tiles. A label only: the caller wraps it in a `NavigationLink` or a
/// `Button`.
struct SettingsRow: View {
    var icon: String
    /// The glyph's colour: secondary, or a role's — the destructive red.
    var tint: Color = .secondary
    var title: LocalizedStringResource
    var summary: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .scaledSystemFont(size: 18, weight: .medium)
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FouleeFont.headline)
                    .foregroundStyle(.primary)
                Text(summary)
                    .font(FouleeFont.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The whole line is the hit area, not just its glyphs.
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
