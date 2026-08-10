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
	await _test_a_touch_away_from_the_pizza_does_nothing()
	await _test_a_fumble_puts_the_pizza_back()
	await _test_a_round_ends_on_its_own()
	await _test_the_tuning_tools_are_absent_from_a_shipped_build()
	await _test_houses_are_solid_at_the_size_they_are_drawn()

	# Not idle padding. A test that throws frees its game a frame later, while the
	# throw is still sounding, and quitting straight after that leaves the clip
	# still referenced: the engine prints "N resources still in use at exit", which
	# reads exactly like a leak and is not one. A fifth of a second of real time is
	# all the audio server needs to let go. Tests that only fumble never trip it,
	# which is what makes the throw the culprit.
	await get_tree().create_timer(0.25).timeout

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
	# Let the pizza finish dropping back into the rider's hand before taking the
	# game away. That return is a tween the game awaits, and freeing the game
	# mid-tween leaves the coroutine suspended for good, still holding the Tween:
	# the engine then reports a leaked instance at exit, which reads like a bug in
	# the game and is only this test being impatient.
	await get_tree().create_timer(game.return_duration + 0.1).timeout
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


## A touch nowhere near the pizza must not start a throw, or the game would
## fling one every time a thumb brushed the screen.
func _test_a_touch_away_from_the_pizza_does_nothing() -> void:
	var game := await _spawn()
	var before: int = game._state.pizzas_left
	var far := Vector2(200.0, 700.0)
	_touch(true, far)
	await get_tree().process_frame
	_move(far + Vector2(0.0, -600.0))
	await get_tree().process_frame
	_touch(false, far + Vector2(0.0, -600.0))
	await get_tree().process_frame
	await get_tree().process_frame
	_check("a flick far from the pizza throws nothing (%d -> %d)" % [before, game._state.pizzas_left],
		game._state.pizzas_left == before and game._flight == null)
	game.queue_free()
	await get_tree().process_frame


## Releasing too slowly should drop the pizza back into your hand rather than
## leaving it stranded wherever the finger stopped.
func _test_a_fumble_puts_the_pizza_back() -> void:
	var game := await _spawn()
	var ready_pizza: Node2D = game.get_node("ReadyPizza")
	var home: Vector2 = ready_pizza.position
	await _drag(game, 300.0, 0.3)
	_check("a fumble leaves the pizza away from home at first",
		ready_pizza.position.distance_to(home) > 1.0 or game._returning)
	await get_tree().create_timer(game.return_duration + 0.2).timeout
	_check("and it has returned home (%.0f px away)" % ready_pizza.position.distance_to(home),
		ready_pizza.position.distance_to(home) < 1.0)
	_check("still holding every pizza (%d)" % game._state.pizzas_left, game._state.pizzas_left == 10)
	game.queue_free()
	await get_tree().process_frame


## The model can be told any size at all, so the thing worth checking here is that
## the game hands it the size the houses are really drawn at. A game that forgot to
## would leave every house thin air and no model test would notice.
func _test_houses_are_solid_at_the_size_they_are_drawn() -> void:
	var game := await _spawn()
	var drawn: HouseView = (game.house_scene.instantiate() as HouseView)
	var expected := Vector2(drawn.width, drawn.wall_height + drawn.roof_height)
	drawn.free()

	var body: Vector2 = game._street.house_body
	_check("the street was given a house body (got %s)" % body, body != Vector2.ZERO)
	_check("and it is the size the house scene draws (%s, want %s)" % [body, expected],
		body.is_equal_approx(expected))

	var solid := 0
	for house in game._street.houses():
		if house.body.is_equal_approx(expected):
			solid += 1
	_check("every house on the real street is solid (%d of %d)"
		% [solid, game._street.houses().size()],
		solid == game._street.houses().size() and solid > 0)

	# A pizza sent through the middle of an open house should be taken by it.
	var open_house: House = null
	for house in game._street.houses():
		if house.is_open():
			open_house = house
			break
	if open_house == null:
		_check("the street offered a house to throw at", false)
		game.queue_free()
		return
	var through_it: House = game._street.struck_house(
		Vector3(open_house.side, expected.y * 0.5, open_house.distance - 5.0),
		Vector3(open_house.side, expected.y * 0.5, open_house.distance + 5.0))
	_check("a pizza through the front of a real house is a delivery", through_it == open_house)
	game.queue_free()


## The tuning sliders and the button that clears a street are for us, not for
## players. The suite runs as a debug build, so the panel has to be told to
## pretend otherwise before it wakes up.
func _test_the_tuning_tools_are_absent_from_a_shipped_build() -> void:
	var shipped := await _spawn(false)
	var panel: DebugPanel = shipped.find_child("DebugPanel", true, false)
	_check("the panel is in the scene to be hidden in the first place", panel != null)
	if panel == null:
		return
	_check("a shipped build does not offer the tuning tools", not panel.is_available())
	_check("and nothing of it is on screen", not panel.visible)
	# The game goes on reporting throws whether anyone is listening or not.
	await _flick(shipped, 400.0)
	_check("throwing with the panel gone does not fault", shipped._flight != null)
	shipped.queue_free()

	var ours := await _spawn()
	var dev_panel: DebugPanel = ours.find_child("DebugPanel", true, false)
	_check("a build we are running still offers them", dev_panel.is_available())
	_check("and its button is on screen", dev_panel.visible)
	ours.queue_free()


# --- helpers ----------------------------------------------------------------

func _spawn(development_build: bool = true) -> Node:
	var game: Node = (load("res://scenes/pizza_game.tscn") as PackedScene).instantiate()
	# Set before the tree wakes the panel: it decides once, in _ready.
	var panel: DebugPanel = game.find_child("DebugPanel", true, false)
	if panel != null:
		panel.development_build = development_build
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
	# The drag has to begin on the pizza itself now: a touch further away than
	# grab_radius is ignored, so a stray tap cannot fling one.
	var start: Vector2 = (game.get_node("ReadyPizza") as Node2D).position
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
