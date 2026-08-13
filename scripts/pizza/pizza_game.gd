class_name PizzaGame
extends Node2D

## Wires the throw, the street and the round together, and draws them.
##
## Everything with a rule in it lives elsewhere and is tested without a screen:
## the flight maths, the gesture reading, the street's streaming, the round's
## bookkeeping. This node's job is only to move numbers between them and put
## the result on the display.

signal round_ended(won: bool, delivered: int)
## Which flavour is now in hand. Nothing about the round changes with it; it is
## here for whatever comes to keep score of orders.
signal flavour_changed(flavour: PizzaFlavour)

@export_group("Content")
## Levels in order. Later entries should be tighter: fewer strikes, faster
## street, houses further back. The last one repeats if the player gets past it.
@export var levels: Array[LevelConfig] = []
@export var physics: PizzaPhysics
@export var projection: StreetProjection
@export var house_scene: PackedScene
## What the shop sells. Leave it unset and there are no flavours, the swap does
## nothing, and the pizza is the plain one the scene draws.
@export var menu: PizzaMenu

@export_group("Flow")
@export var start_automatically: bool = true
## Streets are generated from this plus the level number, so a run is
## reproducible while every level still looks different.
@export var street_seed: int = 20260807

@export_group("Daylight")
## How long the sky takes to cross from one street's hour to the next. The sun
## should be seen coming up, not be found already up.
@export_range(0.0, 12.0, 0.1) var daylight_crossfade: float = 2.5

## Clear space left between the bottom of the strike dots and the top of the order
## ticket. The ticket's own y in the scene is overridden from this: the dots are a
## container whose height depends on how many the level asked for and how big the
## art is, so the only safe place for the ticket is however far below wherever they
## actually end.
## Thirty was what the two happened to clear each other by when both were placed by
## hand, and on a phone that is under two millimetres: the dots sit directly over
## the ticket's width, so at that distance they read as one crowded block and the
## row looks like it is resting on the card. Seventy separates them.
@export_range(0.0, 240.0, 2.0) var ticket_gap_below_strikes: float = 70.0

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
## A tap on the road, away from the pizza, changes what is on the next one.
##
## It costs no screen space and no new gesture because that touch was already
## being thrown away: a press outside [member grab_radius] has always been
## discarded outright. What it does cost is time, which is the point — a couple of
## taps at a quarter of a second each, spent while a house is closing on you.
@export var tap_swaps_flavour: bool = true
## A ring outside [member grab_radius] where a tap does nothing at all.
##
## Without it, reaching for the pizza and missing it by a few pixels would quietly
## change the flavour, which is a bad thing to have happen in the middle of a
## throw. The dead band makes a swap something you meant.
@export_range(0.0, 400.0, 10.0) var swap_clearance: float = 120.0
## How far a touch may travel and still count as a tap. Anything further is a
## finger going somewhere, not asking for a different pizza.
@export_range(0.0, 200.0, 5.0) var swap_tap_slop: float = 40.0
## And how long it may be held. A press left down is not a tap either.
@export_range(0.05, 2.0, 0.05) var swap_tap_time: float = 0.5
## How long the pizza takes to drop back into your hand after a fumble.
@export_range(0.0, 1.0, 0.01) var return_duration: float = 0.18
## How much the pizza's sideways position at release shifts where the throw
## starts from. 1.0 means the throw leaves from exactly where you let go.
@export_range(0.0, 3.0, 0.05) var drag_aim_gain: float = 1.0
## The same for up and down. At 0 every throw begins at the rider's own release
## height however high the pizza was held, which is what makes it appear to drop
## to the bottom of the screen the moment it is let go. At 1 it begins at the
## height the pizza was actually at, and the throw carries on from where the eye
## last saw it.
##
## It is not free: a pizza that starts higher is in the air longer and so travels
## further. Held at the top of the screen it goes about two thirds further than
## the same flick from the hand, so the street's distances are worth a look after
## changing it. Set it to 0 to have exactly the old behaviour back.
@export_range(0.0, 1.0, 0.05) var drag_lift_gain: float = 1.0
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
## How long a missed pizza lies on the road before it starts to fade, and how long
## the fade takes. A win says what it earned with money and words; a miss said only
## the sound and a crossed dot, and the pizza itself vanished mid-air, which left
## nothing on screen to say where the throw actually went. Long enough to read,
## short enough that the road is clear again before the next house arrives.
## Both at zero leaves a miss as it was, with nothing lying on the road.
@export_range(0.0, 3.0, 0.05) var splat_hold: float = 0.45
@export_range(0.0, 2.0, 0.05) var splat_fade: float = 0.55

