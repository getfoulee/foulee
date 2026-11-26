import Foundation

/// The figures of an outing in flight, as the device recording it states them
/// to the other one (#730). One type for every direction: the watch to the
/// iPhone through the mirrored session (#278), the iPhone to the watch through
/// WatchConnectivity (#342), and a Garmin watch to the iPhone (ADR 0009).
///
/// **A complete state, never a delta** (ADR 0003 D2). A delta that goes
/// missing cannot be recovered; a complete state that goes missing is
/// corrected by the next one. HealthKit **caches** what a mirrored session
/// sends and wakes the iOS app periodically, minutes apart, so everything sent
/// between two wakes is lost whatever it was. Hence `sentAt`: the only honest
/// thing a screen can print next to a step count.
nonisolated public struct SessionSnapshot: Equatable, Sendable {
    nonisolated public enum Phase: String, Codable, Sendable {
        case active
        /// The clock stands still on the figure stated at `sentAt` (#384).
        case paused
        /// The outing is over. Sent once, so the other device lets go at once
        /// rather than waiting for the session to go stale. **The only thing
        /// that ends a mirrored display**, with staleness: an `HKWorkoutType`
        /// observer would fire at the first walk→run switch, which saves a
        /// workout (#265).
        case ended
    }

    /// When the recording device stated these figures. Two snapshots can
    /// arrive out of order, so the reader keeps the newest.
    public var sentAt: Date
    /// The **outing's** start across legs, pushed back by every pause: the
    /// instant the clock would have read zero. Not the leg's, or the clock
    /// would reset every time the wearer broke into a run.
    public var outingStartedAt: Date
    public var activity: SessionActivity
    public var phase: Phase
    public var steps: Int
    public var distanceMeters: Double
    public var activeCalories: Int
    public var heartRate: Int?
    /// The outing's climb and descent so far, in metres (#535); 0 when the
    /// device has no barometer or did not send them.
    public var climbMeters: Double
    public var descentMeters: Double
    /// The outing's route so far, cut by portion and thinned (#334). Empty
    /// when there is no fix, and from a device that sends no route.
    public var route: [MirroredRoutePortion]

    public init(
        sentAt: Date,
        outingStartedAt: Date,
        activity: SessionActivity,
        phase: Phase,
        steps: Int,
        distanceMeters: Double,
        activeCalories: Int,
        heartRate: Int? = nil,
        climbMeters: Double = 0,
        descentMeters: Double = 0,
        route: [MirroredRoutePortion] = []
    ) {
        self.sentAt = sentAt
        self.outingStartedAt = outingStartedAt
        self.activity = activity
        self.phase = phase
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.activeCalories = activeCalories
        self.heartRate = heartRate
        self.climbMeters = climbMeters
        self.descentMeters = descentMeters
        self.route = route
    }

    public var isEnded: Bool { phase == .ended }

    public var isPaused: Bool { phase == .paused }

    /// The elapsed time at `sentAt`, pauses left out.
    public var elapsed: TimeInterval { elapsed(at: sentAt) }

    /// How long the outing has run, read at `date`.
    ///
    /// Derived from a **date**, not carried as a duration, so the clock keeps
    /// ticking between two deliveries instead of freezing on the last figure
    /// (#266). Frozen at `sentAt` once the outing is paused or over: the start
    /// is a virtual one, pushed back by every pause, so it only holds while
    /// the clock runs.
    public func elapsed(at date: Date) -> TimeInterval {
        max(0, (phase == .active ? date : sentAt).timeIntervalSince(outingStartedAt))
    }

    /// The instant the clock would have read zero, so the reader runs it on
    /// its own between two deliveries. `nil` while paused or over: a frozen
    /// clock.
    public var timerBasis: Date? {
        phase == .active ? outingStartedAt : nil
    }

    /// Drawn by `MirroredSessionScreen` — the phone's only view of a distance it
    /// did not measure.
    public var distanceKm: Double { distanceMeters / 1_000 }

    /// « ↑ 120 m · ↓ 115 m », or `nil` when neither was measured (#535).
    public var elevationText: String? { elevation.text }

    /// The same, for VoiceOver.
    public var elevationSpokenText: String? { elevation.spokenText }

    private var elevation: Elevation { Elevation(ascent: climbMeters, descent: descentMeters) }

    /// The outing's average pace at the instant these figures were stated —
    /// « 6'10"/km » — or `nil` when there is not enough distance to divide
    /// (#298).
    ///
    /// **Read at `sentAt`, never at « now ».** The clock keeps advancing
    /// between two wakes while the distance stays frozen, so dividing a frozen
    /// distance by a growing duration would drift towards slow precisely when
    /// the mirror has gone quiet.
    public var averagePaceText: String? {
        elapsed.paceText(overKm: distanceKm)
    }

    /// The same, for VoiceOver.
    public var averagePaceSpokenText: String? {
        elapsed.spokenPaceText(overKm: distanceKm)
    }

    /// How old these figures are. What the screen has to say out loud rather
    /// than pretend away.
    public func age(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(sentAt))
    }
}

