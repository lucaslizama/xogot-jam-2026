@tool
class_name HouseHitbox
extends Node2D

## The measurements of one house, and the only place they live.
##
## Every other part of the house reads its size from here: the placeholder
## facades draw to it, and [PizzaGame] asks the house scene for it when it
## stocks a street, so what a player can hit is exactly what they can see. Change
## a number here and the drawing and the collision move together; there is no
## second copy to forget.
##
## It draws itself as an outline so the shape can be dragged into place against
## real art rather than guessed at. The outline is an editor tool, not part of
## the game: [member outline] decides when it is drawn, and the default draws it
## on the canvas only.
##
## The node's origin is where the house meets the ground, matching its parent,
## because that is the point the street projects.

## Emitted whenever a measurement changes, so the facades that draw to this shape
## can redraw. The parent [HouseView] listens and passes the news on; nothing here
## reaches sideways to a sibling.
signal shape_changed

## When the outline is drawn.
enum Outline {
	## On the editor canvas only. What you want almost always: the shape is there
	## to be edited, and the running game never shows it.
	EDITOR_ONLY,
	## In the editor and in the running game. For checking a throw against the
	## shape it was judged by.
	ALWAYS,
	## Never. For a screenshot.
	NEVER,
}

## When the outline is drawn. Editor-only by default; nothing here ever affects
## what a throw hits.
@export var outline: Outline = Outline.EDITOR_ONLY:
	set(value):
		outline = value
		queue_redraw()

@export_group("Shape, in world units")
## How wide the facade stands. A pizza inside this width, above the doorstep and
## below the roof, has hit the house.
@export_range(1.0, 30.0, 0.1) var width: float = 20.5:
	set(value):
		width = value
		_changed()
## How tall the wall stands before the roof starts.
@export_range(1.0, 30.0, 0.1) var wall_height: float = 12.8:
	set(value):
		wall_height = value
		_changed()
## How much the roof adds on top. The throw squares the roof off rather than
## following its slope, so the two top corners are a little kinder than they look.
@export_range(0.0, 15.0, 0.1) var roof_height: float = 6.7:
	set(value):
		roof_height = value
		_changed()
## Pixels per world unit at the rider's distance. Must match the projection
## resource, or houses will not sit at the size the street expects.
@export_range(1.0, 400.0, 1.0) var pixels_per_unit: float = 46.0:
	set(value):
		pixels_per_unit = value
		_changed()

@export_group("The window, in world units")
## The lit window is a target in its own right, and the hardest one: smaller than
## the drop point, higher up, and needing a throw that is both well aimed and a
## little long. It pays the most because of it.
##
## Zero on either axis means no window, and the whole facade is plain wall.
@export var window_size: Vector2 = Vector2(4.3, 4.4):
	set(value):
		window_size = value
		_changed()
## How high the middle of the window sits above the ground.
@export_range(0.0, 30.0, 0.1) var window_centre: float = 7.0:
	set(value):
		window_centre = value
		_changed()

@export_group("Outline")
@export var body_outline: Color = Color(1, 0.294118, 0.427451, 0.85):
	set(value):
		body_outline = value
		queue_redraw()
@export var window_outline: Color = Color(1, 0.894118, 0.470588, 0.9):
	set(value):
		window_outline = value
		queue_redraw()
@export_range(0.5, 12.0, 0.5) var outline_width: float = 2.0:
	set(value):
		outline_width = value
		queue_redraw()

@export_group("Editor preview")
## How high the wall starts counting, drawn as a line across the facade. Below it
## a pizza is arriving at the door rather than hitting the house, and the drop
## point at its feet decides.
##
## Preview only: the real value is [member PizzaGame.wall_doorstep], because it is
## a rule of the round rather than a property of one house. Set it to the same
## number to see where the line falls.
@export_range(0.0, 15.0, 0.5) var doorstep_preview: float = 4.0:
	set(value):
		doorstep_preview = value
		queue_redraw()
@export var doorstep_outline: Color = Color(0.301961, 0.65098, 1, 0.7):
	set(value):
		doorstep_outline = value
		queue_redraw()


func _changed() -> void:
	queue_redraw()
	shape_changed.emit()


## The facade in world units: x how wide, y how tall including the roof. This is
## the pair [PizzaGame] hands the street, so a house is solid at the size it is
## drawn.
func body_size() -> Vector2:
	return Vector2(width, wall_height + roof_height)


## Where the window sits on the wall, in world units, with the house's feet at the
## origin and up being negative as it is on screen. Multiply by
## [member pixels_per_unit] to draw it; the throw uses the same numbers the other
## way round.
func window_rect() -> Rect2:
	return Rect2(-window_size.x * 0.5, -(window_centre + window_size.y * 0.5),
		window_size.x, window_size.y)


func _draw() -> void:
	if outline == Outline.NEVER:
		return
	if outline == Outline.EDITOR_ONLY and not Engine.is_editor_hint():
		return

	var half := width * 0.5 * pixels_per_unit
	var tall := (wall_height + roof_height) * pixels_per_unit
	draw_rect(Rect2(-half, -tall, half * 2.0, tall), body_outline, false, outline_width)

	if doorstep_preview > 0.0:
		var y := -doorstep_preview * pixels_per_unit
		draw_line(Vector2(-half, y), Vector2(half, y), doorstep_outline, outline_width)

	if window_size.x > 0.0 and window_size.y > 0.0:
		var pane := window_rect()
		draw_rect(Rect2(pane.position * pixels_per_unit, pane.size * pixels_per_unit),
			window_outline, false, outline_width)
