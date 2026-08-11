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
	await _test_a_delivery_pays_and_says_so()
	await _test_a_house_shows_the_street_and_not_its_preview()
	await _test_the_menu_says_which_build_it_is()
	await _test_a_throw_starts_from_where_the_pizza_was()
	await _test_a_street_cleared_is_handed_on()
	await _test_a_street_lost_is_not_handed_on()

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
	# Everything is read off the scene before it is let go, since what follows is
	# about numbers rather than about the node they came from.
	var drawn: HouseView = (game.house_scene.instantiate() as HouseView)
	var expected := Vector2(drawn.width, drawn.wall_height + drawn.roof_height)
	var drawn_window: Vector2 = drawn.window_size
	var drawn_window_centre: float = drawn.window_centre
	var drawn_wall: float = drawn.wall_height
	var drawn_width: float = drawn.width
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

	# The window has to be the one that is drawn, or a player would be aiming at a
	# lit rectangle with the target somewhere else on the wall.
	_check("the street was told about the window (%s, want %s)"
			% [game._street.house_window, drawn_window],
		game._street.house_window.is_equal_approx(drawn_window))
	_check("at the height it is drawn at (%.1f, want %.1f)"
			% [game._street.house_window_centre, drawn_window_centre],
		is_equal_approx(game._street.house_window_centre, drawn_window_centre))
	_check("and the window sits inside the wall it is cut into",
		drawn_window_centre + drawn_window.y * 0.5 < drawn_wall
			and drawn_window.x < drawn_width)

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


## The number in the corner exists to be believed. If it can drift from the build
## it is printed on, it is worse than not being there, because it will be trusted
## in exactly the moment somebody is trying to work out whether they are looking at
## an old build.
func _test_the_menu_says_which_build_it_is() -> void:
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame

	var recorded := str(ProjectSettings.get_setting("application/config/version", ""))
	var label: Label = menu.get_node("Version")
	_check("the project records a version at all (%s)" % recorded, not recorded.is_empty())
	_check("the menu shows it (%s)" % label.text, label.text.contains(recorded))
	_check("and it is on screen", label.visible)
	menu.queue_free()
	await get_tree().process_frame


## The pizza used to drop to the rider's line the instant it was released, however
## high it had been held. The height it starts at is now read back off the screen,
## so the throw carries on from where the eye last saw it.
func _test_a_throw_starts_from_where_the_pizza_was() -> void:
	var game := await _spawn()
	var proj: StreetProjection = game.projection
	var floor_height: float = game.physics.release_height

	# Held high, the flight should start at exactly the row it was let go on.
	for held_y in [1400.0, 900.0, 400.0]:
		var h: float = game._release_height_at(held_y)
		var back: float = proj.project(0.0, h, 0.0).y
		_check("let go at %.0f, the throw starts there (%.0f)" % [held_y, back],
			is_equal_approx(back, held_y))

	# Held low, nothing changes. A pizza in hand is drawn below the street's own
	# ground line, so an honest reading there is underground.
	_check("down by the bike it starts where it always did (%.1f)"
			% game._release_height_at(2470.0),
		is_equal_approx(game._release_height_at(2470.0), floor_height))
	_check("and a throw can never begin lower than the rider's own hands",
		game._release_height_at(9999.0) >= floor_height)

	_check("higher up the screen means a higher start",
		game._release_height_at(400.0) > game._release_height_at(1400.0))

	# The way back, if it turns out to feel wrong.
	game.drag_lift_gain = 0.0
	for held_y in [2470.0, 1400.0, 400.0]:
		_check("with the gain at zero, %.0f starts at the old height" % held_y,
			is_equal_approx(game._release_height_at(held_y), floor_height))
	game.queue_free()
	await get_tree().process_frame


## Clearing a street hands the bag to the next rider before the card says what it
## paid. The card must wait for that, or the beat plays behind a card nobody can
## see past.
func _test_a_street_cleared_is_handed_on() -> void:
	var game := await _spawn()
	var card: ResultCard = game.get_node("Ui/ResultCard")
	var relay: Handoff = game.get_node("Ui/Handoff")
	var ended: Array = []
	game.round_ended.connect(func(won: bool, delivered: int) -> void: ended.assign([won, delivered]))

	_check("nothing is being handed over mid street", not relay.is_playing())
	_win_the_street(game)
	await get_tree().process_frame
	_check("clearing the street starts the handoff", relay.is_playing())
	_check("and it is on screen", relay.visible)
	_check("the card waits its turn", not card.visible)
	_check("and the round has not been called over yet", ended.is_empty())

	# A tap sends it on, because nobody wants the same beat three times in a run.
	relay.skip()
	await get_tree().process_frame
	_check("a tap sends the handoff on", not relay.is_playing())
	_check("and puts it away", not relay.visible)
	_check("the card follows it", card.visible)
	_check("and the round is called, won (%s)" % [ended], ended == [true, 10])
	game.queue_free()
	await get_tree().process_frame


## Being fired is not an occasion for a triumphant relay.
func _test_a_street_lost_is_not_handed_on() -> void:
	var game := await _spawn()
	var card: ResultCard = game.get_node("Ui/ResultCard")
	var relay: Handoff = game.get_node("Ui/Handoff")

	while game._state.strikes_left > 0:
		game._state.note_miss()
	await get_tree().process_frame
	_check("a street lost hands nothing over", not relay.is_playing())
	_check("and the card comes straight up", card.visible)
	game.queue_free()
	await get_tree().process_frame


## Empty the stack and let the last throw settle, which is a street cleared.
func _win_the_street(game: Node) -> void:
	while game._state.pizzas_left > 0:
		game._state.spend_pizza()
		game._state.note_delivery(ScoreRules.ThrowTier.NICE)
	game._state.note_flight_settled()


