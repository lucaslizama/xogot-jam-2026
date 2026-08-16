# Pizza Flicker

A mobile game built with [Godot](https://godotengine.org/) (via [Xogot](https://xogot.com/)) for
**Xogot Jam 2026**.

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

The shop also sends tickets. One asks for two or three pizzas of a named flavour, sometimes
two flavours in the same ticket, and it comes with a clock. Filling it pays a bonus on top of
the throws; letting it run out costs nothing but the bonus, so the ticket can be ignored by
anyone who would rather just throw.

The theme runs through the game twice. Once the box leaves your hands it is committed, and all
you can do is watch. And a street cleared ends with the next rider pulling alongside, taking
the bag from you, and riding on with it.

## Current state

Playable end to end, tuned on a real phone, and published to itch on every version tag.

Some of the art has landed. The rider is drawn, and so is every pizza: three flavours, each
with a sixteen frame loop of the box shifting in your hand and a still picture of it in the
air. The houses, the skyline behind them and the street furniture are still coloured shapes
standing in the exact space their pictures will occupy.

- **The throw.** A released flick becomes power, aim and spin, and the pizza arcs through a
  fake-3D street. Full power asks for a committed drag; the arc holds its shape for the whole
  flight; a wound-up pizza spins in your hand and runs down when you stop circling.
- **Endless street.** Houses stream in ahead and are dropped behind, generated from a seed so
  a level is reproducible. Some houses are scenery, so picking a target matters.
- **The round.** A stack of pizzas, a budget of strikes, and a level that ends when the stack
  does. Three streets, each tighter and faster than the last.
- **Flavours.** Three of them, cycled by tapping the road well clear of the pizza, so a swap
  can never be mistaken for a throw. A flavour changes nothing about the flight: houses take
  whatever arrives, and only a ticket cares which.
- **Orders.** A ticket slides in under the strike dots naming what it wants, marks lines off
  as they arrive, and runs a clock down. The first two streets pay a flat bonus for filling
  one. The third pays less for it but hands back a strike, which is worth more.
- **The handoff.** Clear a street and the next rider pulls up alongside, mirrored and
  recoloured so she reads as somebody else, and the bag goes across before the result card
  says what the street paid. A street lost has nothing to hand on and goes straight to the
  card.
- **Day cycle.** The first street is delivered at night, the second at sunrise, the third in
  daylight, crossing between them rather than cutting.
- **Three shaders.** A generated night sky with stars; a road that inverts the projection per
  pixel so its grain and markings scroll at the rate their depth deserves; and a hue rotation
  that turns the rider into a different rider without touching her skin.
- **Menu and pages.** A front menu over a moving street, a how-to-play page that teaches the
  flick and the tap, a settings page, and a credits page.
- **Sound.** Public domain foley for throwing, landing, missing and losing a strike, on a
  Music bus and an SFX bus. The settings page slides each one, and remembers it.
- **Music.** A bed under the menu and under every street, playing faster the harder the street
  gets. Each level can take a track of its own when there is one worth having.
- **Tuning panel.** An on-device "tune" button with sliders for the throw and a readout of what
  the last drag actually measured. Also a button that clears a street outright. It appears only
  in a build run locally, never in the one on itch.

Still to build: art for the houses and the skyline, and somewhere on the order ticket for the
flavour icons, which are drawn and assigned but not yet shown.

## Project structure

```
xogot-jam-2026/
├── project.godot           # Engine + display/input configuration
├── icon.svg                # App icon
├── scenes/                 # Scene files (.tscn): layout, values, arrangement
│   └── ui/                 #   Menu, pages, cards, HUD
├── shaders/                # Night sky, road surface, rider recolour
├── data/                   # Tuning, editable in the editor
│   ├── levels/             #   The three streets
│   ├── daylight/           #   Night, sunrise, day
│   ├── backdrop/           #   The parallax layers behind the houses
│   └── flavours/           #   What the shop sells
├── default_bus_layout.tres # The Music and SFX buses the settings page slides
├── scripts/pizza/          # The glue: PizzaGame, GameAudio, GameMusic, GameVolume
│   ├── rules/              #   Resources: tuning and data, no behaviour
│   ├── sim/                #   The rules themselves, tested with no screen
│   ├── view/               #   Draws the street and what is on it
│   └── ui/                 #   Screens, cards, HUD and buttons
├── tests/                  # Headless test scenes
├── tools/                  # Machine setup, releasing, and the project.godot guard
├── docs/design/            # What is being built and why
├── docs/ideas/             # Concepts that were considered and set aside
├── docs/                   # Art brief, machine setup
├── sprites/                # Textures and art
├── press/                  # itch cover images
├── fonts/                  # Fredoka and Nunito, with credits and their OFL licences
└── sounds/                 # Sound effects and music, with credits
    └── music/              #   What ships; sounds/audition/ is local-only and ignored
```

Scenes own the *values* (positions, colours, sizes, wording) so they stay editable in
Xogot/Godot; scripts own the *behaviour*. Tunables live in exported resources rather than
hardcoded, so they can be retuned without opening a script. Text sizes and colours come from
one theme in `data/ui_theme.tres`, picked per label by variation name, so a heading changes
everywhere at once.

Every piece still waiting for art has an empty texture slot ready for it. Dropping a picture in
makes the coloured shape disappear; `docs/art-brief.md` lists what is left and the measured
sizes.

## Controls

| Input                        | Action                                  |
| ---------------------------- | --------------------------------------- |
| Take hold of the pizza       | Pick it up; it follows your finger      |
| Drag and release             | Throw; flick speed sets how far it goes |
| Lean the flick left or right | Aim                                     |
| Circle it before releasing   | Wind up spin, curving the flight        |
| Release slowly               | Fumble; it drops back into your hand    |
| Tap the road, clear of the pizza | Change flavour                      |

## Requirements

**Godot / Xogot 4.6**, Mobile renderer. The game ships as a browser build played on a phone, so
the engine is all it takes to work on it. Putting a test build on an Android handset also wants
the SDK, which the script below installs along with everything else:

```
bash tools/setup-dev-env.sh
```

See `docs/dev-setup.md`, which also covers the parts that must be done on a phone.

It also points git at `tools/git-hooks`, which stops a commit that quietly reverts
`project.godot`. A Godot editor left open from before someone else's change writes its own
older settings back over that file, and it has cost this project the theme, the version and
the main scene. Restart your editor after pulling. To check by hand:

```
bash tools/check-project-settings.sh
```

## Running

Open the project in Xogot (or Godot 4.6) and press **Play**. That lands on the front menu; the
street starts from there.

To run the tests:

```
godot-4.6 --headless res://tests/test_throw.tscn    # flight, gesture, projection
godot-4.6 --headless res://tests/test_street.tscn   # streaming, landing, round rules
godot-4.6 --headless res://tests/test_game.tscn     # the scene, driven by fake touches
```

## Releasing

```
bash tools/release.sh 0.27.0
```

Bumps the version, commits, tags and pushes. Pushing the tag runs the tests and, if they all
pass, publishes the browser build to itch.io named after the tag. An ordinary push publishes
nothing, and neither does a tag left sitting on one machine: it is the tag arriving at the
remote that starts the build.

## Roadmap

- [x] Scrolling street with parallax and generated houses
- [x] Drop points, landing detection and misses
- [x] Strike dots and the pizza stack on the bike
- [x] Level pacing: fewer strikes, tighter houses, faster street
- [x] Tune the throw against a real thumb
- [x] Sound
- [x] Day cycle across the three streets
- [x] Front menu, how-to-play, settings and credits
- [x] The handoff between one street and the next
- [x] Flavours, and orders that ask for them
- [x] Art for the rider and the pizzas
- [x] Flavour icons shown on the order ticket
- [ ] Art for the houses and the skyline

## Team

Made for the Xogot Game Jam 2026.

- Design and programming: Lucas Lizama, Belén Fuentes
- Design and art: Ian Genskowsky, Belén Fuentes

## License

TBD. Sound effects are CC0 and the music is CC BY, credited in the game as that licence
requires; see `sounds/CREDITS.md`. Fonts are Fredoka and Nunito, both under the SIL Open
Font License; see `fonts/CREDITS.md`.
