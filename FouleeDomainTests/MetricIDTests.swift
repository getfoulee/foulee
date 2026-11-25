import Foundation
import Testing
@testable import FouleeDomain

@Suite struct MetricIDTests {
    @Test func fractionDigitsPerMetric() {
        #expect(MetricID.distance.fractionDigits == 1)
        #expect(MetricID.steps.fractionDigits == 0)
        #expect(MetricID.minutes.fractionDigits == 0)
        #expect(MetricID.calories.fractionDigits == 0)
    }

    @Test func distanceFormatsWithOneDecimalComma() {
        #expect(MetricID.distance.formatted(4.2) == "4,2")
        #expect(MetricID.distance.formatted(12.0) == "12,0")
        #expect(MetricID.distance.formattedWithUnit(4.2) == "4,2 km")
    }

    @Test func wholeNumberMetricsHaveNoDecimalSeparator() {
        // steps/minutes/calories round to integers — never a decimal comma.
        #expect(MetricID.minutes.formatted(25) == "25")
        #expect(MetricID.calories.formatted(142.6) == "143")
        #expect(!MetricID.steps.formatted(5_391).contains(","))
        #expect(MetricID.steps.formattedWithUnit(25) == "25 pas")
    }

    /// Minutes are a duration once totalled (issue #366).
    @Test func minutesWithUnitReadAsADuration() {
        #expect(MetricID.minutes.formattedWithUnit(42) == "42 min")
        #expect(MetricID.minutes.formattedWithUnit(360) == "6 h")
        #expect(MetricID.minutes.formattedWithUnit(95.4) == "1 h 35")
    }

    /// The stats chart's axis (issue #370).
    @Test func axisGraduations() {
        #expect(MetricID.minutes.axisText(120) == "2 h")
        #expect(MetricID.minutes.axisText(30) == "30 min")
        #expect(MetricID.steps.axisText(5_000) == MetricID.steps.formatted(5_000))
    }

    /// The complications' short form: thousands as « k » for whole counts.
    @Test func compactText() {
        let american = Locale(identifier: "en_US")
        #expect(MetricID.steps.compactText(8_240) == "8,2k")
        #expect(MetricID.steps.compactText(8_240, locale: american) == "8.2k")
        #expect(MetricID.steps.compactText(999) == "999")
        #expect(MetricID.minutes.compactText(45) == "45")
        #expect(MetricID.calories.compactText(1_500) == "1,5k")
        #expect(MetricID.distance.compactText(12.34) == "12,3")
    }

    /// One symbol per metric, distinct, on every screen (#721).
    @Test func glyphsAreDistinct() {
        let glyphs = MetricID.allCases.map(\.glyph)
        #expect(Set(glyphs).count == MetricID.allCases.count)
        #expect(!glyphs.contains(""))
    }

    /// Each total has its own HealthKit quantity, read in the unit it is shown
    /// in: a distance in metres shown as km read « 4 523,0 km » (#774).
    @Test func healthKitSourceIsTheDisplayUnit() {
        let sources = MetricID.allCases.map(\.healthKitSource)
        #expect(Set(sources.map(\.quantityIdentifier)).count == MetricID.allCases.count)
        #expect(MetricID.distance.healthKitSource.unit == "km")
        #expect(MetricID.minutes.healthKitSource.unit == "min")
        #expect(MetricID.calories.healthKitSource.unit == "kcal")
    }

    /// The raw values key the watch complication's cache.
    @Test func rawValuesAreStable() {
        #expect(MetricID.allCases.map(\.rawValue) == ["steps", "minutes", "distance", "calories"])
    }
}
