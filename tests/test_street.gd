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
	_test_a_pizza_into_the_house_delivers()
	_test_a_pizza_past_the_house_hits_nothing()
	_test_a_fast_pizza_cannot_pass_through_a_wall()
	_test_only_houses_that_want_a_pizza_are_solid()
	_test_a_street_with_no_bodies_behaves_as_before()
	_test_the_nearest_wall_stops_the_pizza()
	_test_every_house_the_street_makes_is_solid()
	_test_the_wall_does_not_stand_in_its_own_doorway()
	_test_the_street_gives_every_house_the_same_doorstep()
	_test_the_window_is_its_own_target()
	_test_a_tier_is_earned_by_how_close_it_landed()
	_test_every_tier_has_something_to_say()
	_test_a_streak_pays_more_and_is_capped()
	_test_a_miss_breaks_the_streak_but_keeps_the_tips()
	_test_a_street_with_no_rules_still_plays()
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


# --- houses as something to hit ---------------------------------------------

func _test_a_pizza_into_the_house_delivers() -> void:
	var street := _one_solid_house_street(true)
	var target: House = street.houses()[0]
	# Straight at the middle of the wall, chest high.
	_check("a pizza into the front of the house delivers",
		street.struck_house(Vector3(12.0, 6.0, 18.0), Vector3(12.0, 6.0, 26.0)) == target)
	_check("one against the top of the wall still delivers",
		street.struck_house(Vector3(12.0, 11.5, 18.0), Vector3(12.0, 11.5, 26.0)) == target)
	_check("and one against the near edge of the wall delivers",
		street.struck_house(Vector3(2.5, 6.0, 18.0), Vector3(2.5, 6.0, 26.0)) == target)


func _test_a_pizza_past_the_house_hits_nothing() -> void:
	var street := _one_solid_house_street(true)
	_check("one thrown clean over the roof hits nothing",
		street.struck_house(Vector3(12.0, 20.0, 18.0), Vector3(12.0, 19.0, 26.0)) == null)
	_check("one that goes wide of the wall hits nothing",
		street.struck_house(Vector3(40.0, 6.0, 18.0), Vector3(40.0, 6.0, 26.0)) == null)
	_check("one that falls short of the house hits nothing",
		street.struck_house(Vector3(12.0, 6.0, 10.0), Vector3(12.0, 2.0, 18.0)) == null)
	_check("and a step already past the house hits nothing",
		street.struck_house(Vector3(12.0, 6.0, 24.0), Vector3(12.0, 4.0, 30.0)) == null)


## The reason the test takes two points rather than one: at full power a pizza
## covers more ground in one frame than a house is deep, and a single-point test
## would let it through the wall.
func _test_a_fast_pizza_cannot_pass_through_a_wall() -> void:
	var street := _one_solid_house_street(true)
	var target: House = street.houses()[0]
	_check("a step that jumps clean over the house still hits it",
		street.struck_house(Vector3(12.0, 6.0, 0.0), Vector3(12.0, 5.0, 100.0)) == target)


func _test_only_houses_that_want_a_pizza_are_solid() -> void:
	var scenery := _one_solid_house_street(false)
	_check("scenery is thin air, as it was before",
		scenery.struck_house(Vector3(12.0, 6.0, 18.0), Vector3(12.0, 6.0, 26.0)) == null)

	var served := _one_solid_house_street(true)
	served.houses()[0].served = true
	_check("a house already served is thin air too",
		served.struck_house(Vector3(12.0, 6.0, 18.0), Vector3(12.0, 6.0, 26.0)) == null)


func _test_a_street_with_no_bodies_behaves_as_before() -> void:
	var street := _one_house_street(true)
	_check("houses with no body given cannot be hit",
		street.struck_house(Vector3(12.0, 6.0, 18.0), Vector3(12.0, 6.0, 26.0)) == null)
	_check("and their drop point still works",
		street.delivery_at(12.0, 22.0) == street.houses()[0])


func _test_the_nearest_wall_stops_the_pizza() -> void:
	var body := Vector2(20.0, 12.0)
	var street := StreetModel.new(_config(), 9, body)
	var near := House.new(12.0, 22.0, 3.2, true, body)
	var far := House.new(12.0, 40.0, 3.2, true, body)
	street.houses().clear()
	street.houses().append(far)
	street.houses().append(near)
	_check("a throw crossing two houses is taken by the nearer one",
		street.struck_house(Vector3(12.0, 6.0, 0.0), Vector3(12.0, 5.0, 60.0)) == near)


func _test_every_house_the_street_makes_is_solid() -> void:
	var body := Vector2(20.0, 12.0)
	var street := StreetModel.new(_config(), 11, body)
	var bodied := 0
	for house in street.houses():
		if house.body == body:
			bodied += 1
	_check("the houses the street stocked itself with all have bodies (%d of %d)"
		% [bodied, street.houses().size()],
		bodied == street.houses().size() and bodied > 0)


