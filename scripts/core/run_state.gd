class_name RunState
extends Node

## Hearts, progress and difficulty for one run. Lives on the persistent Main
## scene, so nothing has to be serialised to survive a minigame ending —
## minigames are instanced and freed underneath it, this node never unloads.

signal hearts_changed(hearts: int)
signal dish_completed(dish_index: int)
## victory is true when the whole order was served, false on a game over.
signal run_ended(victory: bool, dishes_served: int)

@export_group("Lives")
## Hearts the player starts with. The HUD authors its own heart slots, so this
## is clamped to however many the HUD actually has — see [method bind_heart_capacity].
@export_range(1, 8) var starting_hearts: int = 4

@export_group("Difficulty ramp")
## Each completed dish multiplies every minigame's time by this. Below 1.0
## means the run gets faster.
@export_range(0.5, 1.0, 0.01) var time_scale_per_dish: float = 0.9
## Time never shrinks past this fraction of a minigame's base duration, however
## long the order runs.
@export_range(0.1, 1.0, 0.05) var min_time_scale: float = 0.5
## Difficulty handed to minigames on the first dish, growing by this much each
## dish. Minigames use it for spawn rates and speeds.
@export_range(0.0, 1.0, 0.05) var difficulty_step_per_dish: float = 0.25

var hearts: int = 0
var dishes_served: int = 0

var _max_hearts: int = 8
var _ended: bool = false


## Tell the state how many heart slots exist in the HUD scene. Anything the
## editor allows above that cannot be drawn, so it is clamped and reported
## rather than silently lost.
func bind_heart_capacity(slots: int) -> void:
	_max_hearts = maxi(1, slots)
	if starting_hearts > _max_hearts:
		push_warning("RunState: starting_hearts is %d but the HUD only has %d heart slots; clamping. Add slots in hud.tscn to raise the ceiling."
			% [starting_hearts, _max_hearts])


func reset() -> void:
	_ended = false
	dishes_served = 0
	hearts = clampi(starting_hearts, 1, _max_hearts)
	hearts_changed.emit(hearts)


## Spend a heart. Ends the run when the last one goes.
func lose_heart() -> void:
	if _ended:
		return
	hearts = maxi(0, hearts - 1)
	hearts_changed.emit(hearts)
	if hearts == 0:
		_end(false)


func note_dish_served(dish_index: int) -> void:
	dishes_served += 1
	dish_completed.emit(dish_index)


## Call when every step of the order is done and the player still has hearts.
func note_order_served() -> void:
	_end(true)


func is_over() -> bool:
	return _ended


## Seconds a minigame gets on the given dish, after the run's speed-up.
func duration_for(base_duration: float, dish_index: int) -> float:
	var scale: float = maxf(min_time_scale, pow(time_scale_per_dish, float(dish_index)))
	return base_duration * scale


## Difficulty handed to minigames on the given dish. 1.0 on the first.
func difficulty_for(dish_index: int) -> float:
	return 1.0 + difficulty_step_per_dish * float(dish_index)


func _end(victory: bool) -> void:
	if _ended:
		return
	_ended = true
	run_ended.emit(victory, dishes_served)
