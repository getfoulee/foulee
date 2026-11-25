import FouleeDesignSystem
import FouleeDomain
import SwiftUI
import Testing
import UIKit

/// A metric is drawn in the colour of its ring everywhere (issue #366).
@Suite("Metric colours")
struct MetricIDStyleTests {
    @Test("Steps and minutes take the home ring's colours")
    func ringsColours() {
        // The outer ring is the accent gradient, centred on accentMid; the
        // inner one the activity gradient, centred on success.
        #expect(MetricID.steps.tint == FouleeColor.accentMid)
        #expect(MetricID.minutes.tint == FouleeColor.success)
    }

    @Test("Every metric has its own colour")
    func distinctColours() {
        let tints = MetricID.allCases.map(\.tint)
        #expect(Set(tints.map(\.description)).count == MetricID.allCases.count)
    }

    /// The watch draws from the same palette as the phone (#372).
    @Test("The shared palette matches the brand colours")
    func paletteMatchesTheBrand() {
        #expect(MetricPalette.steps == FouleeColor.accentMid)
        #expect(MetricPalette.minutes == FouleeColor.success)
        #expect(MetricPalette.calories == FouleeColor.warning)
        #expect(MetricPalette.distance == Color(hex: 0x0A84FF))
        #expect(MetricPalette.heartRate == FouleeColor.danger)
    }

    /// The widgets sit on a night background in every mode (#725): their
    /// figures keep the bright shade the phone shows in dark mode.
    @Test("On the widgets' night background, a metric keeps its dark-mode shade")
    func brightTintIsTheDarkShade() {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        for metric in MetricID.allCases {
            #expect(
                UIColor(metric.brightTint).resolvedColor(with: light)
                    == UIColor(metric.tint).resolvedColor(with: dark),
                "\(metric)"
            )
        }
    }
}
