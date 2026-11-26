import FouleeDesignSystem
import FouleeDomain
import SwiftUI

/// « Autre sport » (issue #743): the favourites first, then every other sport
/// Foulée records. Choosing one starts it, and it becomes the sport
/// « Démarrer » starts next time.
struct SportPickerSheet: View {
    var sections: SportChoice.Sections
    /// The sport « Démarrer » starts now, checked.
    var current: SessionActivity
    var onChoose: (SessionActivity) -> Void
    var onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(eyebrow: "Démarrer", title: "Quel sport ?")
                group("Favoris", sports: sections.favorites)
                group("Autres sports", sports: sections.others)
            }
            .screenColumn()
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .topTrailing) { SheetCloseButton(action: onClose) }
        .presentationBackground { SheetBackground() }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func group(_ title: LocalizedStringResource, sports: [SessionActivity]) -> some View {
        if !sports.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(FouleeFont.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(sports, id: \.self) { sport in
                    SportPickerRow(sport: sport, isCurrent: sport == current) { onChoose(sport) }
                }
            }
        }
    }
}

/// The way to another sport than the last one (#743): one line under the
/// home's buttons, so the usual sport stays one tap away.
struct OtherSportButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Autre sport", systemImage: FouleeIcon.otherSport)
                .font(FouleeFont.callout.weight(.semibold))
                .foregroundStyle(ReadablePalette.purpleText)
                .frame(maxWidth: .infinity, minHeight: 44)
                // The whole line takes the tap, not only the glyphs: a plain
                // button hit-tests its content, which left a thin target.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(TodayAccessibility.otherSport)
    }
}

/// One sport. Internal so a test can reach its tap through the `ForEach`.
struct SportPickerRow: View {
    var sport: SessionActivity
    var isCurrent: Bool
    var select: () -> Void

    var body: some View {
        ChoiceRow(
            title: Text(verbatim: sport.label),
            subtitle: nil,
            systemIcon: sport.icon,
            isSelected: isCurrent,
            select: select
        )
        .accessibilityHint(Text("Démarre une sortie"))
    }
}

#Preview {
    SportPickerSheet(
        sections: SportChoice.sections(favorites: [.running]),
        current: .running,
        onChoose: { _ in },
        onClose: {}
    )
}
