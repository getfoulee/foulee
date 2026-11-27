import FouleeDomain
import Testing

/// What a live screen draws for each sport (#732), read from the descriptor.
@Suite("Sport live metrics")
struct SportLiveMetricsTests {
    @Test(
        "A walk, a run, a hike and a trail show steps, distance, calories and the climb",
        arguments: SportID.allCases.filter { $0.descriptor.location == .outdoor }
    )
    func pedestrianSports(sport: SportID) {
        #expect(sport.descriptor.liveMetrics == [.steps, .distance, .calories])
        #expect(sport.descriptor.showsElevation)
    }

    @Test("An indoor session shows its calories alone", arguments: SportID.allCases.filter { $0.descriptor.family == .training })
    func indoorSessions(sport: SportID) {
        #expect(sport.descriptor.liveMetrics == [.calories])
        #expect(sport.descriptor.showsElevation == false)
    }

    @Test("A treadmill run shows steps, distance and calories, without the climb (#746)")
    func treadmill() {
        #expect(SportID.indoorRunning.descriptor.liveMetrics == [.steps, .distance, .calories])
        #expect(SportID.indoorRunning.descriptor.showsElevation == false)
    }
}
