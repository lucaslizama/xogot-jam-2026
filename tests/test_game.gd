extends Node

# Drives the real game scene with synthetic touches. The rules are covered
# elsewhere; this is about the wiring actually running.
#   godot-4.6 --headless res://tests/test_game.tscn

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await _test_scene_runs_and_draws_houses()
	await _test_a_flick_spends_a_pizza()
	await _test_a_fumble_spends_nothing()
	await _test_one_pizza_in_the_air_at_a_time()
	await _test_the_waiting_pizza_is_there_to_grab()
	await _test_a_round_ends_on_its_own()

	print("\n=== %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL  ", f)
	if _failures.is_empty():
		print("  all good")
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _test_scene_runs_and_draws_houses() -> void:
	var game := await _spawn()
	for i in 30:
		await get_tree().process_frame

	var model_houses: int = game._street.houses().size()
	var drawn: int = game.get_node("Houses").get_child_count()
	_check("the street model has houses (got %d)" % model_houses, model_houses > 3)
	_check("every house in the model has a node (%d model, %d drawn)" % [model_houses, drawn],
		drawn == model_houses)
	_check("the level started with a full stack (got %d)" % game._state.pizzas_left,
		game._state.pizzas_left == 10)
	_check("and its strikes (got %d)" % game._state.strikes_left, game._state.strikes_left == 4)
	game.queue_free()
	await get_tree().process_frame


func _test_a_flick_spends_a_pizza() -> void:
	var game := await _spawn()
	var before: int = game._state.pizzas_left
	await _flick(game, 600.0)
	_check("a real flick takes a pizza off the stack (%d -> %d)" % [before, game._state.pizzas_left],
		game._state.pizzas_left == before - 1)
	_check("and puts one in the air", game._flight != null)
	game.queue_free()
	await get_tree().process_frame


func _test_a_fumble_spends_nothing() -> void:
	var game := await _spawn()
	var before: int = game._state.pizzas_left
	# Same gesture, but slow enough that the release is under the throw
	# threshold. Real time has to pass for the flick to read as slow.
	await _drag(game, 40.0, 0.35)
	_check("a slow release does not cost a pizza (%d -> %d)" % [before, game._state.pizzas_left],
		game._state.pizzas_left == before)
	_check("and nothing is in the air", game._flight == null)
	game.queue_free()
	await get_tree().process_frame


func _test_one_pizza_in_the_air_at_a_time() -> void:
	var game := await _spawn()
	await _flick(game, 600.0)
	var after_first: int = game._state.pizzas_left
	_check("first throw is airborne", game._flight != null)
	await _flick(game, 600.0)
	_check("a second throw while one is in the air is refused (%d, still %d)"
			% [after_first, game._state.pizzas_left],
		game._state.pizzas_left == after_first)
	game.queue_free()
	await get_tree().process_frame


func _test_a_round_ends_on_its_own() -> void:
	var game := await _spawn()
	var ended: Array = []
	game.round_ended.connect(func(won: bool, delivered: int) -> void: ended.assign([won, delivered]))

	# Throw blindly until the round resolves. Ten pizzas and four strikes means
	# it has to end one way or the other well inside this budget.
	var throws := 0
	while ended.is_empty() and throws < 40:
		if game._state.can_throw() and game._flight == null:
			await _flick(game, 500.0 + float(throws) * 40.0)
			throws += 1
		await get_tree().process_frame

	_check("a round of blind throws resolves (%d throws, got %s)" % [throws, ended], ended.size() == 2)
	if ended.size() == 2:
		_check("pizzas or strikes ran out, not both silently (pizzas %d, strikes %d)"
				% [game._state.pizzas_left, game._state.strikes_left],
			game._state.pizzas_left == 0 or game._state.strikes_left == 0)
	game.queue_free()
	await get_tree().process_frame


## The pizza you drag has to be on screen before the throw, not conjured once
## one is already in the air.
func _test_the_waiting_pizza_is_there_to_grab() -> void:
	var game := await _spawn()
	var ready_pizza: Node2D = game.get_node("ReadyPizza")
	_check("a pizza is waiting in hand at the start", ready_pizza.visible)

	await _flick(game, 600.0)
	_check("it is gone while one is in the air", not ready_pizza.visible)

	# Empty the stack, then let the last throw settle.
	while game._state.pizzas_left > 0:
		game._state.spend_pizza()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("and it is gone once the stack is empty", not ready_pizza.visible)
	game.queue_free()
	await get_tree().process_frame


# --- helpers ----------------------------------------------------------------

func _spawn() -> Node:
	var game: Node = (load("res://scenes/pizza_game.tscn") as PackedScene).instantiate()
	add_child(game)
	# start_level is deferred in _ready, so give it a frame to land.
	await get_tree().process_frame
	await get_tree().process_frame
	return game


## A fast upward drag: touch, two moves, release. Fast enough to count as a throw.
func _flick(game: Node, travel: float) -> void:
	await _drag(game, travel, 0.0)


## `step_delay` is the real time between each movement. It has to sit BETWEEN
## the moves, not before them: the gesture only measures the last instant of the
## drag, so a pause followed by two instant moves still reads as a fast flick.
func _drag(game: Node, travel: float, step_delay: float) -> void:
	var start := Vector2(585.0, 1900.0)
	_touch(true, start)
	await get_tree().process_frame
	for i in range(1, 3):
		if step_delay > 0.0:
			await get_tree().create_timer(step_delay).timeout
		_move(start + Vector2(0.0, -travel * float(i) * 0.5))
		await get_tree().process_frame
	if step_delay > 0.0:
		await get_tree().create_timer(step_delay).timeout
	_touch(false, start + Vector2(0.0, -travel))
	await get_tree().process_frame
	await get_tree().process_frame


func _touch(pressed: bool, pos: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = get_viewport().get_final_transform() * pos
	Input.parse_input_event(e)


func _move(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = get_viewport().get_final_transform() * pos
	Input.parse_input_event(e)


func _check(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
