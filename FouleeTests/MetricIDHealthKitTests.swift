import FouleeHealth
import FouleeKit
import HealthKit
import Testing

/// The one mapping between a day metric and HealthKit (#721).
@Suite("Metric ↔ HealthKit")
struct MetricIDHealthKitTests {
    @Test("Each metric sums the quantity it has always summed")
    func quantityTypes() {
        #expect(MetricID.steps.quantityIdentifier == .stepCount)
        #expect(MetricID.minutes.quantityIdentifier == .appleExerciseTime)
        #expect(MetricID.distance.quantityIdentifier == .distanceWalkingRunning)
        #expect(MetricID.calories.quantityIdentifier == .activeEnergyBurned)
    }

    @Test("Each unit string is a real HealthKit unit, compatible with its quantity", arguments: MetricID.allCases)
    func compatibleUnit(metric: MetricID) throws {
        let type = try #require(HKQuantityType.quantityType(forIdentifier: metric.quantityIdentifier))
        #expect(type.is(compatibleWith: metric.healthKitUnit))
    }

    @Test("A distance comes back in kilometres (#774)")
    func distanceInKilometres() {
        let sum = HKQuantity(unit: .meter(), doubleValue: 4_523)
        #expect(abs(sum.doubleValue(for: MetricID.distance.healthKitUnit) - 4.523) < 1e-9)
    }
}
