class_name PizzaStack
extends Control

## The stack of boxes on the back of the bike. This is the pizza counter and the
## level's progress bar at the same time, which is why neither exists as a
## number anywhere on screen.
##
## Boxes are authored in the scene and hidden as they are thrown, so the stack
## shrinks from the top exactly the way a real one would.

@onready var _boxes: Control = %Boxes


func _ready() -> void:
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)


## A Control under a CanvasLayer is handed the viewport's rectangle. One under a
## Node2D is not: it comes out zero sized, and anything anchored inside it lands
## off screen with nothing to say so. The stack lives in the world, at the
## rider's own depth, so it has to claim that rectangle itself.
func _fit_to_screen() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


## How many boxes the scene can draw. A level carrying more than this would look
## like it had fewer, so it is worth knowing.
func slot_count() -> int:
	return _boxes.get_child_count()


func show_pizzas(left: int) -> void:
	if left > slot_count():
		push_warning("PizzaStack: level carries %d pizzas but the bike only draws %d boxes; the stack will look short. Add boxes in the scene."
			% [left, slot_count()])
	var boxes := _boxes.get_children()
	for i in boxes.size():
		var box := boxes[i] as CanvasItem
		if box != null:
			box.visible = i < left
