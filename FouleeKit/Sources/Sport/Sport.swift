import Foundation

/// A sport Foulée can name, as data rather than as a branch (issue #720).
///
/// The raw values are stored — in preferences, in the watch ↔ iPhone payload,
/// in the Connect IQ messages — so they never change. They are the same
/// strings `SessionActivity` and `RecordedActivity` already persist, which is
/// what lets those two enums hand their vocabulary over to this one without a
/// migration.
///
/// Adding a sport is adding a case and its descriptor below; the
/// `CaseIterable` tests then demand its HealthKit and Garmin answers.
nonisolated public enum SportID: String, CaseIterable, Codable, Sendable {
    case walking
    case running
    /// Read-side only for now: the résumé has listed hikes since #217, but
    /// Foulée does not record one yet (#744).
    case hiking

    /// Everything Foulée knows about this sport.
    public var descriptor: SportDescriptor {
        switch self {
        case .walking: .walking
        case .running: .running
        case .hiking: .hiking
        }
    }

    /// The sport HealthKit stamped on a workout, from
    /// `HKWorkoutActivityType.rawValue`. `nil` for a type Foulée cannot name.
    ///
    /// The kit stays free of HealthKit (ADR 0007), so the mapping is kept as
    /// raw values here and read through the one extension
    /// `SportID+HealthKit` in FouleeHealth.
    public init?(healthKitActivityRawValue rawValue: UInt) {
        guard let sport = Self.allCases.first(where: { $0.descriptor.healthKitActivityRawValue == rawValue }) else {
            return nil
        }
        self = sport
    }

    /// The sport a Connect IQ message names in its `sport` field.
    public init?(garminSport: String) {
        guard let sport = Self.allCases.first(where: { $0.descriptor.garminSport == garminSport }) else {
            return nil
        }
        self = sport
    }
}

/// One sport's configuration: what it is, where it happens, which sensors it
/// uses, how its speed reads, and how HealthKit and Garmin name it.
///
/// Live and summary metrics belong to the metric catalog (#721).
nonisolated public struct SportDescriptor: Sendable {
    /// The broad kind of effort, which decides the session's shape.
    public enum Family: Equatable, Sendable {
        /// Walking, running, hiking: steps, a pace, a route.
        case onFoot
    }

    /// Where the sport happens, which decides whether GPS is asked for.
    public enum Location: Equatable, Sendable {
        case outdoor
    }

    /// How speed is written for this sport.
    public enum SpeedDisplay: Equatable, Sendable {
        /// Minutes per kilometre, « 6'12" /km ».
        case pace
    }

    /// The record told first when an outing beats several (#742).
    public enum LeadingRecord: Equatable, Sendable {
        /// The longest: a walk or a run is told by its distance.
        case distance
        /// The biggest climb: a hike is told by it.
        case climb
    }

    /// How an outing of this sport stands against the earlier ones (#742):
    /// what the session notification and the Bilan say about it.
    public struct Benchmarks: Equatable, Sendable {
        /// Whether the pace says something about the person. A hike's depends
        /// on the slope more than on the walker, so it is never compared.
        public let comparesPace: Bool
        public let leadingRecord: LeadingRecord

        /// A walk's or a run's: paced, told by its distance. Also the rule
        /// for an activity Foulée cannot name.
        public static let paced = Benchmarks(comparesPace: true, leadingRecord: .distance)
        /// A hike's: told by its climb, its pace left alone.
        public static let climbing = Benchmarks(comparesPace: false, leadingRecord: .climb)
    }

    /// The sensors a session of this sport reads.
    public struct Capabilities: OptionSet, Equatable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        /// A route, from the GPS.
        public static let route = Capabilities(rawValue: 1 << 0)
        /// Steps and cadence, from the pedometer.
        public static let steps = Capabilities(rawValue: 1 << 1)
        /// Climb and descent, from the altimeter.
        public static let elevation = Capabilities(rawValue: 1 << 2)
    }

    public let id: SportID
    public let family: Family
    public let location: Location
    public let capabilities: Capabilities
    public let speedDisplay: SpeedDisplay
    /// Whether Foulée records this sport itself, or only reads it from Santé.
    public let isRecordable: Bool
    /// Kept as resources and resolved on each read, so a label follows the
    /// app's language instead of the one it had when the table was built.
    let labelResource: LocalizedStringResource
    let sessionTitleResource: LocalizedStringResource?
    /// The SF Symbol drawn next to it, from `ActivityGlyph`.
    public let glyph: String
    /// `HKWorkoutActivityType.rawValue`, the stamp the workout carries in Santé.
    public let healthKitActivityRawValue: UInt
    /// The `sport` value of a Connect IQ message, `nil` when the Garmin app
    /// does not record this sport.
    public let garminSport: String?
    /// Kilocalories per step for a phone-recorded session, the only energy
    /// figure it will ever have (see `SessionActivity.kcalPerStep`).
    public let kcalPerStep: Double?
    public let benchmarks: Benchmarks
    let nounResource: LocalizedStringResource
    let verbResource: LocalizedStringResource

    /// The pickers' and the résumé's word for it: « Marche ».
    public var label: String { kitText(labelResource) }

    /// The word inside a sentence: « Ta plus longue marche ». Every sport
    /// Foulée names is feminine, which the sentences around it rely on.
    public var noun: String { kitText(nounResource) }

    /// What the person does, inside a sentence: « tu marches 15 s/km plus vite ».
    public var verb: String { kitText(verbResource) }

    /// How a session in progress is named to the person doing it: « Ta marche ».
    /// `nil` for a sport Foulée does not record.
    public var sessionTitle: String? { sessionTitleResource.map { kitText($0) } }
}

nonisolated extension SportDescriptor {
    static let walking = SportDescriptor(
        id: .walking,
        family: .onFoot,
        location: .outdoor,
        capabilities: [.route, .steps, .elevation],
        speedDisplay: .pace,
        isRecordable: true,
        labelResource: "Marche",
        sessionTitleResource: "Ta marche",
        glyph: ActivityGlyph.walk,
        healthKitActivityRawValue: 52,
        garminSport: "walking",
        kcalPerStep: 0.04,
        benchmarks: .paced,
        nounResource: "marche",
        verbResource: "tu marches"
    )

    static let running = SportDescriptor(
        id: .running,
        family: .onFoot,
        location: .outdoor,
        capabilities: [.route, .steps, .elevation],
        speedDisplay: .pace,
        isRecordable: true,
        labelResource: "Course",
        sessionTitleResource: "Ta course",
        glyph: ActivityGlyph.run,
        healthKitActivityRawValue: 37,
        garminSport: "running",
        kcalPerStep: 0.09,
        benchmarks: .paced,
        nounResource: "course",
        verbResource: "tu cours"
    )

    static let hiking = SportDescriptor(
        id: .hiking,
        family: .onFoot,
        location: .outdoor,
        capabilities: [.route, .steps, .elevation],
        speedDisplay: .pace,
        isRecordable: false,
        labelResource: "Randonnée",
        sessionTitleResource: nil,
        glyph: ActivityGlyph.hike,
        healthKitActivityRawValue: 24,
        garminSport: nil,
        kcalPerStep: nil,
        benchmarks: .climbing,
        nounResource: "randonnée",
        verbResource: "tu marches"
    )
}
