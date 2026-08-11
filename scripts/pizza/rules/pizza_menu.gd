class_name PizzaMenu
extends Resource

## What the shop sells, in the order the player cycles through.
##
## The order on this list is the order a tap walks through, so it is worth
## arranging: the one a player wants most often should be first, since that is
## what they start each run holding and what costs them no taps at all.
##
## An empty menu is not an error. The game then has no flavours, the swap does
## nothing, and the pizza is drawn from the scene's own colours — which is exactly
## how it looked before any of this existed.

@export var flavours: Array[PizzaFlavour] = []


func count() -> int:
	return flavours.size()


## The flavour at an index, wrapped, so a caller can just keep counting upwards
## and never has to know how long the list is. Null for an empty menu.
func flavour_at(index: int) -> PizzaFlavour:
	if flavours.is_empty():
		return null
	return flavours[posmod(index, flavours.size())]
