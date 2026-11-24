import Foundation
import Testing
@testable import FouleeKit

@Suite("SessionRecord")
struct SessionRecordTests {
    private let start = Date(timeIntervalSince1970: 1_760_000_000)

    @Test("Energy of a one-sport session: its steps at that sport's rate")
    func singleActivityCalories() {
        let walk = SessionRecord(startedAt: start, steps: 1_000)
        #expect(walk.estimatedCalories == 40)
        let run = SessionRecord(startedAt: start, steps: 1_000, activity: .running)
        #expect(run.estimatedCalories == 90)
    }

    @Test("Energy of a mixed session: each sport's steps at its own rate")
    func mixedActivityCalories() {
        let session = SessionRecord(
            startedAt: start,
            steps: 1_000,
            stepsByActivity: [.walking: 500, .running: 500]
        )
        #expect(session.estimatedCalories == 65)
    }

    @Test("An empty split falls back to the session's own sport")
    func emptySplitFallsBack() {
        let session = SessionRecord(startedAt: start, steps: 1_000, activity: .running, stepsByActivity: [:])
        #expect(session.estimatedCalories == 90)
    }

    @Test("Distance in kilometres")
    func distanceKm() {
        #expect(SessionRecord(startedAt: start, distanceMeters: 2_500).distanceKm == 2.5)
    }
}
