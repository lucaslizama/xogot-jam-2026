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

> ⚠️ **Work in progress.** The flight model and gesture reading are built and tested; the
> street, the houses and the art are not.

## Current state

- **Throw model** — a released flick becomes power, aim and spin, and the pizza arcs through
  a fake-3D street. Curve comes from how much the gesture turned, so a deliberate pre-spin and
  the accidental hook of a curved flick feed the same number.
- **Projection** — sideways offset, height and distance become screen pixels, kept apart from
  the flight maths so the camera can be reframed on its own.
- **Tests** — the throw, the gesture and the projection are covered headlessly, with no art
  involved.

Still to build: the scrolling street, houses and drop points, landing and scoring, the strike
dots, the pizza stack on the bike, and everything visual.

## Project structure

```
xogot-jam-2026/
├── project.godot           # Engine + iOS/display/input configuration
├── icon.svg                # App/placeholder icon
├── scenes/                 # Scene files (.tscn): layout, values, arrangement
├── scripts/pizza/          # Throw physics, gesture reading, street projection
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

## Requirements

- **Godot / Xogot 4.6** (Mobile renderer)
- For iOS export: macOS + Xcode, an Apple Developer account, and the iOS export template

## Running

Open the project in Xogot (or Godot 4.6) and press **Play**.

To run the tests:

```
godot --headless res://tests/test_throw.tscn
```

## Roadmap

- [ ] Scrolling street with parallax and generated houses
- [ ] Drop points, landing detection and misses
- [ ] Strike dots and the pizza stack on the bike
- [ ] Level pacing: fewer strikes, tighter houses, faster street
- [ ] Art and audio to replace placeholders
- [ ] iOS export preset (bundle ID, icons, launch screen)

## Team

Built for Xogot Jam 2026.

## License

TBD.
