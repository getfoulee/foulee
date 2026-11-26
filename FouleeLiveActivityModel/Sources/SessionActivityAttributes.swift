import ActivityKit
import FouleeDomain
import Foundation

/// The Live Activity of an outing, sport-aware (#732): it carries the figures
/// its sport shows, so a sport without a distance never draws « 0,00 km ».
///
/// In FouleeLiveActivityModel, linked by the app (which starts, updates and
/// ends the activity) and by the FouleeLiveActivity extension (which draws
/// it, #818). It is the only channel between the two: the extension has no
/// app group (#225).
///
/// Replaces `WalkActivityAttributes` for every new activity. That type stays
/// one release, so an activity a previous build left running is still drawn
/// and still reached by the sweeps that end it.
nonisolated public struct SessionActivityAttributes: ActivityAttributes, SessionActivityContent, Sendable {
    public typealias ContentState = SessionActivityState

    public var goalMinutes: Int
    /// The sport, as the app started it; `nil` for an outing the app cannot
    /// name yet (« les deux » unsettled) or a mirrored one, whose sport may
    /// change after the attributes — fixed for the activity's life — are
    /// written (#246, #275).
    public var activity: SessionActivity?
    /// The figures drawn, in order. Fixed with the attributes, like the sport.
    public var metrics: [MetricID]
    public var showsElevation: Bool

    /// The figures `activity`'s sport shows; for an unnamed outing, those of a
    /// walk or a run, the two it can be.
    public init(goalMinutes: Int, activity: SessionActivity?) {
        let descriptor = (activity?.sport ?? .walking).descriptor
        self.init(
            goalMinutes: goalMinutes,
            activity: activity,
            metrics: descriptor.liveMetrics,
            showsElevation: descriptor.showsElevation
        )
    }

    public init(goalMinutes: Int, activity: SessionActivity?, metrics: [MetricID], showsElevation: Bool) {
        self.goalMinutes = goalMinutes
        self.activity = activity
        self.metrics = metrics
        self.showsElevation = showsElevation
    }
}

nonisolated extension SessionActivityAttributes: Codable {
    private enum CodingKeys: String, CodingKey {
        case goalMinutes, activity, metrics, showsElevation
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(goalMinutes, forKey: .goalMinutes)
        try container.encodeIfPresent(activity, forKey: .activity)
        try container.encode(metrics.map(\.rawValue), forKey: .metrics)
        try container.encode(showsElevation, forKey: .showsElevation)
    }

    /// Never fails on what a later build may add: an unknown sport reads as an
    /// unnamed outing and an unknown figure is left out, so the activity stays
    /// within reach of the sweeps that end it (see `WalkActivityAttributes`).
    /// `goalMinutes` stays required: a payload without it is corrupt, not new.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goalMinutes = try container.decode(Int.self, forKey: .goalMinutes)
        activity = try? container.decode(SessionActivity.self, forKey: .activity)
        let raw = (try? container.decode([String].self, forKey: .metrics)) ?? []
        metrics = raw.compactMap(MetricID.init(rawValue:))
        showsElevation = (try? container.decode(Bool.self, forKey: .showsElevation)) ?? false
    }
}

/// What the Live Activity draws, whichever attributes type started it: the
/// views take this, so the legacy attributes need no second set of views.
nonisolated public protocol SessionActivityContent {
    var goalMinutes: Int { get }
    var activity: SessionActivity? { get }
    var metrics: [MetricID] { get }
    var showsElevation: Bool { get }
}

nonisolated extension SessionActivityContent {
    /// Title for the Lock Screen row: « Ta marche », « Ta course · En pause »,
    /// from `SessionActivity.sessionTitle` like the phone's own live screen
    /// (#222). « Ta sortie » for an outing the app cannot name.
    public func title(isPaused: Bool) -> String {
        isPaused ? String(localized: "\(baseTitle) · En pause") : baseTitle
    }

    /// SF Symbol for the same outing; the neutral one when it is unnamed.
    public var glyph: String {
        activity?.icon ?? ActivityGlyph.mixedCardio
    }

    private var baseTitle: String {
        activity?.sessionTitle ?? String(localized: "Ta sortie")
    }
}

