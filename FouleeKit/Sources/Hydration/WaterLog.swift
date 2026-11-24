import Foundation

/// Resolves the user's glass size for surfaces that can't read the app's
/// preferences. `UserPreferences` lives in `UserDefaults.standard`, which the
/// widget process cannot read — the app mirrors the preference into the shared
/// snapshot and every surface resolves it from there.
nonisolated public enum WaterGlass {
    public static let defaultML = 250

    public static func milliliters(from snapshot: WidgetSnapshot?) -> Int {
        snapshot?.hydrationGlassML ?? defaultML
    }
}

/// What became of one glass logged to Santé, on the phone or the watch
/// (issues #607, #724): the same five answers, said the same way by Siri on
/// both devices.
nonisolated public enum WaterLogOutcome: Equatable, Sendable {
    case logged(milliliters: Int)
    case unavailable
    case denied
    /// Never answered: only the app, on screen, can show the question.
    case notDetermined
    case failed

    /// What Siri and Raccourcis say back.
    public var dialog: String {
        switch self {
        case .logged(let glassML): kitText("C'est noté : +\(glassML) ml d'eau.")
        case .unavailable: kitText("Santé n'est pas disponible sur cet appareil.")
        case .denied:
            kitText("Foulée n'a pas l'autorisation d'écrire dans Santé. Active l'eau dans Santé > Profil > Apps > Foulée.")
        case .notDetermined: kitText("Ouvre d'abord Foulée pour autoriser l'accès à Santé.")
        case .failed: kitText("Verre non enregistré — réessaie")
        }
    }
}
