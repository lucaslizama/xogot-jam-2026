extends Node

# Street streaming, landing detection and round rules, with nothing drawn.
#   godot-4.6 --headless res://tests/test_street.tscn

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_test_street_starts_stocked()
	_test_street_scrolls_past_the_rider()
	_test_street_stays_stocked_forever()
	_test_street_is_reproducible()
	_test_houses_respect_their_ranges()
	_test_every_house_can_be_reached()
	_test_landing_in_a_drop_point_delivers()
	_test_landing_short_misses()
	_test_a_house_cannot_be_served_twice()
	_test_scenery_is_never_a_delivery()
	_test_nearest_drop_point_wins()
	_test_round_is_lost_on_the_last_strike()
	_test_round_is_won_when_the_stack_empties()
	_test_round_is_not_won_before_the_last_pizza_lands()
	_test_strikes_are_clamped_to_the_dots_available()

	print("\n=== %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL  ", f)
	if _failures.is_empty():
		print("  all good")
	get_tree().quit(1 if _failures.size() > 0 else 0)


# --- streaming --------------------------------------------------------------

func _test_street_starts_stocked() -> void:
	var street := StreetModel.new(_config(), 1)
	_check("the street opens already populated (got %d houses)" % street.houses().size(),
		street.houses().size() > 3)
	_check("something is waiting at the start (got %d)" % street.open_count(), street.open_count() > 0)


func _test_street_scrolls_past_the_rider() -> void:
	var config := _config()
	var street := StreetModel.new(config, 2)
	var first: House = street.houses()[0]
	var before := first.side
	street.advance(1.0)
	_check("houses slide toward the rider by the street speed (moved %.2f, want %.2f)"
			% [before - first.side, config.street_speed],
		is_equal_approx(before - first.side, config.street_speed))


func _test_street_stays_stocked_forever() -> void:
	var config := _config()
	var street := StreetModel.new(config, 3)
	var low := 9999
	var high := 0
	# Two minutes of street at 1/60, far longer than any level.
	for i in 7200:
		street.advance(1.0 / 60.0)
		low = mini(low, street.houses().size())
		high = maxi(high, street.houses().size())
	_check("the street never runs dry over two minutes (fewest %d)" % low, low > 3)
	_check("and never grows without bound (most %d)" % high, high < 40)
	_check("houses are still waiting after two minutes (got %d)" % street.open_count(),
		street.open_count() > 0)


func _test_street_is_reproducible() -> void:
	var a := StreetModel.new(_config(), 77)
	var b := StreetModel.new(_config(), 77)
	var c := StreetModel.new(_config(), 78)
	for i in 120:
		a.advance(1.0 / 60.0)
		b.advance(1.0 / 60.0)
		c.advance(1.0 / 60.0)
	_check("the same seed gives the same street", _same(a, b))
	_check("a different seed gives a different street", not _same(a, c))


func _test_houses_respect_their_ranges() -> void:
	var config := _config()
	var street := StreetModel.new(config, 5)
	for i in 1200:
		street.advance(1.0 / 60.0)
	var bad_distance := 0
	var bad_gap := 0
	var sorted := street.houses().duplicate()
	sorted.sort_custom(func(x: House, y: House) -> bool: return x.side < y.side)
	for house in sorted:
		if house.distance < config.distance_min - 0.001 or house.distance > config.distance_max + 0.001:
			bad_distance += 1
	for i in range(1, sorted.size()):
		var gap: float = sorted[i].side - sorted[i - 1].side
		if gap < config.gap_min - 0.001 or gap > config.gap_max + 0.001:
			bad_gap += 1
	_check("every house sits within the configured distance range (%d outside)" % bad_distance, bad_distance == 0)
	_check("every gap sits within the configured range (%d outside)" % bad_gap, bad_gap == 0)


## Every house on every street has to be reachable by the hardest throw the
## physics allow. Tuning the throw down once left a street whose far houses
## could not be delivered to at all, however hard the player pulled, and nothing
## said so: the level simply became impossible partway along.
func _test_every_house_can_be_reached() -> void:
	var tuning := PizzaPhysics.new()
	var hardest := PizzaFlight.new(tuning, tuning.launch_from(Vector2(0.0, -99999.0), 0.0))
	while not hardest.step(1.0 / 240.0):
		pass

	for name in ["street_1", "street_2", "street_3"]:
		var level: LevelConfig = load("res://data/levels/%s.tres" % name)
		var needed: float = level.distance_max - level.drop_radius
		_check("%s: its furthest house can be reached (hardest throw %.1f, needs %.1f)"
				% [name, hardest.distance, needed], hardest.distance >= needed)
		_check("%s: and with room to spare, not on the very edge (%.1f over)"
				% [name, hardest.distance - needed], hardest.distance >= needed + 3.0)
		_check("%s: its nearest house is not trivially close (%.1f)" % [name, level.distance_min],
			level.distance_min > 20.0)


# --- landing ----------------------------------------------------------------

