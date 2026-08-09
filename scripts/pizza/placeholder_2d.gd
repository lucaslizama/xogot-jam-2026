class_name Placeholder2D
extends Node2D

## A coloured box that stands in for art which has not arrived yet.
##
## Assign a texture and the box is gone; nothing else changes. That is the whole
## point of it. The alternative, drawing the placeholder in code, means somebody
## has to go and delete that code when the real art lands, and until they do the
## art cannot be tried at all.
##
## The box occupies exactly the space the finished art will, so the layout is
## already right before anything is drawn.

@export var texture: Texture2D:
	set(value):
		texture = value
		if is_inside_tree():
			queue_redraw()

## The space this occupies, in pixels, before the street's perspective scales
## it. A texture is stretched to fit, so art drawn to this size lands unchanged.
@export var size: Vector2 = Vector2(120.0, 120.0):
	set(value):
		size = value
		if is_inside_tree():
			queue_redraw()

## Where the node's origin sits inside that box. Centre is (0.5, 0.5); anything
## standing on the ground wants (0.5, 1.0), because the ground contact point is
## what the street positions.
@export var anchor: Vector2 = Vector2(0.5, 0.5)

@export_group("While it is still a box")
@export var colour: Color = Color(0.88, 0.74, 0.49)
@export var outline: Color = Color(0.0, 0.0, 0.0, 0.35)
## Marks one corner. A plain box looks identical every quarter turn, so anything
## that rotates needs this or its spin cannot be read at all.
@export var corner_mark: bool = false
@export var mark_colour: Color = Color(0.95, 0.95, 0.9)


func _draw() -> void:
	var rect := Rect2(-size * anchor, size)
	if texture != null:
		draw_texture_rect(texture, rect, false)
		return
	draw_rect(rect, colour)
	draw_rect(rect, outline, false, maxf(2.0, size.x * 0.04))
	if corner_mark:
		var mark := size * 0.24
		draw_rect(Rect2(rect.position + mark * 0.35, mark), mark_colour)
