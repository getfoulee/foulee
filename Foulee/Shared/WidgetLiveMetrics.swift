import FouleeKit
import Foundation
@preconcurrency import HealthKit

/// Live HealthKit reads from the widget process — and from « Où j'en suis
/// aujourd'hui » (#605), so Siri says the widgets' figures — overlaid on the
/// app-written snapshot. While the phone is unlocked the rings move on the system's own
/// refresh cadence — no need to open the app. While locked, the Health store
/// is encrypted: reads fail, callers keep the snapshot values (the existing
/// Lock Screen behavior).
nonisolated enum WidgetLiveMetrics {
    /// The shared snapshot with every metric HealthKit can currently provide
    /// refreshed live. Read-only: the app (foreground refresh, background
    /// delivery, BGAppRefresh) owns persistence — having every widget instance
    /// also write the app-group on each render only amplified writes and raced
    /// the app's own updates.
    ///
    /// The live reads are **merged into** the stored snapshot, not substituted
    /// for it (`mergingLiveCounters`): the app can have written counters this
    /// process cannot measure — the Connect IQ overlay (#189) never touches
    /// HealthKit, and a walk that just ended has not been flushed into it yet
    /// (#158) — and replacing them here would discard both on every render.
    /// The snapshot carries how much they lifted (`floor*`), so this process
    /// can hold exactly that much up and let everything else follow the read.
    static func freshSnapshot() async -> WidgetSnapshot {
        // Zero counters from a previous day up front: when locked-phone reads
        // fail below, the fallback must not show yesterday's totals — and the
        // merge below must not have them on its other side either.
        let snapshot = (SharedStore.read() ?? .placeholder).zeroedIfStale()
        guard HKHealthStore.isHealthDataAvailable() else { return snapshot }
        let live = await HealthKitTodaySums.counters(store: HKHealthStore())
        return snapshot.mergingLiveCounters(
            steps: live.steps,
            minutes: live.minutes,
            distanceKm: live.distanceKm,
            calories: live.calories,
            waterML: live.waterML
        )
    }
}
