import FouleeDesignSystem
import FouleeDomain
import SwiftUI

/// Objectifs: what the user moves at, and how much a day.
struct SettingsGoalsPage: View {
    @Bindable var preferences: UserPreferences

    var body: some View {
        // One row per sport, ticked when favourite (#835), in place of the
        // walk / run / both control that could name no third sport. Glass
        // rows of their own, so not inside a glass section. The footnote is
        // the literal truth rather than reassurance: the streak, the record
        // and the calendar count exercise minutes across every activity type
        // and never read this preference (#220).
        VStack(alignment: .leading, spacing: 14) {
            Text("Sports favoris")
                .font(FouleeFont.headline)
                .accessibilityAddTraits(.isHeader)
            FavoriteSportsList(favorites: preferences.favoriteSports) { sport in
                preferences.favoriteSports = SportChoice.toggling(sport, in: preferences.favoriteSports)
            }
            Text("En tête de « Autre sport ». Ta série compte toutes tes activités, quel que soit ce choix.")
                .font(FouleeFont.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The session duration that drives the ring and the « démarrer ta
        // sortie » flow.
        GlassSection("Objectif d'activité") {
            SettingsSlider(
                title: "Objectif d'activité",
                value: $preferences.minutesGoal,
                range: 10...60,
                step: 5,
                tint: FouleeColor.accentMid
            ) { "\($0) min" }
        }
        // Tracked all day — a session only contributes to it — so it stands
        // apart from the activity goal.
        GlassSection("Objectif de pas", footer: "Compté toute la journée, ta sortie incluse.") {
            SettingsSlider(
                title: "Objectif de pas",
                value: $preferences.stepsGoal,
                range: 2_000...15_000,
                step: 500,
                tint: FouleeColor.accentMid
            ) { String(localized: "\($0.groupedText()) pas") }
        }
    }
}
