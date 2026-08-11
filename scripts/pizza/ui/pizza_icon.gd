@tool
class_name PizzaIcon
extends Control

## A pizza, drawn in code, sitting on the result card.
##
## Placeholder art in the house style: a stack of circles and a few blobs, sized
## and coloured from exports so it can be tuned before real art exists. Assign a
## texture to [member art] and the drawing steps aside.
##
## Two moods. A win shows a whole pie, face up, with pepperoni. A loss shows it
## flopped face-down on the floor with a slice broken off and cheese splattered
## beside it — the throw that never got delivered.
##
## Drawn in the editor as well as in the game, so a new piece of art can be judged
## in the card it sits in without running anything. The editor shows the win side;
## the loss only appears once [method set_dropped] is called at runtime.

@export_group("Size")
## Radius of the pie, in pixels. The node reserves a square this wide.
@export_range(20.0, 400.0, 1.0) var radius: float = 150.0:
	set(value):
		radius = value
		custom_minimum_size = Vector2(radius * 2.4, radius * 2.4)
		queue_redraw()

@export_group("Colours")
@export var crust: Color = Color(0.78, 0.55, 0.32)
@export var crust_rim: Color = Color(0.62, 0.41, 0.22)
@export var cheese: Color = Color(0.96, 0.78, 0.36)
@export var sauce: Color = Color(0.79, 0.29, 0.2)
@export var pepperoni: Color = Color(0.72, 0.19, 0.16)
## The underside, shown when the pizza has landed face-down on a loss.
@export var underside: Color = Color(0.66, 0.45, 0.26)
@export var floor_splat: Color = Color(0.86, 0.68, 0.34)

@export_group("Toppings")
@export_range(0, 20) var pepperoni_count: int = 7
## Fixes where the pepperoni sit, so the pie does not reshuffle every time it is
## shown. Change it to deal a different pizza.
@export var topping_seed: int = 7

@export_group("Art, when it arrives")
## Bottom-centred like the houses. Leave empty for the drawn placeholder.
@export var art_whole: Texture2D
@export var art_dropped: Texture2D

var _dropped: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.4, radius * 2.4)


## Whole pie for a win, flopped for a loss.
func set_dropped(dropped: bool) -> void:
	if dropped == _dropped:
		return
	_dropped = dropped
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	if _dropped:
		_draw_dropped(centre)
	else:
		_draw_whole(centre)


func _draw_whole(centre: Vector2) -> void:
	if art_whole != null:
		_draw_art(art_whole, centre)
		return
	# Crust, then the rim darker, then the cheese inset from it.
	draw_circle(centre, radius, crust)
	draw_arc(centre, radius - 3.0, 0.0, TAU, 64, crust_rim, 8.0)
	draw_circle(centre, radius * 0.82, sauce)
	draw_circle(centre, radius * 0.78, cheese)

	var rng := RandomNumberGenerator.new()
	rng.seed = topping_seed
	for i in pepperoni_count:
		# Spread across the pie but kept off the rim so none straddle the crust.
		var ang := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * radius * 0.62
		var spot := centre + Vector2(cos(ang), sin(ang)) * dist
		var r := radius * rng.randf_range(0.1, 0.14)
		draw_circle(spot, r, pepperoni)
		draw_circle(spot - Vector2(r * 0.25, r * 0.25), r * 0.35, pepperoni.lightened(0.25))


func _draw_dropped(centre: Vector2) -> void:
	if art_dropped != null:
		_draw_art(art_dropped, centre)
		return
	# Splats on the floor first, so the pie sits on top of them.
	draw_circle(centre + Vector2(radius * 0.9, radius * 0.55), radius * 0.18, floor_splat)
	draw_circle(centre + Vector2(-radius * 1.05, radius * 0.3), radius * 0.12, floor_splat)
	draw_circle(centre + Vector2(radius * 0.2, radius * 0.95), radius * 0.09, floor_splat)

	# The pie, tilted, showing its underside with a wedge broken away.
	var tilt := deg_to_rad(-18.0)
	draw_set_transform(centre, tilt, Vector2.ONE)
	# A wedge from a bit past the top to a bit before it, left as a gap.
	var pts := PackedVector2Array([Vector2.ZERO])
	var start := deg_to_rad(-58.0)
	var end := deg_to_rad(58.0)
	var steps := 24
	for i in steps + 1:
		var a := start + (end - start) * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, underside)
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 64, crust_rim, 8.0)
	# A couple of grease rings on the underside so it is not a blank disc.
	draw_arc(Vector2(radius * 0.2, -radius * 0.1), radius * 0.4, 0.0, TAU, 32, crust.darkened(0.15), 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_art(art: Texture2D, centre: Vector2) -> void:
	var w := radius * 2.0
	draw_texture_rect(art, Rect2(centre - Vector2(radius, radius), Vector2(w, w)), false)