@onready var _state: LevelState = $LevelState
@onready var _audio: GameAudio = $Audio
@onready var _music: GameMusic = $Music
@onready var _backdrop: Backdrop = $Backdrop
@onready var _houses_root: Node2D = $Houses
@onready var _pizza: PizzaView = $Pizza
@onready var _shadow: GroundShadow = $Shadow
@onready var _ready_pizza: PizzaView = $ReadyPizza
@onready var _splat: Node2D = $Splat
@onready var _aim: AimPreview = $AimPreview
@onready var _rider: RiderView = %Rider
@onready var _strikes: StrikeDots = %StrikeDots
@onready var _tips: Label = %Tips
@onready var _tip_popup: TipPopup = %TipPopup
@onready var _money: MoneyBurst = %MoneyBurst
@onready var _splatter: SplatBurst = %SplatBurst
@onready var _handoff: Handoff = %Handoff
@onready var _ticket: OrderTicket = %OrderTicket
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
## Read off the house scene once by _measure_house.
var _house_body: Vector2 = Vector2.ZERO
var _house_window: Vector2 = Vector2.ZERO
var _house_window_centre_value: float = 0.0
var _measured: bool = false
## Held between the round ending and the card appearing, since the handoff sits
## between the two.
var _pending_won: bool = false
var _pending_delivered: int = 0
## Where the last pizza came down, so a lost streak can be said at the spot that
## lost it. Set before the state is told, because the state answers immediately.
var _last_landing: Vector2 = Vector2.ZERO
## The dropped pizza lying on the road. Held in street coordinates rather than as a
## screen position, and scrolled the way the houses are, so it stays on the piece of
## road it landed on instead of sliding along with the camera.
var _splat_side: float = 0.0
var _splat_distance: float = 0.0
## Counts down through the hold and then the fade; zero means nothing is lying there.
var _splat_left: float = 0.0
## Which way up the menu is. Counted rather than wrapped, so the menu decides how
## long it is and this never has to know.
var _flavour_at: int = 0
## The touch that might turn out to be a tap on the road, and where and when it
## started. A tap is only known to be one when it is let go, so the press has to be
## remembered until then.
var _swap_index: int = -1
var _swap_from: Vector2
var _swap_began: float = 0.0
## The tickets from the shop. Made once and told to begin again at each street, so
## nothing about it outlives a round.
var _orders := OrderBoard.new()
## What the pizza in the air was topped with, taken at release. Not read back off
## the pizza when it lands, because by then it may have been retopped for the next
## throw and the order would be credited to the wrong flavour.
var _flight_flavour: PizzaFlavour


func _ready() -> void:
	_state.bind_strike_capacity(_strikes.slot_count())
	_state.pizzas_changed.connect(_stack.show_pizzas)
	_state.strikes_changed.connect(_strikes.show_strikes)
	_state.strikes_changed.connect(_on_strikes_changed)
	_state.tips_changed.connect(_show_total)
	_state.streak_lost.connect(_on_streak_lost)
	_state.round_ended.connect(_on_round_ended)
	_result.again_pressed.connect(_on_again)
	_handoff.finished.connect(_show_result_card)
	_debug.win_requested.connect(_win_street_now)
	_orders.opened.connect(_ticket.show_order)
	_orders.progressed.connect(_on_order_progressed)
	_orders.completed.connect(_on_order_filled)
	_orders.expired.connect(_on_order_lost)
	_result.hide()
	_pizza.visible = false
	_shadow.visible = false
	_splat.visible = false
	_ready_home = _ready_pizza.position
	# After _ready_home, which is what a tap is measured against: the pizza itself
	# wanders about while it is being dragged, and the ring must not wander with it.
	_apply_flavour()
	_backdrop.projection = projection
	($Sky as NightSky).projection = projection
	($Street as StreetSurface).projection = projection
	_aim.projection = projection
	_aim.physics = physics
	_place_ticket_below_strikes()
	get_viewport().size_changed.connect(_place_ticket_below_strikes)
	# The rider is placed in world space and never moves, so once is enough: unlike
	# the ticket, the stack no longer depends on the shape of the screen at all.
	_stack.place_on(_rider.rack_rect())

	if start_automatically:
		# Deferred: the first houses would otherwise be added while this node is
		# still setting up its own children.
		start_level.call_deferred()


