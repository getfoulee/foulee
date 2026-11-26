import Foundation
import Testing
@testable import FouleeDomain

/// The wire format between the two apps (issue #278).
///
/// It matters more than most `Codable` conformances because the two ends are
/// **two apps that update separately**: a watch on a newer build talks to a
/// phone on an older one for as long as the owner takes to install both.
@Suite("Watch session snapshot")
struct SessionSnapshotTests {
    private let base = Date(timeIntervalSince1970: 1_754_000_000)

    private func snapshot(isEnded: Bool = false) -> SessionSnapshot {
        SessionSnapshot(
            sentAt: base,
            outingStartedAt: base.addingTimeInterval(-600),
            activity: .running,
            phase: isEnded ? .ended : .active,
            steps: 2_480,
            distanceMeters: 1_830,
            activeCalories: 108,
            heartRate: 118
        )
    }

    @Test("A snapshot survives the round trip whole")
    func roundTrip() throws {
        let data = try JSONEncoder().encode(snapshot())
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: data)
        #expect(decoded == snapshot())
    }

    /// The field that would otherwise throw rather than degrade: the
    /// synthesised decoder rejects a raw value it does not know, so a sport
    /// added in a later build would make the whole snapshot undecodable — and
    /// the phone would show *nothing* rather than a walk it half-understood.
    @Test("An unknown sport degrades to a walk instead of failing the decode")
    func anUnknownSportDegrades() throws {
        let json = """
        {"sentAt": 0, "outingStartedAt": 0, "activity": "natation",
         "steps": 10, "distanceMeters": 5, "activeCalories": 1, "isEnded": false}
        """
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: Data(json.utf8))
        #expect(decoded.activity == .walking)
        #expect(decoded.steps == 10)
    }

    /// A watch that has not been updated yet sends fewer keys. The phone shows
    /// zeros for what it was not told, rather than nothing at all.
    @Test("Missing keys fall back rather than failing")
    func missingKeysFallBack() throws {
        let json = #"{"sentAt": 0, "outingStartedAt": 0, "activity": "walking"}"#
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: Data(json.utf8))

        #expect(decoded.steps == 0)
        #expect(decoded.heartRate == nil)
        #expect(decoded.climbMeters == 0)
        #expect(decoded.descentMeters == 0)
        #expect(decoded.isEnded == false)
    }

    /// The climb and descent the wrist measured (#535), and none from a watch
    /// without a barometer: absent, not « ↑ 0 m ».
    @Test("The elevation reads « ↑ 120 m · ↓ 115 m », and nothing unmeasured")
    func elevationText() {
        var figures = snapshot()
        #expect(figures.elevationText == nil)
        figures.climbMeters = 119.6
        #expect(figures.elevationText == "↑ 120 m")
        figures.descentMeters = 115
        #expect(figures.elevationText == "↑ 120 m · ↓ 115 m")
        #expect(figures.elevationSpokenText == "120 mètres de montée, 115 mètres de descente")
        figures.climbMeters = 0.4
        #expect(figures.elevationText == "↓ 115 m")
    }

    /// The two dates are the ones nothing can stand in for, so they are the two
    /// that stay required — **each on its own**. Omitting both at once would
    /// pass even if only one were still mandatory.
    @Test("A snapshot missing either date is refused", arguments: [
        #"{"outingStartedAt": 0, "activity": "walking"}"#,
        #"{"sentAt": 0, "activity": "walking"}"#
    ])
    func datesAreRequired(json: String) {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(SessionSnapshot.self, from: Data(json.utf8))
        }
    }

    /// Tolerance stops at absence. A key present with the wrong type is a
    /// different problem — two builds that disagree about a *shape*, not about
    /// a field list — and swallowing it would hide it.
    @Test("A key of the wrong type is refused rather than guessed at")
    func aWrongTypeIsRefused() {
        let json = #"{"sentAt": 0, "outingStartedAt": 0, "activity": "walking", "steps": "beaucoup"}"#
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(SessionSnapshot.self, from: Data(json.utf8))
        }
    }

    /// 600 s over 1,83 km — the seeded sortie, near enough.
    @Test("The average pace divides the outing, not the wait")
    func averagePaceUsesTheOuting() {
        #expect(snapshot().averagePaceText == "5'27\"/km")
    }

    /// The trap this property exists to avoid. The screen's clock advances
    /// between two wakes while the distance stays frozen at the last snapshot,
    /// so a pace read at « now » would drift towards slow on its own —
    /// precisely when the mirror has gone quiet, which is when someone looks.
    @Test("The pace does not drift while the mirror is silent")
    func thePaceDoesNotDriftWithTheClock() {
        let stated = snapshot().averagePaceText
        // Ten minutes of silence later, the figures say exactly the same thing.
        #expect(snapshot().averagePaceText == stated)
        #expect(snapshot().age(at: base.addingTimeInterval(600)) == 600)
    }

    /// Same rule as everywhere else: a distance too small to divide says
    /// nothing rather than something that looks precise.
    @Test("Under fifty metres there is no average pace either")
    func noAveragePaceWithoutDistance() {
        var short = snapshot()
        short.distanceMeters = 20
        #expect(short.averagePaceText == nil)
    }

    @Test("The age of the figures is what the screen has to say out loud")
    func ageIsStated() {
        #expect(snapshot().age(at: base.addingTimeInterval(90)) == 90)
        // Never negative, whatever the two clocks think of each other.
        #expect(snapshot().age(at: base.addingTimeInterval(-90)) == 0)
    }

    // MARK: - Pause (issue #384)

    @Test("A watch that never sends a pause is never paused")
    func pauseDefaultsToRunning() throws {
        let json = #"{"sentAt": 0, "outingStartedAt": 0, "activity": "walking"}"#
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: Data(json.utf8))
        #expect(decoded.isPaused == false)
    }

    /// The start is a virtual one, pushed back by every pause: it only holds
    /// while the clock runs, so a paused snapshot reads at `sentAt`.
    @Test("A paused outing's clock stands still on what the wrist stated")
    func aPausedClockStandsStill() {
        var paused = snapshot()
        paused.phase = .paused
        #expect(paused.elapsed(at: base.addingTimeInterval(300)) == 600)
        #expect(snapshot().elapsed(at: base.addingTimeInterval(300)) == 900)
    }

    @Test("An outing that is over stops its clock where it was stated")
    func anEndedClockStandsStill() {
        let ended = snapshot(isEnded: true)
        #expect(ended.elapsed(at: base.addingTimeInterval(300)) == 600)
        #expect(ended.timerBasis == nil)
    }

    // MARK: - Both wire formats (#730)

    /// What the iPhone sent before #730: an elapsed time and a phase, no start.
    @Test("A phone payload from before #730 reads with its clock and phase")
    func readsTheOldPhonePayload() throws {
        let json = """
        {"sentAt": 1000, "activity": "running", "phase": "paused", "elapsed": 600,
         "steps": 1800, "distanceMeters": 1650, "activeCalories": 150}
        """
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: Data(json.utf8))
        #expect(decoded.phase == .paused)
        #expect(decoded.elapsed == 600)
        #expect(decoded.outingStartedAt == Date(timeIntervalSinceReferenceDate: 400))
    }

    /// What a watch or a Garmin state said before #730: two flags. Over wins.
    @Test("A watch payload from before #730 reads its flags as a phase", arguments: [
        (false, false, SessionSnapshot.Phase.active),
        (false, true, .paused),
        (true, false, .ended),
        (true, true, .ended)
    ])
    func readsTheOldWatchPayload(isEnded: Bool, isPaused: Bool, phase: SessionSnapshot.Phase) throws {
        let json = """
        {"sentAt": 1000, "outingStartedAt": 400, "activity": "walking",
         "isEnded": \(isEnded), "isPaused": \(isPaused)}
        """
        let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: Data(json.utf8))
        #expect(decoded.phase == phase)
    }

    /// An older build at the other end decodes with its own keys only: the
    /// watch's needs `outingStartedAt`, the phone's `elapsed` and `phase`.
    @Test("A snapshot writes the keys both older builds read", arguments: [
        SessionSnapshot.Phase.active, .paused, .ended
    ])
    func writesBothFormats(phase: SessionSnapshot.Phase) throws {
        var figures = snapshot()
        figures.phase = phase
        let data = try JSONEncoder().encode(figures)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["outingStartedAt"] as? Double == base.addingTimeInterval(-600).timeIntervalSinceReferenceDate)
        #expect(object["elapsed"] as? Double == 600)
        #expect(object["phase"] as? String == phase.rawValue)
        #expect(object["isEnded"] as? Bool == (phase == .ended))
        #expect(object["isPaused"] as? Bool == (phase == .paused))
    }
}
