@tool
class_name HouseView
extends Node2D

## One house on the street. This node draws nothing itself: it owns the parts and
## decides which of them is showing.
##
## Every state of the house is a real child node, so art arrives by editing the
## scene rather than by filling in a property. Drop a Sprite2D, an
## AnimatedSprite2D or a whole sub-scene under [code]Waiting[/code], put a shader
## or a script on it, delete the placeholder underneath, and this node keeps
## working: it only ever sets [code]visible[/code] on the three of them. The state
## nodes need be nothing more than a CanvasItem. A node that happens to have
## [code]show_shape[/code] is additionally told the measurements, which is how the
## placeholder facades draw themselves to the hitbox.
##
## The measurements live in the [HouseHitbox] child, which draws itself on the
## canvas so it can be dragged to fit new art and turned off for a screenshot. It
## is the one place the size of a house is written down: the placeholders draw to
## it and [PizzaGame] reads it when it stocks a street, so what a player can hit is
## exactly what they can see.
##
## The node's origin is the point where the house meets the ground, because that is
## the point the street projects. Scale comes from the parent, which knows how far
## away this house is.
##
## A tool script, so the house shows itself on the editor canvas. Opening
## house.tscn shows the house rather than an empty node, and nudging a wall or a
## colour is answered on the spot instead of after a run.

## Which of the three state nodes is showing.
enum State {
	## The house wants a pizza. The only state worth throwing at.
	WAITING,
	## It has had one. Still a house, no longer a target.
	SERVED,
	## Scenery. Roughly half the street, and what the waiting houses have to be
	## picked out from.
	SCENERY,
}

@export_group("Parts")
## The three state nodes, shown one at a time, and the two nodes that carry the
## shape and the ring. Paths rather than node references, because a typed node
## export does not reliably survive being written into a .tscn. Repoint any of
## them at a replacement and nothing else has to change.
@export var waiting_path: NodePath = ^"Waiting":
	set(value):
		waiting_path = value
		_forget_parts()
@export var served_path: NodePath = ^"Served":
	set(value):
		served_path = value
		_forget_parts()
@export var scenery_path: NodePath = ^"Scenery":
	set(value):
		scenery_path = value
		_forget_parts()
@export var hitbox_path: NodePath = ^"Hitbox":
	set(value):
		hitbox_path = value
		_forget_parts()
@export var drop_point_path: NodePath = ^"DropPoint":
	set(value):
		drop_point_path = value
		_forget_parts()

@export_group("Drop point")
## Whether the landing ring is shown at all. The game wants it; a decorative
## street with nothing to aim at, like the menu behind the title, does not.
@export var show_drop_points: bool = true:
	set(value):
		show_drop_points = value
		_apply_drop_point()

@export_group("Editor preview")
## What the house shows on the canvas when no street is driving it. The game
## overrides it the moment it runs, so this costs nothing at play time and lets
## the scene be opened on a house that is waiting, one that has been served or a
## piece of scenery, without running anything.
@export var preview_state: State = State.WAITING:
	set(value):
		preview_state = value
		_apply_preview()
## Matches street_1's drop radius, in world units, so the ring on the canvas is
## the size the ring in the game will be rather than a stand-in.
@export_range(0.0, 30.0, 0.1) var preview_drop_radius: float = 13.5:
	set(value):
		preview_drop_radius = value
		_apply_preview()

var _state: State = State.WAITING
var _waiting: bool = true
var _served: bool = false
var _drop_radius: float = 3.2
## Whether a street has ever spoken. Until it has, the preview values stand, and
## the first thing the street says is always applied however much it looks like
## what is already there.
var _stated: bool = false

var _parts_found: bool = false
var _hitbox: HouseHitbox = null
var _states: Array[CanvasItem] = [null, null, null]
var _drop: Node2D = null
## So a house with a part missing says so once rather than every frame.
var _complained: bool = false


func _ready() -> void:
	_find_parts()
	if not _stated:
		_apply_preview()
	else:
		_apply_all()


## Show what the exported preview says, for as long as nothing else has spoken.
func _apply_preview() -> void:
	if _stated:
		return
	_state = preview_state
	_waiting = preview_state != State.SCENERY
	_served = preview_state == State.SERVED
	_drop_radius = preview_drop_radius
	_apply_all()


## Told by the street each frame. Does the work only when something actually
## changed, since most houses are static most of the time.
func show_state(waiting: bool, served: bool, drop_radius: float) -> void:
	# The first word from the street is always acted on. Skipping it because it
	# happened to match the preview would leave the pulse switched off for the
	# life of the house, and the only sign would be a drop point that never
	# breathed on a street where every value looked right.
	if _stated and waiting == _waiting and served == _served \
			and is_equal_approx(drop_radius, _drop_radius):
		return
	_stated = true
	_waiting = waiting
	_served = served
	_drop_radius = drop_radius
	if not waiting:
		_state = State.SCENERY
	elif served:
		_state = State.SERVED
	else:
		_state = State.WAITING
	_apply_all()


func _apply_all() -> void:
	_find_parts()
	_apply_state()
	_apply_drop_point()


