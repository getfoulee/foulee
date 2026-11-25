import FouleeKit
import Foundation
import Testing
@testable import FouleeWatch

/// The hidden recorder of #727: an outing's readings and pauses become a
/// trace, sent when the outing ends — and nothing at all with the switch off.
@MainActor
@Suite("Detection trace recorder")
struct WatchDetectionTraceTests {
    private let base = Date(timeIntervalSince1970: 1_716_796_800)

    @Test("With the switch on, the outing's readings and pauses are sent at the end")
    func recordsAndSends() async throws {
        let stub = WorkoutHealthKitStub()
        let motion = FakeMotionSource()
        motion.isAvailable = true
        let store = stub.makeStore(detection: WatchActivityDetection(source: motion.source, pedometer: .inert))
        var sent: [DetectionTrace] = []
        store.recordsTraces = { true }
        store.sendTrace = { sent.append($0) }

        await store.start(activity: .walking)
        await waitUntil { motion.isStreaming }
        motion.deliver(motionEstimate(startDate: base, walking: true))
        await waitUntil { store.trace?.events.isEmpty == false }
        store.pause()
        store.resume()
        await store.stop()

        let trace = try #require(sent.first)
        #expect(sent.count == 1)
        #expect(trace.startedAs == .walking)
        #expect(trace.events.contains { if case .motion = $0 { true } else { false } })
        #expect(trace.events.contains { if case .paused = $0 { true } else { false } })
        #expect(trace.events.contains { if case .resumed = $0 { true } else { false } })
        #expect(store.trace == nil)
    }

    @Test("With the switch off, nothing is recorded or sent")
    func offRecordsNothing() async {
        let stub = WorkoutHealthKitStub()
        let store = stub.makeStore()
        var sent: [DetectionTrace] = []
        store.recordsTraces = { false }
        store.sendTrace = { sent.append($0) }

        await store.start(activity: .walking)
        #expect(store.trace == nil)
        await store.stop()
        #expect(sent.isEmpty)
    }
}
