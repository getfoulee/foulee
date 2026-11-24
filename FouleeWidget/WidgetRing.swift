import SwiftUI
import WidgetKit

/// A goal ring drawn by the Home Screen widgets: a grey track and a gradient
/// arc from twelve o'clock (#721). The app's `ProgressRing` lives in the
/// design system, which the widget does not compile.
///
/// Any progress at all shows at least a sliver, so a first step is visible.
struct WidgetRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
    /// Whether the arc takes the accent colour in the tinted and accented Home
    /// Screen modes (#601), where its own colour would turn white.
    var accentable = true

    var body: some View {
        ZStack {
            Circle().stroke(.gray.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress > 0 ? max(progress, 0.03) : 0)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable(accentable)
        }
    }
}
