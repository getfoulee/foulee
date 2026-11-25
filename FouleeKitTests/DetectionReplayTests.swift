import Foundation
import Testing
@testable import FouleeKit

/// The walk/run detection replayed against traces (#727): built ones here,
/// stating ADR 0002's cases, and recorded ones from `FouleeKitTests/Traces/`.
@Suite("Detection replay")
struct DetectionReplayTests {
    /// 2024-05-27 08:00 UTC.
    private static let start = Date(timeIntervalSince1970: 1_716_796_800)

    /// A stretch of steady movement: a pedometer reading every three seconds,
    /// and a CoreMotion estimate every ten that began 30 s before it arrived —
    /// how slowly it was measured to answer (#248).
    private static func stretch(
        from begin: TimeInterval,
        to end: TimeInterval,
        cadence: Double,
        speed: Double,
        coreMotion activity: SessionActivity?
    ) -> [DetectionTrace.Event] {
        var events: [DetectionTrace.Event] = []
        var time = begin
        while time < end {
            time += 3
            events.append(.pedometer(PedometerReading(
                date: start.addingTimeInterval(time), cadence: cadence, pace: speed > 0 ? 1 / speed : nil
            )))
            if Int(time) % 10 < 3 {
                events.append(.motion(MotionActivityEstimate(
                    startDate: start.addingTimeInterval(max(begin, time - 30)),
                    receivedAt: start.addingTimeInterval(time),
                    confidence: .high,
                    walking: activity == .walking,
                    running: activity == .running
                )))
            }
        }
        return events
    }

    private static func walk(_ begin: TimeInterval, _ end: TimeInterval) -> [DetectionTrace.Event] {
        stretch(from: begin, to: end, cadence: 1.8, speed: 1.4, coreMotion: .walking)
    }

    private static func run(_ begin: TimeInterval, _ end: TimeInterval) -> [DetectionTrace.Event] {
        stretch(from: begin, to: end, cadence: 2.8, speed: 2.9, coreMotion: .running)
    }

    private static func trace(
        _ title: String,
        startedAs activity: SessionActivity = .walking,
        _ events: [DetectionTrace.Event],
        expecting expected: [DetectionTrace.ExpectedSwitch]
    ) -> DetectionTrace {
        DetectionTrace(
            title: title, startedAt: start, startedAs: activity, hasPedometerRhythm: true,
            events: events, expectedSwitches: expected
        )
    }

    @Test("A steady walk stays a walk")
    func steadyWalk() {
        let trace = Self.trace("marche", Self.walk(0, 600), expecting: [])
        #expect(DetectionReplay.switches(in: trace).isEmpty)
    }

    @Test("A walk that turns into a run switches near the change")
    func walkThenRun() throws {
        let trace = Self.trace(
            "marche puis course", Self.walk(0, 300) + Self.run(300, 600),
            expecting: [.init(activity: .running, offset: 300, tolerance: 15)]
        )
        let found = DetectionReplay.switches(in: trace)
        #expect(DetectionReplay.matches(found, in: trace), "found \(found.map { ($0.activity, $0.date.timeIntervalSince(Self.start)) })")
    }

    @Test("A run back to a walk switches back")
    func runThenWalk() {
        let trace = Self.trace(
            "course puis marche", startedAs: .running, Self.run(0, 300) + Self.walk(300, 600),
            expecting: [.init(activity: .walking, offset: 300, tolerance: 45)]
        )
        let found = DetectionReplay.switches(in: trace)
        #expect(DetectionReplay.matches(found, in: trace), "found \(found.map { ($0.activity, $0.date.timeIntervalSince(Self.start)) })")
    }

    @Test("A red light on a run is no walk: a shuffle says nothing")
    func redLightOnARun() {
        let shuffle = Self.stretch(from: 300, to: 340, cadence: 0.6, speed: 0.2, coreMotion: nil)
        let trace = Self.trace("feu rouge", startedAs: .running, Self.run(0, 300) + shuffle + Self.run(340, 600), expecting: [])
        #expect(DetectionReplay.switches(in: trace).isEmpty)
    }

    @Test("Nothing is heard during a pause, and a lost GPS changes nothing")
    func pauseAndGPSLoss() {
        let pausedRun = [DetectionTrace.Event.paused(at: Self.start.addingTimeInterval(300))]
            + Self.run(300, 400)
            + [.resumed(at: Self.start.addingTimeInterval(400)), .location(at: Self.start.addingTimeInterval(401), horizontalAccuracy: nil)]
        let trace = Self.trace("pause et GPS perdu", Self.walk(0, 300) + pausedRun + Self.walk(400, 600), expecting: [])
        #expect(DetectionReplay.switches(in: trace).isEmpty)
    }

    @Test("A trace written and read back is the same trace")
    func roundTrip() throws {
        let trace = Self.trace(
            "aller-retour",
            Self.walk(0, 30) + [.altitude(at: Self.start, Elevation(ascent: 3, descent: 1))],
            expecting: [.init(activity: .running, offset: 12)]
        )
        let data = try DetectionTrace.encoder().encode(trace)
        #expect(try DetectionTrace.decoder().decode(DetectionTrace.self, from: data) == trace)
    }

    // MARK: - Recorded traces

    private final class BundleToken {}

    /// Every trace kept in `FouleeKitTests/Traces/`, each with the switches
    /// its wearer marked. A detection change that loses one fails here.
    @Test("Every recorded trace finds the switches its wearer marked")
    func recordedTraces() throws {
        let urls = Bundle(for: BundleToken.self).urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        try #require(!urls.isEmpty, "no trace in FouleeKitTests/Traces")
        for url in urls {
            let trace = try DetectionTrace.decoder().decode(DetectionTrace.self, from: Data(contentsOf: url))
            #expect(trace.version == DetectionTrace.currentVersion, "\(url.lastPathComponent)")
            let found = DetectionReplay.switches(in: trace)
            let offsets = found.map { ($0.activity, $0.date.timeIntervalSince(trace.startedAt)) }
            #expect(DetectionReplay.matches(found, in: trace), "\(url.lastPathComponent) (\(trace.title)): found \(offsets)")
        }
    }
}

/// The recording side of #727: what the watch keeps and how it names it.
@Suite("Detection trace recording")
struct DetectionTraceRecordingTests {
    @Test("A recording stops growing at its cap")
    func capped() {
        var trace = DetectionTrace(
            title: "", startedAt: .distantPast, startedAs: .walking, hasPedometerRhythm: true, events: []
        )
        for _ in 0..<(DetectionTrace.maximumEvents + 5) { trace.record(.paused(at: .distantPast)) }
        #expect(trace.events.count == DetectionTrace.maximumEvents)
    }

    @Test("A trace file is named by when its outing began")
    func fileName() {
        let trace = DetectionTrace(title: "", startedAt: .now, startedAs: .running, hasPedometerRhythm: false, events: [])
        #expect(trace.fileName.wholeMatch(of: /trace-\d{8}-\d{6}\.json/) != nil)
    }

    @Test("A payload from before the recorder leaves it off")
    func payloadDefaultsOff() throws {
        let json = #"{"streak":3,"minutesGoal":20,"stepsGoal":6000}"#
        let payload = try JSONDecoder().decode(WatchSyncPayload.self, from: Data(json.utf8))
        #expect(!payload.recordsDetectionTraces)
        let on = WatchSyncPayload(streak: 3, minutesGoal: 20, stepsGoal: 6_000, recordsDetectionTraces: true)
        #expect(try JSONDecoder().decode(WatchSyncPayload.self, from: JSONEncoder().encode(on)).recordsDetectionTraces)
    }
}
