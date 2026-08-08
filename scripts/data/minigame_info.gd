class_name MinigameInfo
extends Resource

## Everything the run needs to know about one minigame without loading it.
##
## The host reads this to size the viewport and run the clock; the handoff
## transition reads it to build the get-ready card. Nothing about an individual
## minigame is hardcoded in either, so adding a game means adding a .tres.

## Where this game sits in an ingredient's journey.
enum Phase { HARVEST, TRANSPORT, COOK }

## How the minigame scene is authored. LANDSCAPE scenes are rotated into the
## portrait window by MinigameHost; the scene itself never learns about it.
##
## Named ScreenOrientation rather than Orientation because Godot already has a
## global Orientation enum, which silently shadows a nested one of that name.
enum ScreenOrientation { PORTRAIT, LANDSCAPE }

## Drives the hint shown on the get-ready card.
enum ControlScheme { TAP, DRAG, SWIPE, TILT }

## Name for menus and debugging. Not shown during play.
@export var display_name: String = "Untitled minigame"

@export_group("Get-ready card")
## The big word on the card, e.g. "HARVEST!" or "DRIVE!".
@export var prompt_verb: String = "GO!"
## Small line under the verb telling the player how to play, e.g. "tilt".
@export var control_hint: String = "tap"
@export var control_scheme: ControlScheme = ControlScheme.TAP

@export_group("Run placement")
@export var phase: Phase = Phase.HARVEST
@export var orientation: ScreenOrientation = ScreenOrientation.PORTRAIT

@export_group("Clock")
## Seconds allowed on the first dish, before the run's speed-up is applied.
@export_range(1.0, 30.0, 0.5) var base_duration: float = 5.0
## When true, surviving the clock is a win — dodge-the-cars games. When false,
## the clock running out is a loss — do-the-thing-in-time games.
@export var win_on_timeout: bool = false

@export_group("Scene")
## The scene to instance. Its root must extend Minigame.
@export var scene: PackedScene


func is_landscape() -> bool:
	return orientation == ScreenOrientation.LANDSCAPE
