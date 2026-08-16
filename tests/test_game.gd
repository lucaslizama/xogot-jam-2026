extends Node

# Drives the real game scene with synthetic touches. The rules are covered
# elsewhere; this is about the wiring actually running.
#   godot-4.6 --headless res://tests/test_game.tscn

var _failures: Array[String] = []
var _checks: int = 0

## The floor under the check count. See [method _report].
const EXPECTED: int = 186


func _ready() -> void:
	var per_test := {}
	for test in _tests():
		var before := _checks
		await test.call()
		per_test[test.get_method()] = _checks - before

	# Not idle padding. A test that throws frees its game a frame later, while the
	# throw is still sounding, and quitting straight after that leaves the clip
	# still referenced: the engine prints "N resources still in use at exit", which
	# reads exactly like a leak and is not one. A fifth of a second of real time is
	# all the audio server needs to let go. Tests that only fumble never trip it,
	# which is what makes the throw the culprit.
	await get_tree().create_timer(0.25).timeout
	_report(per_test)


## Every test, in the order they run. A list rather than a run of calls so the
## runner can see what each one contributed; see [method _report].
func _tests() -> Array[Callable]:
	return [
		_test_scene_runs_and_draws_houses,
		_test_a_flick_spends_a_pizza,
		_test_a_fumble_spends_nothing,
		_test_one_pizza_in_the_air_at_a_time,
		_test_the_waiting_pizza_is_there_to_grab,
		_test_a_touch_away_from_the_pizza_does_nothing,
		_test_a_fumble_puts_the_pizza_back,
		_test_a_round_ends_on_its_own,
		_test_the_tuning_tools_are_absent_from_a_shipped_build,
		_test_houses_are_solid_at_the_size_they_are_drawn,
		_test_a_delivery_pays_and_says_so,
		_test_the_skyline_stands_as_nodes,
		_test_the_scenes_show_on_the_canvas_what_the_game_shows,
		_test_the_house_previews_a_building_without_a_street,
		_test_the_stack_rides_with_the_rider,
		_test_a_house_shows_the_street_and_not_its_preview,
		_test_a_house_is_the_same_building_in_every_state,
		_test_the_menu_says_which_build_it_is,
		_test_the_menu_street_keeps_its_town_when_the_hour_turns,
		_test_the_street_can_be_paused_and_left,
		_test_a_throw_starts_from_where_the_pizza_was,
		_test_a_street_cleared_is_handed_on,
		_test_you_become_the_rider_you_handed_the_bag_to,
		_test_a_street_lost_is_not_handed_on,
		_test_the_shop_sells_more_than_one_thing,
		_test_a_tap_on_the_road_changes_the_flavour,
		_test_a_tap_near_the_pizza_leaves_the_flavour_alone,
		_test_the_pizza_in_the_air_keeps_what_it_was_thrown_as,
		_test_only_the_pizza_you_can_grab_is_animated,
		_test_the_strike_row_shows_the_chances_this_street_dealt,
		_test_a_sheet_is_cut_into_frames,
		_test_every_street_asks_for_orders,
		_test_the_order_ticket_clears_the_strike_dots,
		_test_a_ticket_shows_what_is_wanted_and_pays_when_filled,
		_test_a_ticket_cannot_ask_for_more_lines_than_it_can_draw,
		_test_a_lost_pizza_comes_apart_where_it_landed,
		_test_the_page_teaches_the_tap,
		_test_the_card_says_how_the_orders_went,
	]



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
	# Nor is it a tap asking for a different flavour. It began away from the pizza,
	# which is where a tap lives, but it travelled 600 px to get to where it was let
	# go, and a finger going somewhere is not a request for anything.
	_check("and it is not read as a tap on the road either",
		game.current_flavour() == game.menu.flavour_at(0))
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
	var drawn_looks: HouseLooks = drawn.looks
	var drawn_width: float = drawn.width
	drawn.free()

	var body: Vector2 = game._street.house_body
	_check("the street was given a fallback house body (got %s)" % body,
		body != Vector2.ZERO)
	_check("and it is the size the house scene falls back to (%s, want %s)"
		% [body, expected], body.is_equal_approx(expected))

	# Not one size for the street any more. The buildings differ by a unit and a
	# half across and up, and every house is solid at the size of the building it
	# was actually drawn as.
	var solid := 0
	var sizes := {}
	for house in game._street.houses():
		var want := drawn_looks.body_of(house.look) if drawn_looks != null else expected
		if house.body.is_equal_approx(want):
			solid += 1
		sizes[house.body] = true
	_check("every house is solid at the size of its own building (%d of %d)"
		% [solid, game._street.houses().size()],
		solid == game._street.houses().size() and solid > 0)
	_check("and the street is not one size over and over (%d sizes)" % sizes.size(),
		sizes.size() > 1)

	# The window has to be the one drawn on the building this particular house
	# turned out to be, or a player would be aiming at a lit rectangle with the
	# target somewhere else on the wall. Every building on the sheet paints it
	# somewhere different, so this is checked house by house rather than once.
	_check("the street was given the table of windows", drawn_looks != null
		and drawn_looks.rows() > 0)
	if drawn_looks != null and drawn_looks.rows() > 0:
		_check("and it is the one the house scene carries",
			game._street.house_looks == drawn_looks)
		var matched := 0
		var inside := 0
		var panes := 0
		for house in game._street.houses():
			var want := drawn_looks.rects_for(house.look, house.flipped)
			panes += house.windows.size()
			if house.windows.size() == want.size():
				var same := true
				for i in want.size():
					if not house.windows[i].is_equal_approx(want[i]):
						same = false
				if same:
					matched += 1
			# A window standing above the roofline or hanging off the side of the
			# facade would be a measurement typed in wrong, and unreachable. The
			# roofline, not the top of the wall: one of the buildings on the sheet
			# has its windows upstairs, in the gable.
			var fits := true
			for pane in house.windows:
				if pane.position.y + pane.size.y >= expected.y \
						or pane.position.x < -drawn_width * 0.5 \
						or pane.position.x + pane.size.x > drawn_width * 0.5:
					fits = false
			if fits:
				inside += 1
		var total: int = game._street.houses().size()
		_check("every house has the windows painted on its own building (%d of %d)"
			% [matched, total], total > 0 and matched == total)
		_check("and every one of them sits on the facade it is cut into (%d of %d)"
			% [inside, total], total > 0 and inside == total)
		# A building drawn with two windows should offer two targets, so the street
		# ought to be carrying more panes than it has houses with a window.
		_check("and a building with more than one window offers all of them (%d panes)"
			% panes, panes > total)

		# Half the point of a table of buildings is that a street is not one
		# building over and over.
		var dealt := {}
		for house in game._street.houses():
			dealt[house.look] = true
		_check("and the street dealt more than one building (%d of %d)"
			% [dealt.size(), drawn_looks.count()], dealt.size() > 1)

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
## Pausing, and the two ways out of it.
##
## Three of these are worth more than they look. The street must actually stop, or
## the pause is only a picture over a game still being played. The way out must hand
## back a running tree, because a scene changed into a paused one arrives frozen with
## no pause button left to free it. And pausing has to be off once the round is over,
## or the menu offers to resume a street that has finished.
func _test_the_street_can_be_paused_and_left() -> void:
	var game := await _spawn()
	var pause: PauseMenu = game.get_node("Ui/PauseMenu")
	_check("the street offers a way to pause it", pause.get_node("PauseButton").visible)
	_check("and nothing is paused to start with", not get_tree().paused and not pause.is_open())

	pause.open()
	await get_tree().process_frame
	_check("pausing stops the tree", get_tree().paused)
	_check("and puts the menu up", pause.is_open())

	# The street really has to stop, not just be covered over.
	var where: float = game._travelled
	await get_tree().create_timer(0.15).timeout
	_check("the street stopped moving (travelled %.2f, was %.2f)" % [game._travelled, where],
		is_equal_approx(game._travelled, where))

	pause.get_node("%OptionsButton").pressed.emit()
	await get_tree().process_frame
	_check("options opens the same settings page the menu uses",
		pause.get_node("%SettingsPage").visible and pause.get_node("%SettingsPage") is SettingsPage)

	pause.get_node("%SettingsPage").back_pressed.emit()
	await get_tree().process_frame
	_check("and comes back to the buttons", pause.get_node("%Panel").visible)

	pause.close()
	await get_tree().process_frame
	_check("resuming starts the tree again", not get_tree().paused)
	await get_tree().create_timer(0.15).timeout
	_check("and the street moves again (travelled %.2f)" % game._travelled, game._travelled > where)

	# Leaving. The game's own handler is unhooked first, because letting it run would
	# change scene for real and take this test out with it: the suite is the current
	# scene, and change_scene_to_file frees it mid-await. What is checked instead is
	# the promise the handler depends on, that the tree is running when it is asked.
	var running_when_asked := [false]
	pause.leave_pressed.disconnect(game._leave_for_the_menu)
	pause.leave_pressed.connect(func() -> void: running_when_asked[0] = not get_tree().paused)
	pause.open()
	await get_tree().process_frame
	pause.get_node("%MenuButton").pressed.emit()
	await get_tree().process_frame
	_check("leaving unpauses before it asks to change scene", running_when_asked[0])
	_check("and there is a scene for it to go to (%s)" % game.menu_scene,
		ResourceLoader.exists(game.menu_scene))

	# And once the street is over there is nothing left to pause.
	game._state.note_miss()
	game._state.note_miss()
	game._state.note_miss()
	game._state.note_miss()
	game._state.note_miss()
	await get_tree().process_frame
	_check("the round is over", game._state.is_over())
	_check("so the pause button is gone", not pause.get_node("PauseButton").visible)
	_check("and nothing is left paused", not get_tree().paused)
	game.queue_free()
	await get_tree().process_frame


