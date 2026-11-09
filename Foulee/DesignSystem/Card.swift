import SwiftUI

/// The surface cards, hero blocks and sections sit on: one step above the
/// page, edged with a hairline.
///
/// No material, glow or drop shadow: the step from `FouleeColor.page` to
/// `FouleeColor.card` and the hairline carry the depth, in both appearances,
/// so the colour on screen is left to the content — the rings, a route, the
/// water.
struct CardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(FouleeColor.card, in: shape)
            .overlay(shape.strokeBorder(FouleeColor.hairline, lineWidth: 1))
    }
}

extension View {
    /// Apply the Foulée card surface: `Radius.card`, or `Radius.row` for a small
    /// one that sits among others, like a banner or a row.
    func fouleeCard(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius))
    }
}

/// The corner radii, by the size of what they round. An element inside a card
/// takes a smaller one than the card, so the corners stay concentric.
enum Radius {
    /// A card, a section, a sheet's block.
    static let card: CGFloat = 20
    /// A small card among others, a banner, a selectable row.
    static let row: CGFloat = 14
    /// A button or a control inside a card.
    static let control: CGFloat = 12
    /// A tag or a chip.
    static let tag: CGFloat = 8
}
