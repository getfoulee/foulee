import FouleeDomain
import Foundation
@preconcurrency import HealthKit

/// One glass of water written to Santé, the same way by the phone's intent and
/// the watch's (issues #607, #724). What each device does around it — where
/// its glass size comes from, what it refreshes afterwards — stays with it.
nonisolated public enum WaterLog {
    /// Writes `milliliters` of water now.
    ///
    /// - Parameter asksAccess: whether to raise the authorization prompt first.
    ///   The watch does, from its own screen; the phone leaves it to the app,
    ///   since its widget process cannot show the question.
    public static func logGlass(
        _ milliliters: Int,
        store: HKHealthStore,
        asksAccess: Bool
    ) async -> WaterLogOutcome {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let waterType = HKQuantityType(.dietaryWater)
        if asksAccess {
            _ = try? await store.requestAuthorization(toShare: [waterType], read: [waterType])
        }
        // A denied write is said, not swallowed: the widget button would
        // otherwise look broken.
        switch store.authorizationStatus(for: waterType) {
        case .sharingDenied: return .denied
        case .notDetermined: return .notDetermined
        default: break
        }
        let sample = HKQuantitySample(
            type: waterType,
            quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(milliliters)),
            start: .now,
            end: .now
        )
        do {
            try await store.save(sample)
        } catch {
            return .failed
        }
        return .logged(milliliters: milliliters)
    }
}