## The menu walks its levels end to end in front of the player, so the crossing has
## to be an hour turning over and nothing else. It used to build a second street each
## time, which replaced every house on screen in the frame the light changed.
##
## StreetModel is where that is now guaranteed and test_street proves it there. This
## watches the actual nodes, because the guarantee is only worth anything while the
## menu still asks for it: reinstating a new model here would put the bug straight
## back with every sim test passing.
func _test_the_menu_street_keeps_its_town_when_the_hour_turns() -> void:
	var bg: MenuBackground = (load("res://scenes/ui/menu_background.tscn") as PackedScene).instantiate()
	bg.seconds_per_level = 1.0
	add_child(bg)
	for i in 20:
		await get_tree().process_frame

	var houses: Node2D = bg.get_node("Houses")
	var before := {}
	for view in houses.get_children():
		before[view.get_instance_id()] = true
	var hour_before: TimeOfDay = bg._config.time_of_day
	_check("the menu street has a town on it (got %d houses)" % before.size(), before.size() > 2)

	var guard := 0
	while bg._level_index == 0 and guard < 600:
		guard += 1
		await get_tree().process_frame
	await get_tree().process_frame
	_check("the level crossed within a reasonable time", bg._level_index == 1)
	_check("and the hour changed with it", bg._config.time_of_day != hour_before)

	var kept := 0
	for view in houses.get_children():
		if before.has(view.get_instance_id()):
			kept += 1
	_check("every house that was standing is still standing (%d of %d)" % [kept, before.size()],
		kept == before.size())
	bg.queue_free()
	await get_tree().process_frame


func _test_the_menu_says_which_build_it_is() -> void:
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	# Silent here too, for the reason given in _spawn.
	var music: GameMusic = menu.find_child("Music", true, false)
	if music != null:
		music.track = null
		music.audition_path = ""
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


