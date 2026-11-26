import AppIntents
import FouleeDomain
import Observation

/// « Commencer une sortie » for Siri, Raccourcis and Spotlight (issue #604),
/// and the Control Center and Action button control (#606). Opens Foulée and
/// starts the outing the way the home button does: the intent only hands the
/// request to the home, which owns the session. Compiled into the widget
/// extension too, so the control can name it; being a foreground intent, the
/// system still runs it in the app.
///
/// Not in FouleeIntents with `LogWaterIntent` (#724): Siri's training of the
/// App Shortcut phrases « Commence une \(sport) avec Foulée » only resolves a
/// parameter whose `AppEnum` the app declares itself.
struct StartOutingIntent: AppIntent {
    static var title: LocalizedStringResource { "Commencer une sortie" }
    // periphery:ignore - read by the AppIntents runtime, never from code.
    static var description: IntentDescription {
        IntentDescription(
            "Ouvre Foulée et démarre une sortie.",
            categoryName: "Sortie",
            searchKeywords: ["Marche", "Course", "Footing", "Balade"]
        )
    }
    // periphery:ignore - read by the AppIntents runtime, never from code.
    static var supportedModes: IntentModes { .foreground }

    /// Left empty, the last sport starts, as on the home button (#743).
    @Parameter(title: "Sport")
    var activity: OutingActivity?

    init() {}

    init(activity: OutingActivity?) {
        self.activity = activity
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        SessionStartRouter.shared.start(activity?.activity)
        return .result()
    }
}

/// The sport as Raccourcis lists it and Siri hears it.
nonisolated enum OutingActivity: String, AppEnum {
    case walking
    case running
    case automatic

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Sport" }

    static var caseDisplayRepresentations: [OutingActivity: DisplayRepresentation] {
        [
            .walking: DisplayRepresentation(title: "Marche"),
            .running: DisplayRepresentation(title: "Course"),
            // The raw value stays: shortcuts saved with it must keep working.
            .automatic: DisplayRepresentation(
                title: "Dernier sport",
                subtitle: "Le sport de ta dernière sortie"
            )
        ]
    }

    /// The sport this names; `nil` for « Dernier sport », which the home
    /// resolves as « Démarrer » does (#743).
    var activity: SessionActivity? {
        switch self {
        case .walking: .walking
        case .running: .running
        case .automatic: nil
        }
    }
}

/// A start asked for by a shortcut, carried to the home that presents the
/// session — the intent runs before any screen may be mounted.
nonisolated struct SessionStartRequest: Equatable {
    /// `nil` when the shortcut named no sport: the last sport starts.
    let activity: SessionActivity?
}

/// Main-actor spelled out: the widget extension compiles this file without the
/// app's default isolation.
@MainActor
@Observable
final class SessionStartRouter {
    static let shared = SessionStartRouter()

    private(set) var pending: SessionStartRequest?

    func start(_ activity: SessionActivity?) {
        pending = SessionStartRequest(activity: activity)
    }

    /// Read and clear, so a rebuild of the home does not start twice.
    func take() -> SessionStartRequest? {
        guard let request = pending else { return nil }
        pending = nil
        return request
    }
}
