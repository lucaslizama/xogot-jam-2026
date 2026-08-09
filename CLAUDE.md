# Working on this project

A pizza delivery game for Xogot Jam 2026. Portrait, touch only, targeting iOS,
authored in Xogot on an iPad and built with Godot 4.6 on desktop. See
`docs/design/pizza-delivery.md` for what the game is.

## Setting up a new machine

```
bash tools/setup-dev-env.sh
```

Installs Godot 4.6.1, its export templates, the Android SDK, a debug keystore
and a `phone` helper for wireless debugging. Idempotent, no root, nothing
outside the home directory. `docs/dev-setup.md` covers the parts that must be
done on the phone, and the traps around wireless debugging.

## Always use `godot-4.6`, never `godot`

The project targets 4.6. A bare `godot` is usually something newer and will
offer to convert the project, rewriting its recorded engine version and risking
the round trip with Xogot.

## Tests

Three headless suites, no display or art required. Run all three after any
change to the throw, the street or the round rules.

```
godot-4.6 --headless res://tests/test_throw.tscn    # flight, gesture, projection
godot-4.6 --headless res://tests/test_street.tscn   # streaming, landing, round rules
godot-4.6 --headless res://tests/test_game.tscn     # the real scene, fake touches
```

## Building for a phone

```
godot-4.6 --headless --path . --export-debug "Android" build/android/app.apk
phone
adb install -r build/android/app.apk
```

## Engine traps found the hard way

Every one of these cost real time. They are recorded so they are not
rediscovered.

**`--quit-after N` counts frames, not seconds**, and headless runs unthrottled,
so 720 frames can be well under a second of simulated time. Use a wall clock
`timeout` instead when you want the game to actually play for a while.

**A custom `extends SceneTree` main loop run with `--script` does not run nodes'
`_physics_process`.** Movement tests written that way silently pass while
measuring nothing. Write test harnesses as a real scene and run
`godot-4.6 --headless res://tests/whatever.tscn`.

**`Orientation` is a built-in global enum.** Declaring `enum Orientation` inside
a class and typing a property with it resolves to the global one and the class
fails to compile. `--import` does not surface this; only loading the script
does. Prefix such names, as `ScreenOrientation` does.

**`get_viewport_rect()` is a CanvasItem method.** A class extending plain `Node`
must use `get_viewport().get_visible_rect().size`.

**Input events at `_unhandled_input` are already in viewport space.** Use
`get_global_transform().affine_inverse()` to map into a child control, never
`get_global_transform_with_canvas()`, which folds the canvas transform in twice
and throws taps tens of thousands of pixels off.

**`Input.parse_input_event()` takes window space.** In headless the window is
0x0 and the viewport's final transform is a tiny scale, so a tap sent in
viewport coordinates arrives about 40x off. Multiply by
`get_viewport().get_final_transform()` first.

**GDScript lambdas capture locals by value.** Mutating a captured array works;
rebinding it (`captured = [...]`) never reaches the outer variable. Use
`.assign()` or `.append()` in signal callbacks.

**Typed arrays of custom resources serialise as**
`Array[ExtResource("<script id>")]([...])`. Do not hand-write `.tres` files
containing them; build the resources in a throwaway script with `ResourceSaver`
and delete the script afterwards.

**An Android export that fails with an empty error message** is almost always a
project setting the command line will not name. Open the editor's export dialog,
which prints the real reason.

**A running editor overwrites `project.godot` too.** A hand-added key is written
back out from the editor's own in-memory settings and silently disappears, with
no error and nothing in the diff. `gui/theme/custom` was lost this way twice in a
row. Set project settings in the GUI with the editor open, or close it first; for
anything a scene can carry itself, prefer putting it in the scene.

**A running Godot editor overwrites `editor_settings-4.6.tres` when it saves**,
including blanking the Android Java SDK path. Close it before editing that file,
and prefer setting such values in the GUI.

## House style

Anything a designer might reasonably want to change belongs in the editor, not
in code: `@export` rather than a constant, values authored in the `.tscn`, tuning
grouped into `Resource` files. Code owns behaviour, the editor owns values. The
existing `PizzaPhysics`, `LevelConfig` and `StreetProjection` resources are the
pattern to follow.

Text styling lives in `data/ui_theme.tres`, not in per-node `theme_override_*`. A
label or button picks its look with `theme_type_variation` (`PageTitle`,
`CreditName`, `Caption`, `GoButton`, …), so a size or colour is changed once for
every screen at once. Reach for an override only for a genuine one-off, and if a
second node wants it, make it a variation instead.

The theme is assigned on each page scene's root node rather than through the
project-wide `gui/theme/custom` setting. See the trap below: that setting does
not survive an editor save, and because the scenes carry no font sizes of their
own, losing it drops every screen to the 16 px default.

Prefer a scene with real nodes over generating nodes in `_ready`, so the scene is
worth opening. Where the count is variable, author the maximum in the scene and
have code hide the surplus, then clamp to what the scene can actually draw and
warn if a value exceeds it.

## Commits

No Claude, Anthropic or AI attribution anywhere: no `Co-Authored-By` trailer, no
"generated with" line, nothing in the message or a PR body. Write ordinary, clear
commit messages that explain why.
