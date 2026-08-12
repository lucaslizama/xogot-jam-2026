class_name SplatBurst
extends Node2D

## The pizza coming apart where it hit the road.
##
## A miss used to say only a sound and a crossed-off dot. The pizza left lying
## there says where the throw went; this says what happened to it, at the moment it
## happens, which is the part a player can read without looking away from the
## street.
##
## The opposite number to [MoneyBurst], and built the same way: pieces thrown out
## with a velocity, dragged and pulled down, fading as they go, all of it drawn from
## exported sizes and colours so a chunk becomes a picture the moment one is dropped
## into the art slot.
##
## Two things it does that the money does not. It is scaled by how far away the
## landing was, so a pizza lost at the far end of the street throws a small quiet
## spray rather than the same shower as one dropped at the rider's feet. And it
## takes its colours from the flavour that was thrown, so a hawaiian goes everywhere
## in gold and a pepperoni in red.

@export_group("How much")
## Pieces in one splat, before the ceiling.
@export_range(0, 80) var pieces: int = 16
## The most that may be in the air at once. A splat arriving while the last one is
## still falling adds to it, and a fast street throwing miss after miss would
## otherwise pile up hundreds for no gain anyone can see.
@export_range(1, 400) var max_pieces: int = 90

@export_group("Flight")
## Slower than money, and thrown wider. Paper is tossed up; a dropped pizza bursts
## sideways along the ground it hit.
@export_range(20.0, 2000.0, 10.0) var speed_min: float = 190.0
@export_range(20.0, 2000.0, 10.0) var speed_max: float = 620.0
@export_range(0.0, 4000.0, 10.0) var gravity: float = 1900.0
## Air resistance. Cheese does not glide.
@export_range(0.0, 6.0, 0.05) var drag: float = 2.1
@export_range(0.0, 30.0, 0.1) var spin_max: float = 14.0
@export_range(0.1, 4.0, 0.05) var life: float = 0.7
## How wide the spray is, in degrees either side of straight up. Wider than the
## money, because this is a burst outwards rather than a throw upwards.
@export_range(5.0, 180.0, 1.0) var spread_degrees: float = 96.0
## How much of the last of the fall is spent fading.
@export_range(0.05, 1.0, 0.05) var fade_last: float = 0.55

@export_group("Look")
## Radius of a piece in pixels, at the rider's own distance. Scaled down with
## everything else for a landing further up the street.
@export_range(2.0, 80.0, 0.5) var piece_size: float = 15.0
## The share of the pieces that are crust wedges rather than round blobs. The rest
## split between cheese and whatever was on top.
@export_range(0.0, 1.0, 0.05) var crust_share: float = 0.34
@export_range(0.0, 1.0, 0.05) var topping_share: float = 0.3
@export var crust: Color = Color(0.94902, 0.65098, 0.368627)
@export var crust_edge: Color = Color(0.729412, 0.380392, 0.337255, 0.8)
@export var cheese: Color = Color(1, 0.894118, 0.470588)
## Used for the topping pieces when the throw had no flavour on it at all.
@export var topping_fallback: Color = Color(0.690196, 0.188235, 0.360784)
## Drawn in place of all of the above, tinted with the piece's own colour so a
## single chunk image still comes apart in the flavour that was thrown.
@export var chunk_art: Texture2D

## Kinds of piece. Only what they are drawn as differs; they all fly the same.
enum Piece { CRUST, CHEESE, TOPPING }

var _bits: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(false)


## Burst at a point in the viewport. `world_scale` is what the street's perspective
## makes of that distance, so pass [method StreetProjection.scale_at]; `flavour`
## is what was thrown, and may be null.
func burst(at: Vector2, count: int, world_scale: float = 1.0,
		flavour: PizzaFlavour = null) -> void:
	if count <= 0 or world_scale <= 0.0:
		return
	var room := max_pieces - _bits.size()
	if room <= 0:
		return

	var topping_colour := topping_fallback
	var crust_colour := crust
	if flavour != null:
		topping_colour = flavour.topping
		# The base of the pizza doubles as its crust: a flavour dark enough to read
		# as burnt should throw dark crumbs.
		crust_colour = flavour.base.darkened(0.18)

	var spread := deg_to_rad(spread_degrees)
	for i in mini(count, room):
		var angle := -PI * 0.5 + _rng.randf_range(-spread, spread)
		# Speeds are in screen pixels, so they have to shrink with the distance too
		# or a far-off splat would fling debris across the whole screen.
		var speed := _rng.randf_range(speed_min, speed_max) * world_scale
		var kind := _kind_for(_rng.randf())
		var colour := crust_colour
		if kind == Piece.CHEESE:
			colour = cheese
		elif kind == Piece.TOPPING:
			colour = topping_colour
		_bits.append({
			"at": at,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"turn": _rng.randf_range(-PI, PI),
			"spin": _rng.randf_range(-spin_max, spin_max),
			"left": life,
			"kind": kind,
			"colour": colour,
			# Variety in size so a splat does not look stamped out, and the whole
			# spray sized by how far up the street it happened.
			"scale": _rng.randf_range(0.6, 1.25) * world_scale,
		})
	set_process(true)
	queue_redraw()


## Which kind a piece is, from one roll. Crust first, then topping, then cheese
## takes whatever is left, so the three shares cannot add up to more than everything.
func _kind_for(roll: float) -> Piece:
	if roll < crust_share:
		return Piece.CRUST
	if roll < crust_share + topping_share:
		return Piece.TOPPING
	return Piece.CHEESE


func _process(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for bit in _bits:
		bit["left"] -= delta
		if bit["left"] <= 0.0:
			continue
		var velocity: Vector2 = bit["velocity"]
		velocity.y += gravity * delta
		velocity -= velocity * drag * delta
		bit["velocity"] = velocity
		bit["at"] = bit["at"] + velocity * delta
		bit["turn"] = bit["turn"] + bit["spin"] * delta
		alive.append(bit)
	_bits = alive
	queue_redraw()
	if _bits.is_empty():
		set_process(false)


func _draw() -> void:
	for bit in _bits:
		var fade: float = clampf(bit["left"] / maxf(0.01, life * fade_last), 0.0, 1.0)
		draw_set_transform(bit["at"], bit["turn"], Vector2.ONE * bit["scale"])
		_draw_one(bit["kind"], bit["colour"], fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_one(kind: Piece, colour: Color, fade: float) -> void:
	var tint := Color(colour, colour.a * fade)
	if chunk_art != null:
		var rect := Rect2(Vector2.ONE * -piece_size, Vector2.ONE * piece_size * 2.0)
		draw_texture_rect(chunk_art, rect, false, tint)
		return
	if kind == Piece.CRUST:
		# A wedge, so the biggest pieces read as bits of a pizza rather than as
		# gravel. Drawn round the origin because the transform already turned it.
		var wedge := PackedVector2Array([
			Vector2(-piece_size, piece_size * 0.55),
			Vector2(piece_size, piece_size * 0.2),
			Vector2(piece_size * 0.4, -piece_size * 0.75),
		])
		draw_colored_polygon(wedge, tint)
		draw_polyline(wedge + PackedVector2Array([wedge[0]]),
			Color(crust_edge, crust_edge.a * fade), 2.0)
		return
	# Cheese and toppings are both blobs; the topping ones are smaller and rounder,
	# which is what tells them apart once they are in the air.
	var radius: float = piece_size * (0.62 if kind == Piece.TOPPING else 0.85)
	draw_circle(Vector2.ZERO, radius, tint)


## How many pieces are in the air right now. Only the tests ask.
func in_flight() -> int:
	return _bits.size()
