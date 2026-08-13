@tool
class_name RiderView
extends Placeholder2D

## The delivery girl standing at the bottom of the street, in one of two poses.
##
## Placeholder2D already knows how to be a box until art arrives and how to sit a
## thing on the ground; this only chooses which picture is showing. Leave both
## textures empty and it is still the box, so the scene works before the art does.
##
## Her place in the street is not free-hand, though nothing here enforces it, and it
## is a depth rather than a screen row. The street runs left to right across the
## screen and she rides along it; up the screen is across the road, towards the
## houses she throws at. So the road's two lanes are stacked up the screen, divided
## by the dashed line the street shader puts at depth 7, with the tarmac ending at
## depth 18. She rides the bottom lane, which runs from depth 0 to that line.
##
## Her depth in it is 1.0, not the 3.5 that halves the lane, because the lane is not
## halved on screen where it is halved in the world. Perspective squeezes the far
## part of it: the line sits on row 1860 and depth 0 on row 2100, so the depth-3.5
## midpoint draws at 1966.7, only a hundred pixels below the line and two hundred
## above the near edge. She read as riding the line with a wide empty stretch of
## tarmac beneath her. Depth 1.0 lands on 2058.6, which is about the middle of the
## band as drawn, and that is the one a player sees.
##
## The bottom lane is also the honest one. A throw does not leave from wherever she
## is drawn: PizzaGame launches it at depth 0, the rider's own distance, taking only
## its side and height from where the pizza was let go. Standing her in the near
## lane puts her within a few units of the plane the pizza actually flies out of,
## instead of a dozen behind it.
##
## That depth is what fixes both numbers in the scene: y=2058.6 is the row the
## projection puts the ground on there, and 0.9655 is scale_at(1.0). The two have
## to agree. Move her up or down and the scale must be recomputed from
## StreetProjection.scale_at for the depth the new row implies, or she is drawn at
## one distance and standing at another.
##
## Her size is not part of that bargain and can be set to taste; at 650 she is about
## fourteen world units tall, against a house wall of 12.8.
##
## The two poses are drawn on one shared canvas, registered against each other, so
## both are stretched into the same rect and she does not jump when the pose
## changes. That is why there is no per-pose offset here and must not be one: if a
## future pose is trimmed differently, re-export it on the same canvas rather than
## nudging it back into place from code.

## Standing there, which is every moment you are not dragging the pizza.
@export var idle_art: Texture2D:
	set(value):
		idle_art = value
		_refresh()

## Winding up, shown from taking hold of the pizza until it leaves the hand. Leave
## it empty and she simply stays in the idle pose throughout.
@export var aim_art: Texture2D:
	set(value):
		aim_art = value
		_refresh()

@export_group("The rack the boxes ride on")
## The bike's rear rack, as fractions of the picture: how far down its top surface
## sits, and where the flat of it starts and ends across. Read off the sprite by
## finding the long flat run in its silhouette, not guessed, and exported because
## the next bike will have them somewhere else.
##
## Both poses share these. She moves between them; the bike does not.
@export_range(0.0, 1.0, 0.001) var rack_top: float = 0.510
@export_range(0.0, 1.0, 0.001) var rack_left: float = 0.127
@export_range(0.0, 1.0, 0.001) var rack_right: float = 0.385

var _aiming: bool = false


## The flat of the rack in the coordinates of whatever this hangs under: where its
## top surface starts, and how wide it is. No height to it; it is a line to stand
## things on rather than a box.
func rack_rect() -> Rect2:
	var art := Rect2(-size * anchor, size)
	var left := art.position.x + rack_left * art.size.x
	var right := art.position.x + rack_right * art.size.x
	var top := art.position.y + rack_top * art.size.y
	return Rect2(position + Vector2(left, top) * scale, Vector2((right - left) * scale.x, 0.0))


func _ready() -> void:
	_refresh()


## Called by the game as the throw is aimed and again when it is let go.
func set_aiming(value: bool) -> void:
	if _aiming == value:
		return
	_aiming = value
	_refresh()


func _refresh() -> void:
	var wanted: Texture2D = aim_art if _aiming and aim_art != null else idle_art
	# Guarded rather than assigned outright: with neither pose set this leaves
	# whatever texture the scene put there, and the placeholder box if that is
	# nothing, instead of blanking the rider on the way past.
	if wanted != null:
		texture = wanted
