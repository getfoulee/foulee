import FouleeDomain
import Testing
@testable import Foulee

/// The Bilan's « Par sport » lines (#742).
@Suite("Recap sports section")
struct RecapSportsTests {
    @Test("A sport told by its climb shows it; a walk's climb stays in the totals")
    func climbFollowsTheDescriptor() {
        let hike = Recap.SportTotals(activity: .hiking, outings: 1, durationSeconds: 260 * 60, distanceKm: 12.5, climbMeters: 640)
        let walk = Recap.SportTotals(activity: .walking, outings: 4, durationSeconds: 190 * 60, distanceKm: 14.2, climbMeters: 80)

        #expect(RecapSports.figures(of: hike).last == "↑ 640 m")
        #expect(RecapSports.figures(of: walk).count == 3)
        #expect(RecapSports.figures(of: walk)[2] == 14.2.kmText(fractionDigits: 1))
    }

    @Test("VoiceOver hears the figures in words")
    func spokenFigures() {
        let hike = Recap.SportTotals(activity: .hiking, outings: 1, durationSeconds: 60 * 60, distanceKm: 4, climbMeters: 300)
        let spoken = RecapSports.spokenFigures(of: hike)
        #expect(spoken.contains(MetricID.distance.spokenText(4)))
        #expect(spoken.last == Elevation(ascent: 300, descent: 0).spokenText)
    }
}
