import FouleeHealth
import FouleeDomain
@preconcurrency import HealthKit
import WidgetKit

/// One glass of water, logged from outside the home screen: the hydration
/// banner's « J'ai bu » (`WatchHydrationNotificationCenter`) and Siri's
/// « J'ai bu un verre » (`LogWaterIntent`, issue #607). Both run without
/// `WatchTodayStore`, which owns the card, so both tell it through the same
/// signals.
nonisolated enum WatchWaterLog {
    /// Log the phone-synced glass to the watch's HealthKit, then nudge the
    /// home to re-read so the card and haptic reflect it. A denied
    /// authorization or a failed save posts the matching failure signal
    /// instead — the glass didn't count, and only `WatchTodayStore` can say so
    /// on the card.
    static func logGlass(store: HKHealthStore) async -> WaterLogOutcome {
        let glassML = WatchSyncStore.read()?.hydrationGlassML ?? WaterGlass.defaultML
        let outcome = await WaterLog.logGlass(glassML, store: store, asksAccess: true)
        switch outcome {
        case .logged:
            WidgetCenter.shared.reloadAllTimelines()
            await post(HydrationNotification.actionHandled)
        case .denied:
            await post(.watchHydrationActionDenied)
        case .notDetermined, .failed:
            await post(.watchHydrationActionFailed)
        case .unavailable:
            break
        }
        return outcome
    }

    /// Observers rely on these signals arriving on the main actor.
    private static func post(_ name: Notification.Name) async {
        await MainActor.run {
            NotificationCenter.default.post(name: name, object: nil)
        }
    }
}