## Sit the order ticket below the strike dots rather than at the y it was authored
## at. Done here, in the glue, because it is the one place that knows about both.
##
## Run again whenever the window changes shape: the dots are centred on a viewport
## whose size is not the one in the project settings on most phones, and the ticket
## arriving on top of them is the sort of thing only the real device shows.
func _place_ticket_below_strikes() -> void:
	_ticket.position.y = _strikes.bottom_edge() + ticket_gap_below_strikes


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
	# The street's own music, at the street's own speed. Told here rather than in
	# _ready because a run crosses three streets without the scene being rebuilt.
	_music.play_for_level(_level_index, _config.music_speed)
	_debug.bind_to(physics, _config)
	_street = StreetModel.new(_config, street_seed + _level_index, _house_body_size(),
		wall_doorstep, _house_window_size(), _house_window_centre())
	_travelled = 0.0
	_clear_flight()
	_clear_views()
	_result.hide()
	_strikes_seen = -1
	_state.begin(_config)
	_ticket.clear()
	_orders.begin(_orders_for(_config), menu, street_seed + _level_index * 7919)


func _process(delta: float) -> void:
	if _street == null:
		return
	if not _state.is_over():
		_street.advance(delta)
		_travelled += _config.street_speed * delta
		_orders.advance(delta)
		_ticket.show_clock_of(_orders.open_order())
	_backdrop.set_travelled(_travelled)
	($Street as StreetSurface).set_travelled(_travelled)
	_advance_hour(delta)
	_sync_views()
	_advance_flight(delta)
	_advance_splat(delta)
	_update_ready_pizza(delta)


# --- throwing ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _street == null or _state.is_over():
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0

	if event is InputEventScreenTouch:
		if event.pressed:
			# Well clear of the pizza, so it cannot be a reach for it. Noted as a
			# possible tap and answered on release, since a press that turns into a
			# drag is a finger going somewhere and means nothing here.
			if _is_clear_of_the_pizza(event.position):
				_swap_index = event.index
				_swap_from = event.position
				_swap_began = now
				return
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
			# She winds up the moment the pizza is in hand, not on the first drag,
			# so taking hold of it is answered even if the finger never moves.
			_rider.set_aiming(true)
			_audio.play(&"pick_up")
		elif event.index == _swap_index:
			var held := now - _swap_began
			# Typed rather than inferred: an InputEvent's position is a Variant, so
			# the distance off it is one too, and := has nothing to work from.
			var moved: float = event.position.distance_to(_swap_from)
			_swap_index = -1
			if held <= swap_tap_time and moved <= swap_tap_slop:
				_next_flavour()
		elif event.index == _touch_index and _gesture.is_active():
			var flick := _gesture.release(event.position, now)
			var windup := _gesture.windup()
			_touch_index = -1
			_aim.clear()
			_rider.set_aiming(false)
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
	elif event is InputEventScreenDrag and event.index == _swap_index:
		# Gone too far to be a tap. Given up on here rather than at the release, so
		# a long drag that happens to end near where it began is not mistaken for
		# one either.
		if event.position.distance_to(_swap_from) > swap_tap_slop:
			_swap_index = -1


# --- what is on the next one -------------------------------------------------

