# Handoff — Xogot Jam 2026

A mobile game built with [Godot](https://godotengine.org/) (via [Xogot](https://xogot.com/)) for **Xogot Jam 2026**.

> **Theme:** Handoff

## About

This is an early-stage project targeting **iOS** (portrait, touch-first). It currently
contains a playable prototype scaffold — a main menu and a touch-controlled scene — that
we're building the jam entry on top of.

The *Handoff* theme is our design north star: passing something — control, momentum, a
baton, a responsibility — from one hand (or one moment, or one player) to the next.

> ⚠️ **Work in progress.** The core game loop is still being designed. What's in the repo
> today is the technical foundation, not the finished game.

## Current state

- **Main menu** (`scenes/main_menu.tscn`) — title screen with a **Start** button that hands
  off into the game scene.
- **Game scene** (`scenes/game.tscn`) — a touch-controlled avatar you steer by
  **touching and dragging**. Serves as the movement testbed for the jam mechanic.
- **iOS-ready setup** — mobile renderer, 1170×2532 portrait base resolution, expand-aspect
  stretch for varied device sizes, and mouse→touch emulation so it's testable on desktop.

## Project structure

```
xogot-jam-2026/
├── project.godot          # Engine + iOS/display/input configuration
├── icon.svg               # App/placeholder icon
├── scenes/                # Scene files (.tscn) — layout, values, arrangement
│   ├── main_menu.tscn      # Title screen
│   └── game.tscn           # Gameplay prototype
├── scripts/               # GDScript (.gd) — behaviour
│   ├── main_menu.gd        # Start button → loads the game scene
│   └── player.gd           # Touch-and-drag movement
├── sprites/               # Textures and art
└── sounds/                # Music and SFX
```

Scenes own the *values* (positions, colours, sizes, wording) so they stay editable in
Xogot/Godot; scripts own the *behaviour*. Tunables are `@export`ed rather than hardcoded.

## Controls

| Input            | Action                         |
| ---------------- | ------------------------------ |
| Touch + drag     | Move the avatar (on device)    |
| Click + drag     | Same, via mouse (in editor)    |
| **Start** button | Enter the game scene           |

## Requirements

- **Godot / Xogot 4.6** (Mobile renderer)
- For iOS export: macOS + Xcode, an Apple Developer account, and the iOS export template

## Running

1. Open the project in Xogot (or Godot 4.6).
2. Press **Play** — the project boots into the main menu.
3. Tap **Start**, then touch-and-drag to move.

## Roadmap

- [ ] Nail down the core *Handoff* mechanic and game loop
- [ ] Real art and audio to replace placeholders
- [ ] Win/lose states and scoring
- [ ] iOS export preset (bundle ID, icons, launch screen)

## Team

Built for Xogot Jam 2026.

## License

TBD.
