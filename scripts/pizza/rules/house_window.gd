@tool
class_name HouseWindow
extends Resource

## One lit window painted on one of the buildings a house can be.
##
## Measured off the art rather than invented: it is the extent of one window's lit
## panes in one frame of the sheet, converted to world units. Redraw that building
## and this wants remeasuring, which is the price of the drawing and the target
## agreeing at all.
##
## A tool script, because [HouseHitbox] draws these on the editor canvas.

## Which of the buildings on the sheet this window belongs to. Buildings are
## counted from zero, in the order they appear across the sheet.
@export_range(0, 31, 1) var look: int = 0
## How wide and tall the window is, in world units.
@export var size: Vector2 = Vector2(3.5, 4.0)
## Where its middle sits: x across from the middle of the house, y up from the
## ground. Rarely dead centre, because windows rarely are.
@export var centre: Vector2 = Vector2.ZERO


## The window as a rectangle a throw can be tested against, in the sim's own terms:
## x across from the middle of the house, y up from the ground, given by its
## lower-left corner. `flipped` mirrors it, because a house drawn the other way
## round has its windows the other way round with it.
func rect(flipped: bool = false) -> Rect2:
	var across: float = -centre.x if flipped else centre.x
	return Rect2(across - size.x * 0.5, centre.y - size.y * 0.5, size.x, size.y)


func is_real() -> bool:
	return size.x > 0.0 and size.y > 0.0
