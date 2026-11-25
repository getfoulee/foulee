import AppIntents
import FouleeHealth
import FouleeDomain
@preconcurrency import HealthKit
import WidgetKit

/// Logs one glass of water to Apple Health. Declared once here and registered
/// by the app *and* the widget extension (`FouleeIntentsPackage`, #724): the
/// hydration widget's button runs it in the widget process, so the ring
/// updates instantly without opening the app; the app exposes it to Raccourcis
/// and Siri through `FouleeShortcuts`.
nonisolated public struct LogWaterIntent: AppIntent {
    public static var title: LocalizedStringResource { "J'ai bu un verre" }
    // periphery:ignore - read by the AppIntents runtime, never from code.
    public static var description: IntentDescription {
        IntentDescription(
            "Enregistre un verre d'eau dans Santé.",
            categoryName: "Hydratation",
            searchKeywords: ["Eau", "Boire", "Hydratation"]
        )
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = HKHealthStore()
        let glassML = WaterGlass.milliliters(from: SharedStore.read())
        // The widget process cannot show the authorization question: the app
        // asks it, so the intent only reads the answer.
        let outcome = await WaterLog.logGlass(glassML, store: store, asksAccess: false)
        if case .logged = outcome {
            // Refresh the shared snapshot so every surface shows the new total.
            // Prefer HealthKit's own sum (it includes watch-logged water); fall
            // back to an optimistic increment when the store can't answer.
            let previousML = SharedStore.read()?.waterML ?? 0
            let measuredML = await HealthKitTodaySums.sumIfAvailable(
                .dietaryWater, unit: .literUnit(with: .milli), store: store
            )
            SharedStore.updateWater(intakeML: measuredML.map { Int($0) } ?? (previousML + glassML))
            // Targeted reload: only the hydration ring changed — don't spend
            // the other widgets' refresh budget.
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.hydration)
        }
        return .result(dialog: IntentDialog(stringLiteral: outcome.dialog))
    }
}

/// The intents the app and the widget extension both run (#724). Each of them
/// lists this package, so the system finds the intents declared here in both
/// processes, under the same identifiers they always had.
public struct FouleeIntentsPackage: AppIntentsPackage {}
