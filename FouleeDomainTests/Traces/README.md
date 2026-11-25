# Traces de détection (#727)

Chaque fichier `.json` est une sortie réelle enregistrée au poignet, rejouée par `DetectionReplayTests.recordedTraces` à travers la détection marche/course de la montre (`DetectionReplay`, FouleeDomain).

- Format : `DetectionTrace` (FouleeDomain/Sources/Motion/DetectionTrace.swift), dates en secondes depuis 1970.
- Après l'enregistrement, remplir `title` et `expectedSwitches` : chaque bascule réellement faite, son sport, son décalage en secondes depuis `startedAt` et la tolérance admise.
- `synthetic-walk-then-run.json` n'est pas une trace réelle : il vérifie que le chargement fonctionne en attendant les vraies.
- Objectif de #727 : au moins cinq traces réelles avec une bascule marche/course, plus une marche, une course, une pause et une perte de GPS.
