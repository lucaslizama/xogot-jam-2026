@tool
class_name HouseLooks
extends Resource

## The buildings a house can be, and every lit window painted on each one.
##
## Houses are drawn from a sheet holding several different buildings, and a house
## picks one when the street stocks it. The windows are painted into that picture,
## in different places and different numbers on every building, so one window
## shared by the whole street puts the best-paying shot on blank wall while glass a
## player can plainly see counts for nothing. This is the table that keeps the
## targets on the glass.
##
## One entry per window, each saying which building it belongs to: a building drawn
## with three windows has three entries, one drawn with none has no entries and is
## all wall. Grouping them under the buildings instead would nest a list inside a
## list, which the inspector makes hard work of and a diff makes harder.
##
## A tool script, because [HouseHitbox] draws its outlines on the editor canvas and
## has to ask this where the windows are. Without it the editor holds a placeholder
## that answers no calls, and the outlines error out instead of appearing.

## How many buildings the sheet holds. The street never picks one past this, so a
## sheet with more frames than this simply never shows the extra ones.
@export_range(1, 32, 1) var look_count: int = 4

## Every window on every building, in any order.
@export var windows: Array[HouseWindow] = []


## How many windows are described. Entries left empty in the inspector are counted
## but ignored everywhere else, so a half-finished table draws and plays rather
## than erroring.
func rows() -> int:
	return windows.size()


## Every window on the given building, as rectangles a throw can be tested against:
## x measured across from the middle of the house, y up from the ground, each given
## by its lower-left corner. Screen space turns y over; the drawing does that where
## it draws.
func rects_for(look: int, flipped: bool = false) -> Array[Rect2]:
	var found: Array[Rect2] = []
	for window in windows:
		if window == null or window.look != look or not window.is_real():
			continue
		found.append(window.rect(flipped))
	return found
