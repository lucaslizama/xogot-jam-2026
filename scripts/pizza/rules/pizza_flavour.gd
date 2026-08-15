@tool
class_name PizzaFlavour
extends Resource

## One thing on the shop's menu.
##
## A flavour is only ever a look and a name. It never changes whether a throw
## lands, what it pays, or how it flies: houses take whatever arrives. It exists
## so that an order can ask for something in particular, and so the pizza in your
## hand can show what it is.
##
## That is deliberate. Houses go past fast, and a house that demanded a flavour
## would turn the swap into a panic in the worst possible second. Orders are a
## bonus laid over the game rather than a gate in front of it, so a player who
## never swaps at all plays exactly the game that was there before.
##
## A tool script for the same reason [StreetProjection] is: [PizzaView] draws the
## pizza on the editor canvas and asks a flavour how many frames it has and where
## they sit. In the editor a resource without @tool answers no calls at all, so
## the drawing gave up part way through with nothing on screen to say why.

## How an order names it.
@export var display_name: String = "Cheese"
## The finished pizza, standing still. Assign one and the box below is gone; the
## art is stretched to whatever size the node it is drawn on asks for, so one image
## serves every size the pizza is drawn at.
##
## This is what a pizza that is not animated shows — the one in the air, which is
## past too fast for a loop to be read on it. Where there is also an animation
## below, that plays on the pizza in your hand instead, and this stays the still
## picture.
@export var art: Texture2D
## A small square for the order ticket, where a whole pizza would be too much
## detail. Nothing reads it yet; it is here so the slot exists next to the art it
## belongs with.
@export var icon: Texture2D


@export_group("Animation", "animation_")
## The pizza while it is alive in your hand: a grid of frames of the same box,
## read left to right and top to bottom.
##
## It belongs to the flavour rather than to a node because it is a picture of a
## pepperoni, and this file is what makes something a pepperoni. Which of the
## pizzas on screen plays it is a different question, and the scene's to answer —
## see [member PizzaView.animated].
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
## Not decoration. Colour alone is a poor way to tell flavours apart: it reads
## badly at the size the pizza flies at, and it tells a colour-blind player
## nothing at all. A count and a size differ whatever the hue does.
@export var topping: Color = Color(0.690196, 0.188235, 0.360784)
@export_range(0, 16) var toppings: int = 7
## Radius of one topping, as a fraction of the pizza's own radius.
@export_range(0.0, 0.4, 0.005) var topping_size: float = 0.1
## How far out the toppings reach, 1.0 being the edge.
@export_range(0.0, 1.0, 0.01) var topping_spread: float = 0.62


## How many frames the animation has, and zero for a flavour that brought none —
## which is the question anything drawing a pizza asks first, rather than testing
## the texture itself.
func frame_count() -> int:
	if animation == null:
		return 0
	var cells: int = animation_columns * animation_rows
	if animation_length <= 0:
		return cells
	return mini(animation_length, cells)


## Where one frame sits in the sheet, in pixels.
##
## Wrapped, so a caller can keep counting upwards the way the menu does and never
## has to know how long the loop is. An empty rect for a flavour with no animation,
## which draws nothing rather than the whole sheet at once.
func frame_region(index: int) -> Rect2:
	var count := frame_count()
	if count <= 0:
		return Rect2()
	var frame: int = posmod(index, count)
	var cell := Vector2(float(animation.get_width()) / float(animation_columns),
		float(animation.get_height()) / float(animation_rows))
	return Rect2(Vector2(frame % animation_columns, frame / animation_columns) * cell, cell)


## Where each topping sits, as a fraction of the pizza's radius from the middle.
##
## A spiral by the golden angle rather than a scatter, so a flavour is drawn the
## same way every time — in a test and a screenshot as much as in the game — and
## so no two toppings land on top of one another however many there are.
func topping_offsets() -> PackedVector2Array:
	var out := PackedVector2Array()
	if toppings <= 0:
		return out
	for i in toppings:
		var angle := float(i) * 2.399963
		var reach: float = topping_spread * sqrt((float(i) + 0.5) / float(toppings))
		out.append(Vector2(cos(angle), sin(angle)) * reach)
	return out
