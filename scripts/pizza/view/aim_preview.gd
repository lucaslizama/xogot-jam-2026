class_name AimPreview
extends Node2D

## The dotted arc and landing ring shown while a throw is being wound up.
##
## Judging depth in a flat drawing that pretends to have depth is close to
## impossible without help: a pizza high and near looks exactly like one low and
## far. This draws where the current drag would actually put it.
##
## The path comes from the same flight maths that will run once the throw is
## released, so the preview cannot drift out of step with the game.

@export var projection: StreetProjection
@export var physics: PizzaPhysics
## Off by default. The arc is rebuilt each drag event from the flick velocity of
## the last instant, which is genuinely noisy, so it darts about and reads as
## unreliable rather than helpful. Pokémon GO shows no arc either. Turn it on if
## a calmer version is ever wanted.
@export var enabled: bool = false

@export_group("Look")
@export var arc_colour: Color = Color(1.0, 1.0, 1.0, 0.32)
@export var arc_width: float = 5.0
@export var marker_colour: Color = Color(0.24, 0.71, 0.9, 0.75)
## Radius of the landing ring, in world units. Matching a level's drop radius
## makes the preview honest about how much room there is for error.
@export_range(0.2, 20.0, 0.1) var marker_radius: float = 3.4

var _path := PackedVector3Array()


## Show the throw this drag would make. Pass the flick and wind-up as they stand.
##
## Traced from the rider's own line at the rider's own release height, which is
## not where the pizza is once it has been dragged: the real throw starts from
## where it was let go, sideways and now upwards too. The two therefore disagree,
## by more the further the pizza has been moved. It does not show today because
## this is switched off, but anyone turning it on should pass the release point in
## rather than trust the line.
func show_for(flick: Vector2, windup: float) -> void:
	if not enabled or physics == null or projection == null:
		return
	if -flick.y < physics.min_throw_flick:
		# Too slow to be a throw yet, so promise nothing.
		clear()
		return
	_path = PizzaFlight.trace(physics, physics.launch_from(flick, windup))
	queue_redraw()


func clear() -> void:
	if _path.is_empty():
		return
	_path = PackedVector3Array()
	queue_redraw()


func _draw() -> void:
	if _path.size() < 2 or projection == null:
		return

	# Dashes rather than a solid line: it reads as a guess instead of a rail.
	for i in range(0, _path.size() - 1, 2):
		var a := _path[i]
		var b := _path[i + 1]
		draw_line(
			projection.project(a.x, a.y, a.z),
			projection.project(b.x, b.y, b.z),
			arc_colour, arc_width)

	var landing := _path[_path.size() - 1]
	var centre := projection.project(landing.x, 0.0, landing.z)
	var radius: float = marker_radius * projection.pixels_per_unit * projection.scale_at(landing.z)
	# Squashed, because it is lying on the road rather than facing the camera.
	draw_set_transform(centre, 0.0, Vector2(1.0, 0.38))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, marker_colour, 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
