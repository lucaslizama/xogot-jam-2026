class_name StreetModel
extends RefCounted

## The endless street, as data. Keeps itself stocked with houses ahead of the
## rider and drops the ones that have gone by.
##
## No nodes in here, so a whole level's worth of scrolling and landing can be
## replayed in a test far faster than real time. The scene that draws it reads
## [method houses] each frame and does nothing else.

## How big a house's body is, in world units: x its width, y how tall it stands.
## A pizza thrown into a house counts as delivered, so this has to be the size the
## houses are actually drawn at, which is why the game reads it off the house scene
## rather than anyone typing it twice. Zero leaves houses as thin air, and only
## their drop points can be hit.
var house_body: Vector2 = Vector2.ZERO
## How high off the ground a house's wall starts counting. See [member
## House.doorstep]: at zero the wall stands in its own drop point's doorway.
var house_doorstep: float = 0.0
## The lit window on a house's front, and how high its middle sits. Zero leaves
## the facade plain, which is what a street with nothing to aim at wants.
##
## Used only when there is no [member house_looks] to read it from, which is the
## case for a street of plain houses and for tests that want one window and no
## table to set up.
var house_window: Vector2 = Vector2.ZERO
var house_window_centre: float = 0.0
## The buildings a house can be, and where each one's window is painted. When this
## is set, every house picks a building and takes its window from here, so the
## target is on the glass whichever building the house turned out to be.
var house_looks: HouseLooks = null

var _config: LevelConfig
var _rng := RandomNumberGenerator.new()
## A stream of its own for deciding what a house looks like.
##
## Sharing [member _rng] would be simpler and wrong: every look drawn from it
## would shift the gaps and distances that follow, so adding the buildings would
## have quietly rearranged every street in the game and every seeded test with it.
var _look_rng := RandomNumberGenerator.new()
var _houses: Array[House] = []
## Along-street position of the furthest house placed so far.
var _frontier: float = 0.0


## `body` is passed in rather than set afterwards so that the first houses, which
## are placed here, are as solid as every one that follows.
func _init(config: LevelConfig, seed_value: int = 0, body: Vector2 = Vector2.ZERO,
		doorstep: float = 0.0, window: Vector2 = Vector2.ZERO,
		window_centre: float = 0.0, looks: HouseLooks = null) -> void:
	_config = config
	house_body = body
	house_doorstep = doorstep
	house_window = window
	house_window_centre = window_centre
	house_looks = looks
	_rng.seed = seed_value
	_look_rng.seed = hash(Vector2i(seed_value, 0x10075))
	# Start the frontier just behind the rider so the first stretch of street is
	# already populated when the level opens rather than arriving late.
	_frontier = _config.despawn_behind
	_restock()


func houses() -> Array[House]:
	return _houses


## Slide the world past the rider, then top up and prune.
func advance(delta: float) -> void:
	var travelled := _config.street_speed * delta
	for house in _houses:
		house.side -= travelled
	_frontier -= travelled
	_prune()
	_restock()


## The open house whose drop point a landing fell inside, or null for a miss.
## Nearest wins, so overlapping drop points cannot both claim a pizza.
func delivery_at(landed_side: float, landed_distance: float) -> House:
	var best: House = null
	var best_miss: float = INF
	for house in _houses:
		if not house.is_open():
			continue
		var miss := house.miss_by(landed_side, landed_distance)
		if miss <= house.drop_radius and miss < best_miss:
			best = house
			best_miss = miss
	return best


## The open house a pizza flew into on this step of its flight, or null if it hit
## nothing. Both arguments are (side, height, distance).
##
## Only houses that still want a pizza are solid. Scenery is left as thin air on
## purpose: making it block throws would turn near misses into dead stops and take
## something away, and this change is meant to give something.
func struck_house(from: Vector3, to: Vector3) -> House:
	var best: House = null
	for house in _houses:
		if not house.is_open() or not house.struck_by(from, to):
			continue
		# The nearest wall is the one that stops it; anything further up the street
		# is standing in its shadow.
		if best == null or house.distance < best.distance:
			best = house
	return best


## How many houses are still waiting, on screen or not. Useful for telling a
## fair street from one that never offers a target.
func open_count() -> int:
	var open := 0
	for house in _houses:
		if house.is_open():
			open += 1
	return open


func _restock() -> void:
	while _frontier < _config.spawn_ahead:
		_frontier += _rng.randf_range(_config.gap_min, _config.gap_max)
		var house := House.new(
			_frontier,
			_rng.randf_range(_config.distance_min, _config.distance_max),
			_config.drop_radius,
			_rng.randf() < _config.waiting_chance,
			house_body,
			house_doorstep,
			house_window,
			house_window_centre,
		)
		_dress(house)
		_houses.append(house)


## Decide which building this house is, and put its window where that building's
## window is painted. Done here rather than in the scene that draws it, because the
## throw is judged against the window and the two have to be the same one.
func _dress(house: House) -> void:
	if house_looks == null or house_looks.look_count <= 0:
		return
	house.look = _look_rng.randi_range(0, house_looks.look_count - 1)
	house.flipped = _look_rng.randf() < 0.5
	house.windows = house_looks.rects_for(house.look, house.flipped)


func _prune() -> void:
	var kept: Array[House] = []
	for house in _houses:
		if house.side >= _config.despawn_behind:
			kept.append(house)
	_houses = kept
