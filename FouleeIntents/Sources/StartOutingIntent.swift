import AppIntents
import FouleeKit
import Observation

/// « Commencer une sortie » for Siri, Raccourcis and Spotlight (issue #604),
/// and the Control Center and Action button control (#606). Opens Foulée and
/// starts the outing the way the home button does: the intent only hands the
/// request to the home, which owns the session. Registered by the widget
/// extension too (`FouleeIntentsPackage`), so the control can name it; being a
/// foreground intent, the system still runs it in the app.
public struct StartOutingIntent: AppIntent {
    public static var title: LocalizedStringResource { "Commencer une sortie" }
    // periphery:ignore - read by the AppIntents runtime, never from code.
    public static var description: IntentDescription {
        IntentDescription(
            "Ouvre Foulée et démarre une sortie.",
            categoryName: "Sortie",
            searchKeywords: ["Marche", "Course", "Footing", "Balade"]
        )
    }
    // periphery:ignore - read by the AppIntents runtime, never from code.
    public static var supportedModes: IntentModes { .foreground }

    /// Left empty, the user's own mode decides, as on the home button.
    @Parameter(title: "Sport")
    public var activity: OutingActivity?

    public init() {}

    public init(activity: OutingActivity?) {
        self.activity = activity
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        SessionStartRouter.shared.start(activity?.mode)
        return .result()
    }
}

/// The sport as Raccourcis lists it and Siri hears it.
nonisolated public enum OutingActivity: String, AppEnum {
    case walking
    case running
    case automatic

    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Sport" }

    public static var caseDisplayRepresentations: [OutingActivity: DisplayRepresentation] {
        [
            .walking: DisplayRepresentation(title: "Marche"),
            .running: DisplayRepresentation(title: "Course"),
            .automatic: DisplayRepresentation(
                title: "Automatique",
                subtitle: "Foulée reconnaît la marche ou la course"
            )
        ]
    }

    /// « Automatique » is « les deux »: the session's own motion history
    /// settles the sport at the end (#246).
    public var mode: ActivityMode {
        switch self {
        case .walking: .walking
        case .running: .running
        case .automatic: .both
        }
    }
}

/// A start asked for by a shortcut, carried to the home that presents the
/// session — the intent runs before any screen may be mounted.
nonisolated public struct SessionStartRequest: Equatable {
    /// `nil` when the shortcut named no sport: the user's own mode decides.
    public let mode: ActivityMode?
}

/// Main-actor spelled out: the framework has no default isolation.
@MainActor
@Observable
public final class SessionStartRouter {
    public static let shared = SessionStartRouter()

    public private(set) var pending: SessionStartRequest?

    public func start(_ mode: ActivityMode?) {
        pending = SessionStartRequest(mode: mode)
    }

    /// Read and clear, so a rebuild of the home does not start twice.
    public func take() -> SessionStartRequest? {
        guard let request = pending else { return nil }
        pending = nil
        return request
    }
}
