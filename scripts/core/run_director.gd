class_name RunDirector
extends Node

## Drives one order from the first harvest to the last plate.
##
## This node and everything under it is persistent — minigames are instanced
## and freed inside MinigameHost, never swapped in with change_scene_to_file().
## That is what lets hearts survive between minigames without serialising
## anything: nothing is ever torn down.

@export_group("Content")
## The order to play. Swap this to test a different run without touching code.
@export var order: Order

@export_group("Flow")
## Start the order as soon as the scene is ready. Turn off when a main menu is
## driving things instead.
@export var start_automatically: bool = true
## Beat held after a minigame resolves, before the next handoff begins.
@export_range(0.0, 3.0, 0.05) var post_result_pause: float = 0.5
## Log each step as it starts. Invaluable while the chain is being built.
@export var log_steps: bool = true

@onready var _state: RunState = $RunState
@onready var _host: MinigameHost = $GameLayer/MinigameHost
@onready var _hud: Hud = $HudLayer/Hud
@onready var _transition: HandoffTransition = $TransitionLayer/HandoffTransition
@onready var _end_card: RunEndCard = $TransitionLayer/RunEndCard

var _steps: Array[RunStep] = []
var _index: int = 0
var _running: bool = false


func _ready() -> void:
	_state.bind_heart_capacity(_hud.slot_count())
	_state.hearts_changed.connect(_hud.show_hearts)
	_state.run_ended.connect(_on_run_ended)
	_host.minigame_finished.connect(_on_minigame_finished)
	_end_card.replay_requested.connect(start_run)
	_end_card.hide()

	if start_automatically:
		# Deferred: adding the first minigame while this node is still setting
		# up its own children trips "parent node is busy".
		start_run.call_deferred()


func start_run() -> void:
	_steps = _build_steps()
	if _steps.is_empty():
		push_error("RunDirector: order '%s' produced no minigames. Check that its dishes have ingredients with a harvest game, or a cook game."
			% [order.display_name if order != null else "<none>"])
		return

	_index = 0
	_running = true
	_end_card.hide()
	_state.reset()
	if log_steps:
		print("RunDirector: %d steps queued for '%s'" % [_steps.size(), order.display_name])
	_play_next()


## Flatten the order into the exact sequence of minigames it will play.
## Harvest and transport belong to an ingredient; cooking belongs to the dish.
func _build_steps() -> Array[RunStep]:
	var steps: Array[RunStep] = []
	if order == null:
		push_error("RunDirector: no order assigned.")
		return steps

	for dish_index in order.dishes.size():
		var dish := order.dishes[dish_index]
		if dish == null:
			push_warning("RunDirector: order '%s' has an empty dish slot at %d; skipping." % [order.display_name, dish_index])
			continue

		var first_of_dish := steps.size()
		for ingredient in dish.ingredients:
			if ingredient == null:
				push_warning("RunDirector: dish '%s' has an empty ingredient slot; skipping." % dish.display_name)
				continue
			for info in ingredient.journey():
				steps.append(RunStep.new(info, dish, ingredient, dish_index))

		if dish.cook_game != null:
			steps.append(RunStep.new(dish.cook_game, dish, null, dish_index))
		else:
			push_warning("RunDirector: dish '%s' has no cook game; it will end on its last transport." % dish.display_name)

		if steps.size() > first_of_dish:
			steps[steps.size() - 1].is_final_step_of_dish = true

	return steps


func _play_next() -> void:
	if not _running:
		return
	if _index >= _steps.size():
		_state.note_order_served()
		return

	var step := _steps[_index]
	_hud.set_dish_text(step.dish.display_name)
	if log_steps:
		print("  [%d/%d] %s" % [_index + 1, _steps.size(), step.describe()])

	await _transition.play(step)
	# The run can end while the transition is playing if something restarts it.
	if not _running or _index >= _steps.size():
		return

	_host.play(step.info, _context_for(step))


func _context_for(step: RunStep) -> MinigameContext:
	var ctx := MinigameContext.new()
	ctx.duration = _state.duration_for(step.info.base_duration, step.dish_index)
	ctx.difficulty = _state.difficulty_for(step.dish_index)
	ctx.ingredient_name = step.ingredient.display_name if step.ingredient != null else ""
	ctx.dish_name = step.dish.display_name
	ctx.is_landscape = step.info.is_landscape()
	return ctx


func _on_minigame_finished(success: bool) -> void:
	if not _running:
		return
	var step := _steps[_index]
	_host.stop()

	if not success:
		_state.lose_heart()
		if _state.is_over():
			return

	if step.is_final_step_of_dish:
		_state.note_dish_served(step.dish_index)

	_index += 1
	if post_result_pause > 0.0:
		await get_tree().create_timer(post_result_pause).timeout
	_play_next()


func _on_run_ended(victory: bool, dishes_served: int) -> void:
	_running = false
	_host.stop()
	_end_card.show_result(victory, dishes_served)