## The relay means something: the rider who takes the bag is the rider you play next.
## Two riders on screen at once is the only chance the game gets to show that, so the
## arriving one has to be wearing the colours you turn up in on the next street, and
## the leaving one the colours you have been playing. Checked end to end, from clearing
## a street to standing on the next one, because every part of it being individually
## right and the pair being swapped would look exactly like this test passing.
func _test_you_become_the_rider_you_handed_the_bag_to() -> void:
	var game := await _spawn()
	var relay: Handoff = game.get_node("Ui/Handoff")
	var rider: RiderView = game.get_node("Rider")
	var leaving: RiderView = relay.get_node("RiderOut")
	var arriving: RiderView = relay.get_node("RiderIn")

	_check("the first rider is the art as drawn (got %.2f)" % rider.hue(),
		is_equal_approx(rider.hue(), 0.0))
	_check("and no two riders in a row look alike",
		not is_equal_approx(game.rider_hue(0), game.rider_hue(1)))

	_win_the_street(game)
	await get_tree().process_frame
	_check("the rider leaving wears what you were playing (%.2f vs %.2f)"
			% [leaving.hue(), rider.hue()],
		is_equal_approx(leaving.hue(), rider.hue()))
	var taken_by := arriving.hue()
	_check("and the one arriving is somebody else (%.2f)" % taken_by,
		not is_equal_approx(taken_by, leaving.hue()))

	relay.skip()
	await get_tree().process_frame
	game._on_again()
	await get_tree().process_frame
	_check("on the next street you are her (%.2f vs %.2f)" % [rider.hue(), taken_by],
		is_equal_approx(rider.hue(), taken_by))

	# Losing hands nothing over, so it must not move you on to another rider either.
	var mine := rider.hue()
	while game._state.strikes_left > 0:
		game._state.note_miss()
	await get_tree().process_frame
	game._on_again()
	await get_tree().process_frame
	_check("a street lost leaves you as yourself (%.2f)" % rider.hue(),
		is_equal_approx(rider.hue(), mine))
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

	# Each state is its own child now, so the thing to check is that exactly one of
	# them is showing. A house wearing two states at once, or none, is the failure
	# an artist would meet first.
	_check("the waiting house shows its waiting node and nothing else",
		_visible_states(waiting_view) == [HouseView.State.WAITING])
	_check("and the scenery shows its scenery node and nothing else",
		_visible_states(scenery_view) == [HouseView.State.SCENERY])

	# The pulse is the thing an early return would silently switch off. It lives on
	# the drop point, so anything the artist parents there breathes with it.
	_check("a house that wants a pizza is animating its drop point",
		waiting_view.drop_point().is_processing())
	_check("and the scenery is not showing a drop point at all",
		not scenery_view.drop_point().visible)

	# A house nobody has spoken to shows its preview, which is the whole point of
	# the exercise: that is what the editor canvas draws.
	var fresh: HouseView = (game.house_scene.instantiate() as HouseView)
	add_child(fresh)
	await get_tree().process_frame
	_check("an undriven house shows its preview ring (%.1f, want %.1f)"
			% [fresh._drop_radius, fresh.preview_drop_radius],
		is_equal_approx(fresh._drop_radius, fresh.preview_drop_radius))
	_check("and its preview state", _visible_states(fresh) == [fresh.preview_state])

	# And a house told exactly what its preview already said still wakes up.
	fresh.show_state(fresh.preview_state != HouseView.State.SCENERY,
		fresh.preview_state == HouseView.State.SERVED, fresh.preview_drop_radius)
	_check("even one told exactly what it was already showing",
		fresh.drop_point().is_processing())

	# The house answers its size from the hitbox child, so an artist can drag the
	# shape without the throw and the drawing drifting apart.
	var hitbox: HouseHitbox = fresh.hitbox()
	_check("the house scene carries a hitbox", hitbox != null)
	if hitbox != null:
		_check("and the size it reports is the hitbox's (%s, want %s)"
				% [Vector2(fresh.width, fresh.wall_height), Vector2(hitbox.width, hitbox.wall_height)],
			is_equal_approx(fresh.width, hitbox.width)
				and is_equal_approx(fresh.wall_height, hitbox.wall_height)
				and fresh.looks == hitbox.looks)
	fresh.queue_free()
	game.queue_free()
	await get_tree().process_frame


## The rows of silhouettes behind the street are nodes rather than rectangles drawn
## in a loop, so a building can carry a shader or an animation. Three things have to
## hold for that to be worth having: a row must stand its buildings up, it must not
## keep making them as the street rolls on, and a row handed a scene must use it.
func _test_the_skyline_stands_as_nodes() -> void:
	var game := await _spawn()
	var backdrop: Backdrop = game.get_node("Backdrop")
	var rows: int = backdrop.layers.size()

	_check("every row has a holder, in the order the rows are listed (%d of %d)"
		% [backdrop.get_child_count(), rows], backdrop.get_child_count() == rows)
	var standing: int = backdrop._standing.size()
	_check("and the rows are standing buildings up (%d)" % standing, standing > rows)

	# The street is endless. A row that made a building and never dropped it would
	# grow without bound, and nothing on screen would say so for a long while.
	backdrop.set_travelled(4000.0)
	await get_tree().process_frame
	var later: int = backdrop._standing.size()
	_check("and drops them again as the street rolls on (%d, was %d)" % [later, standing],
		later <= standing + rows)

	# A row given a scene uses it. Any Node2D scene will do; this is about the
	# wiring, not about what a silhouette looks like.
	var swapped: BackdropLayer = backdrop.layers[0].duplicate()
	swapped.art = load("res://scenes/pizza.tscn")
	var original: BackdropLayer = backdrop.layers[0]
	backdrop.layers[0] = swapped
	backdrop.set_travelled(0.0)
	await get_tree().process_frame
	var made_from_art := 0
	for building in backdrop.get_child(0).get_children():
		if building is PizzaView:
			made_from_art += 1
	_check("a row handed a scene stands that scene up (%d buildings)" % made_from_art,
		made_from_art > 0)
	backdrop.layers[0] = original

	game.queue_free()
	await get_tree().process_frame


## A scene that draws one thing on the canvas and another in the game cannot be
## judged by opening it, and judging it by opening it is what the editor is for.
##
## The pizza is the case that kept catching people out: PizzaGame assigns a
## flavour the moment a round starts, so every pizza looked right in play and was a
## grey placeholder box in the editor. Nobody could see whether the one in hand was
## too big or whether it cleared the bottom of the screen. The scene carries a
## flavour now, and the game overwrites it exactly as before.
func _test_the_scenes_show_on_the_canvas_what_the_game_shows() -> void:
	var pizza: PizzaView = (load("res://scenes/pizza.tscn") as PackedScene).instantiate()
	_check("the pizza scene carries a flavour, so the canvas draws a pizza "
		+ "rather than a placeholder box", pizza.flavour != null)
	if pizza.flavour != null:
		_check("and that flavour has art on it (%s)" % pizza.flavour.display_name,
			pizza.flavour.art != null or pizza.flavour.animation != null)
	pizza.free()

	# And the game still says what it wants, so nothing a player sees moved.
	var game := await _spawn()
	var wanted: PizzaFlavour = game.current_flavour()
	if wanted != null:
		_check("the game still sets the waiting pizza's flavour itself (%s)"
			% wanted.display_name, game._ready_pizza.flavour == wanted)
	game.queue_free()
	await get_tree().process_frame


