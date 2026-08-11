class_name MoneyBurst
extends Node2D

## Bills thrown into the air where a pizza was delivered.
##
## How many depends on how good the throw was. That is the whole point of it: a
## bullseye should look different from a scrape from across the room, without
## anyone reading a word. The tip that floats up says the number; this says how
## pleased the street is, and it says it first.
##
## Everything is drawn from exported sizes and colours, so a bill becomes a
## picture the moment one is dropped into the art slot, with nothing to delete.
##
## Positions are the viewport's own, because this sits in the same layer the
## pizza's landing point was worked out in.

@export_group("How much")
## A bullseye is meant to be worth showing off about.
@export_range(0, 60) var bills_bullseye: int = 24
@export_range(0, 60) var bills_nice: int = 12
## A scrape still pays, so it still shows something, just not a party.
@export_range(0, 60) var bills_scraped: int = 5
## The most that may be in the air at once. A burst arriving while the last one
## is still falling adds to it, and without a ceiling a fast street could pile up
## hundreds of them for no gain anyone can see.
@export_range(1, 300) var max_bills: int = 90

@export_group("Flight")
@export_range(50.0, 2000.0, 10.0) var speed_min: float = 340.0
@export_range(50.0, 2000.0, 10.0) var speed_max: float = 820.0
@export_range(0.0, 4000.0, 10.0) var gravity: float = 1500.0
## Air resistance. Paper does not fly like a stone, and without this the bills
## arc like thrown gravel.
@export_range(0.0, 6.0, 0.05) var drag: float = 1.3
@export_range(0.0, 20.0, 0.1) var spin_max: float = 9.0
@export_range(0.1, 4.0, 0.05) var life: float = 1.15
## How wide the spray is, in degrees either side of straight up.
@export_range(5.0, 180.0, 1.0) var spread_degrees: float = 64.0
## How much the last of the fall is spent fading. At 0.4 a bill is solid for the
## first sixty per cent of its life and gone by the end.
@export_range(0.05, 1.0, 0.05) var fade_last: float = 0.45

@export_group("Look")
@export var bill_size: Vector2 = Vector2(56.0, 28.0)
@export var note: Color = Color(0.35294118, 0.87058824, 0.47058824)
## The band down the middle, so a bill reads as a bill and not as a green brick.
@export var note_band: Color = Color(0.83, 0.98, 0.85, 0.85)
@export var note_edge: Color = Color(0.09, 0.32, 0.18, 0.75)
## Drawn in place of everything above, filling the same rectangle.
@export var bill_art: Texture2D

## side and spin are per bill; everything else is shared.
var _bills: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(false)


## Throw `count` bills into the air at a point in the viewport.
func burst(at: Vector2, count: int) -> void:
	if count <= 0:
		return
	var room := max_bills - _bills.size()
	if room <= 0:
		return
	var spread := deg_to_rad(spread_degrees)
	for i in mini(count, room):
		# Straight up is -PI/2 on screen, and the spread opens either side of it.
		var angle := -PI * 0.5 + _rng.randf_range(-spread, spread)
		var speed := _rng.randf_range(speed_min, speed_max)
		_bills.append({
			"at": at,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"turn": _rng.randf_range(-PI, PI),
			"spin": _rng.randf_range(-spin_max, spin_max),
			"left": life,
			# A little variety in size, so a burst does not look stamped out.
			"scale": _rng.randf_range(0.82, 1.18),
		})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for bill in _bills:
		bill["left"] -= delta
		if bill["left"] <= 0.0:
			continue
		var velocity: Vector2 = bill["velocity"]
		velocity.y += gravity * delta
		velocity -= velocity * drag * delta
		bill["velocity"] = velocity
		bill["at"] = bill["at"] + velocity * delta
		bill["turn"] = bill["turn"] + bill["spin"] * delta
		alive.append(bill)
	_bills = alive
	queue_redraw()
	if _bills.is_empty():
		set_process(false)


func _draw() -> void:
	for bill in _bills:
		var fade: float = clampf(bill["left"] / maxf(0.01, life * fade_last), 0.0, 1.0)
		draw_set_transform(bill["at"], bill["turn"], Vector2.ONE * bill["scale"])
		_draw_one(fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_one(fade: float) -> void:
	var rect := Rect2(-bill_size * 0.5, bill_size)
	if bill_art != null:
		draw_texture_rect(bill_art, rect, false, Color(1.0, 1.0, 1.0, fade))
		return
	draw_rect(rect, Color(note, note.a * fade))
	# A band across the middle and a line round the edge: enough for the eye to
	# call it paper money at the size it goes past.
	draw_rect(Rect2(rect.position + Vector2(0.0, bill_size.y * 0.38),
		Vector2(bill_size.x, bill_size.y * 0.24)), Color(note_band, note_band.a * fade))
	draw_rect(rect, Color(note_edge, note_edge.a * fade), false, 2.0)


## How many bills a tier is worth, so the caller does not have to know the map.
func bills_for(tier: ScoreRules.ThrowTier) -> int:
	match tier:
		ScoreRules.ThrowTier.BULLSEYE:
			return bills_bullseye
		ScoreRules.ThrowTier.NICE:
			return bills_nice
		_:
			return bills_scraped


## How many are in the air right now. Only the tests ask.
func in_flight() -> int:
	return _bills.size()