// MARK: - Wire format

/// The two apps update separately, so a new build talks to an old one for as
/// long as the owner takes to install both. Before #730 each direction had its
/// own payload: the watch's (`outingStartedAt`, `isEnded`, `isPaused`) and the
/// phone's (`phase`, `elapsed`). A snapshot writes the keys of both, so an
/// older build in either direction still reads it, and reads either.
nonisolated extension SessionSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case sentAt, outingStartedAt, elapsed, activity, phase, isEnded, isPaused
        case steps, distanceMeters, activeCalories, heartRate, climbMeters, descentMeters, route
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sentAt, forKey: .sentAt)
        try container.encode(outingStartedAt, forKey: .outingStartedAt)
        try container.encode(elapsed, forKey: .elapsed)
        try container.encode(activity, forKey: .activity)
        try container.encode(phase, forKey: .phase)
        try container.encode(isEnded, forKey: .isEnded)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encode(steps, forKey: .steps)
        try container.encode(distanceMeters, forKey: .distanceMeters)
        try container.encode(activeCalories, forKey: .activeCalories)
        try container.encodeIfPresent(heartRate, forKey: .heartRate)
        try container.encode(climbMeters, forKey: .climbMeters)
        try container.encode(descentMeters, forKey: .descentMeters)
        try container.encode(route, forKey: .route)
    }

    /// Tolerant by hand: an unknown sport reads as a walk (the synthesised
    /// decoder would reject the whole snapshot), a missing figure as 0, a
    /// route this build cannot read as no route. `sentAt` is required, and the
    /// outing's start unless the payload is the phone's (it carries a phase).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sentAt = try container.decode(Date.self, forKey: .sentAt)
        if container.contains(.outingStartedAt) || !(container.contains(.phase) || container.contains(.elapsed)) {
            // The watch's format: no start, no outing to show.
            outingStartedAt = try container.decode(Date.self, forKey: .outingStartedAt)
        } else {
            // The phone's format before #730, which always carried a phase.
            let elapsed = try container.decodeIfPresent(TimeInterval.self, forKey: .elapsed) ?? 0
            outingStartedAt = sentAt.addingTimeInterval(-elapsed)
        }
        activity = (try? container.decode(SessionActivity.self, forKey: .activity)) ?? .walking
        if let phase = try? container.decodeIfPresent(Phase.self, forKey: .phase) {
            self.phase = phase
        } else if try container.decodeIfPresent(Bool.self, forKey: .isEnded) == true {
            phase = .ended
        } else if try container.decodeIfPresent(Bool.self, forKey: .isPaused) == true {
            phase = .paused
        } else {
            phase = .active
        }
        steps = try container.decodeIfPresent(Int.self, forKey: .steps) ?? 0
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters) ?? 0
        activeCalories = try container.decodeIfPresent(Int.self, forKey: .activeCalories) ?? 0
        heartRate = try container.decodeIfPresent(Int.self, forKey: .heartRate)
        climbMeters = try container.decodeIfPresent(Double.self, forKey: .climbMeters) ?? 0
        descentMeters = try container.decodeIfPresent(Double.self, forKey: .descentMeters) ?? 0
        route = (try? container.decodeIfPresent([MirroredRoutePortion].self, forKey: .route)) ?? []
    }
}
