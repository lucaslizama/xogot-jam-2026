class_name StubMinigame
extends Minigame

## Throwaway placeholder standing in for a real minigame, so the chain can be
## proved end to end before any of them exist. Delete once every phase has a
## real game.
##
## Both behaviours are here rather than in two scripts so the three stub scenes
## differ only by authored values — which is also how the real minigames should
## feel to add.

enum Mode {
	## Tap the screen [member taps_to_win] times before the clock runs out.
	TAP_TARGET,
	## Keep the marker on screen with tilt until the clock runs out.
	SURVIVE_TILT,
}

@export var mode: Mode = Mode.TAP_TARGET
## TAP_TARGET only. How many taps clear it.
@export_range(1, 20) var taps_to_win: int = 3
## SURVIVE_TILT only. Marker travel in pixels per second at full deflection.
@export_range(50.0, 4000.0, 10.0) var tilt_speed: float = 1400.0

@onready var _verb: Label = %Verb
@onready var _progress: Label = %Progress
@onready var _marker: ColorRect = %Marker

var _taps: int = 0


func begin(ctx: MinigameContext) -> void:
	_verb.text = ctx.ingredient_name if not ctx.ingredient_name.is_empty() else ctx.dish_name
	_taps = 0
	_marker.visible = mode == Mode.SURVIVE_TILT
	if mode == Mode.SURVIVE_TILT:
		_marker.position = (_play_area() - _marker.size) * 0.5
	_refresh_progress()


func _process(delta: float) -> void:
	if mode != Mode.SURVIVE_TILT or is_resolved():
		return

	_marker.position += Tilt.get_tilt() * tilt_speed * delta
	var limit := _play_area() - _marker.size
	if _marker.position.x < 0.0 or _marker.position.y < 0.0 \
			or _marker.position.x > limit.x or _marker.position.y > limit.y:
		_marker.position = _marker.position.clamp(Vector2.ZERO, limit)
		fail()
		return
	_refresh_progress()


func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.TAP_TARGET or is_resolved():
		return
	if event is InputEventScreenTouch and event.pressed:
		_taps += 1
		_refresh_progress()
		if _taps >= taps_to_win:
			succeed()


func _refresh_progress() -> void:
	match mode:
		Mode.TAP_TARGET:
			_progress.text = "%d / %d taps" % [_taps, taps_to_win]
		Mode.SURVIVE_TILT:
			var source := "keyboard" if Tilt.is_using_fallback() else "gyro"
			_progress.text = "hold it steady (%s)" % source


## The viewport this minigame was given — already portrait or landscape, so a
## minigame never has to ask which way up it is. Note get_viewport_rect() is a
## CanvasItem method and Minigame is a plain Node, hence the longer route.
func _play_area() -> Vector2:
	return get_viewport().get_visible_rect().size
