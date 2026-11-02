# ADR 0015 — Foulée sur l'iPhone Duo : SDK 27.1 et mise en page par l'espace disponible

- **Statut** : acceptée (2026-11)
- **Issues** : [#659](https://github.com/getfoulee/foulee/issues/659), [#660](https://github.com/getfoulee/foulee/issues/660), [#661](https://github.com/getfoulee/foulee/issues/661), [#662](https://github.com/getfoulee/foulee/issues/662), [#663](https://github.com/getfoulee/foulee/issues/663), [#664](https://github.com/getfoulee/foulee/issues/664), [#665](https://github.com/getfoulee/foulee/issues/665), [#666](https://github.com/getfoulee/foulee/issues/666), [#672](https://github.com/getfoulee/foulee/issues/672)

## Contexte

L'iPhone Duo a deux écrans : un écran extérieur de téléphone (1398 × 2034 px) et un écran intérieur pliable, bien plus large. Compilée avec le SDK iOS 26, Foulée y tournait en mode compatibilité : une fenêtre de téléphone centrée sur l'écran intérieur, entourée de vide. Apple impose à partir d'**avril 2027** le SDK iOS 27 pour tout envoi sur App Store Connect, des captures iPhone Duo prises sur l'appareil ou son simulateur pour les apps compilées avec le SDK 27.1 (Guideline 2.3.3), et une interface utilisable dans toutes les postures (Guideline 2.1(a)).

L'app avait de bonnes bases : ni `UIScreen.main`, ni test d'idiome, ni barre d'onglets. Mais elle avait des tailles fixes (anneau de séance de 232 pt, héros du jour de 128 pt) et des cartes plein cadre, pensées pour un écran de téléphone.

## Décisions

### D1 — Le SDK iOS 27.1 est le plancher, le déploiement reste iOS 26 (#660)

- La CI, la release et le job des paquets Swift choisissent tous les trois **le Xcode 27.x stable le plus récent à partir de 27.1** (`setup-xcode` avec `'^27.1'`) : `.github/actions/prepare-project/action.yml`, `release.yml`, `swift-packages.yml`. Il n'y a pas de fichier `.xcode-version` et Tuist ne fixe rien.
- 27.1 est le plancher parce que c'est son SDK qui étend l'app à tout l'écran intérieur au lieu du mode compatibilité. Passer à Xcode 28 est un changement délibéré des trois réglages.
- La cible de déploiement reste **iOS 26.0** (`Project.swift`) : changer de SDK ne retire aucun appareil.
- Le verrou en portrait (`UISupportedInterfaceOrientations`) reste pour l'écran extérieur. L'écran intérieur l'ignore : l'app doit donc tenir en paysage comme en portrait.

### D2 — On décide sur l'espace disponible, jamais sur l'appareil (#661)

- Aucun écran ne demande s'il tourne sur un iPhone Duo, dans quelle posture ni dans quelle orientation. Les décisions se prennent sur la taille que la fenêtre donne, comme Apple le recommande. C'est ce qui fait marcher le même code en Split View ou dans une fenêtre redimensionnée.
- Chaque écran pose son contenu dans une **colonne de lecture** : `View.screenColumn(gutter:)` (`Foulee/DesignSystem/Components/ScreenColumn.swift`), **640 pt au plus**, centrée, avec une marge latérale de 20 pt par défaut. Sur un téléphone, plus étroit que 640 pt, rien ne bouge.
- Elle couvre Aujourd'hui, le Bilan, les statistiques, les Réglages, l'Hydratation, le détail d'une sortie, les feuilles de partage et de Garmin, les Nouveautés et l'onboarding. Les feuilles s'affichent en cartes centrées, sans détente à régler. Les tailles fixes des héros sont gardées.
- Un écran nouveau prend `screenColumn()`. On ne recrée pas de largeur maximale à la main.

### D3 — La sortie en cours passe sur deux volets quand la place le permet (#662, #664)

- `LiveWalkLayout` (`Foulee/Features/ActiveWalk/`), commun à `ActiveWalkScreen` et `MirroredWalkScreen`, pose la carte à côté des chiffres **seulement si la fenêtre est plus large que haute et que chaque volet garde au moins 320 pt**, avec 24 pt entre les deux. Sinon, la pile habituelle : une Split View étroite reste empilée.
- Sur deux volets, la carte est toujours visible : le bouton « Carte » et « Voir le parcours » disparaissent.
- L'anneau grandit avec la fenêtre, à partir d'une référence de 440 × 860 pt, jusqu'à 1,4 fois sa taille et dans la colonne de 640 pt. Sur un téléphone, il garde ses 232 pt.
- La logique est testée sans simulateur (`FouleeTests/LiveWalkLayoutTests.swift`).

### D4 — Seuls les fonds débordent, le contenu reste dans les marges de sécurité (#663)

- Les cartes et les fonds peuvent courir jusqu'aux bords (`ignoresSafeArea`). Ce qu'on lit ou qu'on touche, non : la carte d'étape, l'indice et « Tracé en attente » restent dans les marges de sécurité et dans la colonne, même quand la carte elle-même est plein cadre.
- Les taches du `Wallpaper` s'étirent avec la fenêtre, jamais en dessous de leur taille de téléphone (`FouleeTests/WallpaperTests.swift`).

### D5 — Passer d'un écran à l'autre ne perd rien (#664)

- Toutes les tailles se lisent en direct (`GeometryReader`, `onGeometryChange`). Aucune n'est gardée dans un `@State`.
- Aucun changement d'identité (`.id`) ne suit la taille : défilement, feuille ouverte et étape d'onboarding (`OnboardingFlow`, `UserPreferences`) survivent au pliage. `onOpenURL` reste hors des branches de mise en page.

### D6 — L'écran intérieur est testé en CI, l'écran extérieur à la main (#665, #672)

- Le job **iPhone Duo** (`tools/smoke_test.sh`, cible `FouleeSmoke`) parcourt l'app en mode capture sur un simulateur « Foulee Duo » au runtime le plus récent : l'accueil, le Bilan, les Réglages et retour, puis une sortie lancée et arrêtée. Il ne tourne que quand l'app iPhone change.
- Sur l'iPhone Duo, le bouton retour est dessiné dans la bande latérale, hors de la barre de navigation : les tests le trouvent par l'identifiant `BackButton`.
- Ni `simctl` ni XCTest ne savent plier le simulateur. L'écran extérieur se vérifie donc à la main.

### D7 — Les captures Duo se prennent sur le simulateur déplié à la main (#666)

- Une famille `iphone-duo` de plus dans `tools/compose_appstore_screenshots.swift` : des planches de **2007 × 2853 px** composées à partir de captures de 2006 × 2852 px (XCTest saisit l'écran intérieur avec un pixel de moins dans chaque sens). Les six feuilles perdent leur bande grisée : 320 px en haut et 24 px de chaque côté.
- Rien ne déplie le simulateur. On le déplie dans Simulator.app, en portrait et dans le bon sens, puis on lance `tools/capture_screenshots.sh "Foulee Duo" iphone-duo`. Le script refuse d'écrire si les captures ne mesurent pas 2006 × 2852.
- Le workflow **Store screenshots** ne peut pas le faire : il refuse « publish ». Les planches Duo se capturent et se téléversent depuis un Mac (`fastlane screenshots`), et le lane s'arrête s'il manque une famille, puisque deliver viderait son onglet.

## Hors périmètre

- **Les APIs de charnière et de posture** : aucune mise en page ne dépend de l'angle ou de la pliure.
- **Les « arrangements »**, c'est-à-dire réorganiser un écran entier pour l'écran intérieur (barres d'outils verticales, plusieurs colonnes de contenu). Une colonne lisible passait avant ; seule la sortie en cours a deux volets.
- La montre et l'app Garmin ne sont pas concernées.

## Conséquences

- Un écran iPhone nouveau pose son contenu avec `screenColumn()` et ne lit jamais l'appareil, l'idiome ni l'orientation.
- Une taille nouvelle se lit en direct et se teste comme `LiveWalkLayout`, en logique pure.
- Un changement d'écran met à jour le parcours de `FouleeSmoke` s'il touche à la navigation.
- Une version proposée à l'App Store a ses planches iPhone Duo, en français et en anglais, prises sur un Mac (`docs/RELEASE.md` § 9).
- L'app a besoin de Xcode 27.1 au moins, en local comme en CI.

## Ce qui reste non vérifié

- Aucun iPhone Duo réel n'a fait tourner Foulée : tout a été vu au simulateur.
- Plier ou déplier l'appareil pendant une sortie, et la Live Activity à ce moment-là, n'ont pas été essayés.
- Les captures Duo n'ont pas encore été téléversées ni vues dans l'aperçu d'App Store Connect (#666, avant avril 2027).
