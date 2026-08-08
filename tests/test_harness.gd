extends Node

# Throwaway verification for the slice-1 harness. Run with:
#   godot-4.6 --headless res://tests/test_harness.tscn

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await _test_letterbox(false)
	await _test_letterbox(true)
	await _test_centre_maps_to_centre(false)
	await _test_centre_maps_to_centre(true)
	await _test_rotation_direction()
	await _test_taps_counted_once(false)
	await _test_taps_counted_once(true)
	await _test_hearts_run_out()
	await _test_order_served()

	print("\n=== %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL  ", f)
	if _failures.is_empty():
		print("  all good")
	get_tree().quit(1 if _failures.size() > 0 else 0)


# --- the design box is letterboxed into the window, whichever way it turns ---

func _test_letterbox(landscape: bool) -> void:
	var main := _spawn_main()
	var host: MinigameHost = main.get_node("GameLayer/MinigameHost")
	host.play(_tap_info(landscape, 60.0), _ctx(60.0))
	await get_tree().process_frame

	var sub: SubViewport = host.get_node("SubViewportContainer/SubViewport")
	var label := "landscape" if landscape else "portrait"
	var want_size := Vector2i(2532, 1170) if landscape else Vector2i(1170, 2532)
	_check("%s: subviewport is %s (got %s)" % [label, want_size, sub.size], sub.size == want_size)

	var screen := main.get_viewport().get_visible_rect().size
	# What the letterbox should be, worked out independently of the host.
	var footprint := Vector2(want_size.y, want_size.x) if landscape else Vector2(want_size)
	var fit: float = minf(screen.x / footprint.x, screen.y / footprint.y)
	var drawn := footprint * fit
	var want_lo := (screen - drawn) * 0.5

	var box := _drawn_box(host.get_node("SubViewportContainer"))
	# Rotation leaves sub-pixel float dust; compare to a tolerance, not exactly.
	_check("%s: drawn box top-left %s == %s" % [label, box[0], want_lo], box[0].distance_to(want_lo) < 0.01)
	_check("%s: drawn box size %s == %s" % [label, box[1] - box[0], drawn], (box[1] - box[0]).distance_to(drawn) < 0.01)
	main.queue_free()
	await get_tree().process_frame


# --- a tap in the middle of the screen is a tap in the middle of the game ----

func _test_centre_maps_to_centre(landscape: bool) -> void:
	var main := _spawn_main()
	var host: MinigameHost = main.get_node("GameLayer/MinigameHost")
	host.play(_tap_info(landscape, 60.0), _ctx(60.0))
	await get_tree().process_frame

	var sub: SubViewport = host.get_node("SubViewportContainer/SubViewport")
	var probe := _listen(sub)
	await get_tree().process_frame

	var screen := main.get_viewport().get_visible_rect().size
	_tap(screen * 0.5)
	await get_tree().process_frame
	await get_tree().process_frame

	var label := "landscape" if landscape else "portrait"
	var want := Vector2(sub.size) * 0.5
	_check("%s: screen centre reaches the minigame at all" % label, probe.seen.size() > 0)
	if probe.seen.size() > 0:
		_check("%s: screen centre lands at viewport centre (got %s, want %s)" % [label, probe.seen[0], want],
			probe.seen[0].distance_to(want) < 0.5)
	main.queue_free()
	await get_tree().process_frame


# --- landscape turns the documented way, not the other one ------------------

func _test_rotation_direction() -> void:
	var main := _spawn_main()
	var host: MinigameHost = main.get_node("GameLayer/MinigameHost")
	host.landscape_clockwise = true
	host.play(_tap_info(true, 60.0), _ctx(60.0))
	await get_tree().process_frame

	var sub: SubViewport = host.get_node("SubViewportContainer/SubViewport")
	var probe := _listen(sub)
	await get_tree().process_frame

	var screen := main.get_viewport().get_visible_rect().size
	_tap(screen * 0.5 + Vector2(0.0, 300.0))   # lower down the portrait screen
	await get_tree().process_frame
	await get_tree().process_frame

	var centre := Vector2(sub.size) * 0.5
	_check("clockwise: further down the screen is further along the game's +x (got %s vs centre %s)"
			% [probe.seen[0] if probe.seen.size() > 0 else "nothing", centre],
		probe.seen.size() > 0 and probe.seen[0].x > centre.x + 1.0
			and absf(probe.seen[0].y - centre.y) < 0.5)
	main.queue_free()
	await get_tree().process_frame


# --- each tap must count exactly once, not twice ----------------------------