## The house draws itself in the editor now, from preview values it carries. Those
## must not survive contact with a real street: a house that kept its preview would
## be waiting when the street said scenery, and one whose first instruction merely
## matched the preview would never start its drop point pulsing, which is invisible
## right up until nobody can find anything to aim at.
func _test_a_house_shows_the_street_and_not_its_preview() -> void:
	var game := await _spawn()
	var scenery: House = null
	var waiting: House = null
	for house in game._street.houses():
		if house.waiting and waiting == null:
			waiting = house
		elif not house.waiting and scenery == null:
			scenery = house
	_check("the street offered both kinds of house to look at",
		waiting != null and scenery != null)
	if waiting == null or scenery == null:
		game.queue_free()
		return

	var views: Dictionary = game._views
	var waiting_view: HouseView = views[waiting]
	var scenery_view: HouseView = views[scenery]
	_check("the house that wants a pizza is drawn as one", waiting_view._waiting)
	_check("and the scenery is not, whatever its preview said",
		not scenery_view._waiting)
	_check("the drop point is the size this street's ring really is (%.1f, want %.1f)"
			% [waiting_view._drop_radius, game._config.drop_radius],
		is_equal_approx(waiting_view._drop_radius, game._config.drop_radius))

	# The pulse is the thing an early return would silently switch off.
	_check("a house that wants a pizza is animating its drop point",
		waiting_view.is_processing())

	# A house nobody has spoken to shows its preview, which is the whole point of
	# the exercise: that is what the editor canvas draws.
	var fresh: HouseView = (game.house_scene.instantiate() as HouseView)
	add_child(fresh)
	await get_tree().process_frame
	_check("an undriven house shows its preview ring (%.1f, want %.1f)"
			% [fresh._drop_radius, fresh.preview_drop_radius],
		is_equal_approx(fresh._drop_radius, fresh.preview_drop_radius))
	_check("and its preview state", fresh._waiting == fresh.preview_waiting)

	# And a house told exactly what its preview already said still wakes up.
	fresh.show_state(fresh.preview_waiting, fresh.preview_served, fresh.preview_drop_radius)
	_check("even one told exactly what it was already showing",
		fresh.is_processing())
	fresh.queue_free()
	game.queue_free()
	await get_tree().process_frame


## The rules can be perfect and pay nobody if the scene forgot to hand them over,
## and the tips can be counted and never shown. Both are wiring, so both are here.
func _test_a_delivery_pays_and_says_so() -> void:
	var game := await _spawn()
	var rules: ScoreRules = game._state.scoring
	_check("the scene gave the state its scoring rules", rules != null)
	if rules == null:
		game.queue_free()
		return

	var total: Label = game.get_node("Ui/Tips")
	var popup: TipPopup = game.get_node("Ui/TipPopup")

	# The theme has been lost whole before now, and a variation going missing is
	# silent: the label simply falls back to the default and nobody notices until
	# a screenshot. Money is money, so it is checked rather than trusted.
	var theme: Theme = load("res://data/ui_theme.tres")
	_check("the theme still has somewhere to say money",
		theme.has_theme_item(Theme.DATA_TYPE_COLOR, "font_color", "Money"))
	_check("and the total is dressed in it (%s)" % total.theme_type_variation,
		total.theme_type_variation == &"Money")
	_check("money is green, not the default text colour",
		total.get_theme_color(&"font_color").g > total.get_theme_color(&"font_color").r)
	_check("and the tip a throw pays is too",
		rules.label_tip.contains("$") and rules.label_total.contains("$"))

	_check("the running total starts at nothing", total.text == rules.label_total % 0)
	_check("and nothing is floating over the street yet", not popup.visible)

	var paid: int = game._state.note_delivery(ScoreRules.ThrowTier.BULLSEYE)
	_check("a bullseye paid something (got %d)" % paid, paid > 0)
	await get_tree().process_frame
	_check("and the total on screen followed it (shows %s)" % total.text,
		total.text == rules.label_total % paid)

	# The popup is the game's own reaction, not the state's, so it is driven the
	# way the game drives it.
	var money: MoneyBurst = game.get_node("Ui/MoneyBurst")
	game._show_tip(Vector2(500.0, 900.0), ScoreRules.ThrowTier.BULLSEYE, paid, 1)
	_check("the tip is said where the pizza landed", popup.visible)
	_check("and the money went up with it (%d bills)" % money.in_flight(),
		money.in_flight() > 0)
	_check("a bullseye throws more of it than a scrape (%d against %d)"
			% [money.bills_for(ScoreRules.ThrowTier.BULLSEYE),
				money.bills_for(ScoreRules.ThrowTier.SCRAPED)],
		money.bills_for(ScoreRules.ThrowTier.BULLSEYE)
			> money.bills_for(ScoreRules.ThrowTier.SCRAPED))

	# A street throwing faster than the bills fall must not pile up forever.
	for i in 40:
		money.burst(Vector2(500.0, 900.0), 30)
	_check("the burst is capped however hard it is asked (%d, ceiling %d)"
		% [money.in_flight(), money.max_bills],
		money.in_flight() <= money.max_bills)

	# And they have to clear on their own, or the street fills with money. Waited
	# on the clock, not on frames: headless runs unthrottled, so thirty frames can
	# be almost no simulated time at all and the bills would still be in the air.
	await get_tree().create_timer(money.life + 0.3).timeout
	_check("bills fall out of the air in time (%d left)" % money.in_flight(),
		money.in_flight() == 0)
	game.queue_free()
	await get_tree().process_frame


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
