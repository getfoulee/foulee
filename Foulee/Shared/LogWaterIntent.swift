import AppIntents
import FouleeKit
@preconcurrency import HealthKit
import WidgetKit

/// Resolves the user's glass size for surfaces that can't read the app's
/// preferences. `UserPreferences` lives in `UserDefaults.standard`, which the
/// widget process cannot read — the app mirrors the preference into the shared
/// snapshot and both sides resolve it from there.
nonisolated enum WaterGlass {
    static let defaultML = 250

    static func milliliters(from snapshot: WidgetSnapshot?) -> Int {
        snapshot?.hydrationGlassML ?? defaultML
    }
}

/// Logs one glass of water to Apple Health. Compiled into the app *and* the
/// widget extension: the hydration widget's button runs it in the widget
/// process, so the ring updates instantly without opening the app; the app
/// target exposes it to Raccourcis / Siri via `FouleeShortcuts`.
nonisolated struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource { "J'ai bu un verre" }
    // periphery:ignore - read by the AppIntents runtime, never from code.
    static var description: IntentDescription {
        IntentDescription(
            "Enregistre un verre d'eau dans Santé.",
            categoryName: "Hydratation",
            searchKeywords: ["Eau", "Boire", "Hydratation"]
        )
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .result(dialog: "Santé n'est pas disponible sur cet appareil.")
        }
        let store = HKHealthStore()
        let waterType = HKQuantityType(.dietaryWater)
        // Surface a denied write as a spoken/visible dialog instead of a
        // silent failure — the widget button otherwise looks broken.
        switch store.authorizationStatus(for: waterType) {
        case .sharingDenied:
            return .result(dialog: IntentDialog(
                "Foulée n'a pas l'autorisation d'écrire dans Santé. Active l'eau dans Santé > Profil > Apps > Foulée."
            ))
        case .notDetermined:
            return .result(dialog: "Ouvre d'abord Foulée pour autoriser l'accès à Santé.")
        default:
            break
        }

        let glassML = WaterGlass.milliliters(from: SharedStore.read())
        let sample = HKQuantitySample(
            type: waterType,
            quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(glassML)),
            start: .now,
            end: .now
        )
        try await store.save(sample)

        // Refresh the shared snapshot so every surface shows the new total.
        // Prefer HealthKit's own sum (it includes watch-logged water); fall
        // back to an optimistic increment when the store can't answer.
        let previousML = SharedStore.read()?.waterML ?? 0
        let measuredML = await HealthKitTodaySums.sumIfAvailable(.dietaryWater, unit: .literUnit(with: .milli), store: store)
        let totalML = measuredML.map { Int($0) } ?? (previousML + glassML)
        SharedStore.updateWater(intakeML: totalML)
        // Targeted reload: only the hydration ring changed — don't spend the
        // other widgets' refresh budget.
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.hydration)
        return .result(dialog: "C'est noté : +\(glassML) ml d'eau.")
    }
}
