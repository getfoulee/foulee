import SwiftUI

/// Circular progress ring with a flat stroke and a centred label slot.
///
/// `progress` is clamped to `0...1`. Animates with an `.easeOut(0.6)` curve
/// so quick HealthKit updates feel snappy without jitter — or not at all with
/// « Réduire les animations ».
struct ProgressRing<Label: View>: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    /// The metric the ring fills, in its own colour — steps by default.
    var tint: Color = MetricPalette.steps
    /// One step above the surface, so it shows on a card and on the dark
    /// background of the session screen alike (issue #408).
    var trackColor: Color = FouleeColor.raised
    @ViewBuilder var label: () -> Label

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .motionAnimation(.easeOut(duration: 0.6), value: clamped)
            label()
        }
    }
}
