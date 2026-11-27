import FouleeDomain
import FouleeLiveActivityModel
import Foundation
import Testing

/// What the sport-aware Live Activity draws (#732), and that its payload
/// survives a build that knows more or less than this one.
@Suite("Session Live Activity attributes")
struct SessionActivityAttributesTests {
    private let state = SessionActivityState(
        timerBasis: Date(timeIntervalSinceReferenceDate: 0),
        pausedAt: nil,
        elapsed: 600,
        steps: 2_480,
        distanceKm: 1.83,
        activeCalories: 108
    )

    @Test(
        "A walk and a run draw what they always did",
        arguments: SessionActivity.allCases.filter { $0.sport.descriptor.location == .outdoor }
    )
    func walkAndRun(activity: SessionActivity) {
        let attributes = SessionActivityAttributes(goalMinutes: 30, activity: activity)
        #expect(attributes.metrics == [.steps, .distance, .calories])
        #expect(attributes.showsElevation)
        #expect(attributes.headlineMetric == .distance)
        #expect(attributes.cellMetrics == [.steps, .calories])
        #expect(attributes.rowMetrics == [.steps, .distance])
    }

    @Test(
        "An indoor session draws its calories alone, with no climb (#745)",
        arguments: SessionActivity.allCases.filter { $0.sport.descriptor.family == .training }
    )
    func indoorSession(activity: SessionActivity) {
        let attributes = SessionActivityAttributes(goalMinutes: 30, activity: activity)
        #expect(attributes.metrics == [.calories])
        #expect(attributes.showsElevation == false)
        #expect(attributes.headlineMetric == .calories)
    }

    @Test("An unnamed outing draws a walk's figures as « Ta sortie »")
    func unnamedOuting() {
        let attributes = SessionActivityAttributes(goalMinutes: 30, activity: nil)
        #expect(attributes.metrics == [.steps, .distance, .calories])
        #expect(attributes.title(isPaused: false) == "Ta sortie")
        #expect(attributes.glyph == ActivityGlyph.mixedCardio)
    }

    @Test("A sport without a distance never draws one")
    func withoutDistance() {
        let attributes = SessionActivityAttributes(goalMinutes: 30, activity: nil, metrics: [.calories], showsElevation: false)
        #expect(attributes.headlineMetric == .calories)
        #expect(attributes.cellMetrics.isEmpty)
        #expect(attributes.rowMetrics == [.calories])
        #expect(attributes.rowMetrics.map(state.text(for:)) == ["108 kcal"])
    }

    @Test("The legacy attributes draw the same figures as a walk")
    func legacyAttributes() {
        let legacy = WalkActivityAttributes(goalMinutes: 30, activity: .running)
        #expect(legacy.metrics == SessionActivityAttributes(goalMinutes: 30, activity: .running).metrics)
        #expect(legacy.title(isPaused: true) == SessionActivityAttributes(goalMinutes: 30, activity: .running).title(isPaused: true))
    }

    @Test("Calories a source does not state read « — », never 0")
    func missingCalories() {
        var garmin = state
        garmin.activeCalories = nil
        #expect(garmin.text(for: .calories) == "— kcal")
        #expect(garmin.valueText(for: .calories) == "—")
    }

    @Test("The attributes survive the round trip, in JSON and in a property list")
    func roundTrip() throws {
        let attributes = SessionActivityAttributes(goalMinutes: 45, activity: .running)
        let json = try JSONDecoder().decode(SessionActivityAttributes.self, from: JSONEncoder().encode(attributes))
        let plist = try PropertyListDecoder().decode(
            SessionActivityAttributes.self,
            from: PropertyListEncoder().encode(attributes)
        )
        #expect(json.goalMinutes == 45)
        #expect(json.activity == .running)
        #expect(json.metrics == attributes.metrics)
        #expect(plist.metrics == attributes.metrics)
        #expect(plist.showsElevation)
    }

    @Test("A sport or a figure from a later build is left out, not fatal")
    func laterBuild() throws {
        let json = #"{"goalMinutes": 30, "activity": "natation", "metrics": ["laps", "calories"], "showsElevation": false}"#
        let decoded = try JSONDecoder().decode(SessionActivityAttributes.self, from: Data(json.utf8))
        #expect(decoded.activity == nil)
        #expect(decoded.metrics == [.calories])
    }

    @Test("A payload without its goal is corrupt and refused")
    func missingGoal() {
        let json = #"{"activity": "walking", "metrics": ["steps"]}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SessionActivityAttributes.self, from: Data(json.utf8))
        }
    }
}
