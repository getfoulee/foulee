import FouleeHealth
import FouleeDomain
import Foundation

/// The outing's climb and descent over time (issues #535, #564): the screen
/// reads its total, and each leg's workout is stamped with its own share as
/// it is saved.
///
/// Spans every leg, as the route does: a change of sport is not a change of
/// slope. **Writes nothing itself**, and whatever happens here, the outing
/// goes on.
final class WatchClimbStore {
    private(set) var trail = ClimbTrail()
    /// Hears each reading, for a trace (#727).
    var onRecord: ((Elevation, Date) -> Void)?

    private let source: AltitudeClient
    private var recording: Task<Void, Never>?

    init(source: AltitudeClient = .live) {
        self.source = source
    }

    /// Start a fresh climb, each reading dated by `clock`.
    func start(clock: @escaping @MainActor () -> Date) {
        stop()
        trail = ClimbTrail()
        recording = Task { [weak self, source] in
            for await elevation in source.updates() {
                self?.record(elevation, at: clock())
            }
        }
    }

    /// The outing's climb and descent as of `date`.
    func record(_ elevation: Elevation, at date: Date) {
        trail.record(elevation, at: date)
        onRecord?(elevation, date)
    }

    /// Stop measuring and keep what was climbed. Idempotent.
    func stop() {
        recording?.cancel()
        recording = nil
    }
}
