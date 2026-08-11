# Handoff — Xogot Jam 2026

A mobile game built with [Godot](https://godotengine.org/) (via [Xogot](https://xogot.com/)) for **Xogot Jam 2026**.

> **Theme:** Handoff

Play it: **[lucaslizama.itch.io/pizza-flicker](https://lucaslizama.itch.io/pizza-flicker)**

## About

You are a pizza delivery rider on an endless street. You sit at the bottom of the screen and
never move sideways; the houses scroll past you in parallax. On the back of your bike is a
stack of pizza boxes, and you throw them at the houses that are waiting for one.

Hit a house that is waiting, or land the box in the ring at its feet, and the delivery
counts. Miss the house entirely and you take a strike. The strikes are dots along the top of
the screen, and when the last one is crossed the round is over. Otherwise you keep going
until the stack is empty.

How well you threw decides what you are paid. The middle of the ring is a bullseye, the rest
of it is merely nice, and the wall pays least because it is the easiest thing to hit. Put one
straight through the lit window and it pays best of all: it asks for a throw long enough to
reach the wall and tight enough to find a target a fifth of its width. Deliveries in a row
build a streak that multiplies the tip, and a miss ends it.

The throw carries the theme: once the box leaves your hands it is committed, and all you can
do is watch.

> ⚠️ **Work in progress.** It plays end to end and it has a voice, but everything you *see*
> is still a placeholder rectangle.

## Current state

Playable, tuned on a real phone, and published to itch on every version tag.

- **The throw** — a released flick becomes power, aim and spin, and the pizza arcs through a
  fake-3D street. Full power asks for a committed drag; the arc holds its shape for the whole
  flight; a wound-up pizza spins in your hand and runs down when you stop circling.
- **Endless street** — houses stream in ahead and are dropped behind, generated from a seed so
  a level is reproducible. Some houses are scenery, so picking a target matters.
- **The round** — a stack of pizzas, a budget of strikes, and a level that ends when the stack
  does. Three streets, each tighter and faster than the last.
- **Day cycle** — the first street is delivered at night, the second at sunrise, the third in
  daylight, crossing between them rather than cutting.
- **Two shaders** — a generated night sky with stars, and a road that inverts the projection
  per pixel so its grain and markings scroll at the rate their depth deserves.
- **Sound** — public domain foley for throwing, landing, missing and losing a strike.
- **Tuning panel** — an on-device "tune" button with sliders for the throw and a readout of
  what your last drag actually measured. Also a button that clears a street outright. It
  appears only in a build we are running ourselves, never in the one on itch.

Still to build: art, and whatever sits between one street and the next.

## Project structure

```
xogot-jam-2026/
├── project.godot           # Engine + iOS/display/input configuration
├── icon.svg                # App/placeholder icon
├── scenes/                 # Scene files (.tscn): layout, values, arrangement
├── shaders/                # Night sky, road surface
├── data/                   # Tuning, levels and times of day, editable in the editor
├── scripts/pizza/          # Throw, street, round rules and their views
├── tests/                  # Headless test scenes
├── tools/                  # Machine setup, releasing, and the project.godot guard
├── docs/design/            # What is being built and why
├── docs/                   # Art brief, machine setup
├── sprites/                # Textures and art
├── fonts/                  # Fredoka and Nunito, with credits and their OFL licences
└── sounds/                 # Sound effects, with credits
```

Scenes own the *values* (positions, colours, sizes, wording) so they stay editable in
Xogot/Godot; scripts own the *behaviour*. Tunables live in exported resources rather than
hardcoded, so they can be retuned without opening a script.

Every visible piece has an empty texture slot waiting for it. Dropping a picture in makes the
placeholder disappear; see `docs/art-brief.md` for the list and the measured sizes.

## Controls

| Input                        | Action                                  |
| ---------------------------- | --------------------------------------- |
| Take hold of the pizza       | Pick it up; it follows your finger       |
| Drag and release             | Throw; flick speed sets how far it goes  |
| Lean the flick left or right | Aim                                     |
| Circle it before releasing   | Wind up spin, curving the flight         |
| Release slowly               | Fumble; it drops back into your hand     |

## Requirements

- **Godot / Xogot 4.6** (Mobile renderer)
- For iOS export: macOS + Xcode, an Apple Developer account, and the iOS export template

Everything else a machine needs is installed by one script:

```
bash tools/setup-dev-env.sh
```

See `docs/dev-setup.md`, which also covers the parts that must be done on a phone.

It also points git at `tools/git-hooks`, which stops a commit that quietly reverts
`project.godot`. A Godot editor left open from before someone else's change writes
its own older settings back over that file, and it has cost us the theme, the
version and the main scene. Restart your editor after pulling. To check by hand:

```
bash tools/check-project-settings.sh
```

## Running

Open the project in Xogot (or Godot 4.6) and press **Play**.

To run the tests:

```
godot-4.6 --headless res://tests/test_throw.tscn    # flight, gesture, projection
godot-4.6 --headless res://tests/test_street.tscn   # streaming, landing, round rules
godot-4.6 --headless res://tests/test_game.tscn     # the scene, driven by fake touches
```

## Releasing

```
bash tools/release.sh 0.11.0
```

Bumps the version, commits, tags and pushes. Pushing the tag runs the tests and, if they all
pass, publishes the browser build to itch.io named after the tag. An ordinary push publishes
nothing.

## Roadmap

- [x] Scrolling street with parallax and generated houses
- [x] Drop points, landing detection and misses
- [x] Strike dots and the pizza stack on the bike
- [x] Level pacing: fewer strikes, tighter houses, faster street
- [x] Tune the throw against a real thumb
- [x] Sound
- [x] Day cycle across the three streets
- [ ] Art to replace the placeholders
- [ ] Whatever happens between one street and the next
- [ ] iOS export preset (bundle ID, icons, launch screen)

## Team

Built for Xogot Jam 2026.

## License

TBD. Sound is CC0; see `sounds/CREDITS.md`. Fonts are Fredoka and Nunito, both under
the SIL Open Font License; see `fonts/CREDITS.md`.
