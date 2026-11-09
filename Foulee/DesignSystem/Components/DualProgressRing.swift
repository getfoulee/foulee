import SwiftUI

/// Two concentric progress rings (Fitness-style) for showing two independent
/// goals at once: an `outer` ring and an inset `inner` ring, each in its
/// metric's colour, plus a centred label slot. Both progresses are clamped to
/// `0...1`.
///
/// The home's one place of rich colour: everything around it stays neutral,
/// so the two rings read first.
struct DualProgressRing<Label: View>: View {
    var outerProgress: Double
    var innerProgress: Double
    var lineWidth: CGFloat = 9
    var outerTint: Color = MetricPalette.steps
    var innerTint: Color = MetricPalette.minutes
    var trackColor: Color = FouleeColor.raised
    @ViewBuilder var label: () -> Label

    private var inset: CGFloat { lineWidth + 5 }

    var body: some View {
        ZStack {
            ring(progress: outerProgress, tint: outerTint)
            ring(progress: innerProgress, tint: innerTint)
                .padding(inset)
            label()
        }
    }

    private func ring(progress: Double, tint: Color) -> some View {
        let clamped = min(max(progress, 0), 1)
        return ZStack {
            Circle().stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .motionAnimation(.easeOut(duration: 0.6), value: clamped)
        }
    }
}
