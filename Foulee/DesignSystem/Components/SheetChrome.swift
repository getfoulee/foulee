import SwiftUI

/// A round button for a sheet's top corner (issues #392, #410): the « × »
/// every sheet closes with, and the actions that sit beside it. One definition
/// so the sheets stop drifting apart — a solid card with a hairline keeps it
/// readable over a map as well as over the page.
struct SheetRoundButton: View {
    var systemImage: String
    var accessibilityLabel: LocalizedStringResource
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(FouleeColor.card, in: Circle())
                .overlay(Circle().strokeBorder(FouleeColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// The round « × », inset from the sheet's corner.
struct SheetCloseButton: View {
    var accessibilityLabel: LocalizedStringResource = "Fermer"
    var action: () -> Void

    var body: some View {
        SheetRoundButton(systemImage: "xmark", accessibilityLabel: accessibilityLabel, action: action)
            .padding(20)
    }
}

/// A quiet eyebrow over a large title — the opening line of a sheet
/// (« Récap / Ton bilan », « Hydratation / Aujourd'hui »…).
struct SheetHeader: View {
    var eyebrow: LocalizedStringResource
    var title: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eyebrow)
                .font(FouleeFont.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(FouleeFont.largeTitle)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A titled card: the one way a sheet groups related content. The title
/// sits inside the card, an optional footnote under its content.
struct CardSection<Content: View>: View {
    var title: LocalizedStringResource?
    var footer: LocalizedStringResource?
    let content: Content

    init(_ title: LocalizedStringResource? = nil, footer: LocalizedStringResource? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(FouleeFont.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            content
            if let footer {
                Text(footer)
                    .font(FouleeFont.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .fouleeCard()
    }
}
