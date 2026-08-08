# Handoff — Xogot Jam 2026

A mobile game built with [Godot](https://godotengine.org/) (via [Xogot](https://xogot.com/)) for **Xogot Jam 2026**.

> **Theme:** Handoff

## About

You are a pizza delivery rider on an endless street. You sit at the bottom of the screen and
never move sideways; the houses scroll past you in parallax. On the back of your bike is a
stack of pizza boxes, and you throw them at the houses that are waiting for one.

Land a box in a drop point and the delivery counts. Miss and it hits the wall, which costs
you a strike. The strikes are dots along the top of the screen, and when the last one is
crossed the round is over. Otherwise you keep going until the stack is empty.

The throw carries the theme: once the box leaves your hands it is committed, and all you can
do is watch.

> ⚠️ **Work in progress.** It is playable end to end, but everything you see is a grey box.
> No art, no sound.

## Current state

Playable. Drag and release to throw, land boxes in the blue drop circles, miss and lose a dot.

- **Throw model** — a released flick becomes power, aim and spin, and the pizza arcs through
  a fake-3D street. Curve comes from how much the gesture turned, so a deliberate pre-spin and
  the accidental hook of a curved flick feed the same number.
- **Endless street** — houses stream in ahead and are dropped behind, generated from a seed so
  a level is reproducible. Some houses are scenery, so picking a target matters.
- **The round** — a stack of pizzas, a budget of strikes, and a level that ends when the stack
  does. Three streets are set up, each tighter than the last.
- **Aiming help** — while you drag, a dotted arc and a landing ring show where the throw would
  go, and a shadow tracks the pizza along the road while it flies. Both can be turned off.
- **Placeholder visuals** — sky, road, parallax skyline, houses, rider, the stack on the bike
  and the strike dots, all drawn as flat shapes.

Still to build: art, sound, and whatever sits between one street and the next.

## Project structure

```
xogot-jam-2026/
├── project.godot           # Engine + iOS/display/input configuration
├── icon.svg                # App/placeholder icon
├── scenes/                 # Scene files (.tscn): layout, values, arrangement
├── data/                   # Tuning and level resources, editable in the editor
├── scripts/pizza/          # Throw, street, round rules and their views
├── tests/                  # Headless test scenes
├── docs/design/            # What is being built and why
├── docs/ideas/             # Shelved concepts kept for later
├── sprites/                # Textures and art
└── sounds/                 # Music and SFX
```

Scenes own the *values* (positions, colours, sizes, wording) so they stay editable in
Xogot/Godot; scripts own the *behaviour*. Tunables live in exported resources rather than
hardcoded, so they can be retuned without opening a script.

## Controls

| Input                        | Action                                 |
| ---------------------------- | -------------------------------------- |
| Drag and release             | Throw a pizza; flick speed sets power   |
| Lean the flick left or right | Aim                                    |
| Circle before releasing      | Wind up spin, curving the flight        |
| Release slowly               | Fumble; the pizza stays on the bike      |

## Requirements

- **Godot / Xogot 4.6** (Mobile renderer)
- For iOS export: macOS + Xcode, an Apple Developer account, and the iOS export template

## Running

Open the project in Xogot (or Godot 4.6) and press **Play**.

To run the tests:

```
godot --headless res://tests/test_throw.tscn    # flight, gesture, projection
godot --headless res://tests/test_street.tscn   # streaming, landing, round rules
godot --headless res://tests/test_game.tscn     # the scene, driven by fake touches
```

## Roadmap

- [x] Scrolling street with parallax and generated houses
- [x] Drop points, landing detection and misses
- [x] Strike dots and the pizza stack on the bike
- [x] Level pacing: fewer strikes, tighter houses, faster street
- [ ] Tune the throw against a real thumb
- [ ] Art and audio to replace placeholders
- [ ] iOS export preset (bundle ID, icons, launch screen)

## Team

Built for Xogot Jam 2026.

## License

TBD.
