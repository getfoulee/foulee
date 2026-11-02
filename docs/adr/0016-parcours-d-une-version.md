# ADR 0016 — Le parcours d'une version : des notes écrites une fois, une soumission validée à la main

- **Statut** : acceptée (2026-11)
- **Issues** : [#620](https://github.com/getfoulee/foulee/issues/620), [#621](https://github.com/getfoulee/foulee/issues/621), [#622](https://github.com/getfoulee/foulee/issues/622), [#623](https://github.com/getfoulee/foulee/issues/623), [#624](https://github.com/getfoulee/foulee/issues/624), [#625](https://github.com/getfoulee/foulee/issues/625), [#702](https://github.com/getfoulee/foulee/issues/702)

## Contexte

Un tag `v*` publiait déjà une build sur TestFlight (`release.yml`). Tout le reste se faisait à la main : les notes de version, recopiées dans TestFlight, la fiche App Store et la release GitHub ; la soumission à l'App Store ; la publication. Les copies divergeaient (la note anglaise de la fiche décrivait encore la 1.57.0), et l'app ne disait jamais ce qui avait changé.

## Décisions

### D1 — Les notes sont écrites une fois, dans le dépôt (#622, #702)

- Chaque version a deux fichiers : `docs/releases/X.Y.Z.md` en français et `X.Y.Z.en.md` en anglais. Ce sont les seules sources.
- Le workflow en tire la release GitHub (le français, puis l'anglais sous `## English`, que le site sépare), le « À tester » de TestFlight (en français) et les « Nouveautés » de la fiche App Store dans chaque langue. Il n'y a plus de `release_notes.txt` dans `fastlane/metadata/`.
- Sans ces deux fichiers dans le commit tagué, la release s'arrête avant le build. `tools/check_store_metadata.py` refuse une PR dont la note n'a pas sa traduction ou dépasse 4 000 caractères.
- Pour les écrire, on part du brouillon « Prochaine version », réécrit à chaque push sur `main` avec les titres des PR fusionnées depuis le dernier tag. C'est une liste pour le développeur ; la note, elle, s'adresse aux utilisateurs.

### D2 — TestFlight est la dernière étape automatique (#624)

- Un tag ne va jamais plus loin que TestFlight. La fiche ne reçoit une build qu'à la demande : le workflow « App Store submission », lancé à la main avec le tag, attend l'approbation de l'environnement `app-store` (relecteur obligatoire, branche `main` seulement).
- Il écrit la fiche telle qu'elle est sur `main`, attache la build du tag et la soumet à la revue d'Apple.
- Une fois la version approuvée, elle sort seule en **publication progressive sur 7 jours**. On peut la mettre en pause ou la publier pour tous depuis App Store Connect.

### D3 — L'app montre ses nouveautés sans appel réseau (#621)

- Le contenu de l'écran « Nouveautés » vient de `Foulee/Resources/WhatsNew.json`, embarqué dans l'app, en français et en anglais.
- Une version n'est « notable » que si elle a une entrée dans ce fichier ; sinon l'app ne montre rien. L'écran s'affiche une seule fois par version, jamais au premier lancement (l'onboarding la marque comme vue). Qui a sauté des versions voit la plus récente qu'il a manquée.
- Ce texte est distinct des notes de version : il est plus court, et il est écrit pour l'écran.

### D4 — Pas encore de bêta publique (#623)

- Les builds TestFlight vont au groupe de testeurs internes. Le groupe externe, son lien public et sa place sur getfoulee.app restent à faire : ils demandent une action dans App Store Connect et la revue bêta d'Apple.

## Conséquences

- Publier une version, c'est écrire deux fichiers, pousser un tag, puis lancer et approuver un workflow. Le parcours complet est dans `docs/RELEASE.md`, « A version's journey ».
- Corriger une note publiée se fait dans le dépôt : relancer le dernier job de la release réécrit la release GitHub, et, tant que la version n'est pas soumise, le workflow « Store listing » réécrit la fiche sans rien soumettre.
- L'app Garmin garde son propre parcours (`garmin-v*`, envoi du `.iq` à la main sur le store Connect IQ).
