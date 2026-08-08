class_name StreetModel
extends RefCounted

## The endless street, as data. Keeps itself stocked with houses ahead of the
## rider and drops the ones that have gone by.
##
## No nodes in here, so a whole level's worth of scrolling and landing can be
## replayed in a test far faster than real time. The scene that draws it reads
## [method houses] each frame and does nothing else.

var _config: LevelConfig
var _rng := RandomNumberGenerator.new()
var _houses: Array[House] = []
## Along-street position of the furthest house placed so far.
var _frontier: float = 0.0


func _init(config: LevelConfig, seed_value: int = 0) -> void:
	_config = config
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
		))


func _prune() -> void:
	var kept: Array[House] = []
	for house in _houses:
		if house.side >= _config.despawn_behind:
			kept.append(house)
	_houses = kept