func _test_taps_counted_once(landscape: bool) -> void:
	var main := _spawn_main()
	var host: MinigameHost = main.get_node("GameLayer/MinigameHost")

	var outcome: Array = []
	host.minigame_finished.connect(func(success: bool) -> void: outcome.append(success))
	host.play(_tap_info(landscape, 60.0), _ctx(60.0))   # stub needs 3 taps
	await get_tree().process_frame

	var screen := main.get_viewport().get_visible_rect().size
	var label := "landscape" if landscape else "portrait"

	for i in 2:
		_tap(screen * 0.5)
		await get_tree().process_frame
		await get_tree().process_frame
	_check("%s: 2 of 3 taps has NOT resolved it (double counting would have)" % label, outcome.is_empty())

	_tap(screen * 0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("%s: the 3rd tap resolves it as a win (got %s)" % [label, outcome],
		outcome.size() == 1 and outcome[0] == true)
	main.queue_free()
	await get_tree().process_frame


# --- hearts persist across minigames and end the run at zero ----------------

func _test_hearts_run_out() -> void:
	var main := _spawn_main(_order_of(4, false))
	var state: RunState = main.get_node("RunState")
	_hurry(main)
	var seen: Array[int] = []
	state.hearts_changed.connect(func(h: int) -> void: seen.append(h))

	main.start_run()
	var ended: Array = await state.run_ended

	_check("hearts counted 4,3,2,1,0 across separate minigames (got %s)" % [seen], seen == [4, 3, 2, 1, 0])
	_check("run ended as a loss (victory=%s)" % [ended[0]], ended[0] == false)
	main.queue_free()
	await get_tree().process_frame


# --- clearing every step serves the order ----------------------------------

func _test_order_served() -> void:
	var main := _spawn_main(_order_of(3, true))
	var state: RunState = main.get_node("RunState")
	_hurry(main)

	main.start_run()
	var ended: Array = await state.run_ended

	_check("winning every step serves the order (victory=%s)" % [ended[0]], ended[0] == true)
	_check("one dish counted as served (got %s)" % [ended[1]], ended[1] == 1)
	main.queue_free()
	await get_tree().process_frame


# --- helpers ----------------------------------------------------------------

func _drawn_box(container: Control) -> Array[Vector2]:
	var xf := container.get_transform()
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for corner in [Vector2.ZERO, Vector2(container.size.x, 0.0), Vector2(0.0, container.size.y), container.size]:
		var p: Vector2 = xf * corner
		lo = lo.min(p)
		hi = hi.max(p)
	return [lo, hi]


func _listen(sub: SubViewport) -> Node:
	var probe := Node.new()
	probe.set_script(load("res://tests/test_listener.gd"))
	sub.add_child(probe)
	return probe


func _spawn_main(order: Order = null) -> Node:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.start_automatically = false
	main.log_steps = false
	if order != null:
		main.order = order
	add_child(main)
	return main


## Collapse the transition and pause so a whole run takes about a second.
func _hurry(main: Node) -> void:
	var t: HandoffTransition = main.get_node("TransitionLayer/HandoffTransition")
	t.handoff_duration = 0.05
	t.card_duration = 0.05
	t.fade_duration = 0.0
	main.post_result_pause = 0.0


func _tap_info(landscape: bool, duration: float) -> MinigameInfo:
	var info := MinigameInfo.new()
	info.display_name = "tap probe"
	info.scene = load("res://scenes/minigames/stub_harvest.tscn")
	info.orientation = MinigameInfo.ScreenOrientation.LANDSCAPE if landscape \
		else MinigameInfo.ScreenOrientation.PORTRAIT
	info.base_duration = duration
	info.win_on_timeout = false
	return info


## A minigame nobody can influence: it resolves purely on the clock.
func _clock_info(wins: bool) -> MinigameInfo:
	var info := MinigameInfo.new()
	info.display_name = "clock probe"
	info.scene = load("res://scenes/minigames/stub_harvest.tscn")
	info.base_duration = 0.2
	info.win_on_timeout = wins
	return info


func _order_of(steps: int, wins: bool) -> Order:
	var info := _clock_info(wins)
	var ingredient := Ingredient.new()
	ingredient.display_name = "Probe"
	ingredient.harvest_game = info
	var legs: Array[MinigameInfo] = []
	for i in maxi(0, steps - 2):
		legs.append(info)
	ingredient.transport_games = legs

	var dish := Dish.new()
	dish.display_name = "Probe dish"
	dish.ingredients = [ingredient]
	dish.cook_game = info

	var order := Order.new()
	order.display_name = "Probe order"
	order.dishes = [dish]
	return order


func _ctx(duration: float) -> MinigameContext:
	var ctx := MinigameContext.new()
	ctx.duration = duration
	ctx.dish_name = "Probe dish"
	return ctx


## `pos` is in viewport space, the space everything else here talks in.
## Input.parse_input_event expects window space, and the two differ by the
## viewport's final (stretch) transform — which headless makes extreme, since
## the window is 0x0. Converting here keeps the tests honest at any size.
func _tap(pos: Vector2) -> void:
	var to_window := get_viewport().get_final_transform()
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = pressed
		touch.position = to_window * pos
		Input.parse_input_event(touch)


func _check(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
