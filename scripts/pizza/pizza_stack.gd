class_name PizzaStack
extends Control

## The stack of boxes on the back of the bike. This is the pizza counter and the
## level's progress bar at the same time, which is why neither exists as a
## number anywhere on screen.
##
## Boxes are authored in the scene and hidden as they are thrown, so the stack
## shrinks from the top exactly the way a real one would.

@onready var _boxes: Control = %Boxes


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
