import SwiftUI

/// Small tag with optional leading SF Symbol — used for status badges
/// ("En cours", "Départ dans 18 min", "3 / 5 sorties", …). Quiet by default:
/// secondary text on the raised neutral; a tint only when it means something.
struct Chip: View {
    var label: LocalizedStringResource
    var systemIcon: String?
    var tint: Color = .secondary
    var fill: Color = FouleeColor.raised

    var body: some View {
        HStack(spacing: 6) {
            if let systemIcon {
                Image(systemName: systemIcon)
                    .font(FouleeFont.footnote.weight(.medium))
            }
            Text(label)
                .font(FouleeFont.footnote.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(fill, in: .rect(cornerRadius: Radius.tag))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
    }
}
