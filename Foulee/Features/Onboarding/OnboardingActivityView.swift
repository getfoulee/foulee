import FouleeDesignSystem
import FouleeDomain
import SwiftUI

/// Second onboarding screen: the favourite sports, the same list as
/// Réglages › Activité (#835, owner's choice), walking ticked by default.
///
/// Placed right after the welcome and before the goal step: the flow is linear
/// with no back navigation, and this is its first consequential choice whose
/// default isn't self-evident, so it has to be asked before the screens that
/// are written around it (issue #221).
///
/// Nothing here touches the streak: the favourites are a presentation
/// preference, and the streak stays `max(appleExerciseTime, workout minutes)`
/// over every activity type whatever is picked.
struct OnboardingActivityView: View {
    var preferences: UserPreferences
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Scrolled: the heading and a row per sport outgrow the screen,
            // all the more at the larger Dynamic Type sizes. The CTA stays
            // pinned to the bottom.
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    OnboardingStepIndicator(step: .activity)
                        .frame(maxWidth: .infinity)
                    heading
                    choices
                }
                .screenColumn(gutter: 24)
                .padding(.top, 70)
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryButton(title: "Continuer", systemIcon: nil, action: confirm)
                .screenColumn(gutter: 24)
                .padding(.bottom, 36)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quels sont\ntes sports ?")
                .scaledSystemFont(size: 30, weight: .bold)
                .lineSpacing(2)
                .accessibilityAddTraits(.isHeader)
            Text("Coche tes favoris : ils passent en tête. Ta série, elle, compte toutes tes activités.")
                .font(FouleeFont.body)
                .foregroundStyle(.secondary)
        }
    }

    /// Written the moment a row is tapped rather than held in local state
    /// until the end: an onboarding abandoned midway still leaves the choice
    /// behind, and it is on disk well before `hasCompletedOnboarding`.
    private var choices: some View {
        FavoriteSportsList(favorites: preferences.favoriteSports) { sport in
            preferences.favoriteSports = SportChoice.toggling(sport, in: preferences.favoriteSports)
        }
    }

    /// Re-assigning the value already in memory looks redundant, but `didSet`
    /// is what writes `UserDefaults`: this is how someone who accepts the
    /// default (marche) still leaves the key on disk, instead of a blank that
    /// reads exactly like the installs which predate the question (#219).
    private func confirm() {
        let chosen = preferences.favoriteSports
        preferences.favoriteSports = chosen
        onContinue()
    }
}

// Spelled out in each block rather than shared through a helper: the screen
// holds a plain reference (no `@State` wrapper needed), and any named
// declaration only previews reach reads as dead code to the Periphery scan.
#Preview("Light") {
    ZStack {
        Wallpaper()
        OnboardingActivityView(
            preferences: UserPreferences(
                defaults: UserDefaults(suiteName: "preview-onboarding-activity") ?? .standard
            ),
            onContinue: {}
        )
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        Wallpaper()
        OnboardingActivityView(
            preferences: UserPreferences(
                defaults: UserDefaults(suiteName: "preview-onboarding-activity") ?? .standard
            ),
            onContinue: {}
        )
    }
    .preferredColorScheme(.dark)
}
