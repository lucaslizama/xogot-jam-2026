@tool
class_name HouseHitbox
extends Node2D

## The measurements of one house, and the only place they live.
##
## Every other part of the house reads its size from here, and [PizzaGame] reads
## it when it stocks a street, so what a player can hit is exactly what they can
## see. Change a number here and the collision moves with the drawing; there is no
## second copy to forget.
##
## The body is one shape for every building on the sheet, because they differ by
## only a unit or so across and up. The windows are not: each building is drawn
## with its own, in its own places and its own number of them, so they come from
## [member looks]. [member shown_look] says which building this house is.
##
## It draws itself as an outline so the shape can be dragged into place against
## real art rather than guessed at. The outline is an editor tool, not part of the
## game: [member outline] decides when it is drawn, and the default draws it on the
## canvas only.
##
## The node's origin is where the house meets the ground, matching its parent,
## because that is the point the street projects.

## Emitted whenever a measurement changes, so anything drawing to this shape can
## redraw. The parent [HouseView] listens and passes the news on; nothing here
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
##
## Measured off the art: the walls are about 19.6 across and the eaves reach about
## 22.6, so this sits between them and a throw that clips the overhang counts. That
## is the right way round for a throw already committed to.
@export_range(1.0, 30.0, 0.1) var width: float = 21.5:
	set(value):
		width = value
		_changed()
## How tall the wall stands before the roof starts.
@export_range(1.0, 30.0, 0.1) var wall_height: float = 13.3:
	set(value):
		wall_height = value
		_changed()
## How much the roof adds on top. The throw squares the roof off rather than
## following its slope, so the two top corners are a little kinder than they look.
##
## Wall plus roof is the roofline of the drawn houses, which runs from 18.5 to 21.6
## across the sheet and averages about 20. The chimney stands above it deliberately:
## a pizza passing beside a chimney should not count as hitting a house.
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

@export_group("The windows")
## Where the lit windows sit on each building the sheet holds.
##
## A lit window is a target in its own right, and the hardest one: smaller than the
## drop point, higher up, and needing a throw that is both well aimed and a little
## long. It pays the most because of it. Every window on a building counts, so one
## drawn with three panes is three chances rather than one. Leave this empty and
## houses have nothing to aim at but wall and the ring at their feet.
@export var looks: HouseLooks:
	set(value):
		looks = value
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

## Which building this house turned out to be, and whether it is drawn mirrored.
##
## Set by [HouseView], from the street in the game and from its preview on the
## canvas. There is deliberately no preview of its own here: two knobs both called
## preview_look, one of which quietly loses, is worse than one that always wins.
var shown_look: int = 0
var shown_flipped: bool = false


func _changed() -> void:
	queue_redraw()
	shape_changed.emit()


## Told by [HouseView] once the street has decided what this house is.
func show_look(look: int, flipped: bool) -> void:
	if look == shown_look and flipped == shown_flipped:
		return
	shown_look = look
	shown_flipped = flipped
	queue_redraw()


## The facade in world units: x how wide, y how tall including the roof. This is
## the pair [PizzaGame] hands the street, so a house is solid at the size it is
## drawn.
func body_size() -> Vector2:
	return Vector2(width, wall_height + roof_height)


## Where the windows of the building now showing sit, in world units, with the
## house's feet at the origin and up being negative as it is on screen. Multiply by
## [member pixels_per_unit] to draw them; the throw uses the same numbers with y
## the other way up.
func window_rects() -> Array[Rect2]:
	var panes: Array[Rect2] = []
	if looks == null:
		return panes
	for pane in looks.rects_for(shown_look, shown_flipped):
		# The table speaks in the sim's terms, where up is positive. Screen space
		# turns that over, and this is the one place it happens.
		panes.append(Rect2(pane.position.x, -(pane.position.y + pane.size.y),
			pane.size.x, pane.size.y))
	return panes


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

	for pane in window_rects():
		draw_rect(Rect2(pane.position * pixels_per_unit, pane.size * pixels_per_unit),
			window_outline, false, outline_width)
