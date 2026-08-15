class_name OrderRules
extends Resource

## How a street asks for orders: how often, how much, how long, and what filling
## one is worth.
##
## Orders sit over the game rather than in front of it: an order that runs out of
## time takes no strike and leaves no mark, so a player can ignore the ticket and
## play the street exactly as it played before orders existed.
##
## Which means these numbers, not the code, decide whether the feature is any good.
## Pay too little and nobody swaps; pay too much and the ticket becomes a tax.
## Expect to move them by feel. A street with no rules has no orders, which is a
## fair way to author the first one.

@export_group("When one turns up")
## Seconds before the first ticket. Long enough that a player has thrown a pizza or
## two and is not reading a ticket before they have the street.
@export_range(0.0, 40.0, 0.5) var first_after: float = 7.0
## And the gap after one is filled or lost, so there is a beat with nothing to read.
@export_range(0.0, 40.0, 0.5) var gap_after: float = 5.0

@export_group("What it asks for")
## Pizzas the ticket wants in total, across all its lines.
@export_range(1, 8) var items_min: int = 2
@export_range(1, 8) var items_max: int = 3
## How many flavours one ticket may name. At 1 it needs only the swap that starts
## it; at 2 or more it needs one partway through, which is the harder ask.
@export_range(1, 4) var kinds_max: int = 2

@export_group("How long it lasts")
## Seconds on the clock. Worth measuring against the street rather than guessing:
## it has to be long enough for that many houses to actually come past.
@export_range(4.0, 120.0, 0.5) var seconds_min: float = 20.0
@export_range(4.0, 120.0, 0.5) var seconds_max: float = 28.0

@export_group("What filling it pays")
## Straight onto the tips. An order is several throws' work, so weigh it against
## what one delivery pays.
@export_range(0, 20000, 50) var pays: int = 900
## And a chance back, never more than the street started with. A difficulty valve
## that opens only for good play: it makes a hard street survivable without making
## it easier for everybody.
@export var gives_strike_back: bool = false


## The ranges, in order however they were typed. The larger number in the "min" box
## should give a sane order, not an empty range that silently never fires.
func item_range() -> Vector2i:
	return Vector2i(mini(items_min, items_max), maxi(items_min, items_max))


func seconds_range() -> Vector2:
	return Vector2(minf(seconds_min, seconds_max), maxf(seconds_min, seconds_max))
