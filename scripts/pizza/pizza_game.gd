class_name PizzaGame
extends Node2D

## Wires the throw, the street and the round together, and draws them.
##
## Everything with a rule in it lives elsewhere and is tested without a screen:
## the flight maths, the gesture reading, the street's streaming, the round's
## bookkeeping. This node's job is only to move numbers between them and put
## the result on the display.

signal round_ended(won: bool, delivered: int)

@export_group("Content")
## Levels in order. Later entries should be tighter: fewer strikes, faster
## street, houses further back. The last one repeats if the player gets past it.
@export var levels: Array[LevelConfig] = []
@export var physics: PizzaPhysics
@export var projection: StreetProjection
@export var house_scene: PackedScene

@export_group("Flow")
@export var start_automatically: bool = true
## Streets are generated from this plus the level number, so a run is
## reproducible while every level still looks different.
@export var street_seed: int = 20260807

@export_group("Feel")
## How far the waiting pizza slides with your finger, as a fraction of the drag.
## Pokemon GO nudges the ball with the drag; it makes the throw feel connected
## rather than like flicking at a fixed picture.
@export_range(0.0, 1.0, 0.05) var ready_pizza_follow: float = 0.35
## How much the waiting pizza turns per radian of wind-up. This is the only
## feedback the player gets that a curve is being loaded.
@export_range(0.0, 3.0, 0.05) var windup_spin_gain: float = 1.0
## How fast the pizza tumbles in the air, before spin is added on top.
@export_range(0.0, 30.0, 0.1) var pizza_tumble_rate: float = 4.5
## Radius of the pizza on screen at the rider's own distance, in pixels.
@export_range(4.0, 300.0, 1.0) var pizza_radius: float = 34.0

@onready var _state: LevelState = $LevelState
@onready var _backdrop: Backdrop = $Backdrop
@onready var _houses_root: Node2D = $Houses
@onready var _pizza: Node2D = $Pizza
@onready var _shadow: GroundShadow = $Shadow
@onready var _ready_pizza: Node2D = $ReadyPizza
@onready var _aim: AimPreview = $AimPreview
@onready var _strikes: StrikeDots = %StrikeDots
@onready var _stack: PizzaStack = %PizzaStack
@onready var _result: ResultCard = %ResultCard

var _config: LevelConfig
var _street: StreetModel
var _flight: PizzaFlight
var _gesture := ThrowGesture.new()
var _views: Dictionary = {}
var _travelled: float = 0.0
var _level_index: int = 0
var _touch_index: int = -1
var _ready_home: Vector2
var _drag_from: Vector2


func _ready() -> void:
	_state.bind_strike_capacity(_strikes.slot_count())
	_state.pizzas_changed.connect(_stack.show_pizzas)
	_state.strikes_changed.connect(_strikes.show_strikes)
	_state.round_ended.connect(_on_round_ended)
	_result.again_pressed.connect(_on_again)
	_result.hide()
	_pizza.visible = false
	_shadow.visible = false
	_ready_home = _ready_pizza.position
	_backdrop.projection = projection
	_aim.projection = projection
	_aim.physics = physics

	if start_automatically:
		# Deferred: the first houses would otherwise be added while this node is
		# still setting up its own children.
		start_level.call_deferred()


func start_level() -> void:
	_config = _level_at(_level_index)
	if _config == null:
		push_error("PizzaGame: no levels assigned. Add at least one LevelConfig to the levels array.")
		return
	if physics == null or projection == null or house_scene == null:
		push_error("PizzaGame: physics, projection and house_scene must all be assigned.")
		return

	# The landing ring promises exactly the room this street actually gives.
	_aim.marker_radius = _config.drop_radius
	_street = StreetModel.new(_config, street_seed + _level_index)
	_travelled = 0.0
	_clear_flight()
	_clear_views()
	_result.hide()
	_state.begin(_config)


func _process(delta: float) -> void:
	if _street == null:
		return
	if not _state.is_over():
		_street.advance(delta)
		_travelled += _config.street_speed * delta
	_backdrop.set_travelled(_travelled)
	_sync_views()
	_advance_flight(delta)
	_update_ready_pizza()


# --- throwing ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _street == null or _state.is_over():
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0

	if event is InputEventScreenTouch:
		if event.pressed:
			# One pizza in the air at a time, and only if there is one to throw.
			if _flight != null or not _state.can_throw() or _gesture.is_active():
				return
			_touch_index = event.index
			_drag_from = event.position
			_gesture.begin(event.position, now)
		elif event.index == _touch_index and _gesture.is_active():
			var flick := _gesture.release(event.position, now)
			_touch_index = -1
			_aim.clear()
			_throw(flick, _gesture.windup())
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_gesture.update(event.position, now)
		_aim.show_for(_gesture.current_flick(), _gesture.windup())
		_ready_pizza.position = _ready_home + (event.position - _drag_from) * ready_pizza_follow
		_ready_pizza.rotation = _gesture.windup() * windup_spin_gain


