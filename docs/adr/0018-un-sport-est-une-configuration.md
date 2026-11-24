# ADR 0018 — Un sport est une configuration, pas une branche de code

- **Statut** : acceptée (2026-11)
- **Issues** : [#720](https://github.com/getfoulee/foulee/issues/720), épic [#798](https://github.com/getfoulee/foulee/issues/798)

## Contexte

Foulée ne connaissait que la marche et la course, et chaque fait sur un sport vivait dans un `switch` : le libellé, l'icône, le titre de séance, les calories par pas dans `SessionActivity` ; le libellé et l'icône à nouveau dans `RecordedActivity` ; la correspondance avec HealthKit dans deux extensions de l'app ; le nom envoyé par l'app Garmin ailleurs encore. Ajouter le vélo ou la natation aurait demandé de rouvrir chacun de ces `switch`.

## Décisions

### D1 — `SportID` nomme le sport, `SportDescriptor` dit tout ce qu'on en sait

- `SportID` (FouleeKit) est une énumération aux valeurs brutes **stables** : `walking`, `running`, `hiking`. Ce sont les chaînes que `SessionActivity` et `RecordedActivity` enregistraient déjà, dans les préférences, entre la montre et l'iPhone et dans les messages Connect IQ : aucune migration.
- `SportDescriptor` porte : la famille (à pied…), le lieu (dehors…), les capteurs utilisés (tracé, pas, dénivelé), l'affichage de la vitesse (allure en min/km), si Foulée enregistre ce sport ou se contente de le lire, le libellé, le titre de séance, le symbole SF, le type HealthKit, le nom Garmin et les calories par pas.
- Ajouter un sport, c'est ajouter un cas et son descripteur. Les tests parcourent `SportID.allCases` et exigent pour chaque sport un type HealthKit réel, un libellé et un symbole distincts, et, s'il est enregistrable, un titre de séance, des calories et un nom Garmin.

### D2 — Une seule correspondance avec HealthKit, gardée hors du kit

- Le kit reste sans HealthKit (ADR 0007) : le descripteur garde la valeur brute de `HKWorkoutActivityType`. La seule traduction se trouve dans `FouleeHealth/Sources/SportID+HealthKit.swift`, dans le module FouleeHealth que l'iPhone et la montre lient (#725).
- L'écriture (`SessionActivity.hkActivityType`), la lecture (`RecordedActivity(_:)`, `SessionActivity(_:)`) et le filtre du résumé (`WorkoutActivityFilter`) passent par elle. Le filtre accepte désormais exactement les sports du tableau.

### D3 — `SessionActivity` et `RecordedActivity` restent, adossés au tableau

- `SessionActivity` reste l'ensemble de ce que Foulée a le droit d'**écrire**, et `RecordedActivity` ce qu'elle sait **lire**, avec `.other` pour ce qu'elle ne sait pas nommer. Leur distinction (#223, #245) tient toujours.
- Ils ne contiennent plus de faits : leurs propriétés lisent le descripteur. Le renommage des types propres à la marche est l'affaire de #722.

### D4 — Les métriques et les repères viendront s'y accrocher

- Les métriques en direct et du résumé relèvent du catalogue de métriques (#721), les règles de repères du Bilan et de la notification de #742. Les deux s'ajouteront au descripteur au lieu de créer de nouveaux `switch`.
- Les familles, lieux et capteurs n'ont aujourd'hui que les valeurs de la marche, de la course et de la randonnée. Chaque sport nouveau ajoute celles dont il a besoin.

## Conséquences

- Aucun changement visible : la marche et la course gardent leurs libellés, leurs icônes, leurs calories et leur type Santé, ce que `SportTests` vérifie.
- Une valeur brute de `SportID` ne doit jamais changer : des données d'utilisateurs en dépendent.
