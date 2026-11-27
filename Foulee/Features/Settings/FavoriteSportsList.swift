import FouleeDomain
import SwiftUI

/// One row per sport Foulée records, ticked when it is a favourite (#835):
/// Réglages › Activité and the onboarding's activity step, the same list.
/// Favourites lead « Autre sport » on the iPhone and the watch.
struct FavoriteSportsList: View {
    var favorites: Set<SportID>
    var toggle: (SportID) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(SessionActivity.allCases, id: \.self) { activity in
                FavoriteSportRow(
                    activity: activity,
                    isFavorite: favorites.contains(activity.sport),
                    isOnlyFavorite: favorites == [activity.sport],
                    toggle: { toggle(activity.sport) }
                )
            }
        }
    }
}

/// One sport. Internal so a test can reach its tap through the `ForEach`.
struct FavoriteSportRow: View {
    var activity: SessionActivity
    var isFavorite: Bool
    /// The last favourite cannot be unticked: « Démarrer » needs one.
    var isOnlyFavorite: Bool
    var toggle: () -> Void

    var body: some View {
        ChoiceRow(
            title: Text(verbatim: activity.label),
            subtitle: nil,
            systemIcon: activity.icon,
            isSelected: isFavorite,
            select: toggle
        )
        .accessibilityValue(isFavorite ? Text("Favori") : Text("Pas favori"))
        .accessibilityHint(
            isOnlyFavorite
                ? Text("Il te faut au moins un sport favori")
                : Text(isFavorite ? "Retire des favoris" : "Ajoute aux favoris")
        )
    }
}

#Preview {
    FavoriteSportsList(favorites: [.walking, .hiking], toggle: { _ in })
        .padding()
}