## Whether a touch is far enough from the waiting pizza to be about the menu
## rather than about the throw. Everything inside the grab ring plus its clearance
## belongs to the pizza, whether or not one is showing: the ring does not move when
## the pizza is in the air, so the same patch of screen means the same thing all
## the way through a throw.
func _is_clear_of_the_pizza(where: Vector2) -> bool:
	if not tap_swaps_flavour or menu == null or menu.count() < 2:
		return false
	return where.distance_to(_ready_home) > grab_radius + swap_clearance


## Move one along the menu. Wraps by counting upwards, so adding a fourth flavour
## needs nothing here.
func _next_flavour() -> void:
	_flavour_at += 1
	_apply_flavour()
	_audio.play(&"pick_up")


## Put the flavour on the pizza in your hand, and say so.
##
## Only the waiting one. A pizza already in the air was thrown as whatever it was,
## and changing it mid-flight would let a player pick the flavour after seeing
## where the throw was going to land.
func _apply_flavour() -> void:
	var flavour := current_flavour()
	_ready_pizza.flavour = flavour
	flavour_changed.emit(flavour)


## What the next throw will be. Null when there is no menu at all.
func current_flavour() -> PizzaFlavour:
	return menu.flavour_at(_flavour_at) if menu != null else null


func _throw(flick: Vector2, windup: float) -> void:
	if not _state.can_throw():
		return

	var launch := physics.launch_from(flick, windup)
	# The throw leaves from wherever the pizza was let go, not from the rider's
	# line, so dragging it sideways before releasing actually means something.
	launch["start_side"] = ((_ready_pizza.position.x - projection.centre_x)
		/ projection.pixels_per_unit) * drag_aim_gain
	launch["start_height"] = _release_height_at(_ready_pizza.position.y)
	_flight = PizzaFlight.new(physics, launch)
	_last_flick = -flick.y
	_audio.play(&"throw")
	_state.spend_pizza()
	_ready_pizza.visible = false
	_pizza.visible = true
	_pizza.rotation = 0.0
	# Fixed at the moment of release. What is in the air is what was in the hand,
	# and tapping while it flies is preparing the next one.
	_flight_flavour = current_flavour()
	_pizza.flavour = _flight_flavour
	_place_pizza()


## What height a pizza let go at this point on the screen should start its flight
## at, so the throw carries on from where it was rather than reappearing lower.
##
## Inverting the projection is straightforward at the rider's own distance, where
## nothing is scaled: a row on screen is the ground line less the height times the
## pixels a unit is worth.
##
## Never below the rider's own release height, for two reasons. A pizza in hand is
## drawn below the street's ground line, so an honest reading of a low hold is a
## negative height, which is underground and would land on the frame it was
## thrown. And it means this can only ever add: a throw from down by the bike goes
## exactly as far as it always did, so nothing anybody had learned is taken away.
func _release_height_at(screen_y: float) -> float:
	var mapped := (projection.near_ground_y - screen_y) / projection.pixels_per_unit
	return lerpf(physics.release_height, maxf(physics.release_height, mapped),
		drag_lift_gain)


func _advance_flight(delta: float) -> void:
	if _flight == null:
		return
	# Both ends of the step, because a house is hit somewhere between them: a hard
	# throw crosses more than a house's width in a single frame.
	var from := Vector3(_flight.side, _flight.height, _flight.distance)
	var landed := _flight.step(delta)
	var to := Vector3(_flight.side, _flight.height, _flight.distance)
	var struck := _street.struck_house(from, to)
	if struck != null:
		# A pizza in the front door has arrived, whether or not it had got as far
		# as the ground. Where in the front matters: the window is worth more than
		# the wall around it, so the house is asked which it was.
		_resolve_landing(struck, struck.hit_by(from, to))
		return
	if landed:
		_resolve_landing()
		return
	_pizza.rotation += (pizza_tumble_rate + _flight.current_spin() * 8.0) * delta
	_place_pizza()


