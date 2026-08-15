@tool
class_name PizzaFlavour
extends Resource

## One thing on the shop's menu.
##
## A flavour is only a look and a name. It never changes whether a throw lands,
## what it pays or how it flies: houses take whatever arrives. It exists so an order
## can ask for something and the pizza in your hand can show what it is.
##
## Deliberately so. Houses go past fast, and a house that demanded a flavour would
## turn the swap into a panic in the worst second. A player who never swaps plays
## the game that was there before orders existed.
##
## A tool script because [PizzaView] draws the pizza on the editor canvas and asks
## a flavour how many frames it has; a resource without one answers no calls there.

## How an order names it.
@export var display_name: String = "Cheese"
## The finished pizza, standing still. Assign one and the box below is gone. It is
## stretched to whatever size it is drawn at, so one image serves them all.
##
## What a pizza that is not animated shows, which is the one in the air: too fast
## for a loop to read on. With an animation below as well, that plays in your hand
## and this stays the still picture.
@export var art: Texture2D
## A small square for the order ticket. Nothing reads it yet; the slot is here so
## it sits beside the art it belongs with.
@export var icon: Texture2D


@export_group("Animation", "animation_")
## The pizza while it is alive in your hand: a grid of frames of the same box, read
## left to right and top to bottom.
##
## On the flavour rather than on a node because it is a picture of a pepperoni, and
## this file is what makes something a pepperoni. Which pizza plays it is the
## scene's question: see [member PizzaView.animated].
@export var animation: Texture2D
@export_range(1, 16) var animation_columns: int = 4
@export_range(1, 16) var animation_rows: int = 4
## How many of those cells are drawn, for a sheet whose last row is not full.
## Zero, the usual case, means every cell in the grid.
@export_range(0, 256) var animation_length: int = 0
## Frames a second, so the loop comes round in length / fps.
@export_range(1.0, 60.0, 1.0) var animation_fps: float = 12.0

@export_group("While it is still a box")
@export var base: Color = Color(1, 0.709804, 0.439216)
## Toppings, drawn as discs over the base.
##
## Not decoration. Colour alone reads badly at the size the pizza flies at and
## tells a colour-blind player nothing; a count and a size differ whatever hue
## does.
@export var topping: Color = Color(0.690196, 0.188235, 0.360784)
@export_range(0, 16) var toppings: int = 7
## Radius of one topping, as a fraction of the pizza's own radius.
@export_range(0.0, 0.4, 0.005) var topping_size: float = 0.1
## How far out the toppings reach, 1.0 being the edge.
@export_range(0.0, 1.0, 0.01) var topping_spread: float = 0.62


## How many frames the animation has, zero for a flavour with none, which is what
## anything drawing a pizza asks rather than testing the texture itself.
func frame_count() -> int:
	if animation == null:
		return 0
	var cells: int = animation_columns * animation_rows
	if animation_length <= 0:
		return cells
	return mini(animation_length, cells)


## Where one frame sits in the sheet, in pixels. Wrapped, so a caller can keep
## counting up the way the menu does without knowing the loop's length. An empty
## rect for a flavour with no animation, which draws nothing rather than the whole
## sheet.
func frame_region(index: int) -> Rect2:
	var count := frame_count()
	if count <= 0:
		return Rect2()
	var frame: int = posmod(index, count)
	var cell := Vector2(float(animation.get_width()) / float(animation_columns),
		float(animation.get_height()) / float(animation_rows))
	var column: int = frame % animation_columns
	# Whole rows along, so the truncation is the answer rather than a loss of one.
	# Frame 5 of a four-wide sheet is row 1, 256 px down a 1024 px sheet. Dividing
	# as floats makes it 1.25 rows, and every frame past the first row is then cut
	# from two rows at once, half of each.
	#
	# The warning is switched off here rather than left to be tidied away later by
	# somebody reading it as the mistake it looks like.
	@warning_ignore("integer_division")
	var row: int = frame / animation_columns
	return Rect2(Vector2(column, row) * cell, cell)


## Where each topping sits, as a fraction of the pizza's radius from the middle.
## A golden-angle spiral rather than a scatter, so a flavour is drawn the same way
## every time and no two toppings land on each other however many there are.
func topping_offsets() -> PackedVector2Array:
	var out := PackedVector2Array()
	if toppings <= 0:
		return out
	for i in toppings:
		var angle := float(i) * 2.399963
		var reach: float = topping_spread * sqrt((float(i) + 0.5) / float(toppings))
		out.append(Vector2(cos(angle), sin(angle)) * reach)
	return out