/// Where each figure goes, from the sport's list (#732).
nonisolated extension SessionActivityContent {
    /// The large figure of the expanded Dynamic Island: the distance when the
    /// sport has one, else its first figure.
    public var headlineMetric: MetricID? {
        metrics.contains(.distance) ? .distance : metrics.first
    }

    /// The cells under it: every other figure, then the goal.
    public var cellMetrics: [MetricID] {
        metrics.filter { $0 != headlineMetric }
    }

    /// The Lock Screen row: the first two figures.
    public var rowMetrics: [MetricID] {
        Array(metrics.prefix(2))
    }
}

/// Pushed on outing events (start, pause, resume, new figures); the clock
/// itself runs system-side off `timerBasis`. Shared by both attributes types,
/// so its payload is the one every build has written.
nonisolated public struct SessionActivityState: Codable, Hashable, Sendable {
    /// Virtual start of the outing: now minus accumulated elapsed, recomputed
    /// on every push so `Text(timerInterval:)` keeps the clock running while
    /// the app is suspended.
    public var timerBasis: Date
    /// Set while paused; freezes the system timer via `pauseTime`.
    public var pausedAt: Date?
    public var elapsed: TimeInterval
    public var steps: Int
    public var distanceKm: Double
    /// `nil` when the source states none — a Garmin watch (ADR 0009, D7): the
    /// Lock Screen says « — » rather than a measured-looking 0. Optional, so a
    /// state written before it decodes as is.
    public var activeCalories: Int?
    /// The climb and descent so far, in metres (#576); `nil` when the source
    /// states none live. Optional, so a state written before them decodes.
    public var climbMeters: Double?
    public var descentMeters: Double?

    public init(
        timerBasis: Date,
        pausedAt: Date?,
        elapsed: TimeInterval,
        steps: Int,
        distanceKm: Double,
        activeCalories: Int? = nil,
        climbMeters: Double? = nil,
        descentMeters: Double? = nil
    ) {
        self.timerBasis = timerBasis
        self.pausedAt = pausedAt
        self.elapsed = elapsed
        self.steps = steps
        self.distanceKm = distanceKm
        self.activeCalories = activeCalories
        self.climbMeters = climbMeters
        self.descentMeters = descentMeters
    }

    public var isPaused: Bool { pausedAt != nil }

    /// « ↑ 120 m · ↓ 115 m », or `nil` with nothing measured.
    public var elevation: Elevation? {
        guard climbMeters != nil || descentMeters != nil else { return nil }
        return Elevation(ascent: climbMeters ?? 0, descent: descentMeters ?? 0)
    }

    /// `metric` as drawn: « 5 391 pas », « 2,48 km », « 320 kcal », and
    /// « — kcal » for calories the source does not state.
    public func text(for metric: MetricID) -> String {
        switch metric {
        case .distance: distanceKm.kmText()
        case .calories: activeCalories.map { "\($0) kcal" } ?? "— kcal"
        default: value(of: metric).map(metric.formattedWithUnit) ?? "—"
        }
    }

    /// The same figure for VoiceOver (#601).
    public func spokenText(for metric: MetricID) -> String {
        guard let value = value(of: metric) else { return String(localized: "Calories indisponibles") }
        return metric.spokenText(value)
    }

    /// The bare figure of a Dynamic Island cell: « 5 391 », « 320 », « — ».
    public func valueText(for metric: MetricID) -> String {
        guard let value = value(of: metric) else { return "—" }
        return metric == .distance ? distanceKm.kmText() : metric.formatted(value)
    }

    private func value(of metric: MetricID) -> Double? {
        switch metric {
        case .steps: Double(steps)
        case .distance: distanceKm
        case .calories: activeCalories.map(Double.init)
        case .minutes: elapsed / 60
        }
    }
}
