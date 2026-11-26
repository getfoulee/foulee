import FouleeDomain
import Testing

/// What a live screen draws for each sport (#732), read from the descriptor.
@Suite("Sport live metrics")
struct SportLiveMetricsTests {
    @Test("A walk, a run and a hike show steps, distance, calories and the climb", arguments: SportID.allCases)
    func pedestrianSports(sport: SportID) {
        #expect(sport.descriptor.liveMetrics == [.steps, .distance, .calories])
        #expect(sport.descriptor.showsElevation)
    }
}