func _test_landing_in_a_drop_point_delivers() -> void:
	var street := _one_house_street(true)
	var target: House = street.houses()[0]
	_check("a landing dead on the drop point delivers",
		street.delivery_at(target.side, target.distance) == target)
	_check("a landing just inside the drop point delivers",
		street.delivery_at(target.side + target.drop_radius * 0.9, target.distance) == target)


func _test_landing_short_misses() -> void:
	var street := _one_house_street(true)
	var target: House = street.houses()[0]
	_check("a landing just outside the drop point misses",
		street.delivery_at(target.side, target.distance - target.drop_radius * 1.1) == null)
	_check("a landing nowhere near anything misses",
		street.delivery_at(target.side + 500.0, target.distance + 500.0) == null)


func _test_a_house_cannot_be_served_twice() -> void:
	var street := _one_house_street(true)
	var target: House = street.houses()[0]
	target.served = true
	_check("a served house stops accepting pizzas",
		street.delivery_at(target.side, target.distance) == null)


func _test_scenery_is_never_a_delivery() -> void:
	var street := _one_house_street(false)
	var scenery: House = street.houses()[0]
	_check("a house that never wanted a pizza is not a delivery",
		street.delivery_at(scenery.side, scenery.distance) == null)


func _test_nearest_drop_point_wins() -> void:
	var street := _one_house_street(true)
	var near := House.new(10.0, 20.0, 6.0, true)
	var far := House.new(13.0, 20.0, 6.0, true)
	street.houses().clear()
	street.houses().append(far)
	street.houses().append(near)
	_check("overlapping drop points give the pizza to the nearer one",
		street.delivery_at(10.5, 20.0) == near)


# --- the round --------------------------------------------------------------

func _test_round_is_lost_on_the_last_strike() -> void:
	var state := _state(_config_with(5, 3))
	# assign(), not `ended = [...]`: a GDScript lambda captures locals by value,
	# so rebinding inside it never reaches this one. Mutating does.
	var ended: Array = []
	state.round_ended.connect(func(won: bool, delivered: int) -> void: ended.assign([won, delivered]))
	state.note_miss()
	state.note_miss()
	_check("two of three strikes does not end it", ended.is_empty())
	state.note_miss()
	_check("the third strike ends the round as a loss (got %s)" % [ended], ended.size() == 2 and ended[0] == false)
	state.free()


func _test_round_is_won_when_the_stack_empties() -> void:
	var state := _state(_config_with(3, 3))
	var ended: Array = []
	state.round_ended.connect(func(won: bool, delivered: int) -> void: ended.assign([won, delivered]))
	for i in 3:
		state.spend_pizza()
		state.note_delivery()
	state.note_flight_settled()
	_check("emptying the stack with a strike left wins (got %s)" % [ended],
		ended.size() == 2 and ended[0] == true and ended[1] == 3)
	state.free()


func _test_round_is_not_won_before_the_last_pizza_lands() -> void:
	var state := _state(_config_with(2, 3))
	var ended: Array = []
	state.round_ended.connect(func(won: bool, delivered: int) -> void: ended.assign([won, delivered]))
	state.spend_pizza()
	state.note_flight_settled()
	_check("the round is not won while pizzas remain", ended.is_empty())
	_check("and throwing is still allowed", state.can_throw())
	state.spend_pizza()
	_check("the round is not won the instant the last pizza is thrown", ended.is_empty())
	_check("and throwing is now refused", not state.can_throw())
	state.note_flight_settled()
	_check("it is won once that last pizza settles (got %s)" % [ended], ended.size() == 2 and ended[0] == true)
	state.free()


func _test_strikes_are_clamped_to_the_dots_available() -> void:
	var state := LevelState.new()
	add_child(state)
	state.bind_strike_capacity(3)
	state.begin(_config_with(5, 8))
	_check("a level asking for more strikes than there are dots is clamped (got %d)" % state.strikes_left,
		state.strikes_left == 3)
	state.free()


# --- helpers ----------------------------------------------------------------

func _config() -> LevelConfig:
	return LevelConfig.new()


func _config_with(pizzas: int, strikes: int) -> LevelConfig:
	var c := LevelConfig.new()
	c.pizzas_in_stack = pizzas
	c.strikes = strikes
	return c


func _state(config: LevelConfig) -> LevelState:
	var state := LevelState.new()
	add_child(state)
	state.bind_strike_capacity(8)
	state.begin(config)
	return state


func _one_house_street(waiting: bool) -> StreetModel:
	var street := StreetModel.new(_config(), 9)
	street.houses().clear()
	street.houses().append(House.new(12.0, 22.0, 3.2, waiting))
	return street


func _same(a: StreetModel, b: StreetModel) -> bool:
	if a.houses().size() != b.houses().size():
		return false
	for i in a.houses().size():
		if not is_equal_approx(a.houses()[i].side, b.houses()[i].side):
			return false
		if not is_equal_approx(a.houses()[i].distance, b.houses()[i].distance):
			return false
	return true


func _check(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures.append(what)
