import Clocks
import Dependencies
import FouleeKit
import Foundation
import Testing
@testable import Foulee

/// What an outing goes without when iOS refused a permission (issue #611).
@Suite("ActiveSessionStore degraded states")
struct ActiveSessionStoreDegradedTests {
    @Test("An outing says what it goes without when iOS refused it")
    func refusedPermissionsAreShown() async {
        await withDependencies {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.pedometer = .testValue
            $0.healthKit = .testValue
            $0.continuousClock = TestClock()
            var location = LocationClient.testValue
            location.access = { .denied }
            $0.location = location
            var motion = MotionActivityHistory.testValue
            motion.access = { .denied }
            $0.motionActivityHistory = motion
        } operation: {
            let store = ActiveSessionStore()
            store.start()
            var spins = 0
            while store.degradedStates.isEmpty, spins < 1_000 {
                await Task.yield()
                spins += 1
            }
            #expect(store.degradedStates == [.locationDenied, .motionDenied])
            store.reset()
            #expect(store.degradedStates.isEmpty)
        }
    }
}