## The House node offers a preview of which state it shows and which of the
## sheet's buildings it is, so the scene can be opened on any of them without
## running anything. The state half worked because it only toggles visibility; the
## building half reached the hitbox's window outline and stopped, because the
## sprite's script was not a tool script and the editor holds one of those as a
## placeholder that answers no calls.
##
## Nothing here runs in the editor, so this checks the wiring the preview uses and
## then checks the one property that decides whether the editor may use it at all.
func _test_the_house_previews_a_building_without_a_street() -> void:
	var house: HouseView = (load("res://scenes/house.tscn") as PackedScene).instantiate()
	add_child(house)
	await get_tree().process_frame

	var drew := {}
	for look in [2, 1, 3, 0]:
		house.preview_look = look
		house.preview_flipped = look % 2 == 1
		await get_tree().process_frame
		var sprites := _sprites_under(house.state_node(HouseView.State.WAITING))
		if sprites.is_empty():
			continue
		var sprite: Sprite2D = sprites[0]
		drew[look] = sprite.frame == look and sprite.flip_h == (look % 2 == 1)
		_check("previewing building %d draws building %d%s (drew %d%s)"
			% [look, look, "mirrored" if look % 2 == 1 else "", sprite.frame,
				"mirrored" if sprite.flip_h else ""],
			sprite.frame == look and sprite.flip_h == (look % 2 == 1))

	_check("the preview reached the sprite at all", drew.size() > 0)
	var hitbox: HouseHitbox = house.hitbox()
	_check("and the window outline follows the same building (%d, want 0)"
		% hitbox.shown_look, hitbox.shown_look == 0)

	# The wiring above runs outside the editor, where every script is live. On the
	# canvas only a tool script can be spoken to, so this is what decides whether
	# any of it is visible while the scene is open.
	var painter := load("res://scripts/pizza/view/house_color.gd") as Script
	_check("and the sprite's script is a tool script, so the canvas sees it too",
		painter.is_tool())

	house.queue_free()
	await get_tree().process_frame


## The stack of boxes sits on the rider's rack, and where the rack is was asked
## once, at _ready, on the grounds that she never moved. She moves now: she bobs
## and leans as she rides. Nothing failed when that changed, which is the problem
## with it — she simply rode out from under her own pizzas while the stack hung in
## the air, and only an eye on the screen would have said so.
##
## It also checks she is really moving, because a rider sitting still would pass
## the tracking check without proving anything at all.
func _test_the_stack_rides_with_the_rider() -> void:
	var game := await _spawn()
	var rider: RiderView = game.get_node("%Rider")
	var stack: PizzaStack = game.get_node("%PizzaStack")
	var boxes: Control = stack.get_node("%Boxes")

	var rider_ys := {}
	var worst := 0.0
	var gap := 0.0
	for frame in 10:
		await get_tree().process_frame
		var rack := rider.rack_rect()
		rider_ys[snappedf(rider.position.y, 0.01)] = true
		var this_gap: float = boxes.position.y - rack.position.y
		if frame == 0:
			gap = this_gap
		worst = maxf(worst, absf(this_gap - gap))

	_check("the rider is actually animating (%d positions in 10 frames)"
		% rider_ys.size(), rider_ys.size() > 1)
	_check("and the stack stays on her rack while she moves (drifts %.2f px)" % worst,
		worst < 1.0)

	# Behind her, and it has to stay behind her: in the aiming pose she holds a box
	# out over the rack, and drawn the other way round the stack paints across her
	# hand.
	_check("the stack is drawn behind the rider (stack %d, rider %d)"
		% [stack.z_index, rider.z_index], stack.z_index < rider.z_index)

	game.queue_free()
	await get_tree().process_frame


## A house is drawn by a different node in each state, and art that rolls its own
## look rolls a different one per node. Left alone, that turned a house into
## another building the moment it was served: new shape, mirrored, repainted. The
## look is chosen once for the house and handed to every state, and this is the
## only thing that would notice it stopping, since a served house is normally seen
## for a moment and never beside the one it used to be.
func _test_a_house_is_the_same_building_in_every_state() -> void:
	var scene: PackedScene = load("res://scenes/house.tscn")
	var agreed := 0
	var compared := 0
	var drawn := {}
	var mirrored := {}
	for trial in 12:
		var house: HouseView = scene.instantiate()
		add_child(house)
		await get_tree().process_frame
		# Told the same way the street tells it, since the building is the street's
		# to decide and a house left alone shows whatever its preview says.
		house.show_look(trial % 4, trial % 3 == 0)
		await get_tree().process_frame
		var waiting := _sprites_under(house.state_node(HouseView.State.WAITING))
		var served := _sprites_under(house.state_node(HouseView.State.SERVED))
		if not waiting.is_empty() and waiting.size() == served.size():
			compared += 1
			var same := true
			for i in waiting.size():
				var a: Sprite2D = waiting[i]
				var b: Sprite2D = served[i]
				if a.frame != b.frame or a.flip_h != b.flip_h:
					same = false
				drawn[a.frame] = true
				mirrored[a.flip_h] = true
			if same:
				agreed += 1
		house.queue_free()
		await get_tree().process_frame

	_check("the house scene has sprites to compare between its states", compared > 0)
	_check("a served house is the building it was while waiting (%d of %d)"
		% [agreed, compared], compared > 0 and agreed == compared)
	# Without this the test above would pass just as happily on a house that drew
	# frame 0 whatever it was told, which is the other way to break the same thing.
	_check("and the building it draws is the one it was told (%d drawn)"
		% drawn.size(), drawn.size() > 1)
	# Mirroring is a separate binding from the building, and a house told to mirror
	# that quietly does not would still agree with itself across its states. Only
	# seeing it both ways round proves the wire is connected.
	_check("and a house told to face the other way does (%d ways round)"
		% mirrored.size(), mirrored.size() > 1)