## Exactly one state node is visible. Anything else under this node — a shadow, a
## bush, a light — is left alone.
func _apply_state() -> void:
	for i in _states.size():
		var part := _states[i]
		if part != null:
			part.visible = (i == int(_state))


func _apply_drop_point() -> void:
	if _drop == null:
		return
	var wanted := show_drop_points and _waiting
	_drop.visible = wanted
	if _drop.has_method("show_radius"):
		_drop.show_radius(_drop_radius * pixels_per_unit, _served,
			wanted and not _served)


# --- the parts ---------------------------------------------------------------

## Look the parts up once. Resolving by path rather than holding node references
## means this works on a scene that has been instantiated but not added to a tree,
## which is how [PizzaGame] asks a house its size before a street exists.
func _find_parts() -> void:
	if _parts_found:
		return
	var hitbox := get_node_or_null(hitbox_path) as HouseHitbox
	var waiting := get_node_or_null(waiting_path) as CanvasItem
	var served := get_node_or_null(served_path) as CanvasItem
	var scenery := get_node_or_null(scenery_path) as CanvasItem
	var drop := get_node_or_null(drop_point_path) as Node2D

	# An exported setter fires while the scene is still being loaded, before any
	# child has been parented, so everything looks missing for a moment. Caching
	# that would leave the house permanently empty and shouting about it. Nothing
	# at all, on a node that has not finished readying, means too early rather
	# than misconfigured: come back next time.
	if not is_node_ready() and hitbox == null and waiting == null \
			and served == null and scenery == null and drop == null:
		return

	_parts_found = true
	_hitbox = hitbox
	_states[State.WAITING] = waiting
	_states[State.SERVED] = served
	_states[State.SCENERY] = scenery
	_drop = drop

	if _hitbox != null:
		if not _hitbox.shape_changed.is_connected(_push_shape):
			_hitbox.shape_changed.connect(_push_shape)
		_push_shape()
	_warn_about_missing_parts()


## Hand the measurements to every state node that wants them. Real art does not,
## and is left untouched; the placeholder facades draw to whatever arrives.
func _push_shape() -> void:
	for part in _states:
		if part != null and part.has_method("show_shape"):
			part.show_shape(_hitbox)


func _warn_about_missing_parts() -> void:
	if _complained:
		return
	var missing := PackedStringArray()
	if _hitbox == null:
		missing.append("Hitbox (%s)" % hitbox_path)
	if _states[State.WAITING] == null:
		missing.append("Waiting (%s)" % waiting_path)
	if _states[State.SERVED] == null:
		missing.append("Served (%s)" % served_path)
	if _states[State.SCENERY] == null:
		missing.append("Scenery (%s)" % scenery_path)
	if _drop == null:
		missing.append("DropPoint (%s)" % drop_point_path)
	if missing.is_empty():
		return
	_complained = true
	# A renamed or deleted part makes the house quieter, not broken: the state
	# simply does not show and, with no hitbox, the street is told the house is
	# thin air. Both are worth saying out loud.
	push_warning("%s: no %s. Repoint the paths on the House node."
		% [name, ", ".join(missing)])


func _forget_parts() -> void:
	if _hitbox != null and _hitbox.shape_changed.is_connected(_push_shape):
		_hitbox.shape_changed.disconnect(_push_shape)
	_parts_found = false
	_complained = false
	if is_inside_tree():
		_apply_all()


## The hitbox, for anything that wants to read or move the shape directly.
func hitbox() -> HouseHitbox:
	_find_parts()
	return _hitbox


## The landing ring, which owns its own pulse.
func drop_point() -> Node2D:
	_find_parts()
	return _drop


## The node showing for the given state, whatever the artist has put there.
func state_node(state: State) -> CanvasItem:
	_find_parts()
	return _states[int(state)]


# --- the shape, read off the hitbox ------------------------------------------
#
# The house is asked its size by PizzaGame and by the tests, and it answers from
# the hitbox rather than keeping a second copy. A house with no hitbox answers
# zero, which the street reads as a house that cannot be hit; the warning for it
# is raised above.

var width: float:
	get:
		_find_parts()
		return _hitbox.width if _hitbox != null else 0.0

var wall_height: float:
	get:
		_find_parts()
		return _hitbox.wall_height if _hitbox != null else 0.0

var roof_height: float:
	get:
		_find_parts()
		return _hitbox.roof_height if _hitbox != null else 0.0

var window_size: Vector2:
	get:
		_find_parts()
		return _hitbox.window_size if _hitbox != null else Vector2.ZERO

var window_centre: float:
	get:
		_find_parts()
		return _hitbox.window_centre if _hitbox != null else 0.0

var pixels_per_unit: float:
	get:
		_find_parts()
		return _hitbox.pixels_per_unit if _hitbox != null else 0.0


## Where the window sits on the wall, in world units, with the house's feet at the
## origin and up being negative as it is on screen.
func window_rect() -> Rect2:
	_find_parts()
	return _hitbox.window_rect() if _hitbox != null else Rect2()
