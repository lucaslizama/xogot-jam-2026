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

var _config: LevelConfig
var _rng := RandomNumberGenerator.new()
var _houses: Array[House] = []
## Along-street position of the furthest house placed so far.
var _frontier: float = 0.0


## `body` is passed in rather than set afterwards so that the first houses, which
## are placed here, are as solid as every one that follows.
func _init(config: LevelConfig, seed_value: int = 0, body: Vector2 = Vector2.ZERO,
		doorstep: float = 0.0) -> void:
	_config = config
	house_body = body
	house_doorstep = doorstep
	_rng.seed = seed_value
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
		_houses.append(House.new(
			_frontier,
			_rng.randf_range(_config.distance_min, _config.distance_max),
			_config.drop_radius,
			_rng.randf() < _config.waiting_chance,
			house_body,
			house_doorstep,
		))


func _prune() -> void:
	var kept: Array[House] = []
	for house in _houses:
		if house.side >= _config.despawn_behind:
			kept.append(house)
	_houses = kept