## Every Sprite2D under a state node, in tree order. Art can be nested, so this
## looks at the whole subtree rather than the node's own children.
func _sprites_under(node: Node) -> Array:
	var found := []
	if node == null:
		return found
	if node is Sprite2D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_sprites_under(child))
	return found


## Which of a house's state nodes are showing, in order. Exactly one should be.
func _visible_states(view: HouseView) -> Array:
	var showing := []
	for state in [HouseView.State.WAITING, HouseView.State.SERVED,
			HouseView.State.SCENERY]:
		var node := view.state_node(state)
		if node != null and node.visible:
			showing.append(state)
	return showing


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
	# way the game drives it: through the node that owns the money.
	var money: MoneyBurst = game.get_node("Ui/MoneyBurst")
	var payouts: GamePayouts = game.get_node("Payouts")
	payouts.pay_throw(Vector2(500.0, 900.0), ScoreRules.ThrowTier.BULLSEYE, paid, 1)
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


## Authoring, not code, but worth pinning: every street asks for orders, the first
## one included. It used to open with none, so the throw could be learned with
## nothing else on screen to read; that was changed deliberately on 11 August 2026
## and the ramp now comes from the rules getting harder rather than from the first
## street being bare. Anyone taking orders off it again is undoing that on purpose
## and should have to change this test to say so.
func _test_every_street_asks_for_orders() -> void:
	var game := await _spawn()
	for i in game.levels.size():
		_check("street %d asks for orders" % (i + 1), game._orders_for(game.levels[i]) != null)
	_check("and the first one is no exception", game._orders_for(game.levels[0]) != null)
	game.queue_free()
	await get_tree().process_frame


## The whole chain, from a ticket being written to the money landing: the board's
## signals, the handlers, the real ticket scene and LevelState's bonus. Driven by
## handing the board rules with no delay rather than by waiting out the seven
## seconds a real street takes.
func _test_a_ticket_shows_what_is_wanted_and_pays_when_filled() -> void:
	var game := await _spawn()
	var ticket: OrderTicket = game.get_node("Ui/OrderTicket")
	var rules := OrderRules.new()
	rules.first_after = 0.0
	rules.items_min = 2
	rules.items_max = 2
	rules.kinds_max = 1
	rules.seconds_min = 30.0
	rules.seconds_max = 30.0
	rules.pays = 800
	rules.gives_strike_back = false

	game._orders.begin(rules, game.menu, 4)
	game._orders.advance(0.1)
	await get_tree().process_frame
	var order: PizzaOrder = game._orders.open_order()
	_check("a ticket was written", order != null)
	_check("and it is on screen", ticket.visible)

	var row: Label = ticket.get_node("Lines/Line1/Text")
	_check("the first row says what is wanted (%s)" % row.text,
		row.text.contains(order.wants[0].display_name) and row.text.begins_with("0/"))
	var spare: Control = ticket.get_node("Lines/Line3")
	_check("and rows the ticket does not need are hidden", not spare.visible)

	# The picture as well as the name. A row showing the wrong flavour's icon would
	# read as the ticket asking for something it is not, and no wording on the card
	# would talk the player out of what they can see.
	var icon: TextureRect = ticket.get_node("Lines/Line1/Icon")
	_check("and shows that flavour's icon, not another's",
		icon.visible and icon.texture == order.wants[0].icon)

	# One of two: the row must move without the ticket being done with.
	var tips_before: int = game._state.tips
	game._orders.note_delivery(order.wants[0])
	await get_tree().process_frame
	_check("delivering one moves the row on (%s)" % row.text, row.text.begins_with("1/"))
	_check("and pays nothing yet", game._state.tips == tips_before)

	game._orders.note_delivery(order.wants[0])
	await get_tree().process_frame
	_check("filling it pays the bonus (%d -> %d)" % [tips_before, game._state.tips],
		game._state.tips == tips_before + 800)
	# Said over the rider, not on the card. The card is in the top corner and the
	# player is watching a pizza land at the far end of the street when this happens,
	# so a verdict written there went unread. Moved deliberately on 12 August 2026;
	# putting it back on the ticket means changing this test to say so.
	var popup: TipPopup = game.get_node("Ui/OrderPopup")
	var rider: Node2D = game.get_node("Rider")
	_check("and it says so (%s)" % popup.get_node("Rows/Tier").text,
		popup.visible and popup.get_node("Rows/Tier").text == ticket.filled_wording)
	_check("nearer the rider than the ticket is",
		absf(popup.position.y - rider.position.y) < absf(ticket.position.y - rider.position.y))
	_check("with nothing left on the board", game._orders.open_order() == null)

	# Both the ticket leaving and the popup floating are tweens, and freeing the game
	# mid-tween is what the recorded leak was. Let the longer of the two play out.
	var floating := maxf(ticket.finished_linger + ticket.arrive_duration, popup.linger)
	await get_tree().create_timer(floating + 0.1).timeout
	game.queue_free()
	await get_tree().process_frame


## The scene decides how many lines a ticket can have, the same way it decides how
## many strikes there can be. A rules file asking for more would put a line on the
## ticket nobody can see, and then hold the order open waiting for it.
func _test_a_ticket_cannot_ask_for_more_lines_than_it_can_draw() -> void:
	var game := await _spawn()
	var ticket: OrderTicket = game.get_node("Ui/OrderTicket")
	var rows := ticket.line_capacity()
	_check("the ticket scene has rows to draw with (got %d)" % rows, rows >= 2)

	var greedy := OrderRules.new()
	greedy.kinds_max = rows + 4
	var used: OrderRules = game._orders_for_rules(greedy)
	_check("a greedy rules file is clamped to the rows there are (got %d)" % used.kinds_max,
		used.kinds_max == rows)
	_check("on a copy, leaving the original as it was written (still %d)" % greedy.kinds_max,
		greedy.kinds_max == rows + 4)

	# And a modest one is passed straight through rather than needlessly copied.
	var modest := OrderRules.new()
	modest.kinds_max = 1
	_check("a rules file within its means is used as it is",
		game._orders_for_rules(modest) == modest)
	game.queue_free()
	await get_tree().process_frame