func _throw(flick: Vector2, windup: float) -> void:
	if not _state.can_throw():
		return
	# A slow release is a fumble, not a throw. Spending a pizza on a stray tap
	# would be the cruellest possible way to lose a round.
	if -flick.y < physics.min_throw_flick:
		return

	_flight = PizzaFlight.new(physics, physics.launch_from(flick, windup))
	_state.spend_pizza()
	_ready_pizza.visible = false
	_pizza.visible = true
	_pizza.rotation = 0.0
	_place_pizza()


func _advance_flight(delta: float) -> void:
	if _flight == null:
		return
	if _flight.step(delta):
		_resolve_landing()
		return
	_pizza.rotation += (pizza_tumble_rate + _flight.current_spin() * 8.0) * delta
	_place_pizza()


func _resolve_landing() -> void:
	var house: House = _street.delivery_at(_flight.side, _flight.distance)
	_flight = null
	_pizza.visible = false
	_shadow.visible = false

	if house != null:
		house.served = true
		_state.note_delivery()
	else:
		_state.note_miss()
	# Only now can the round be won: the last throw still had to land.
	_state.note_flight_settled()


func _place_pizza() -> void:
	_pizza.position = projection.project(_flight.side, _flight.height, _flight.distance)
	var scale := projection.scale_at(_flight.distance)
	_pizza.scale = Vector2(scale, scale)

	# The shadow sits at the same spot on the ground, which is what tells the
	# player how far out the throw actually is.
	_shadow.visible = true
	_shadow.position = projection.project(_flight.side, 0.0, _flight.distance)
	_shadow.scale = Vector2(scale, scale)
	_shadow.z_index = clampi(int(-_flight.distance), -4000, 4000)
	# Draw order is by depth, so a pizza passing behind a near house is hidden
	# by it. Negative because nearer means a smaller distance.
	_pizza.z_index = clampi(int(-_flight.distance), -4000, 4000)


## The pizza waiting in your hand, at the bottom of the screen. It is the thing
## you drag, so it has to be there before the throw rather than appearing only
## once one is in the air.
func _update_ready_pizza() -> void:
	_ready_pizza.visible = _flight == null and not _state.is_over() and _state.can_throw()
	if not _gesture.is_active():
		_ready_pizza.position = _ready_home
		_ready_pizza.rotation = 0.0


# --- houses -----------------------------------------------------------------

## Give every house in the model a node, place it, and drop the nodes whose
## houses have gone by.
func _sync_views() -> void:
	var live := {}
	for house in _street.houses():
		var view: HouseView = _views.get(house)
		if view == null:
			view = house_scene.instantiate() as HouseView
			if view == null:
				push_error("PizzaGame: house_scene's root must extend HouseView.")
				return
			_houses_root.add_child(view)
			_views[house] = view
		_place_house(view, house)
		live[house] = true

	for house in _views.keys():
		if not live.has(house):
			(_views[house] as Node).queue_free()
			_views.erase(house)


func _place_house(view: HouseView, house: House) -> void:
	var scale := projection.scale_at(house.distance)
	view.position = projection.project(house.side, 0.0, house.distance)
	view.scale = Vector2(scale, scale)
	view.z_index = clampi(int(-house.distance), -4000, 4000)
	view.show_state(house.waiting, house.served, house.drop_radius)


func _clear_views() -> void:
	for view in _views.values():
		(view as Node).queue_free()
	_views.clear()


func _clear_flight() -> void:
	_flight = null
	_touch_index = -1
	_pizza.visible = false
	_shadow.visible = false
	_aim.clear()


# --- the round ---------------------------------------------------------------

func _on_round_ended(won: bool, delivered: int) -> void:
	_clear_flight()
	_result.show_result(won, delivered, _level_index + 1)
	round_ended.emit(won, delivered)


func _on_again() -> void:
	# Winning moves you up the list; losing puts you back on the same street.
	if _result.was_won():
		_level_index = mini(_level_index + 1, maxi(0, levels.size() - 1))
	start_level()


func _level_at(index: int) -> LevelConfig:
	if levels.is_empty():
		return null
	return levels[clampi(index, 0, levels.size() - 1)]
