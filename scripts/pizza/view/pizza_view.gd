@tool
class_name PizzaView
extends Placeholder2D

## A pizza that knows what is on it.
##
## Everything [Placeholder2D] does, plus a flavour. With no flavour set it is that
## plain box exactly, so nothing that has not heard of flavours changes.
##
## The flavour is drawn rather than tinted. The waiting pizza's [member
## CanvasItem.modulate] is already spoken for by the wind-up, which eases it
## towards a charged tint every frame, so anything put there would be wiped out
## between one frame and the next.

@export var flavour: PizzaFlavour:
	set(value):
		if flavour == value:
			return
		flavour = value
		if is_inside_tree():
			queue_redraw()


func _draw() -> void:
	if flavour == null:
		super()
		return
	var rect := Rect2(-size * anchor, size)
	if flavour.art != null:
		draw_texture_rect(flavour.art, rect, false)
		return

	draw_rect(rect, flavour.base)
	draw_rect(rect, outline, false, maxf(2.0, size.x * 0.04))
	var middle := rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.5
	for offset in flavour.topping_offsets():
		draw_circle(middle + offset * radius, radius * flavour.topping_size, flavour.topping)

	# The corner mark exists only to make a spin readable, and a scatter of
	# toppings does that better. It is drawn only for a flavour that brought none,
	# so a plain cheese pizza can still be seen to turn.
	if corner_mark and flavour.toppings <= 0:
		draw_corner_mark(rect)
