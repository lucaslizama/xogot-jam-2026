@tool
class_name HouseFacade
extends Node2D

## Placeholder art for one state of a house: a wall, a roof, and optionally a lit
## window, drawn to whatever the house's [HouseHitbox] says the shape is.
##
## This node exists to be replaced. Each state of the house is its own child of
## [HouseView], so real art arrives by dropping a Sprite2D, an AnimatedSprite2D or
## a whole sub-scene in beside this node — or on it, since anything parented here
## is drawn on top — and deleting this one when it is no longer wanted. A shader
## or a script goes on that node and affects that state alone.
##
## [HouseView] does not care what a state node is. It shows one and hides the
## others; only a node that happens to have [method show_shape] is told the
## measurements. So nothing has to be wired up for a plain sprite to work.
##
## The origin is the point where the house meets the ground, matching the parent,
## and up is negative as it is everywhere on screen.

## Whether the lit window is drawn. It is how a house says it is still waiting, so
## the waiting state wants it and the other two do not.
@export var show_window: bool = true:
	set(value):
		show_window = value
		queue_redraw()

@export_group("Colours")
@export var wall: Color = Color(0.729412, 0.380392, 0.337255):
	set(value):
		wall = value
		queue_redraw()
@export var roof: Color = Color(0.341176, 0.160784, 0.294118):
	set(value):
		roof = value
		queue_redraw()
@export var window_lit: Color = Color(1, 0.894118, 0.470588):
	set(value):
		window_lit = value
		queue_redraw()
## A frame around the window, so it reads as something to aim at rather than as a
## patch of light on the wall.
@export var window_frame: Color = Color(0.152941, 0.152941, 0.211765, 0.8):
	set(value):
		window_frame = value
		queue_redraw()
@export_range(0.5, 12.0, 0.5) var window_frame_width: float = 4.0:
	set(value):
		window_frame_width = value
		queue_redraw()

## The shape to draw to. Handed over by [HouseView], which owns the wiring; this
## node never goes looking for a sibling itself.
var _shape: HouseHitbox = null


## Told by [HouseView] when the house's measurements change. A state node without
## this method is simply left alone, which is what real art wants.
func show_shape(shape: HouseHitbox) -> void:
	_shape = shape
	queue_redraw()


func _draw() -> void:
	if _shape == null:
		# Nothing to draw to. Silent rather than noisy: the warning for a house
		# with no hitbox is raised once, by HouseView, which is the node that
		# knows whether one was expected.
		return

	var unit := _shape.pixels_per_unit
	var half := _shape.width * 0.5 * unit
	var wall_top := _shape.wall_height * unit
	var peak := _shape.roof_height * unit

	draw_rect(Rect2(-half, -wall_top, half * 2.0, wall_top), wall)
	if peak > 0.0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-half, -wall_top), Vector2(half, -wall_top),
			Vector2(0.0, -wall_top - peak),
		]), roof)

	# Drawn from the same measurements the throw is judged against rather than
	# from fractions of the wall that only happened to look right. However many
	# windows the building it is standing in for was drawn with.
	if show_window:
		for pane in _shape.window_rects():
			var lit := Rect2(pane.position * unit, pane.size * unit)
			draw_rect(lit, window_lit)
			draw_rect(lit, window_frame, false, window_frame_width)
