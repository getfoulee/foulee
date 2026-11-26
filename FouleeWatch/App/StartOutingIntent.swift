import AppIntents
import FouleeDomain

/// « Commencer une sortie » for Siri on the watch (issue #607).
///
/// Left empty or set to « Dernier sport », it does what « Démarrer » does:
/// the last sport starts (#743). The intent only parks the request;
/// `WatchRootView` owns the session.
struct StartOutingIntent: AppIntent {
    static var title: LocalizedStringResource { "Commencer une sortie" }
    // periphery:ignore - read by the AppIntents runtime, never from code.
    static var description: IntentDescription { "Ouvre Foulée et démarre une sortie." }
    // periphery:ignore - read by the AppIntents runtime, never from code.
    static var supportedModes: IntentModes { .foreground }

    @Parameter(title: "Sport")
    var activity: WatchOutingActivity?

    @MainActor
    func perform() async throws -> some IntentResult {
        WatchPendingStart.shared.request(Self.activity(for: activity))
        return .result()
    }

    /// Static so a test drives it against a throwaway defaults suite, like
    /// `WatchRootView.sportChoice`.
    @MainActor
    static func activity(
        for activity: WatchOutingActivity?,
        syncedTo defaults: UserDefaults = WatchSyncStore.sharedDefaults
    ) -> SessionActivity {
        activity?.activity ?? WatchRootView.sportChoice(syncedTo: defaults).activity
    }
}

/// The Action button of the Apple Watch Ultra (issue #607). Its settings list
/// `suggestedWorkouts`: « Dernier sport » first, which starts what
/// « Démarrer » would (#743), then one per sport.
struct StartWorkoutOutingIntent: StartWorkoutIntent {
    static var title: LocalizedStringResource { "Commencer une sortie" }
    // periphery:ignore - read by the AppIntents runtime, never from code.
    /// Hidden from Raccourcis, which already lists `StartOutingIntent`.
    static var isDiscoverable: Bool { false }

    /// What the Action button's settings list.
    static var suggestedWorkouts: [StartWorkoutOutingIntent] {
        WatchOutingActivity.allCases.map { StartWorkoutOutingIntent(style: $0) }
    }

    @Parameter(title: "Sport")
    var workoutStyle: WatchOutingActivity

    // periphery:ignore - read by the AppIntents runtime, never from code.
    var displayRepresentation: DisplayRepresentation {
        WatchOutingActivity.caseDisplayRepresentations[workoutStyle]
            ?? DisplayRepresentation(title: "Sortie")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        WatchPendingStart.shared.request(StartOutingIntent.activity(for: workoutStyle))
        return .result()
    }
}

/// The sport as Siri hears it and the Action button lists it.
enum WatchOutingActivity: String, AppEnum, CaseIterable {
    /// The sport « Démarrer » starts: the last one (#743).
    case last
    case walking
    case running

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Sport" }

    static var caseDisplayRepresentations: [WatchOutingActivity: DisplayRepresentation] {
        [
            .last: DisplayRepresentation(title: "Dernier sport", image: .init(systemName: "arrow.clockwise")),
            .walking: DisplayRepresentation(title: "Marche", image: .init(systemName: "figure.walk")),
            .running: DisplayRepresentation(title: "Course", image: .init(systemName: "figure.run"))
        ]
    }

    /// `nil` for « Dernier sport », resolved at the tap.
    var activity: SessionActivity? {
        switch self {
        case .last: nil
        case .walking: .walking
        case .running: .running
        }
    }
}
