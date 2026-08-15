class_name PizzaStack
extends Control

## The stack of boxes on the back of the bike: the pizza counter and the level's
## progress bar at once, which is why neither exists as a number on screen. Boxes
## are authored in the scene and hidden as they are thrown, so the stack shrinks
## from the top the way a real one would.
##
## Two things the scene cannot say itself, because Godot drops every comment in a
## .tscn when it saves.
##
## Neither this node nor Boxes is anchored. This one sits at the top-left on purpose
## and claims the viewport in [method _fit_to_screen]. Boxes is placed by [method
## place_on] from the rider's rack, and the size authored on it is one box, only so
## the editor has something to show.
##
## The stack's z_index in pizza_game.tscn is below the rider's and has to stay
## there: in the aiming pose she holds a box out over the rack, and drawn the other
## way round the stack paints across her hand.

@onready var _boxes: Control = %Boxes

## So a scene that cannot seat the stack says so once rather than every frame.
var _complained: bool = false


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


## Sit the stack on the bike's rack, given where the rack is.
##
## The boxes are resized to the rack's width, so making the rider bigger carries
## them with her and nothing in the scene is retyped to match. Before there was a
## bike the stack was pinned to the corner of the viewport, which put it somewhere
## different relative to her on every screen shape.
func place_on(rack: Rect2) -> void:
	var first := _boxes.get_child(0) as Control
	if first == null or first.size.x <= 0.0 or rack.size.x <= 0.0:
		# Once. This is asked every frame now that the rider moves, and a scene
		# that cannot answer would otherwise say so sixty times a second.
		if not _complained:
			_complained = true
			push_warning("PizzaStack: cannot sit on the rack; the scene needs at least one box with a width.")
		return
	var to_rack: float = rack.size.x / first.size.x
	_boxes.scale = Vector2(to_rack, to_rack)
	# The lowest box hangs below the container's origin, so the origin sits one box
	# above the rack: the stack then rests on the surface instead of sinking through.
	_boxes.position = Vector2(rack.position.x, rack.position.y - first.size.y * to_rack)


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
