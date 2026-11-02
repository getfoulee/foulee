# App preview — iPhone Duo

The App Store previews for the iPhone Duo, in French and in English: the same
thirty seconds, beats and captions as the published 6.9" preview, with the app
laid out on the Duo's inner screen. It is a [HyperFrames](https://hyperframes.heygen.com) project:
HTML and GSAP, rendered frame by frame to MP4.

## Why 886 × 1920 with a device inside

App Store Connect accepts only **886 × 1920** (portrait) or 1920 × 886 for an
iPhone Duo preview, a shape that matches neither of the Duo's screens
(1398 × 2034 outside, 2007 × 2853 inside). Footage of the inner screen
stretched to that size comes out distorted. So the film is motion design, like
the 6.9" one: the frame is 886 × 1920, and the Duo drawn inside it keeps the
inner screen's own proportions.

The screen is 669 × 951 CSS pixels, one pixel per point of the inner screen, so
each scene is the app at its own sizes, following ADR 0015:

- the content sits in the **640 pt reading column** (`ScreenColumn`), 20 pt
  gutter, centred;
- a **sheet** is a card inset from the sides and the top over a dimmed parent
  (Série, Bilan and the outing's detail pushed inside it, Hydratation);
- the **outing in progress** stays stacked (portrait is taller than wide) and
  its ring grows to 257 pt (232 pt × 1.106).

## Scenes

| Time | Caption | Scene file |
|------|---------|------------|
| 0 – 2.6 s | Foulée — Bouge un peu, chaque jour. | `intro.html` |
| 2 – 5.4 s | Bienvenue — Prêt en trois étapes. | `onboarding.html` |
| 5.4 – 8.3 s | Accueil — Chaque anneau, sa couleur. | `today.html` |
| 8.3 – 10 s | Séries — Ta série, jour après jour. | `streak.html` |
| 10 – 12.3 s | Sortie — Lance ta sortie, on compte tout. | `outing.html` |
| 12.3 – 14.7 s | Objectif atteint — Anneau fermé, bravo ! | `goal.html` |
| 14.7 – 17.4 s | Bilan — Ta semaine, du lundi au dimanche. | `recap.html` |
| 17.4 – 20.7 s | Sortie multi-sport — Marche, course : chaque portion. | `detail.html` |
| 20.7 – 23.7 s | Hydratation — Ton eau, verre après verre. | `water.html` |
| 23.7 – 25.8 s | Réglages — Foulée, à ta façon. | `settings.html` |
| 25.8 – 28.3 s | Apple Watch — Aussi au poignet. | `watch.html` |
| 28.3 – 30 s | Foulée — iPhone · iPhone Duo · Apple Watch | `outro.html` |

The English captions follow the French ones (« Ready in three steps. »,
« Each ring, its own color. »…); the app's words come from its string catalog
(`Foulee/Resources/Localizable.xcstrings`) and its numbers from the US formats
the app uses (« 4,218 », « 2 hr, 52 min », « 12:10 PM »).

The outing's map is a town block drawn like the app's route map: the walk goes
up the street and along the avenue to the park, the run goes round the park's
loop, the walk comes home by the quay. Every stretch follows a street or a
path.

## Two languages

French is written in the HTML. An element that reads differently in English
carries its English markup in `data-en`; `assets/i18n.js` swaps it in, and
formats numbers, decimals and durations, when the root's `locale` variable is
`en`. The default is `fr`. In Studio the variable is in the Variables panel; on
the command line:

```bash
npx hyperframes@0.9.5 render --variables '{"locale":"en"}' -o renders/en.mp4
```

A new text in a scene gets its `data-en` in the same change.

## Structure

`index.html` holds the ground, the Duo and the scene hosts; the captions are
one scene of their own (`captions.html`). The screen scenes overlap by about
half a second so each transition (a sheet rising, a page pushed, a cover
leaving) plays over the scene before it. They paint in DOM order, each in its
own stacking context. Shared styles are in `assets/app.css`, shared icons in
the SVG sprite at the top of `index.html`.

## Working on it

Node 22 and FFmpeg. From this folder:

```bash
npx hyperframes@0.9.5 preview --background   # Studio, to watch and edit
npm run check                               # lint, layout and timing checks
npx hyperframes@0.9.5 snapshot --at 6,12,18  # frames to look at
./master.sh                                 # both languages, App Store masters
```

`master.sh` writes `renders/foulee-iphone-duo-preview-fr.mp4` and
`renders/foulee-iphone-duo-preview-en.mp4` (`./master.sh en` for one
language): 886 × 1920, 30 fps,
H.264 High Profile Level 4.0 at about 11 Mbps and a silent stereo AAC track
(the 6.9" preview's track is silent too), 30 s. The renders are not versioned,
like `appstore-screenshots/`.

`check` still reports warnings that come with the brief: the UI text is the
app's size, under the film's reading floor; the transitions hold some lines
under a second; the film is silent. The screens are redrawn from the
App Store boards and the code, not captured: when a screen changes in the app,
its scene changes here.