# --- what a delivery is worth -------------------------------------------------

## The bug this was written for: with the wall reaching all the way down, every
## throw accurate enough to land in the drop point had to pass through the facade
## on the way, so the wall took it and called it a scrape. A bullseye could not
## happen at all, and the better the throw the worse the tier it earned.
func _test_the_wall_does_not_stand_in_its_own_doorway() -> void:
	var body := Vector2(20.0, 12.0)
	var doorstep := 4.0
	var street := StreetModel.new(_config(), 9, body, doorstep)
	street.houses().clear()
	street.houses().append(House.new(12.0, 22.0, 3.2, true, body, doorstep))

	_check("a pizza skimming in at ankle height reaches the drop point",
		street.struck_house(Vector3(12.0, 1.0, 18.0), Vector3(12.0, 0.0, 26.0)) == null)
	_check("one arriving above the doorstep is still stopped by the wall",
		street.struck_house(Vector3(12.0, 8.0, 18.0), Vector3(12.0, 8.0, 26.0)) != null)
	_check("and one right on the doorstep's line is let through",
		street.struck_house(Vector3(12.0, doorstep, 18.0), Vector3(12.0, doorstep, 26.0)) == null)

	var street_without := StreetModel.new(_config(), 9, body, 0.0)
	street_without.houses().clear()
	street_without.houses().append(House.new(12.0, 22.0, 3.2, true, body, 0.0))
	_check("with no doorstep the wall takes the low one, which was the bug",
		street_without.struck_house(Vector3(12.0, 1.0, 18.0), Vector3(12.0, 0.5, 26.0)) != null)


## The window sits inside the wall, so it has to be asked about first, and it has
## to be genuinely harder: a pizza anywhere on the front is a scrape, and only one
## through a target a fifth of the house's width is the good throw.
func _test_the_window_is_its_own_target() -> void:
	var body := Vector2(20.0, 14.0)
	var window := Vector2(4.0, 4.0)
	var centre := 7.0
	var street := StreetModel.new(_config(), 9, body, 4.0, window, centre)
	street.houses().clear()
	street.houses().append(House.new(12.0, 22.0, 3.2, true, body, 4.0, window, centre))
	var house: House = street.houses()[0]

	var through := func(side: float, height: float) -> int:
		return house.hit_by(Vector3(side, height, 18.0), Vector3(side, height, 26.0))

	_check("dead through the middle of the window",
		through.call(12.0, centre) == House.HouseHit.WINDOW)
	_check("just inside its edge is still through it",
		through.call(12.0 + window.x * 0.45, centre) == House.HouseHit.WINDOW)
	_check("a hand's width wide of it is only the wall",
		through.call(12.0 + window.x, centre) == House.HouseHit.WALL)
	_check("above it is only the wall",
		through.call(12.0, centre + window.y) == House.HouseHit.WALL)
	# Just under the sill, but still above the doorstep, is wall. Lower than the
	# doorstep is neither: that is the doormat, and the ring decides it.
	_check("just under the sill is only the wall",
		through.call(12.0, centre - window.y * 0.5 - 0.5) == House.HouseHit.WALL)
	_check("and under the doorstep is not the house at all",
		through.call(12.0, 1.0) == House.HouseHit.NONE)
	_check("a house with no window has nothing but wall to hit",
		House.new(12.0, 22.0, 3.2, true, body, 4.0).hit_by(
			Vector3(12.0, centre, 18.0), Vector3(12.0, centre, 26.0)) == House.HouseHit.WALL)

	_check("a pizza through the window is still a delivery",
		street.struck_house(Vector3(12.0, centre, 18.0), Vector3(12.0, centre, 26.0)) == house)

	var rules := ScoreRules.new()
	_check("and it pays better than a bullseye, which pays better than a scrape",
		rules.tip_for(ScoreRules.ThrowTier.WINDOW)
			> rules.tip_for(ScoreRules.ThrowTier.BULLSEYE)
		and rules.tip_for(ScoreRules.ThrowTier.BULLSEYE)
			> rules.tip_for(ScoreRules.ThrowTier.SCRAPED))


func _test_the_street_gives_every_house_the_same_doorstep() -> void:
	var street := StreetModel.new(_config(), 12, Vector2(20.0, 12.0), 4.0)
	var right := 0
	for house in street.houses():
		if is_equal_approx(house.doorstep, 4.0):
			right += 1
	_check("the houses the street stocked share its doorstep (%d of %d)"
		% [right, street.houses().size()],
		right == street.houses().size() and right > 0)

