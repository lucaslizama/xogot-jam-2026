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
##
## What it draws, in order: the flavour's animation if this pizza plays one, then
## its still art, then a frame of the animation for a flavour that brought no still
## art at all, and failing everything a coloured box with toppings on it. Each step
## down is a flavour with less art assigned, which is how the game looked while the
## art was still being drawn.
##
## pizza.tscn assigns a flavour, and that is on purpose rather than left over.
## [PizzaGame] overwrites it the moment a round starts, so it changes nothing that
## a player sees; what it changes is the editor. Without it, every pizza in every
## scene was a grey box on the canvas, and a scene that shows something the game
## never shows is a scene you cannot judge anything by: not whether the pizza in
## hand is too big, not whether it clears the bottom of the screen. The flavour it
## carries is the first one on the shop's menu, so the canvas shows what a player
## sees at the start of a run.

@export var flavour: PizzaFlavour:
	set(value):
		if flavour == value:
			return
		flavour = value
		if is_inside_tree():
			queue_redraw()

## Whether this pizza plays its flavour's animation or holds one still frame.
##
## The scene's to decide and not the flavour's, because it is about which pizza
## this is rather than what is on it. The one waiting in your hand is being held,
## and a loop reads on it: it is large, it is still, and the player is looking
## straight at it while deciding where to throw. The one in the air is small, turning
## and gone in a second, so a loop there is detail nobody can see, spent on the
## frame where the game is busiest.
@export var animated: bool = false:
	set(value):
		animated = value
		if is_inside_tree():
			set_process(animated and not Engine.is_editor_hint())
			queue_redraw()

## Which frame a pizza that does not animate holds.
##
## Only reached by a flavour that has an animation and no still art of its own;
## where there is still art, that is the picture and this is not consulted.
@export_range(0, 255) var still_frame: int = 0:
	set(value):
		still_frame = value
		if is_inside_tree():
			queue_redraw()

## How far into the loop this pizza is. Real seconds, not frames, so the loop runs
## at the speed the flavour asks for whatever the frame rate does.
var _elapsed: float = 0.0
var _frame: int = 0


func _ready() -> void:
	# Not conditional on there being an animation to play. The flavour is assigned
	# by whoever owns this node, which happens after this runs, so a check here
	# would look at a pizza that has no flavour yet and switch processing off for
	# good. Deciding per frame instead costs one early return.
	set_process(animated and not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if flavour == null:
		return
	var count := flavour.frame_count()
	if count <= 1:
		return
	_elapsed += delta
	var next: int = posmod(int(_elapsed * flavour.animation_fps), count)
	if next == _frame:
		return
	_frame = next
	queue_redraw()


## Whether a loop is actually running here: this pizza was asked to animate and its
## flavour brought something to animate. Asked by the tests, and the honest answer
## to "is this the pizza that moves", which [member animated] alone is not.
func plays_animation() -> bool:
	return animated and flavour != null and flavour.frame_count() > 1


## Which frame of the flavour's animation is on screen. Meaningless for a flavour
## with no animation, where nothing is cut out of a sheet at all.
func frame_shown() -> int:
	if plays_animation():
		return _frame
	return still_frame


func _draw() -> void:
	if flavour == null:
		super()
		return
	var rect := Rect2(-size * anchor, size)
	if plays_animation():
		draw_texture_rect_region(flavour.animation, rect, flavour.frame_region(_frame))
		return
	if flavour.art != null:
		draw_texture_rect(flavour.art, rect, false)
		return
	if flavour.frame_count() > 0:
		draw_texture_rect_region(flavour.animation, rect, flavour.frame_region(still_frame))
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
