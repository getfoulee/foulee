import AppIntents
import FouleeDomain
@preconcurrency import HealthKit

/// « J'ai bu un verre » for Siri on the watch (issue #607). The phone's intent
/// of the same name writes to the phone's Santé; this one writes to the
/// watch's, without opening the app, through the hydration banner's own path,
/// and answers as the phone does (`WaterLogOutcome`, #724).
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource { "J'ai bu un verre" }
    // periphery:ignore - read by the AppIntents runtime, never from code.
    static var description: IntentDescription { "Enregistre un verre d'eau dans Santé." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = await WatchWaterLog.logGlass(store: HKHealthStore())
        return .result(dialog: IntentDialog(stringLiteral: outcome.dialog))
    }
}
