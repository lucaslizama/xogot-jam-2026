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

@export_group("Daylight")
## How long the sky takes to cross from one street's hour to the next. The sun
## should be seen coming up, not be found already up.
@export_range(0.0, 12.0, 0.1) var daylight_crossfade: float = 2.5

@export_group("Feel")
## Whether a pizza thrown into a house counts as delivered, as well as one that
## lands in the drop point at its feet. On, the house is what the player can see,
## so it is what they aim at; off, only the ring on the ground counts and the
## house is thin air. Its size is not a value here: it is read from the house
## scene, so what can be hit is exactly what is drawn.
@export var houses_are_solid: bool = true
## How high off the ground a house's wall starts, in world units. A pizza arriving
## lower than this is landing on the doormat, and the ring at the house's feet
## decides how well it went.
##
## This is not a detail. At zero the wall blocks its own drop point: every throw
## accurate enough to reach the ring has to pass through the facade to get there,
## so every good throw was called a scrape and a dead centre landing could not
## happen at all. Raising it hands precise throws back to the ring and leaves the
## wall as what saves an overthrow.
@export_range(0.0, 15.0, 0.5) var wall_doorstep: float = 4.0
## How close to the waiting pizza a touch has to land to pick it up. Touches
## further away are ignored, so a stray tap cannot fling a pizza.
@export_range(50.0, 800.0, 10.0) var grab_radius: float = 340.0
## How long the pizza takes to drop back into your hand after a fumble.
@export_range(0.0, 1.0, 0.01) var return_duration: float = 0.18
## How much the pizza's sideways position at release shifts where the throw
## starts from. 1.0 means the throw leaves from exactly where you let go.
@export_range(0.0, 3.0, 0.05) var drag_aim_gain: float = 1.0
## How fast the pizza spins in your hand at full wind-up, in radians a second.
##
## It has to be a rate, not an angle. Showing the loaded spin as a fixed angle
## meant the pizza turned a little and then sat there while you kept circling,
## which reads as the wind-up having broken. A spinning object says "loaded" the
## way a still one at an odd angle never will.
@export_range(0.0, 40.0, 0.5) var spin_visual_rate: float = 11.0
## How far past full the wind-up may bank before it is capped. A little headroom
## keeps a hard wind from dropping off the moment the finger eases, but too much
## and the spin appears frozen while the surplus drains.
@export_range(1.0, 3.0, 0.05) var windup_headroom: float = 1.25
## How much of the previous turn survives each sixtieth of a second. Higher is
## heavier and calmer; 0 snaps straight to the target.
@export_range(0.0, 0.95, 0.05) var windup_smoothing: float = 0.35
## How much bigger the pizza gets at full wind-up. Spin is capped, and without a
## cue for the cap the player keeps circling for nothing.
@export_range(1.0, 1.6, 0.01) var charged_scale: float = 1.14
## Tint multiplied in as the wind-up fills. Reaching it means fully wound.
@export var charged_tint: Color = Color(1.35, 1.12, 0.75)
## How fast the pizza tumbles in the air, before spin is added on top.
@export_range(0.0, 30.0, 0.1) var pizza_tumble_rate: float = 4.5
## Radius of the pizza on screen at the rider's own distance, in pixels.
@export_range(4.0, 300.0, 1.0) var pizza_radius: float = 34.0

@onready var _state: LevelState = $LevelState
@onready var _audio: GameAudio = $Audio
@onready var _backdrop: Backdrop = $Backdrop
@onready var _houses_root: Node2D = $Houses
@onready var _pizza: Node2D = $Pizza
@onready var _shadow: GroundShadow = $Shadow
@onready var _ready_pizza: Node2D = $ReadyPizza
@onready var _aim: AimPreview = $AimPreview
@onready var _strikes: StrikeDots = %StrikeDots
@onready var _tips: Label = %Tips
@onready var _tip_popup: TipPopup = %TipPopup
@onready var _money: MoneyBurst = %MoneyBurst
@onready var _stack: PizzaStack = %PizzaStack
@onready var _result: ResultCard = %ResultCard
@onready var _debug: DebugPanel = %DebugPanel

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
var _grab_offset: Vector2
var _returning: bool = false
var _spin_now: float = 0.0
var _last_flick: float = 0.0
var _hour: TimeOfDay
var _hour_from: TimeOfDay
var _hour_to: TimeOfDay
var _hour_blend: float = 1.0
var _strikes_seen: int = -1
## Cached by _house_body_size.
var _house_body: Vector2 = Vector2.ZERO
## Where the last pizza came down, so a lost streak can be said at the spot that
## lost it. Set before the state is told, because the state answers immediately.
var _last_landing: Vector2 = Vector2.ZERO


