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

## How an order names it.
@export var display_name: String = "Cheese"
## The finished pizza. Assign one and the box below is gone; the art is stretched
## to whatever size the node it is drawn on asks for, so the same image serves the
## big one in your hand and the small one in the air.
@export var art: Texture2D
## A small square for the order ticket, where a whole pizza would be too much
## detail. Nothing reads it yet; it is here so the slot exists next to the art it
## belongs with.
@export var icon: Texture2D

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