func _test_a_tier_is_earned_by_how_close_it_landed() -> void:
	var rules := ScoreRules.new()
	rules.bullseye_fraction = 0.35
	var radius := 10.0
	_check("dead centre is a bullseye",
		rules.tier_for(0.0, radius, false) == ScoreRules.ThrowTier.BULLSEYE)
	_check("just inside the sweet spot is still a bullseye",
		rules.tier_for(3.4, radius, false) == ScoreRules.ThrowTier.BULLSEYE)
	_check("just outside it is merely nice",
		rules.tier_for(3.6, radius, false) == ScoreRules.ThrowTier.NICE)
	_check("out at the rim is nice",
		rules.tier_for(9.9, radius, false) == ScoreRules.ThrowTier.NICE)
	_check("and a pizza that went into the wall scraped in, however close it was",
		rules.tier_for(0.0, radius, true) == ScoreRules.ThrowTier.SCRAPED)
	_check("a bullseye pays more than a scrape",
		rules.tip_for(ScoreRules.ThrowTier.BULLSEYE) > rules.tip_for(ScoreRules.ThrowTier.SCRAPED))


## The wording is a list now, picked from at random, so the same throw twice does
## not say the same thing twice. An empty list has to say nothing rather than put
## a blank box over the street.
func _test_every_tier_has_something_to_say() -> void:
	var rules := ScoreRules.new()
	for tier in [ScoreRules.ThrowTier.WINDOW, ScoreRules.ThrowTier.BULLSEYE,
			ScoreRules.ThrowTier.NICE, ScoreRules.ThrowTier.SCRAPED]:
		var said := {}
		for i in 60:
			said[rules.label_for(tier)] = true
		_check("tier %d has more than one thing to say (heard %d: %s)"
			% [tier, said.size(), said.keys()],
			said.size() > 1)
		_check("and none of them is blank", not said.has(""))

	rules.labels_nice = PackedStringArray()
	_check("a tier with nothing written for it says nothing",
		rules.label_for(ScoreRules.ThrowTier.NICE) == "")


func _test_a_streak_pays_more_and_is_capped() -> void:
	var rules := ScoreRules.new()
	rules.streak_starts_at = 2
	rules.streak_step = 0.15
	rules.streak_cap = 2.5
	_check("one delivery is not yet a streak", is_equal_approx(rules.multiplier_for(1), 1.0))
	_check("the second pays a step more", rules.multiplier_for(2) > 1.0)
	_check("and the third more than the second",
		rules.multiplier_for(3) > rules.multiplier_for(2))
	_check("a very long run is held at the cap (got %.2f)" % rules.multiplier_for(200),
		is_equal_approx(rules.multiplier_for(200), rules.streak_cap))
	_check("the same throw is worth more inside a run (%d then %d)"
			% [rules.award_for(ScoreRules.ThrowTier.NICE, 1),
				rules.award_for(ScoreRules.ThrowTier.NICE, 6)],
		rules.award_for(ScoreRules.ThrowTier.NICE, 6)
			> rules.award_for(ScoreRules.ThrowTier.NICE, 1))


func _test_a_miss_breaks_the_streak_but_keeps_the_tips() -> void:
	var config := _config_with(10, 4)
	var state := _state(config)
	state.scoring = ScoreRules.new()
	state.begin(config)

	var lost: Array = []
	state.streak_lost.connect(func(had: int) -> void: lost.append(had))

	for i in 4:
		state.note_delivery(ScoreRules.ThrowTier.NICE)
	var banked: int = state.tips
	_check("four deliveries make a run of four (got %d)" % state.streak, state.streak == 4)
	_check("and they paid something (got %d)" % banked, banked > 0)

	state.note_miss()
	_check("a miss ends the run", state.streak == 0)
	_check("the run that ended was reported, and its length (%s)" % [lost],
		lost.size() == 1 and lost[0] == 4)
	_check("but the tips already earned are not taken away (%d)" % state.tips,
		state.tips == banked)
	_check("and the best run is remembered (%d)" % state.best_streak, state.best_streak == 4)

	state.note_delivery(ScoreRules.ThrowTier.NICE)
	_check("the next delivery starts a new run", state.streak == 1)
	_check("and the best run still stands", state.best_streak == 4)


## The scoring is an extra on top of the game, not the game. A street with no
## rules assigned has to keep working, because the menu's decorative one has none.
func _test_a_street_with_no_rules_still_plays() -> void:
	var config := _config_with(3, 2)
	var state := _state(config)
	state.scoring = null
	state.begin(config)
	state.note_delivery(ScoreRules.ThrowTier.BULLSEYE)
	_check("a delivery still counts with no rules", state.delivered == 1)
	_check("and still builds a run", state.streak == 1)
	_check("but pays nothing", state.tips == 0)
	state.note_miss()
	_check("and a miss still costs a strike", state.strikes_left == 1)


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


## A street holding one solid house, 20 wide and 12 tall, at side 12 distance 22.
func _one_solid_house_street(waiting: bool) -> StreetModel:
	var body := Vector2(20.0, 12.0)
	var street := StreetModel.new(_config(), 9, body)
	street.houses().clear()
	street.houses().append(House.new(12.0, 22.0, 3.2, waiting, body))
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
