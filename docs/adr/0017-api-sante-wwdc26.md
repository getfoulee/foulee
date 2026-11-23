# ADR 0017 — Les API santé de la WWDC26 ne changent pas le socle : on reste sur iOS 26 et watchOS 26

- **Statut** : acceptée (2026-11)
- **Issues** : [#719](https://github.com/getfoulee/foulee/issues/719), épic [#798](https://github.com/getfoulee/foulee/issues/798)

## Contexte

L'épic multi-sport va figer un moteur de séance unique sur `HKWorkoutSession`, partagé par l'iPhone et la montre (#729, #730), puis ajouter le vélo, la natation et des séances avancées. Avant de l'écrire, il fallait savoir si iOS 27 et watchOS 27 (WWDC26, juin 2026) changent ces choix ou imposent de relever la cible de déploiement, aujourd'hui iOS 26 et watchOS 26.

Sources relues : la page des nouveautés HealthKit, la session WWDC26 « 207 » sur les zones, les notes de version d'iOS 27 et de watchOS 27, les pages de mise à jour de WorkoutKit, CoreMotion et ActivityKit, la session WWDC25 « 322 » (séances sur iPhone), et une réponse d'un ingénieur Apple sur les forums. Les liens sont en fin de document.

## Décisions

### D1 — La cible reste iOS 26 et watchOS 26

Côté séances, la seule nouveauté de la WWDC26 est l'API des **zones** de fréquence cardiaque et de puissance. Tout ce que l'épic prévoit existe déjà en 26 ou avant. Rien ne justifie d'abandonner les utilisateurs restés en 26.

### D2 — Séance iPhone et moteur partagé : on s'appuie sur iOS 26, rien de neuf en 27

- Depuis iOS 26, `HKWorkoutSession` et `HKLiveWorkoutBuilder` tournent sur iPhone, pour tous les types d'activité. La reprise après un crash passe par `recoverActiveWorkoutSession`. Siri peut démarrer, mettre en pause et arrêter la séance (`INStartWorkoutIntent` et les intents voisins). Une Live Activity s'affiche sur l'écran verrouillé, après une autorisation système.
- L'iPhone n'a pas de capteur cardiaque : la fréquence cardiaque n'y vient que d'une ceinture ou d'écouteurs Bluetooth au profil standard.
- iOS 27 et watchOS 27 n'ajoutent aucune API de session. Les notes de version de watchOS 27 ne citent qu'un correctif du miroir vers l'iPhone.
- La règle de l'ADR 0003 tient, et Apple dit la même chose : quand l'app montre est installée, la séance démarre sur la montre, et l'iPhone en est le miroir. `WorkoutEngine` (#730) vise donc l'API de 26, sans branche par version.

### D3 — Natation : rien de neuf, la piscine et l'eau libre restent sur la montre

- Aucun nouveau `HKWorkoutActivityType` en 26 ni en 27. La piscine (longueur de bassin, longueurs, mouvements de bras) et l'eau libre existent déjà sur watchOS.
- WorkoutKit sait déjà décrire des séances de natation en piscine (iOS 18 / watchOS 11).
- Sur iPhone, ces types sont disponibles mais n'ont rien à mesurer : pas de détection de longueurs, et pas de téléphone dans l'eau. #751 et #752 restent des issues **montre**.

### D4 — Capteurs vélo : sur la montre seulement, l'iPhone passe

- Depuis watchOS 10, la montre se jumelle elle-même à des capteurs Bluetooth de puissance, de cadence et de vitesse, et leurs mesures arrivent par HealthKit pendant et après la séance. #749 n'a rien d'autre à écrire.
- Sur iPhone, un ingénieur Apple l'a écrit sur les forums : les capteurs vélo ne se connectent pas à iOS 26 ; seule la montre les gère. Les notes d'iOS 27 n'annoncent pas de changement. Une ceinture cardiaque, elle, se connecte bien à l'iPhone.
- Le vélo sur iPhone (#750) reste donc **GPS seul**, comme prévu. On n'écrit pas de client Core Bluetooth pour les profils de puissance et de vitesse/cadence : ce serait du code de capteur à maintenir pour un cas que la montre couvre déjà.

### D5 — Les zones de 27 viendront plus tard, derrière `#available`

- iOS 27 et watchOS 27 ajoutent les zones aux séances : `HKWorkoutZoneGroup`, `HKWorkoutZoneConfiguration`, `zoneGroupsByType` sur `HKWorkout` et sur chaque `HKWorkoutActivity` (donc par discipline d'un multisport), et des mises à jour en direct dans le builder (`setCustomZoneConfiguration(_:for:)` avant `beginCollection`, `workoutBuilder(_:didUpdateWorkoutZone:)`).
- Cette API demande le SDK de Xcode 27. Elle n'entre pas dans le socle : elle fera l'objet d'une issue à part, derrière `if #available(iOS 27, watchOS 27, *)`, et ne doit rien changer au moteur.
- Le nom exact de l'accès aux zones préférées de l'utilisateur est à vérifier dans le SDK : la documentation et le code de la session ne citent pas la même méthode.

### D6 — WorkoutKit, multisport et Smart Stack : rien de neuf, tout est faisable en 26

- `WorkoutPlan` décrit les objectifs, les allures, les intervalles et les séances multisport depuis iOS 17 / watchOS 10. La WWDC26 n'ajoute rien à WorkoutKit. Les défis programmés (#756) et le triathlon (#754) se font en 26.
- Les Live Activities apparaissent dans la Smart Stack de la montre depuis 2024. La WWDC26 n'apporte aucune API propre aux séances pour les Live Activities ou la Smart Stack (#732, #758).

### D7 — Une nouveauté d'iOS 27 touche déjà l'app : l'historique limité

- Avec iOS 27, l'utilisateur peut n'ouvrir à une app qu'une **partie** de son historique Santé. Cela s'applique aussi à une app compilée pour iOS 26.
- La série, son record et le Bilan lisent douze mois d'historique (`StreakCalculator.historyWindowDays`). Avec un historique limité, ils peuvent paraître plus courts qu'ils ne sont, sans erreur.
- Aucune API permettant de détecter cette limite n'a été confirmée. Une issue à part doit vérifier le comportement sur un appareil en iOS 27 et, si besoin, l'expliquer à l'utilisateur.

## Conséquences

- #729 et #730 s'écrivent contre iOS 26, sans `#available`.
- #749, #751 et #752 restent sur la montre ; #750 reste GPS seul sur iPhone.
- Deux issues de suivi : les zones (D5) et l'historique limité d'iOS 27 (D7).
- Ce document sera relu à la WWDC27 avant tout changement de cible.

## Sources

- [Nouveautés HealthKit](https://developer.apple.com/documentation/updates/healthkit)
- [HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- [WWDC25, session 322 : séances sur iPhone](https://developer.apple.com/videos/play/wwdc2025/322/)
- [WWDC26, session 207 : zones de séance](https://developer.apple.com/videos/play/wwdc2026/207/)
- [HKWorkoutZoneGroup](https://developer.apple.com/documentation/healthkit/hkworkoutzonegroup)
- [Notes de version d'iOS 27](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)
- [Notes de version de watchOS 27](https://developer.apple.com/documentation/watchos-release-notes/watchos-27-release-notes)
- [HKWorkoutActivityType](https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype)
- [Nouveautés WorkoutKit](https://developer.apple.com/documentation/updates/workoutkit)
- [WorkoutPlan](https://developer.apple.com/documentation/workoutkit/workoutplan)
- [Nouveautés watchOS](https://developer.apple.com/documentation/updates/watchos)
- [Nouveautés ActivityKit](https://developer.apple.com/documentation/updates/activitykit)
- [Forums Apple : capteurs vélo et iOS 26](https://developer.apple.com/forums/thread/793399)
