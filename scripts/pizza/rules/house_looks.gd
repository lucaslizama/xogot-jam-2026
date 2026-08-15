@tool
class_name HouseLooks
extends Resource

## The buildings a house can be: how big each one stands, and every lit window
## painted on it.
##
## Houses are drawn from a sheet holding several different buildings, and a house
## picks one when the street stocks it. Everything that makes a throw fair is
## different on each of them, so one answer shared by the whole street is wrong
## twice over: a single window puts the best-paying shot on blank wall, and a
## single body leaves one building with a strip of sky counting as house while
## another has a foot of wall a pizza sails straight through.
##
## So this is the table, and it is the only place either is written down. [member
## bodies] has one entry per building, and its length is how many buildings there
## are. [member windows] has one entry per window, each naming the building it
## belongs to: a building drawn with three windows has three entries, one with none
## has no entries and is all wall. Grouping the windows under the buildings would
## nest a list inside a list, which the inspector makes hard work of and a diff
## makes harder.
##
## Measured off the art rather than invented. A body is as wide as the halfway
## point between the walls and the eaves, so a throw that clips the overhang
## counts, and as tall as the roofline with the chimney left out, because a pizza
## passing beside a chimney should not count as hitting a house. A window is the
## extent of its lit panes. Redraw a building and its numbers want remeasuring,
## which is the price of the drawing and the target agreeing at all.
##
## A tool script, because [HouseHitbox] draws its outlines on the editor canvas and
## has to ask this what the shapes are. Without it the editor holds a placeholder
## that answers no calls, and the outlines error out instead of appearing.

## How wide and tall each building stands, in world units, roof included. One entry
## per building, in the order they appear across the sheet. The street never picks
## a building past the end of this, so a sheet with more frames than entries simply
## never shows the extra ones.
@export var bodies: Array[Vector2] = []

## Every window on every building, in any order.
@export var windows: Array[HouseWindow] = []


## How many buildings are described.
func count() -> int:
	return bodies.size()


## How big the given building stands. Zero for one this table does not describe,
## which reads as a house that cannot be hit rather than as a house of no size.
func body_of(look: int) -> Vector2:
	if look < 0 or look >= bodies.size():
		return Vector2.ZERO
	return bodies[look]


## How many windows are described. Entries left empty in the inspector are counted
## but ignored everywhere else, so a half-finished table draws and plays rather
## than erroring.
func rows() -> int:
	return windows.size()


## Every window on the given building, as rectangles a throw can be tested against.
##
## In the sim's own terms: x measured across from the middle of the house, y
## measured up from the ground, and the rectangle given by its lower-left corner.
## Screen space turns y over; the drawing does that where it draws.
##
## `flipped` mirrors the whole front, because a house drawn the other way round has
## its windows the other way round with it.
func rects_for(look: int, flipped: bool = false) -> Array[Rect2]:
	var found: Array[Rect2] = []
	for window in windows:
		if window == null or window.look != look or not window.is_real():
			continue
		found.append(window.rect(flipped))
	return found
