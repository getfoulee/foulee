import FouleeDesignSystem
import SwiftUI

/// One tappable glass row: the sports of « Autre sport » (#743), and the
/// favourite sports of Réglages and the onboarding (#835). A selected row
/// carries a check, a ring and the selected trait.
struct ChoiceRow: View {
    var title: Text
    var subtitle: Text?
    var systemIcon: String
    var isSelected: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(FouleeFont.headline)
                        .foregroundStyle(Color.primary)
                    if let subtitle {
                        subtitle
                            .font(FouleeFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: FouleeIcon.check)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FouleeColor.accentMid)
                    .opacity(isSelected ? 1 : 0)
                    // The selected trait says it.
                    .accessibilityHidden(true)
            }
            .padding(14)
            .fouleeGlass(cornerRadius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(FouleeColor.accentMid.opacity(isSelected ? 0.8 : 0), lineWidth: 2)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var icon: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                isSelected
                    ? AnyShapeStyle(FouleeColor.accentGradient)
                    : AnyShapeStyle(FouleeColor.accentMid.opacity(0.15))
            )
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: systemIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(FouleeColor.accentMid))
            }
            .accessibilityHidden(true)
    }
}