## `struck` is the house the pizza flew into, when it did. Without one the landing
## spot on the ground decides, as it always has.
func _resolve_landing(struck: House = null,
		hit: House.HouseHit = House.HouseHit.NONE) -> void:
	_debug.show_throw(_last_flick, _flight.distance, _flight.side)
	var house: House = struck
	if house == null:
		house = _street.delivery_at(_flight.side, _flight.distance)
	# Where it ended, kept before the flight is dropped, so the tip can be shown
	# at the spot the player was looking at rather than somewhere generic.
	var landed_at := projection.project(_flight.side, 0.0, _flight.distance)
	_last_landing = landed_at
	# Kept too, because a dropped pizza has to be scrolled along the street after the
	# flight that put it there is gone.
	var landed_side := _flight.side
	var landed_distance := _flight.distance
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
			if hit == House.HouseHit.WINDOW:
				tier = ScoreRules.ThrowTier.WINDOW
			else:
				# A pizza that went into the wall has no distance from the ring
				# worth reading, so it is told outright that it scraped in.
				tier = _state.scoring.tier_for(miss, house.drop_radius, struck != null)
		var award := _state.note_delivery(tier)
		_show_tip(landed_at, tier, award, _state.streak)
		_audio.play(&"delivered")
		# After the tip, so an order being filled has the last word on screen rather
		# than arriving underneath what the throw itself paid.
		_orders.note_delivery(_flight_flavour)
	else:
		_drop_splat(landed_side, landed_distance)
		# The pizza comes apart before it is lying there. Sized and sorted by how far
		# up the street it happened, so a loss at the far end is a small spray behind
		# the houses rather than the same shower as one at the rider's feet.
		_splatter.z_index = clampi(int(-landed_distance), -4000, 4000)
		_splatter.burst(landed_at, _splatter.pieces,
			projection.scale_at(landed_distance), _flight_flavour)
		_state.note_miss()
		_audio.play(&"missed")
	# Only now can the round be won: the last throw still had to land.
	_state.note_flight_settled()


# --- orders ------------------------------------------------------------------

## Which rules a street takes its orders from, clamped to what the ticket can draw.
##
## A rules file asking for more flavours in one ticket than the scene has rows would
## put a line on the ticket the player cannot see, and then hold the order open
## waiting for a pizza nothing ever asked for. Clamped on a copy so the file on disk
## is left as the designer wrote it.
func _orders_for(config: LevelConfig) -> OrderRules:
	if config == null or config.orders == null:
		return null
	return _orders_for_rules(config.orders)


## The clamp itself, apart from the level that carried the rules, so it can be
## checked without authoring a level to check it with.
func _orders_for_rules(rules: OrderRules) -> OrderRules:
	var rows := _ticket.line_capacity()
	if rules.kinds_max <= rows:
		return rules
	push_warning("PizzaGame: order rules ask for up to %d flavours a ticket but the ticket scene only has %d rows; clamping. Add rows in order_ticket.tscn to raise the ceiling."
		% [rules.kinds_max, rows])
	var clamped := rules.duplicate() as OrderRules
	clamped.kinds_max = rows
	return clamped


func _on_order_progressed(order: PizzaOrder) -> void:
	_ticket.update_order(order)


## Filling one pays, and on the harder streets hands a spent chance back. The money
## bursts where the last pizza landed rather than over the ticket: that is where the
## player is looking, and it is the throw that earned it.
func _on_order_filled(order: PizzaOrder) -> void:
	_state.award_bonus(order.pays)
	var gave_one_back := order.gives_strike_back and _state.restore_strike()
	_ticket.update_order(order)
	_ticket.close_order(_ticket.filled_wording, _ticket.line_filled, order.pays,
		gave_one_back)
	_money.burst(_last_landing, _money.bills_for(ScoreRules.ThrowTier.WINDOW))
	_audio.play(&"delivered")


## Losing one costs nothing but the bonus, so it is said quietly and with no sound.
## A noise here would be indistinguishable from a strike.
func _on_order_lost(_order: PizzaOrder) -> void:
	_ticket.close_order(_ticket.expired_wording, _ticket.line_owed, 0, false)


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


# --- the pizza that did not make it -----------------------------------------

## Leave the dropped pizza on the road where the throw ended. The only thing on
## screen that says where a miss went: the flying pizza is hidden the instant it
## lands, so without this a bad throw disappears in mid-air and the player is left
## to work out what happened from a sound and a crossed-off dot.
func _drop_splat(side: float, distance: float) -> void:
	if splat_hold <= 0.0 and splat_fade <= 0.0:
		return
	_splat_side = side
	_splat_distance = distance
	_splat_left = splat_hold + splat_fade
	_splat.modulate.a = 1.0
	_splat.visible = true
	_advance_splat(0.0)


