import FouleeKit
import SwiftUI
import Testing
@testable import Foulee

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

    /// The watch's palette is the brand's, spelled out (#372).
    @Test("The shared palette matches the brand colours")
    func paletteMatchesTheBrand() {
        #expect(MetricPalette.steps == FouleeColor.accentMid)
        #expect(MetricPalette.minutes == FouleeColor.success)
        #expect(MetricPalette.calories == FouleeColor.warning)
        #expect(MetricPalette.distance == Color(hex: 0x0A84FF))
        #expect(MetricPalette.heartRate == FouleeColor.danger)
    }
}
