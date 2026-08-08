class_name HouseView
extends Node2D

## Draws one house. Placeholder art: everything here is rectangles and a circle,
## drawn from exported sizes so the shape can be nudged in the editor before any
## real art exists.
##
## When sprites arrive this should become Sprite2D children instead, and the
## drawing below should go. The exported values are already the right ones to
## hand to an artist as the sizes to draw to.
##
## The node's origin is the point where the house meets the ground, because that
## is the point the street projects. Scale comes from the parent, which knows
## how far away this house is.

@export_group("Shape, in world units")
@export_range(1.0, 30.0, 0.1) var width: float = 8.0
@export_range(1.0, 30.0, 0.1) var wall_height: float = 5.0
@export_range(0.0, 15.0, 0.1) var roof_height: float = 2.6
## Pixels per world unit at the rider's distance. Must match the projection
## resource, or houses will not sit at the size the street expects.
@export_range(1.0, 400.0, 1.0) var pixels_per_unit: float = 46.0

@export_group("Colours")
@export var wall_waiting: Color = Color(0.62, 0.44, 0.36)
@export var wall_scenery: Color = Color(0.28, 0.26, 0.32)
@export var wall_served: Color = Color(0.34, 0.47, 0.32)
@export var roof: Color = Color(0.36, 0.22, 0.24)
@export var window_lit: Color = Color(1.0, 0.85, 0.45)
@export var drop_open: Color = Color(0.24, 0.71, 0.9, 0.55)
@export var drop_served: Color = Color(0.45, 0.85, 0.5, 0.5)

var _waiting: bool = true
var _served: bool = false
var _drop_radius: float = 3.2


## Told by the street each frame. Redraws only when something actually changed,
## since most houses are static most of the time.
func show_state(waiting: bool, served: bool, drop_radius: float) -> void:
	if waiting == _waiting and served == _served and is_equal_approx(drop_radius, _drop_radius):
		return
	_waiting = waiting
	_served = served
	_drop_radius = drop_radius
	queue_redraw()


func _draw() -> void:
	var half := width * 0.5 * pixels_per_unit
	var wall := wall_height * pixels_per_unit
	var peak := roof_height * pixels_per_unit

	# The drop point sits on the ground, so it is drawn first and squashed
	# vertically to read as lying flat rather than facing the camera.
	var radius := _drop_radius * pixels_per_unit
	if _waiting:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, radius, drop_served if _served else drop_open)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var body := wall_scenery
	if _waiting:
		body = wall_served if _served else wall_waiting
	draw_rect(Rect2(-half, -wall, half * 2.0, wall), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half, -wall), Vector2(half, -wall), Vector2(0.0, -wall - peak),
	]), roof)

	# A lit window is how a house says it is still waiting, without a HUD.
	if _waiting and not _served:
		var w := half * 0.42
		draw_rect(Rect2(-w * 0.5, -wall * 0.72, w, wall * 0.34), window_lit)
