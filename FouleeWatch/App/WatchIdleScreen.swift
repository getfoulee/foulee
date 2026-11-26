import FouleeDomain
import SwiftUI

/// The watch's idle route: the home screen, or the sport picker that
/// « Autre sport » opens (issues #224, #743).
///
/// Split out of `WatchRootView` because this is where the decision is made,
/// and a decision inside a `View` body is unassertable — the same argument
/// that put `sportChoice` on `WatchRootView` as a static function.
/// Everything here is a plain `let` or closure, so a test builds the screen,
/// pulls `WatchTodayView` out of the tree and taps its real « Démarrer »
/// action, then checks what it started.
///
/// The picker replaces the home rather than being presented over it as a
/// sheet. Cancelling rebuilds `WatchTodayView` scrolled back to the top, which
/// costs nothing since « Démarrer » is pinned there (ADR 0008). A
/// `.sheet`/`.fullScreenCover` stores its content in a closure, which puts the
/// picker out of reach of `ViewTreeProbe` — and the probe is what makes
/// « choosing Course records a run » assertable at all.
struct WatchIdleScreen: View {
    let today: WatchTodayStore
    var errorMessage: String?
    /// Whether the picker is currently on screen. Owned by `WatchRootView`,
    /// passed in rather than held here so the route is a function of its
    /// inputs and a test can build both halves.
    var isChoosingActivity: Bool
    /// What « Démarrer » starts and what « Autre sport » lists, read from
    /// what the phone synced. Defaulted to the real read, overridden by tests.
    var choice: () -> SportChoice.Resolved = { WatchRootView.sportChoice() }
    /// Start now.
    var onStart: (SessionActivity) -> Void
    /// « Autre sport ».
    var onChooseSport: () -> Void
    /// Backed out of the picker without starting anything.
    var onCancel: () -> Void

    var body: some View {
        let choice = choice()
        if isChoosingActivity {
            // The answer goes down the very same path as a one-gesture start,
            // so there is one place a session can begin, not two.
            WatchActivityChoiceView(
                sections: choice.sections,
                current: choice.activity,
                onChoose: onStart,
                onCancel: onCancel
            )
        } else {
            WatchTodayView(
                store: today,
                errorMessage: errorMessage,
                sport: choice.activity,
                // Read again at the tap: the phone can push a newer last sport
                // while this screen sits on the wrist.
                onStart: { onStart(self.choice().activity) },
                onChooseSport: onChooseSport
            )
        }
    }
}
