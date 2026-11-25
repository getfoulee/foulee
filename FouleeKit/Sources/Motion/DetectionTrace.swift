import Foundation

/// What the sensors said during one real outing, in the order the watch
/// heard it (issue #727): enough to replay the walk/run detection against it.
///
/// The detection has cost two releases (ADR 0002), each time on a wrist no
/// simulator imitates. A trace turns one such outing into a test: the readings
/// go back through `DetectionReplay`, and the switches it finds are compared
/// with the ones the wearer marked.
nonisolated public struct DetectionTrace: Codable, Equatable, Sendable {
    /// Bumped when the layout changes, so an old file is read knowingly.
    public static let currentVersion = 1

    public var version = Self.currentVersion
    /// What the outing was, in a few words: « marche puis course au parc ».
    public var title: String
    public var startedAt: Date
    public var startedAs: SessionActivity
    /// Whether the device gave a live cadence: without it a run needs no
    /// pedometer confirmation (issue #390).
    public var hasPedometerRhythm: Bool
    public var events: [Event]
    /// The changes of sport the wearer actually made, marked by hand once the
    /// trace is kept as a fixture. Empty in a fresh recording.
    public var expectedSwitches: [ExpectedSwitch]

    public init(
        title: String,
        startedAt: Date,
        startedAs: SessionActivity,
        hasPedometerRhythm: Bool,
        events: [Event],
        expectedSwitches: [ExpectedSwitch] = []
    ) {
        self.title = title
        self.startedAt = startedAt
        self.startedAs = startedAs
        self.hasPedometerRhythm = hasPedometerRhythm
        self.events = events
        self.expectedSwitches = expectedSwitches
    }

    /// The hidden setting that turns recording on (#727): on the iPhone, in
    /// `UserDefaults.standard`, never synced — a trace is wanted from one
    /// wrist, the one being tested.
    public static let recordingSettingKey = "debug.recordsDetectionTraces"

    /// The metadata a trace file travels to the iPhone with, so the phone
    /// tells it from any other file the watch may send one day.
    public static let transferMetadata = ["kind": "detectionTrace"]

    /// Past this many events a recording stops growing: two hours of an outing
    /// stay well under it, and a forgotten session cannot fill the watch.
    public static let maximumEvents = 40_000

    /// Adds `event` unless the recording is full.
    public mutating func record(_ event: Event) {
        guard events.count < Self.maximumEvents else { return }
        events.append(event)
    }

    /// « trace-20240527-080000.json », from when the outing began: sorts by
    /// date, and names a file without reading its attributes.
    public var fileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "trace-\(formatter.string(from: startedAt)).json"
    }

    /// How a trace file is written and read: dates in seconds since 1970,
    /// readable by any tool, keys sorted so two recordings diff cleanly.
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    /// One thing the watch was told, dated by when it arrived.
    public enum Event: Codable, Equatable, Sendable {
        case pedometer(PedometerReading)
        case motion(MotionActivityEstimate)
        /// The outing's climb and descent so far.
        case altitude(at: Date, Elevation)
        /// A GPS fix, `nil` accuracy for a fix lost.
        case location(at: Date, horizontalAccuracy: Double?)
        case paused(at: Date)
        case resumed(at: Date)
    }

    /// A change the wearer made, with how far from it a detected boundary may
    /// fall and still count.
    public struct ExpectedSwitch: Codable, Equatable, Sendable {
        public var activity: SessionActivity
        /// Seconds after `startedAt`.
        public var offset: TimeInterval
        public var tolerance: TimeInterval

        public init(activity: SessionActivity, offset: TimeInterval, tolerance: TimeInterval = 30) {
            self.activity = activity
            self.offset = offset
            self.tolerance = tolerance
        }
    }
}

/// A trace played back through the same detection the watch runs (#727).
nonisolated enum DetectionReplay {
    /// The changes of sport the detection finds in `trace`, in order.
    ///
    /// A pause stops the detection and a resume starts it again from the sport
    /// of the moment, as `WatchWorkoutStore` does: readings in between are not
    /// heard.
    static func switches(in trace: DetectionTrace) -> [ActivitySwitchDetector.Switch] {
        var activity = trace.startedAs
        var core: ActivityDetectionCore? = ActivityDetectionCore(
            startedAs: activity, at: trace.startedAt, runningNeedsPedometer: trace.hasPedometerRhythm
        )
        var found: [ActivitySwitchDetector.Switch] = []
        for event in trace.events {
            var step: ActivityDetectionCore.Step?
            switch event {
            case .pedometer(let reading): step = core?.ingest(reading)
            case .motion(let estimate): step = core?.ingest(estimate)
            case .paused: core = nil
            case .resumed(let date):
                core = ActivityDetectionCore(startedAs: activity, at: date, runningNeedsPedometer: trace.hasPedometerRhythm)
            case .altitude, .location: break
            }
            if let confirmed = step?.confirmed {
                activity = confirmed.activity
                found.append(confirmed)
            }
        }
        return found
    }

    /// Whether `found` are the wearer's switches: as many, the same sports in
    /// the same order, each boundary within its tolerance.
    static func matches(_ found: [ActivitySwitchDetector.Switch], in trace: DetectionTrace) -> Bool {
        guard found.count == trace.expectedSwitches.count else { return false }
        return zip(found, trace.expectedSwitches).allSatisfy { switched, expected in
            let offset = switched.date.timeIntervalSince(trace.startedAt)
            return switched.activity == expected.activity && abs(offset - expected.offset) <= expected.tolerance
        }
    }
}