## A miss has to say something at the moment it happens. The pizza left lying on the
## road says where the throw went, but only after; the burst is what a player can
## read without looking away from the street.
func _test_a_lost_pizza_comes_apart_where_it_landed() -> void:
	var game := await _spawn()
	var splatter: SplatBurst = game.get_node("SplatBurst")
	_check("nothing is in the air to begin with", splatter.in_flight() == 0)

	# Driven through the game's own landing, with no house anywhere near, so this is
	# the real miss path rather than the burst being poked directly.
	game._flight = PizzaFlight.new(game.physics, game.physics.launch_from(
		Vector2(0.0, -2000.0), 0.0))
	game._flight_flavour = game.current_flavour()
	var strikes_before: int = game._state.strikes_left
	game._resolve_landing()
	_check("a miss took a strike (%d -> %d)" % [strikes_before, game._state.strikes_left],
		game._state.strikes_left == strikes_before - 1)
	_check("and the pizza came apart (%d pieces)" % splatter.in_flight(),
		splatter.in_flight() > 0)

	# A landing further up the street is smaller on screen, so its debris has to be
	# too, or a loss at the far end would fling cheese across the whole viewport.
	var near_scale: float = game.projection.scale_at(10.0)
	var far_scale: float = game.projection.scale_at(90.0)
	_check("the street makes a far landing smaller (%.2f against %.2f)"
			% [far_scale, near_scale],
		far_scale < near_scale)

	# However hard a street throws misses at it, the screen must not fill up.
	for i in 40:
		splatter.burst(Vector2(500.0, 1800.0), 40, 1.0, game.current_flavour())
	_check("the burst is capped however hard it is asked (%d, ceiling %d)"
			% [splatter.in_flight(), splatter.max_pieces],
		splatter.in_flight() <= splatter.max_pieces)

	# And it clears on its own. On the clock, not on frames: headless runs
	# unthrottled, so thirty frames can be almost no simulated time at all.
	await get_tree().create_timer(splatter.life + 0.3).timeout
	_check("the pieces clear on their own (%d left)" % splatter.in_flight(),
		splatter.in_flight() == 0)

	# A delivery is not a splat: the money goes up instead, and nothing comes apart.
	(game.get_node("Payouts") as GamePayouts).pay_throw(
		Vector2(500.0, 900.0), ScoreRules.ThrowTier.BULLSEYE, 500, 1)
	_check("a delivery throws no debris", splatter.in_flight() == 0)
	game.queue_free()
	await get_tree().process_frame


## The tap is a touch on empty road. There is no button, no icon and nothing on
## screen that hints at it, so if the page does not say it, the orders are a ticket
## the player cannot fill and the whole feature is dead weight. That makes this step
## part of the mechanic rather than documentation of it.
func _test_the_page_teaches_the_tap() -> void:
	var page: Control = (load("res://scenes/ui/how_to_play.tscn") as PackedScene).instantiate()
	add_child(page)
	await get_tree().process_frame

	var steps: Array[Node] = []
	for child in page.find_child("Steps", true, false).get_children():
		if child is HowToStep:
			steps.append(child)
	_check("the page has steps (got %d)" % steps.size(), steps.size() >= 5)

	var taught := false
	var drawn := false
	for step in steps:
		var caption: String = (step as HowToStep).caption.to_lower()
		if caption.contains("tap"):
			taught = true
			# And it has to be a picture, not only a sentence. A page of prose on a
			# phone is a page nobody reads to the end of. Which picture is not fixed
			# here: the tap was taught by the ticket when the ticket was the only
			# reason to swap, and is taught by the flavours now that they are a step
			# of their own. Pinning the kind made this fail for a page that had got
			# better, so it asks only that the step draws something.
			drawn = (step as HowToStep).diagram != HowToDiagram.DiagramKind.NONE
	_check("one of them says to tap", taught)
	_check("and it is drawn, not only written", drawn)

	page.queue_free()
	await get_tree().process_frame


## The board counts what the shop asked for and what arrived; the card is the only
## place a player ever sees it.
func _test_the_card_says_how_the_orders_went() -> void:
	var card: ResultCard = (load("res://scenes/ui/result_card.tscn") as PackedScene).instantiate()
	add_child(card)
	await get_tree().process_frame
	var line: Label = card.get_node("%Orders")

	card.show_result(true, 8, 2, 3400, 5, 2, 3)
	_check("a part-filled street is reported (%s)" % line.text,
		line.visible and line.text == card.orders_line % [2, 3])

	card.show_result(true, 8, 2, 3400, 5, 3, 3)
	_check("filling every one gets said outright (%s)" % line.text,
		line.visible and line.text == card.orders_all_line)

	# The first street writes no orders at all, and "0 of 0" on the card would read
	# as something having gone wrong.
	card.show_result(true, 8, 1, 3400, 5, 0, 0)
	_check("a street with no orders says nothing about them", not line.visible)

	card.queue_free()
	await get_tree().process_frame


# --- helpers ----------------------------------------------------------------

func _spawn(development_build: bool = true) -> Node:
	var game: Node = (load("res://scenes/pizza_game.tscn") as PackedScene).instantiate()
	# Set before the tree wakes the panel: it decides once, in _ready.
	var panel: DebugPanel = game.find_child("DebugPanel", true, false)
	if panel != null:
		panel.development_build = development_build
	# No music under the tests. A four-minute track started by every one of two dozen
	# spawns is still playing when its game is freed, and a stream the audio server
	# has not let go of is reported at exit as a resource still in use — the message
	# this suite has already been sent chasing once. Emptied before the tree wakes it,
	# because it picks its track in _ready.
	var music: GameMusic = game.find_child("Music", true, false)
	if music != null:
		music.track = null
		music.audition_path = ""
	add_child(game)
	# start_level is deferred in _ready, so give it a frame to land.
	await get_tree().process_frame
	await get_tree().process_frame
	return game


