@tool
class_name HouseLooks
extends Resource

## The buildings a house can be: how big each one stands, and the lit windows on it.
##
## A house picks one of them when the street stocks it, and both numbers decide
## whether a throw was fair, so both have to be that building's own. One body
## shared by the street leaves the short building with a strip of sky counting as
## house; one window leaves the best-paying shot on blank wall.
##
## [member bodies] has an entry per building and its length is how many there are.
## [member windows] has an entry per window, each naming its building, so a
## building drawn with three has three and one with none is all wall. Flat rather
## than nested, because the inspector makes hard work of a list inside a list.
##
## Measured off the art, not invented: a body is as wide as halfway between the
## walls and the eaves and as tall as the roofline without the chimney; a window is
## the extent of its lit panes. Redraw a building and its numbers want taking
## again.
##
## A tool script because [HouseHitbox] draws these on the editor canvas, and a
## resource without one answers no calls there.

## How wide and tall each building stands, in world units, roof included, in the
## order they appear across the sheet. A sheet with more frames than entries never
## shows the extra ones.
@export var bodies: Array[Vector2] = []

## Every window on every building, in any order.
@export var windows: Array[HouseWindow] = []


## How many buildings are described.
func count() -> int:
	return bodies.size()


## How big the given building stands. Zero for one not in the table, which reads as
## a house that cannot be hit.
func body_of(look: int) -> Vector2:
	if look < 0 or look >= bodies.size():
		return Vector2.ZERO
	return bodies[look]


## How many windows are described. Empty entries are counted here and ignored
## everywhere else, so a half-finished table still plays.
func rows() -> int:
	return windows.size()


## Every window on the given building, in the sim's terms: x across from the middle
## of the house, y up from the ground, each rect given by its lower-left corner.
## Screen space turns y over, and does it where it draws. `flipped` mirrors the
## front, windows with it.
func rects_for(look: int, flipped: bool = false) -> Array[Rect2]:
	var found: Array[Rect2] = []
	for window in windows:
		if window == null or window.look != look or not window.is_real():
			continue
		found.append(window.rect(flipped))
	return found