func _ready() -> void:
	_state.bind_strike_capacity(_strikes.slot_count())
	_state.pizzas_changed.connect(_stack.show_pizzas)
	_state.strikes_changed.connect(_strikes.show_strikes)
	_state.strikes_changed.connect(_on_strikes_changed)
	_state.tips_changed.connect(_show_total)
	_state.streak_lost.connect(_on_streak_lost)
	_state.round_ended.connect(_on_round_ended)
	_result.again_pressed.connect(_on_again)
	_debug.win_requested.connect(_win_street_now)
	_result.hide()
	_pizza.visible = false
	_shadow.visible = false
	_ready_home = _ready_pizza.position
	_backdrop.projection = projection
	($Sky as NightSky).projection = projection
	($Street as StreetSurface).projection = projection
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
	_begin_hour(_config.time_of_day)
	_debug.bind_to(physics, _config)
	_street = StreetModel.new(_config, street_seed + _level_index, _house_body_size(),
		wall_doorstep)
	_travelled = 0.0
	_clear_flight()
	_clear_views()
	_result.hide()
	_strikes_seen = -1
	_state.begin(_config)


func _process(delta: float) -> void:
	if _street == null:
		return
	if not _state.is_over():
		_street.advance(delta)
		_travelled += _config.street_speed * delta
	_backdrop.set_travelled(_travelled)
	($Street as StreetSurface).set_travelled(_travelled)
	_advance_hour(delta)
	_sync_views()
	_advance_flight(delta)
	_update_ready_pizza(delta)


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
			# You have to actually take hold of the pizza, the way you take hold
			# of the ball in Pokemon GO. Otherwise a tap anywhere would teleport
			# it across the screen.
			if not _ready_pizza.visible or event.position.distance_to(_ready_pizza.position) > grab_radius:
				return
			_touch_index = event.index
			_drag_from = event.position
			_grab_offset = _ready_pizza.position - event.position
			_returning = false
			_gesture.begin(event.position, now)
			_audio.play(&"pick_up")
		elif event.index == _touch_index and _gesture.is_active():
			var flick := _gesture.release(event.position, now)
			var windup := _gesture.windup()
			_touch_index = -1
			_aim.clear()
			# A slow release is a fumble: the pizza drops back into your hand and
			# costs nothing. Only a real flick leaves the bike.
			if -flick.y < physics.min_throw_flick:
				_return_ready_pizza()
			else:
				_throw(flick, windup)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_gesture.update(event.position, now)
		_aim.show_for(_gesture.current_flick(), _gesture.windup())
		_show_windup(event.position)


func _throw(flick: Vector2, windup: float) -> void:
	if not _state.can_throw():
		return

	var launch := physics.launch_from(flick, windup)
	# The throw leaves from wherever the pizza was let go, not from the rider's
	# line, so dragging it sideways before releasing actually means something.
	launch["start_side"] = ((_ready_pizza.position.x - projection.centre_x)
		/ projection.pixels_per_unit) * drag_aim_gain
	_flight = PizzaFlight.new(physics, launch)
	_last_flick = -flick.y
	_audio.play(&"throw")
	_state.spend_pizza()
	_ready_pizza.visible = false
	_pizza.visible = true
	_pizza.rotation = 0.0
	_place_pizza()


func _advance_flight(delta: float) -> void:
	if _flight == null:
		return
	# Both ends of the step, because a house is hit somewhere between them: a hard
	# throw crosses more than a house's width in a single frame.
	var from := Vector3(_flight.side, _flight.height, _flight.distance)
	var landed := _flight.step(delta)
	var struck := _street.struck_house(
		from, Vector3(_flight.side, _flight.height, _flight.distance))
	if struck != null:
		# A pizza in the front door has arrived, whether or not it had got as far
		# as the ground.
		_resolve_landing(struck)
		return
	if landed:
		_resolve_landing()
		return
	_pizza.rotation += (pizza_tumble_rate + _flight.current_spin() * 8.0) * delta
	_place_pizza()


