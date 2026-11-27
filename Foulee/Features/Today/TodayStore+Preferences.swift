import FouleeDomain
import Foundation

/// The mirrored copy of the user's preferences: what the store derives from it,
/// and the gate that decides whether a change is worth re-deriving and
/// publishing. Split out of `TodayStore.swift` for the same reason
/// `TodayStore+WidgetPublication.swift` is — that file is at the length limit.
extension TodayStore {
    /// The favourites as the walk / run / both mode the widgets and the Watch
    /// payload still speak in.
    var activityMode: ActivityMode { ActivityMode(favorites: favoriteSports) }

    /// The last sport, or the first favourite, and the sections of
    /// « Quel sport ? » (#743). On the store rather than in `TodayScreen`, so
    /// a test can reach it.
    var sportChoice: SportChoice.Resolved {
        SportChoice.resolve(last: lastSport, favorites: favoriteSports)
    }

    /// The sport the home's buttons name and start: the one just picked in
    /// « Quel sport ? » (#832), else the last one or the first favourite.
    var startActivity: SessionActivity { chosenSport ?? sportChoice.activity }

    /// What « Commencer une sortie » starts (#604): the sport the shortcut
    /// names, or exactly what the home button would.
    func startActivity(requested activity: SessionActivity?) -> SessionActivity {
        activity ?? startActivity
    }

    /// The one place an outing starts from the home, on the iPhone or on the
    /// watch (#832): resolves the sport, records it once as the last sport,
    /// and forgets the pick, which the last sport now names.
    func beginStart(requested activity: SessionActivity?, preferences: UserPreferences) -> SessionActivity {
        let started = startActivity(requested: activity)
        preferences.recordStart(of: started)
        chosenSport = nil
        apply(preferences: preferences)
        return started
    }

    /// The walk window as the mirrored copy stores it — hour and minute only.
    /// Not private: `apply` (in `TodayStore.swift`) stores what it returns and
    /// `hasChanged` compares against it, and they must agree.
    static func window(for preferences: UserPreferences) -> DateComponents {
        DateComponents(
            hour: preferences.walkWindowStart.hour,
            minute: preferences.walkWindowStart.minute
        )
    }

    /// Whether anything the mirrored copy holds differs from `preferences`.
    ///
    /// Gates both halves of `apply`: the snapshot re-derivation (goal, days and
    /// window are what the ring and the streak are computed against) *and* the
    /// publish, which is the only thing that carries the hydration prefs and
    /// the activity mode to the Watch. Neither of the latter two is a snapshot
    /// input — they're compared here so a settings change reaches the wrist
    /// without waiting for the next refresh (issue #223).
    ///
    /// The last sport is not compared (#743): it moves at every start, the
    /// streak and the widgets do not depend on it, and the refresh that
    /// follows the outing carries it to the wrist.
    ///
    /// Internal, not private, and that is the point: for a preference the
    /// snapshot doesn't feed, `apply`'s only visible effect is a publish, and
    /// the publish goes through the process-global app group — unassertable
    /// from a suite that runs in parallel. This gate is where such a change is
    /// either noticed or lost, so it is the seam the tests hold.
    func hasChanged(preferences: UserPreferences) -> Bool {
        preferences.stepsGoal != stepsGoal
            || preferences.minutesGoal != minutesGoal
            || Self.window(for: preferences) != walkWindowStart
            || preferences.activeDays != activeDays
            || preferences.hydrationEnabled != hydrationEnabled
            || preferences.hydrationGoalML != hydrationGoalML
            || preferences.hydrationGlassML != hydrationGlassML
            || preferences.favoriteSports != favoriteSports
    }
}