## Scrolled along with the houses and faded out where it lies. Kept in street
## coordinates and reprojected every frame, so it sits on its piece of road rather
## than hanging in one spot on screen while the street moves under it.
func _advance_splat(delta: float) -> void:
	if _splat_left <= 0.0:
		return
	_splat_left -= delta
	if _splat_left <= 0.0:
		_splat.visible = false
		return
	if not _state.is_over():
		_splat_side -= _config.street_speed * delta
	_splat.position = projection.project(_splat_side, 0.0, _splat_distance)
	var scale := projection.scale_at(_splat_distance)
	_splat.scale = Vector2(scale, scale)
	_splat.z_index = clampi(int(-_splat_distance), -4000, 4000)
	# Full strength through the hold, then down to nothing across the fade, which
	# falls out of one countdown rather than needing two.
	_splat.modulate.a = clampf(_splat_left / maxf(splat_fade, 0.001), 0.0, 1.0)


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
	_measure_house()
	return _house_body


## The window a pizza can go through, read off the same scene that draws it. Zero
## while the houses are not solid, since a window in thin air is not a target.
func _house_window_size() -> Vector2:
	if not houses_are_solid:
		return Vector2.ZERO
	_measure_house()
	return _house_window


func _house_window_centre() -> float:
	_measure_house()
	return _house_window_centre_value


## Ask the house scene its measurements, once. Instancing a scene to ask it its
## size is cheap, but there is no reason to do it every level.
func _measure_house() -> void:
	if _measured:
		return
	var probe := house_scene.instantiate() as HouseView
	if probe == null:
		# The error for this is already raised where the views are made.
		return
	_measured = true
	_house_body = Vector2(probe.width, probe.wall_height + probe.roof_height)
	_house_window = probe.window_size
	_house_window_centre_value = probe.window_centre
	probe.free()


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
	# A pizza dropped on the last street does not belong on the next one.
	_splat_left = 0.0
	_splat.visible = false
	_aim.clear()
	_rider.set_aiming(false)


# --- the round ---------------------------------------------------------------

func _on_strikes_changed(left: int) -> void:
	# Only a strike being spent makes a noise; the first count of a fresh round
	# is not a loss and must stay silent.
	if _strikes_seen >= 0 and left < _strikes_seen:
		_audio.play(&"strike")
	_strikes_seen = left


func _on_round_ended(won: bool, delivered: int) -> void:
	_clear_flight()
	# Silently, verdict and all. A street ending under an open ticket is not the
	# player having failed that ticket, and "order gone" over the result card would
	# say it was.
	_orders.close()
	_ticket.clear()
	_audio.play(&"round_won" if won else &"round_lost")
	# A street cleared is passed on to the next rider before the card says what it
	# paid. A street lost has nothing to hand over, so it goes straight to the
	# card: making somebody watch a triumphant relay after being fired would be a
	# joke at their expense.
	_pending_won = won
	_pending_delivered = delivered
	if won and _handoff != null:
		_handoff.play()
		return
	_show_result_card()


## Deliberately driven by the handoff's signal rather than by awaiting it here. A
## round handler left waiting on a beat is a coroutine suspended for good if the
## scene goes away mid-beat, holding the tween with it.
func _show_result_card() -> void:
	_result.show_result(_pending_won, _pending_delivered, _level_index + 1,
		_state.tips, _state.best_streak, _orders.filled, _orders.filled + _orders.lost)
	round_ended.emit(_pending_won, _pending_delivered)


func _on_again() -> void:
	# Winning moves you up the list; losing puts you back on the same street.
	if _result.was_won():
		_level_index = mini(_level_index + 1, maxi(0, levels.size() - 1))
	start_level()


func _level_at(index: int) -> LevelConfig:
	if levels.is_empty():
		return null
	return levels[clampi(index, 0, levels.size() - 1)]