## `struck` is the house the pizza flew into, when it did. Without one the landing
## spot on the ground decides, as it always has.
func _resolve_landing(struck: House = null) -> void:
	_debug.show_throw(_last_flick, _flight.distance, _flight.side)
	var house: House = struck
	if house == null:
		house = _street.delivery_at(_flight.side, _flight.distance)
	# Where it ended, kept before the flight is dropped, so the tip can be shown
	# at the spot the player was looking at rather than somewhere generic.
	var landed_at := projection.project(_flight.side, 0.0, _flight.distance)
	_last_landing = landed_at
	var miss := 0.0
	if house != null:
		miss = house.miss_by(_flight.side, _flight.distance)
	_flight = null
	_pizza.visible = false
	_shadow.visible = false

	if house != null:
		house.served = true
		var tier := ScoreRules.ThrowTier.NICE
		if _state.scoring != null:
			# A pizza that went into the wall has no distance from the ring worth
			# reading, so it is told outright that it scraped in.
			tier = _state.scoring.tier_for(miss, house.drop_radius, struck != null)
		var award := _state.note_delivery(tier)
		_show_tip(landed_at, tier, award, _state.streak)
		_audio.play(&"delivered")
	else:
		_state.note_miss()
		_audio.play(&"missed")
	# Only now can the round be won: the last throw still had to land.
	_state.note_flight_settled()


# --- tips --------------------------------------------------------------------

## Say what the throw earned, where it landed. A tip nobody sees is only a number
## going up in the corner, and the corner is not where anyone is looking.
func _show_tip(at: Vector2, tier: ScoreRules.ThrowTier, award: int, streak: int) -> void:
	# The bills go up before the words do, and there are more of them for a better
	# throw. Across the room the burst is the only part anyone can read, so it has
	# to be the part that says how it went.
	_money.burst(at, _money.bills_for(tier))
	var rules: ScoreRules = _state.scoring
	if rules == null:
		return
	var run := ""
	if rules.streak_is_paying(streak):
		run = rules.label_streak % streak
	_tip_popup.show_tip(at, rules.label_for(tier), rules.label_tip % award, run,
		_tip_popup.colour_for(tier))


## A run ending is worth saying only when it was long enough to have been worth
## keeping. The popup goes where the miss happened, so it reads as the consequence
## of that throw rather than as an announcement.
func _on_streak_lost(had: int) -> void:
	var rules: ScoreRules = _state.scoring
	if rules == null:
		return
	# The wording may or may not want the number in it, so both spellings work
	# and neither crashes the round over a format string.
	var said := rules.label_streak_lost
	if said.contains("%d"):
		said = said % had
	_tip_popup.show_message(_last_landing, said, _tip_popup.colour_streak_lost)


func _show_total(total: int) -> void:
	if _state.scoring == null:
		return
	_tips.text = _state.scoring.label_total % total


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


## Clear the street outright. Only the debug panel asks for this, and it does it
## through the same moves a real win is made of, throwing the rest of the stack
## away and letting the round settle, rather than reaching past the rules. A
## street with no strikes left is already lost and stays lost.
func _win_street_now() -> void:
	if _state.is_over():
		return
	_clear_flight()
	while _state.can_throw():
		_state.spend_pizza()
	_state.note_flight_settled()


## Start crossing to a street's hour. The first street simply is its hour; every
## one after that is arrived at from wherever the last one left the sky.
func _begin_hour(hour: TimeOfDay) -> void:
	if hour == null:
		return
	_hour_from = _hour if _hour != null else hour
	_hour_to = hour
	_hour_blend = 0.0 if _hour != null and daylight_crossfade > 0.0 else 1.0
	_apply_hour(_hour_from.blended_with(_hour_to, _hour_blend))


func _advance_hour(delta: float) -> void:
	if _hour_blend >= 1.0 or _hour_to == null:
		return
	_hour_blend = minf(1.0, _hour_blend + delta / maxf(0.01, daylight_crossfade))
	_apply_hour(_hour_from.blended_with(_hour_to, _hour_blend))


## Hand the palette to everything that paints with it. The haze lives on the
## projection because the houses and the skyline ask it for their tint, so
## changing the hour changes those without either of them knowing about hours.
func _apply_hour(hour: TimeOfDay) -> void:
	_hour = hour

	var sky := ($Sky as ColorRect).material as ShaderMaterial
	if sky != null:
		sky.set_shader_parameter("top_colour", hour.sky_top)
		sky.set_shader_parameter("horizon_colour", hour.sky_horizon)
		sky.set_shader_parameter("star_brightness", hour.star_brightness)
		sky.set_shader_parameter("star_chance", hour.star_chance)

	var road := ($Street as ColorRect).material as ShaderMaterial
	if road != null:
		road.set_shader_parameter("asphalt", hour.asphalt)
		road.set_shader_parameter("asphalt_grain", hour.asphalt_grain)
		road.set_shader_parameter("verge_colour", hour.verge)
		road.set_shader_parameter("lane_colour", hour.lane)
		road.set_shader_parameter("haze_colour", hour.haze_colour)
		road.set_shader_parameter("haze_strength", hour.haze_strength)

	projection.haze_colour = hour.haze_colour
	projection.haze_strength = hour.haze_strength
	_backdrop.modulate = hour.world_tint
	_backdrop.queue_redraw()