## The order ticket slides in under the strike dots, and the two are the only
## things sharing that corner. They were laid out by hand and cleared each other by
## thirty pixels, which held on the desktop and not on a phone. The ticket is now
## placed from wherever the dots actually end, so this checks the gap rather than
## the number: a bigger dot, a sixth one, or a differently shaped screen all move
## the row, and none of them may put the ticket on top of it.
func _test_the_order_ticket_clears_the_strike_dots() -> void:
	var game := await _spawn()
	var dots: StrikeDots = game.find_child("StrikeDots", true, false)
	var ticket: OrderTicket = game.find_child("OrderTicket", true, false)
	_check("the dots and the ticket are both in the scene", dots != null and ticket != null)
	if dots == null or ticket == null:
		game.queue_free()
		return
	var below := dots.bottom_edge()
	_check("the ticket starts below the dots (dots end %.0f, ticket starts %.0f)"
		% [below, ticket.position.y], ticket.position.y >= below)
	_check("with the gap the game asks for",
		is_equal_approx(ticket.position.y, below + game.ticket_gap_below_strikes))

	# The row growing is the case the hand-typed y could not survive, so make it
	# grow: a taller dot lengthens the container, and the ticket must follow.
	var first := dots.get_node("%Dots").get_child(0) as Control
	first.custom_minimum_size = Vector2(84, 300)
	await get_tree().process_frame
	game._place_ticket_below_strikes()
	_check("a taller row pushes the ticket down with it (now ends %.0f, ticket %.0f)"
		% [dots.bottom_edge(), ticket.position.y], ticket.position.y >= dots.bottom_edge())
	game.queue_free()


## A fast upward drag: touch, two moves, release. Fast enough to count as a throw.
## The menu is data, and data can be filled in wrongly without anything breaking.
## Two flavours drawn the same way would leave the swap invisible: the tap would
## work, the order would tick, and the player would have no way to tell what they
## were holding. Cheap to check, and impossible to notice by eye once the pizza is
## the size it flies at.
func _test_the_shop_sells_more_than_one_thing() -> void:
	var game := await _spawn()
	var menu: PizzaMenu = game.menu
	_check("the game was given a menu", menu != null)
	_check("with something on it (got %d)" % menu.count(), menu.count() >= 2)
	_check("and the pizza in hand is the first thing on it",
		game._ready_pizza.flavour == menu.flavour_at(0))

	var seen_names := {}
	var seen_looks := {}
	for i in menu.count():
		var f: PizzaFlavour = menu.flavour_at(i)
		seen_names[f.display_name] = true
		# What a player actually tells them apart by, once the pizza is small: how
		# many toppings and how big, not only the hue.
		seen_looks["%d/%.3f" % [f.toppings, f.topping_size]] = true
	_check("every flavour has its own name (%d of %d)" % [seen_names.size(), menu.count()],
		seen_names.size() == menu.count())
	_check("and its own scatter of toppings (%d of %d)" % [seen_looks.size(), menu.count()],
		seen_looks.size() == menu.count())
	game.queue_free()
	await get_tree().process_frame


## The tap is the whole input for the swap, and it is deliberately a touch the
## game used to throw away, so it is worth proving it now lands.
func _test_a_tap_on_the_road_changes_the_flavour() -> void:
	var game := await _spawn()
	var menu: PizzaMenu = game.menu
	var first: PizzaFlavour = game.current_flavour()

	await _tap(Vector2(180.0, 640.0))
	_check("a tap on the road moves one along the menu",
		game.current_flavour() == menu.flavour_at(1))
	_check("and the pizza in hand is drawn as it", game._ready_pizza.flavour == menu.flavour_at(1))

	# Round the rest of the way. However long the menu is, tapping through it must
	# come back to where it started rather than running off the end.
	for i in menu.count() - 1:
		await _tap(Vector2(180.0, 640.0))
	_check("and %d taps come back round to the first" % menu.count(),
		game.current_flavour() == first)

	_check("no pizza was thrown by any of it (%d left)" % game._state.pizzas_left,
		game._state.pizzas_left == 10 and game._flight == null)
	game.queue_free()
	await get_tree().process_frame


## A player reaching for the pizza and missing it by a little must not find they
## have changed flavour instead. That is the dead band around the grab ring, and it
## is the reason the swap can be a bare tap at all.
func _test_a_tap_near_the_pizza_leaves_the_flavour_alone() -> void:
	var game := await _spawn()
	var first: PizzaFlavour = game.current_flavour()
	var home: Vector2 = game._ready_home

	# Just outside the grab ring, so no throw begins, but inside the clearance.
	var near := home + Vector2(0.0, -(game.grab_radius + game.swap_clearance * 0.5))
	await _tap(near)
	_check("a tap that just missed the pizza changes nothing",
		game.current_flavour() == first and game._flight == null)

	# And on the pizza itself, which is a grab and a fumble rather than a tap.
	await _tap(home)
	_check("nor does a tap on the pizza itself", game.current_flavour() == first)
	await get_tree().create_timer(game.return_duration + 0.1).timeout
	game.queue_free()
	await get_tree().process_frame


## Tapping while a pizza is in the air prepares the next one. It must not reach
## back and change the one already thrown, or a player could wait to see where a
## throw was going to land before deciding what it had been all along.
func _test_the_pizza_in_the_air_keeps_what_it_was_thrown_as() -> void:
	var game := await _spawn()
	var thrown: PizzaFlavour = game.current_flavour()
	await _flick(game, 600.0)
	_check("the pizza in the air is what was in the hand", game._pizza.flavour == thrown)

	await _tap(Vector2(180.0, 640.0))
	_check("a tap mid-flight leaves it alone", game._pizza.flavour == thrown)
	_check("and changes what comes next instead", game.current_flavour() != thrown)
	game.queue_free()
	await get_tree().process_frame


