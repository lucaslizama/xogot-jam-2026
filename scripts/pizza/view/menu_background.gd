class_name MenuBackground
extends Node2D

## The game's street, running behind the menu with no one riding it.
##
## It reuses the same pieces the game draws with — the sky and road shaders, the
## parallax skyline, the streamed houses — driven the same way, so the title sits
## in front of the world the player is about to enter. What it leaves out is
## everything that belongs to a round: the rider, the pizzas, the HUD, and the
## landing rings under the houses. It also loops: it walks the level list end to
## end, crossing from each street's hour to the next, and starts over.

@export_group("Content")
## The same levels the game uses, in order. Their streets and hours are what the
## background cycles through. Point this at the game's list.
@export var levels: Array[LevelConfig] = []
@export var projection: StreetProjection
@export var house_scene: PackedScene

@export_group("Flow")
## A different seed from the game's, so the menu is not a preview of the exact
## street about to be played.
@export var street_seed: int = 90210
## How long each level's street runs before crossing to the next, in seconds.
@export_range(2.0, 60.0, 0.5) var seconds_per_level: float = 9.0

@onready var _backdrop: Backdrop = $Backdrop
@onready var _houses_root: Node2D = $Houses
@onready var _daylight: GameDaylight = $Daylight

var _street: StreetModel
var _config: LevelConfig
var _views: Dictionary = {}
var _travelled: float = 0.0
var _level_index: int = 0
var _time_on_level: float = 0.0
var _looks: HouseLooks = null
var _looks_measured: bool = false


func _ready() -> void:
	if projection == null or house_scene == null or levels.is_empty():
		push_warning("MenuBackground: assign projection, house_scene and at least one level.")
		set_process(false)
		return
	_daylight.projection = projection
	_backdrop.projection = projection
	($Sky as NightSky).projection = projection
	($Street as StreetSurface).projection = projection
	_enter_level(0)


func _process(delta: float) -> void:
	if _street == null:
		return
	_street.advance(delta)
	_travelled += _config.street_speed * delta
	_backdrop.set_travelled(_travelled)
	($Street as StreetSurface).set_travelled(_travelled)
	_daylight.advance(delta)
	_sync_views()

	_time_on_level += delta
	if _time_on_level >= seconds_per_level:
		_enter_level((_level_index + 1) % levels.size())


func _enter_level(index: int) -> void:
	_level_index = index
	_config = levels[index]
	_time_on_level = 0.0
	if _street == null:
		# The looks table is passed for the variety, not for the targets: nothing here
		# can be thrown at. Without it every house on the menu street would be the same
		# building, since the street is what decides which one a house is.
		_street = StreetModel.new(_config, street_seed + index, Vector2.ZERO, 0.0,
			_house_looks())
	else:
		# Keep travelling, and keep the town. Building a second model here replaced
		# every house on screen in the frame the hour changed, so the row of buildings
		# the player was watching became a different row for no reason they could see.
		# The new level's rules take over for the houses still to come; the ones
		# already standing ride out of view as they were.
		_street.carry_on_as(_config)
	_daylight.begin(_config.time_of_day)



#region houses, as in the game, but without a landing ring

func _sync_views() -> void:
	var live := {}
	for house in _street.houses():
		var view: HouseView = _views.get(house)
		if view == null:
			view = house_scene.instantiate() as HouseView
			if view == null:
				push_error("MenuBackground: house_scene's root must extend HouseView.")
				return
			# The menu street is scenery: no circles to aim at.
			view.show_drop_points = false
			_houses_root.add_child(view)
			_views[house] = view
		_place_house(view, house)
		live[house] = true

	for house in _views.keys():
		if not live.has(house):
			(_views[house] as Node).queue_free()
			_views.erase(house)


func _place_house(view: HouseView, house: House) -> void:
	var shrink := projection.scale_at(house.distance)
	view.position = projection.project(house.side, 0.0, house.distance)
	view.scale = Vector2(shrink, shrink)
	view.z_index = clampi(int(-house.distance), -4000, 4000)
	view.modulate = projection.haze_tint(house.distance) * _world_tint()
	view.show_state(house.waiting, house.served, house.drop_radius)
	view.show_look(house.look, house.flipped)


## Which buildings the house scene can draw, read off it once.
func _house_looks() -> HouseLooks:
	if _looks_measured:
		return _looks
	_looks_measured = true
	var probe := house_scene.instantiate() as HouseView
	if probe == null:
		# The error for this is already raised where the views are made.
		return null
	_looks = probe.looks
	probe.free()
	return _looks


func _world_tint() -> Color:
	return _daylight.world_tint()

#endregion