## The pizza waiting in your hand, at the bottom of the screen. It is the thing
## you drag, so it has to be there before the throw rather than appearing only
## once one is in the air.
func _update_ready_pizza(delta: float) -> void:
	_ready_pizza.visible = _flight == null and not _state.is_over() and _state.can_throw()
	if _returning:
		return
	if _gesture.is_active():
		# Drain the wind-up every frame and re-read it, so a finger that stops
		# circling watches the spin run down instead of holding forever.
		_gesture.bleed(physics.windup_bleed * delta)
		_gesture.limit(physics.full_spin_windup * windup_headroom)
		_spin_now = physics.spin_from(_gesture.windup())
	else:
		_spin_now = 0.0
		_ready_pizza.position = _ready_home

	# The turn, swell and tint are eased towards their targets rather than set
	# outright. Set outright, every wobble of the hand showed up as a flick of
	# the wrist on screen.
	var blend: float = 1.0 - pow(windup_smoothing, delta * 60.0) if windup_smoothing > 0.0 else 1.0
	blend = clampf(blend, 0.0, 1.0)
	var charge: float = absf(_spin_now)
	if _gesture.is_active():
		# Keep turning while it is wound, faster the more spin is loaded.
		_ready_pizza.rotation += _spin_now * spin_visual_rate * delta
	else:
		_ready_pizza.rotation = lerpf(wrapf(_ready_pizza.rotation, -PI, PI), 0.0, blend)
	_ready_pizza.scale = _ready_pizza.scale.lerp(Vector2.ONE * lerpf(1.0, charged_scale, charge), blend)
	_ready_pizza.modulate = _ready_pizza.modulate.lerp(Color.WHITE.lerp(charged_tint, charge), blend)


## Carry the pizza with the finger, and note how much spin the throw would get.
## The turn shown is the spin itself, already past its deadzone, so idly moving
## the pizza about neither turns it nor loads a curve.
func _show_windup(touch: Vector2) -> void:
	var screen := get_viewport_rect().size
	_ready_pizza.position = (touch + _grab_offset).clamp(Vector2(120.0, 260.0), screen - Vector2(120.0, -120.0))


## Drop the pizza back into your hand after a release too slow to be a throw.
func _return_ready_pizza() -> void:
	_returning = true
	# Unwind by the short way round rather than spooling back through every
	# turn the pizza has just made.
	_ready_pizza.rotation = wrapf(_ready_pizza.rotation, -PI, PI)
	var tween := create_tween()
	tween.tween_property(_ready_pizza, "position", _ready_home, return_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_ready_pizza, "rotation", 0.0, return_duration)
	tween.parallel().tween_property(_ready_pizza, "scale", Vector2.ONE, return_duration)
	tween.parallel().tween_property(_ready_pizza, "modulate", Color.WHITE, return_duration)
	await tween.finished
	_returning = false


# --- houses -----------------------------------------------------------------

## How big a house's body is, in world units, taken from the house scene itself.
## Nobody types these numbers twice: whatever the scene is drawn at is what a
## pizza can hit, so moving a wall in the editor moves what the player is aiming
## at with it.
##
## Read once and kept. Instancing a scene to ask it its size is cheap, but there
## is no reason to do it every level.
func _house_body_size() -> Vector2:
	if not houses_are_solid:
		return Vector2.ZERO
	if _house_body != Vector2.ZERO:
		return _house_body
	var probe := house_scene.instantiate() as HouseView
	if probe == null:
		# The error for this is already raised where the views are made.
		return Vector2.ZERO
	_house_body = Vector2(probe.width, probe.wall_height + probe.roof_height)
	probe.free()
	return _house_body


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
	view.modulate = projection.haze_tint(house.distance) * _world_tint()
	view.show_state(house.waiting, house.served, house.drop_radius)


func _world_tint() -> Color:
	return _hour.world_tint if _hour != null else Color.WHITE


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

func _on_strikes_changed(left: int) -> void:
	# Only a strike being spent makes a noise; the first count of a fresh round
	# is not a loss and must stay silent.
	if _strikes_seen >= 0 and left < _strikes_seen:
		_audio.play(&"strike")
	_strikes_seen = left


func _on_round_ended(won: bool, delivered: int) -> void:
	_clear_flight()
	_audio.play(&"round_won" if won else &"round_lost")
	_result.show_result(won, delivered, _level_index + 1, _state.tips, _state.best_streak)
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