## Which pizza moves, and which one holds still. Both are decided in the scene, so
## both can be undone in the scene by accident; and neither is visible to a test
## that only looks at flavours, because the pizza in the air is drawn from the same
## flavour as the one in the hand.
func _test_only_the_pizza_you_can_grab_is_animated() -> void:
	var game := await _spawn()
	var hand: PizzaView = game._ready_pizza
	var air: PizzaView = game._pizza
	var flavour: PizzaFlavour = game.current_flavour()

	_check("the flavour brought a sheet with frames on it (got %d)" % flavour.frame_count(),
		flavour.frame_count() > 1)
	_check("the pizza you can grab plays it", hand.plays_animation())
	_check("and the one in the air does not", not air.plays_animation())

	# Real time, not frames. Headless runs unthrottled, so a hundred process frames
	# can be a few milliseconds of a loop that turns over twelve times a second.
	var was: int = hand.frame_shown()
	await get_tree().create_timer(2.5 / flavour.animation_fps).timeout
	_check("the pizza in hand has moved on (frame %d, was %d)" % [hand.frame_shown(), was],
		hand.frame_shown() != was)

	# And the thrown one stays on its one frame the whole way down the street.
	await _flick(game, 600.0)
	var held: int = air.frame_shown()
	await get_tree().create_timer(2.5 / flavour.animation_fps).timeout
	_check("the thrown pizza is still on frame %d" % air.frame_shown(),
		game._pizza.frame_shown() == held and not air.plays_animation())
	_check("and it is drawn from the flavour's still art, not a cut of the sheet",
		air.flavour.art != null)
	game.queue_free()
	await get_tree().process_frame


## The grid maths, on a sheet whose numbers are picked to make a wrong answer
## obvious. Cheap to get subtly wrong — a row and a column swapped draws the right
## frames in the wrong order, which reads as bad animation rather than as a bug.
func _test_a_sheet_is_cut_into_frames() -> void:
	var flavour := PizzaFlavour.new()
	_check("a flavour with no sheet has no frames", flavour.frame_count() == 0)
	_check("and asking for one draws nothing", flavour.frame_region(0) == Rect2())

	var sheet := PlaceholderTexture2D.new()
	sheet.size = Vector2(400, 200)
	flavour.animation = sheet
	flavour.animation_columns = 4
	flavour.animation_rows = 2
	_check("a 4x2 sheet has eight frames (got %d)" % flavour.frame_count(),
		flavour.frame_count() == 8)
	_check("the first is the top left corner (%s)" % flavour.frame_region(0),
		flavour.frame_region(0) == Rect2(0, 0, 100, 100))
	_check("the second is beside it, not below (%s)" % flavour.frame_region(1),
		flavour.frame_region(1) == Rect2(100, 0, 100, 100))
	_check("the fifth starts the second row (%s)" % flavour.frame_region(4),
		flavour.frame_region(4) == Rect2(0, 100, 100, 100))
	_check("and counting past the end comes round to the start",
		flavour.frame_region(8) == flavour.frame_region(0))

	# A sheet with a part-filled last row: the cells are still cut the same way,
	# there are just fewer of them drawn.
	flavour.animation_length = 6
	_check("a shortened sheet stops where it is told (got %d)" % flavour.frame_count(),
		flavour.frame_count() == 6)
	_check("and wraps at that point instead",
		flavour.frame_region(6) == flavour.frame_region(0))
	flavour.animation_length = 99
	_check("asking for more frames than the grid holds is clamped to the grid",
		flavour.frame_count() == 8)


## The row must show the chances this street dealt and no more.
##
## It used to show all five dots whatever the street granted, so the spares sat there
## as crosses and every street opened by telling the player they had already missed:
## four and a cross on the first street, three and two crosses on the others. The
## count was right and the picture was wrong, which no test looking at LevelState
## could see.
func _test_the_strike_row_shows_the_chances_this_street_dealt() -> void:
	var game := await _spawn()
	var dots: StrikeDots = game.get_node("Ui/StrikeDots")
	var row: Control = dots.get_node("Dots")
	var granted: int = game._state.strike_budget()

	_check("the street dealt some chances (got %d)" % granted, granted > 0)
	_check("the scene carries spares to deal from (%d dots for %d strikes)"
		% [dots.slot_count(), granted], dots.slot_count() >= granted)
	_check("as many dots on screen as chances dealt (%d shown, %d dealt)"
		% [_visible_dots(row), granted], _visible_dots(row) == granted)

	# And none of them a cross, because nothing has been thrown yet. A spare drawn as
	# spent is exactly what this test exists to catch.
	var spent := 0
	for dot in row.get_children():
		if (dot as Control).visible and (dot as StrikeDot).is_spent():
			spent += 1
	_check("and not one of them spent before a throw (%d looked spent)" % spent, spent == 0)

	# A miss turns one into a cross without changing how many dots there are.
	game._state.note_miss()
	await get_tree().process_frame
	_check("a miss spends one (%d left of %d)" % [game._state.strikes_left, granted],
		game._state.strikes_left == granted - 1)
	_check("the row still shows %d dots, one of them now a cross" % granted,
		_visible_dots(row) == granted)
	game.queue_free()
	await get_tree().process_frame


func _visible_dots(row: Control) -> int:
	var shown := 0
	for dot in row.get_children():
		if (dot as Control).visible:
			shown += 1
	return shown


func _flick(game: Node, travel: float) -> void:
	await _drag(game, travel, 0.0)


## Press and release in the same place. Deliberately not routed through _drag,
## which starts on the pizza and moves: a tap is the absence of both.
func _tap(pos: Vector2) -> void:
	_touch(true, pos)
	await get_tree().process_frame
	_touch(false, pos)
	await get_tree().process_frame


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


## Say how it went, and refuse to call a short run a good one.
##
## A GDScript error inside a test kills the rest of that test and nothing else:
## the run carries on, the summary prints, and the only trace is a check count
## that quietly dropped. That happened three times in one afternoon and was
## noticed each time by eye. So the count is held to a floor, and a test that
## made no checks at all is named.
##
## Raise EXPECTED in the same commit that adds checks. Lowering it is a decision,
## not a tidy-up: it means checks that used to run no longer do.
func _report(per_test: Dictionary) -> void:
	print("\n=== %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL  ", f)

	var silent := PackedStringArray()
	for name in per_test:
		if per_test[name] == 0:
			silent.append(name)
	var short := _checks < EXPECTED
	if short:
		print("  SHORT  %d checks, expected at least %d. A test died part way and"
			% [_checks, EXPECTED])
		print("         took its remaining checks with it. Per test:")
		for name in per_test:
			print("           %-56s %d" % [name, per_test[name]])
	for name in silent:
		print("  SILENT  %s made no checks at all" % name)

	if _failures.is_empty() and not short and silent.is_empty():
		print("  all good")
	get_tree().quit(1 if _failures.size() > 0 or short or not silent.is_empty() else 0)
