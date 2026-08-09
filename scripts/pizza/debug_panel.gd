class_name DebugPanel
extends Control

## Live tuning on the device, because the throw can only be judged with a thumb
## and no amount of measuring on a desktop substitutes for that.
##
## The rows are authored in debug_panel.tscn; this only binds them. Renaming or
## removing a row leaves it inert and says so, rather than taking the screen down.
##
## Nothing here writes to disk. Read the number off the screen, decide, and put
## it in the resource.

## Asked for by the button that clears a street outright, so the hours of the
## day can be looked at without playing three rounds to reach the third.
signal win_requested

## Which throw physics to drive. Set by the game at startup.
var physics: PizzaPhysics
## Used to report the finger speed each part of the street asks for.
var level: LevelConfig

@onready var _rows: Control = %Rows
@onready var _readout: Label = %Readout
@onready var _reach: Label = %Reach
@onready var _panel: Control = %Panel
@onready var _toggle: Button = %ToggleButton
@onready var _win: Button = %WinButton

## Slider unique name -> the property it drives, and how to print it.
const BINDINGS := {
	"%FlickSlider": {"property": "full_power_flick", "format": "%.0f px/s"},
	"%CurveSlider": {"property": "power_curve", "format": "%.2f"},
	"%ReachSlider": {"property": "max_forward_speed", "format": "%.0f"},
	"%FloorSlider": {"property": "min_power", "format": "%.2f"},
	"%SpinSlider": {"property": "spin_curve", "format": "%.0f"},
}


func _ready() -> void:
	_toggle.pressed.connect(func() -> void: _panel.visible = not _panel.visible)
	_win.pressed.connect(func() -> void: win_requested.emit())
	_panel.visible = false


## Called by the game once the physics resource is known.
func bind_to(p_physics: PizzaPhysics, p_level: LevelConfig) -> void:
	physics = p_physics
	level = p_level
	for unique in BINDINGS:
		var slider := get_node_or_null(unique) as HSlider
		if slider == null:
			push_warning("DebugPanel: no slider named %s in the scene; that row will do nothing." % unique)
			continue
		var property: String = BINDINGS[unique]["property"]
		slider.value = physics.get(property)
		slider.value_changed.connect(func(value: float) -> void: _apply(unique, value))
		_show_value(unique, slider.value)
	_refresh_reach()


## Report what the last throw actually did, which is the number that matters
## when the question is "why did that go so far".
func show_throw(flick: float, landed: float, curve: float) -> void:
	_readout.text = "last throw: %.0f px/s  ->  %.1f away, %.1f across" % [flick, landed, curve]


func _apply(unique: String, value: float) -> void:
	physics.set(BINDINGS[unique]["property"], value)
	_show_value(unique, value)
	_refresh_reach()


func _show_value(unique: String, value: float) -> void:
	var slider := get_node_or_null(unique) as HSlider
	if slider == null:
		return
	# The readout is the sibling named Value, so a row needs one unique name
	# rather than two, and survives being reordered.
	var label := slider.get_parent().get_node_or_null("Value") as Label
	if label != null:
		label.text = BINDINGS[unique]["format"] % value


## The whole point of the exercise: how hard you must drag to reach each part of
## the street, recomputed every time a slider moves.
func _refresh_reach() -> void:
	if physics == null or level == null:
		return
	_reach.text = "needs  %.0f  to reach the near houses,  %.0f  the far ones,  %.0f  to overshoot" % [
		_flick_for(level.distance_min),
		_flick_for(level.distance_max),
		_flick_for(level.distance_max + level.drop_radius),
	]


func _flick_for(target_distance: float) -> float:
	var low := 0.0
	var high := 40000.0
	for i in 30:
		var mid := (low + high) * 0.5
		if _lands(mid) < target_distance:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


func _lands(flick: float) -> float:
	var flight := PizzaFlight.new(physics, physics.launch_from(Vector2(0.0, -flick), 0.0))
	var guard := 0
	while not flight.step(1.0 / 120.0) and guard < 4000:
		guard += 1
	return flight.distance
