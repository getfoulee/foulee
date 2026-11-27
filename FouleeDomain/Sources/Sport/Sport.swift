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
    /// Recorded since #744; the résumé has listed hikes since #217.
    case hiking
    /// A run on trails (#744). HealthKit has no type for it: Santé records a
    /// run, and Foulée tells it apart by `FouleeWorkoutMetadata.sport`.
    case trailRunning
    /// Indoor sessions without a route or steps (#745): duration, heart rate
    /// and calories only.
    case strength
    case hiit
    case yoga
    /// Indoor machines (#746). A rower and an elliptical go nowhere, like
    /// strength; a treadmill run keeps its steps and its distance, without a
    /// route. HealthKit has no treadmill type: Santé records an indoor run,
    /// and Foulée tells it apart by `FouleeWorkoutMetadata.sport`, as a trail.
    case rowing
    case elliptical
    case indoorRunning
    /// Rides (#749), recorded on the watch: a route, a speed in km/h, and the
    /// power and cadence a Bluetooth sensor sends. An indoor ride is a ride
    /// in Santé, indoors, told apart by Foulée's tag.
    case cycling
    case indoorCycling

    /// Everything Foulée knows about this sport.
    public var descriptor: SportDescriptor {
        switch self {
        case .walking: .walking
        case .running: .running
        case .hiking: .hiking
        case .trailRunning: .trailRunning
        case .strength: .strength
        case .hiit: .hiit
        case .yoga: .yoga
        case .rowing: .rowing
        case .elliptical: .elliptical
        case .indoorRunning: .indoorRunning
        case .cycling: .cycling
        case .indoorCycling: .indoorCycling
        }
    }

    /// The sport HealthKit stamped on a workout, from
    /// `HKWorkoutActivityType.rawValue`. `nil` for a type Foulée cannot name.
    ///
    /// Two sports can share a type (a trail is a run in Santé): the first in
    /// `allCases` answers, the plain one. `init(healthKitActivityRawValue:tag:)`
    /// reads Foulée's own tag to tell them apart.
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

    /// The sport of a workout: Foulée's tag (`FouleeWorkoutMetadata.sport`)
    /// when it names a sport of the workout's type, the type alone otherwise —
    /// another app's workout, or one Foulée wrote before #744.
    public init?(healthKitActivityRawValue rawValue: UInt, tag: String?) {
        if let tagged = tag.flatMap(Self.init(rawValue:)),
           tagged.descriptor.healthKitActivityRawValue == rawValue {
            self = tagged
        } else {
            self.init(healthKitActivityRawValue: rawValue)
        }
    }

    /// What a workout of this sport carries so that it reads back as itself
    /// (#744): the sport's raw value, under Foulée's own key.
    public var workoutMetadata: [String: Any] {
        [FouleeWorkoutMetadata.sport: rawValue]
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
        /// Strength, HIIT, yoga, rower, elliptical: a duration, a heart rate,
        /// calories (#745, #746).
        case training
        /// Rides (#749): a speed rather than a pace, no steps.
        case cycling
    }

    /// The devices that record a sport.
    public enum Devices: Equatable, Sendable {
        case phoneAndWatch
        /// Cycling until the iPhone records it with the GPS alone (#750).
        case watchOnly
    }

    /// Where the sport happens, which decides whether GPS is asked for.
    public enum Location: Equatable, Sendable {
        case outdoor
        /// No GPS, and no location permission asked for (#745).
        case indoor
    }

    /// How fast the sport moves, which decides how finely its pace is shown.
    public enum Gait: Equatable, Sendable {
        case walk
        case run
    }

    /// How speed is written for this sport.
    public enum SpeedDisplay: Equatable, Sendable {
        /// Minutes per kilometre, « 6'12" /km ».
        case pace
        /// Kilometres per hour, « 24 km/h »: a ride (#749).
        case speed
        /// No speed: a session that goes nowhere.
        case none
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
        /// A session that goes nowhere (#745): no pace, and with no distance
        /// its records never fire.
        public static let stationary = Benchmarks(comparesPace: false, leadingRecord: .distance)
        /// A ride's (#749): told by its distance. Its speed is not compared:
        /// the sentences that compare speak in seconds per kilometre.
        public static let ridden = Benchmarks(comparesPace: false, leadingRecord: .distance)
    }

    /// The sensors a session of this sport reads.
    public struct Capabilities: OptionSet, Equatable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        /// A route, from the GPS.
        public static let route = Capabilities(rawValue: 1 << 0)
        /// A distance: from the GPS outdoors, from the accelerometer on a
        /// treadmill (#746), where the builder estimates it without a route.
        public static let distance = Capabilities(rawValue: 1 << 3)
        /// Speed, cadence and power from a Bluetooth bike sensor (#749),
        /// when one is paired; the distance too, indoors.
        public static let cyclingSensors = Capabilities(rawValue: 1 << 4)
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
    /// `nil` for a sport without a pace.
    public let gait: Gait?
    /// Whether the watch follows a change between walking and running during
    /// the outing, one workout per stretch (#265). A hike or a trail is one
    /// sport from start to finish, whatever the pace on the climbs.
    public let followsGaitChanges: Bool
    /// Whether Foulée records this sport itself, or only reads it from Santé.
    public let isRecordable: Bool
    /// Which devices record it, when it is recordable.
    public var devices: Devices = .phoneAndWatch
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
    /// Kilocalories per minute, for a sport without steps (#745): the phone's
    /// only energy figure for it. Low on purpose, like the per-step rates.
    public var kcalPerMinute: Double?
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
        capabilities: [.route, .distance, .steps, .elevation],
        speedDisplay: .pace,
        gait: .walk,
        followsGaitChanges: true,
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
        capabilities: [.route, .distance, .steps, .elevation],
        speedDisplay: .pace,
        gait: .run,
        followsGaitChanges: true,
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
        capabilities: [.route, .distance, .steps, .elevation],
        speedDisplay: .pace,
        gait: .walk,
        followsGaitChanges: false,
        isRecordable: true,
        labelResource: "Randonnée",
        sessionTitleResource: "Ta randonnée",
        glyph: ActivityGlyph.hike,
        healthKitActivityRawValue: 24,
        // The Garmin app records walks and runs only (#748).
        garminSport: nil,
        // Walking's: the climb costs more, but the phone has no honest figure
        // for it, and under-crediting is the rule (`ActivitySegmentation`).
        kcalPerStep: 0.04,
        benchmarks: .climbing,
        nounResource: "randonnée",
        verbResource: "tu marches"
    )

    static let trailRunning = SportDescriptor(
        id: .trailRunning,
        family: .onFoot,
        location: .outdoor,
        capabilities: [.route, .distance, .steps, .elevation],
        speedDisplay: .pace,
        gait: .run,
        followsGaitChanges: false,
        isRecordable: true,
        labelResource: "Trail",
        sessionTitleResource: "Ton trail",
        glyph: ActivityGlyph.trail,
        // A run in Santé: HealthKit has no trail type. Foulée's tag tells it
        // apart (`SportID.workoutMetadata`).
        healthKitActivityRawValue: 37,
        garminSport: nil,
        kcalPerStep: 0.09,
        // Its pace depends on the slope, like a hike's.
        benchmarks: .climbing,
        // « Ta plus longue course en trail »: the sentences around the noun
        // are written for a feminine word.
        nounResource: "course en trail",
        verbResource: "tu cours"
    )

    // Indoor sessions (#745): no route, no steps, no climb, so no GPS and no
    // location permission. The watch measures their heart rate and energy;
    // the phone estimates the energy from the duration, at low rates (MET 2.5
    // to 8 for about 70 kg, rounded down): under-crediting is the rule for an
    // estimate.

    static let strength = SportDescriptor(
        id: .strength,
        family: .training,
        location: .indoor,
        capabilities: [],
        speedDisplay: .none,
        gait: nil,
        followsGaitChanges: false,
        isRecordable: true,
        labelResource: "Renfo",
        sessionTitleResource: "Ta séance de renfo",
        glyph: ActivityGlyph.strength,
        healthKitActivityRawValue: 50,
        garminSport: nil,
        kcalPerStep: nil,
        kcalPerMinute: 4,
        benchmarks: .stationary,
        nounResource: "séance de renfo",
        verbResource: "tu t'entraînes"
    )

    static let hiit = SportDescriptor(
        id: .hiit,
        family: .training,
        location: .indoor,
        capabilities: [],
        speedDisplay: .none,
        gait: nil,
        followsGaitChanges: false,
        isRecordable: true,
        labelResource: "HIIT",
        sessionTitleResource: "Ta séance de HIIT",
        glyph: ActivityGlyph.hiit,
        healthKitActivityRawValue: 63,
        garminSport: nil,
        kcalPerStep: nil,
        kcalPerMinute: 8,
        benchmarks: .stationary,
        nounResource: "séance de HIIT",
        verbResource: "tu t'entraînes"
    )

    static let yoga = SportDescriptor(
        id: .yoga,
        family: .training,
        location: .indoor,
        capabilities: [],
        speedDisplay: .none,
        gait: nil,
        followsGaitChanges: false,
        isRecordable: true,
        labelResource: "Yoga",
        sessionTitleResource: "Ta séance de yoga",
        glyph: ActivityGlyph.yoga,
        healthKitActivityRawValue: 57,
        garminSport: nil,
        kcalPerStep: nil,
        kcalPerMinute: 3,
        benchmarks: .stationary,
        nounResource: "séance de yoga",
        verbResource: "tu t'entraînes"
    )

    // Indoor machines (#746). The rower and the elliptical are priced by the
    // minute like strength (MET 5 to 7 for about 70 kg, rounded down). The
    // Apple Watch measures no distance on either without a connected machine,
    // so they show none: no « 0,00 km ».

    static let rowing = SportDescriptor(
        id: .rowing,
        family: .training,
        location: .indoor,
        capabilities: [],
        speedDisplay: .none,
        gait: nil,
        followsGaitChanges: false,
        isRecordable: true,
        labelResource: "Rameur",
        sessionTitleResource: "Ta séance de rameur",
        glyph: ActivityGlyph.rower,
        healthKitActivityRawValue: 35,
        garminSport: nil,
        kcalPerStep: nil,
        kcalPerMinute: 6,
        benchmarks: .stationary,
        nounResource: "séance de rameur",
        verbResource: "tu rames"
    )

    static let elliptical = SportDescriptor(
        id: .elliptical,
        family: .training,
        location: .indoor,
        capabilities: [],
        speedDisplay: .none,
        gait: nil,
        followsGaitChanges: false,
        isRecordable: true,
        labelResource: "Elliptique",
        sessionTitleResource: "Ta séance d'elliptique",
        glyph: ActivityGlyph.elliptical,
        healthKitActivityRawValue: 16,
        garminSport: nil,
        kcalPerStep: nil,
        kcalPerMinute: 5,
        benchmarks: .stationary,
        nounResource: "séance d'elliptique",
        verbResource: "tu t'entraînes"
    )

    /// A run on a treadmill: steps, the distance the watch estimates from
    /// them, a pace; no route, no climb, so no GPS.
    static let indoorRunning = SportDescriptor(
        id: .indoorRunning,
        family: .onFoot,
        location: .indoor,
        capabilities: [.distance, .steps],
        speedDisplay: .pace,
        gait: .run,
        // One sport from start to finish: a walk on the belt is still the
        // treadmill session the person started.
        followsGaitChanges: false,
        isRecordable: true,
        labelResource: "Tapis",
        sessionTitleResource: "Ta course sur tapis",
        glyph: ActivityGlyph.treadmill,
        // A run in Santé, indoors: HealthKit has no treadmill type. Foulée's
        // tag tells it apart (`SportID.workoutMetadata`).
        healthKitActivityRawValue: 37,
        garminSport: nil,
        kcalPerStep: 0.09,
        benchmarks: .paced,
        nounResource: "course sur tapis",
        verbResource: "tu cours"
    )
}
