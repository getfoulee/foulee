import FouleeDomain
import SwiftUI

/// « Autre sport » (issues #224, #743): the favourites first, then every other
/// sport the watch records. Choosing one starts it.
///
/// A full screen, not an extra control on the home: each sport gets the full
/// width of the watch, stacked, with nothing else on screen to mis-hit, and
/// the crown scrolls it at the largest Dynamic Type sizes.
///
/// It closes with the system's own button (ADR 0008): `.cancellationAction`,
/// in the top corner every watchOS sheet keeps it, taking none of the
/// answers' room.
///
/// Answering starts the session at once and `WatchWorkoutStore.stop()` saves
/// unconditionally, so a sport tapped by mistake is still a permanent
/// workout. Discarding a session already under way would be an action on the
/// active screen — its own issue.
struct WatchActivityChoiceView: View {
    var sections: SportChoice.Sections
    /// The sport « Démarrer » starts now, marked.
    var current: SessionActivity
    var onChoose: (SessionActivity) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    Text("Quel sport ?")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .padding(.bottom, 2)
                        .accessibilityAddTraits(.isHeader)
                    rows(sections.favorites)
                    if !sections.others.isEmpty {
                        Text("Autres sports")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                            .accessibilityAddTraits(.isHeader)
                        rows(sections.others)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollBounceBehavior(.basedOnSize)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    WatchActivityCancelButton(cancel: onCancel)
                }
            }
        }
    }

    /// The favourites need no title: they come first, under the question.
    private func rows(_ sports: [SessionActivity]) -> some View {
        ForEach(sports, id: \.self) { activity in
            WatchActivityChoiceButton(
                activity: activity,
                isCurrent: activity == current,
                select: { onChoose(activity) }
            )
        }
    }
}

/// One full-width answer. Internal rather than private for the same reason as
/// the phone's `ActivityChoiceButton`: `ForEach` stores a closure instead of
/// its rows, and calling it is the only way a test can reach the tap action.
struct WatchActivityChoiceButton: View {
    var activity: SessionActivity
    var isCurrent = false
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            Label(activity.label, systemImage: activity.icon)
                .font(.headline)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        // The current sport in the accent colour, the others in grey: the
        // same tap starts any of them.
        .tint(isCurrent ? Color("AccentColor") : .gray)
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }
}

/// The way back out, and on the watch it is the *only* one — there is no
/// navigation bar behind this screen to swipe back to. Named for the same
/// reason the answers are: wired to nothing it strands the user on a screen
/// that replaced their home.
struct WatchActivityCancelButton: View {
    var cancel: () -> Void

    var body: some View {
        Button("Annuler", systemImage: "xmark", role: .cancel, action: cancel)
    }
}

#Preview {
    WatchActivityChoiceView(
        sections: SportChoice.sections(favorites: [.running]),
        current: .running,
        onChoose: { _ in },
        onCancel: {}
    )
}
