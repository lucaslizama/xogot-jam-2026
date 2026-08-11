class_name OrderBoard
extends RefCounted

## Writes the tickets, counts down their clocks, and marks deliveries off them.
##
## One ticket at a time, and that is a decision rather than a shortcut. Two clocks
## running at once is the whole game in Overcooked, but this street is already a
## timer — a house you do not reach slides away — and a second countdown would be
## competing for the same glance the house needs. One ticket can be read in the gap
## between houses, which is dead time the game was not using for anything.
##
## Nothing here can hurt the player. A ticket that runs out is gone, and that is
## the end of it: no strike, no broken streak, no mark on the round. The board is
## driven by the game but knows nothing about it, so all of this is tested with no
## screen and no street.

## A new ticket is up.
signal opened(order: PizzaOrder)
## A delivery was marked off one. Not emitted for a delivery the ticket did not
## want, so a listener can take this as "something changed on the ticket".
signal progressed(order: PizzaOrder)
## Filled in time. The reward is on the order, not decided here.
signal completed(order: PizzaOrder)
## Ran out of clock.
signal expired(order: PizzaOrder)

## Filled and lost this street, and what the filled ones paid. For the result card.
var filled: int = 0
var lost: int = 0
var earned: int = 0

var _rules: OrderRules
var _menu: PizzaMenu
var _rng := RandomNumberGenerator.new()
var _open: PizzaOrder
var _until_next: float = 0.0
var _closed: bool = false


## Start taking orders for a street. A null rules or an empty menu leaves the board
## dormant: [method advance] does nothing and no ticket ever appears, which is how a
## street is authored to have no orders at all.
func begin(rules: OrderRules, menu: PizzaMenu, seed_value: int) -> void:
	_rules = rules
	_menu = menu
	_open = null
	_closed = false
	filled = 0
	lost = 0
	earned = 0
	_rng.seed = seed_value
	if not _is_taking_orders():
		return
	_until_next = maxf(0.0, rules.first_after)


func _is_taking_orders() -> bool:
	return _rules != null and _menu != null and _menu.count() > 0


## The ticket on the board, or null when there is none.
func open_order() -> PizzaOrder:
	return _open


## Run the clocks. Called every frame by the game while the street is being played.
func advance(delta: float) -> void:
	if _closed or not _is_taking_orders():
		return
	if _open != null:
		_open.seconds_left -= delta
		if _open.has_run_out():
			var gone := _open
			_open = null
			lost += 1
			_until_next = maxf(0.0, _rules.gap_after)
			expired.emit(gone)
		return
	_until_next -= delta
	if _until_next <= 0.0:
		_open = _write_order()
		opened.emit(_open)


## Mark a delivery off the open ticket. The flavour is the one that was thrown, not
## the one now in hand: swapping while a pizza is in the air prepares the next one
## and must not change what the last one counted as.
func note_delivery(flavour: PizzaFlavour) -> void:
	if _closed or _open == null:
		return
	if not _open.take(flavour):
		return
	if not _open.is_filled():
		progressed.emit(_open)
		return
	var full := _open
	_open = null
	filled += 1
	earned += full.pays
	_until_next = maxf(0.0, _rules.gap_after)
	completed.emit(full)


## The street is over. Any open ticket is dropped without a word: a round ending is
## not the player failing an order, and saying "too late" over the result card would
## read as though it were.
func close() -> void:
	_closed = true
	_open = null


## Deal a ticket. Every item is a real flavour off the menu and every line asks for
## at least one, so a ticket can always be filled by somebody who reads it.
func _write_order() -> PizzaOrder:
	var order := PizzaOrder.new()
	var items_range := _rules.item_range()
	var items := _rng.randi_range(items_range.x, items_range.y)
	# Never more kinds than there are items to spread over them, or than the shop
	# actually sells.
	var kinds: int = mini(mini(_rules.kinds_max, _menu.count()), items)

	var picked := _pick_flavours(kinds)
	order.wants = picked
	order.needed.resize(picked.size())
	order.done.resize(picked.size())
	# One each first, so no line asks for nothing, then the remainder scattered.
	for i in picked.size():
		order.needed[i] = 1
		order.done[i] = 0
	for _extra in items - picked.size():
		var at := _rng.randi_range(0, picked.size() - 1)
		order.needed[at] += 1

	var seconds := _rules.seconds_range()
	order.seconds_total = _rng.randf_range(seconds.x, seconds.y)
	order.seconds_left = order.seconds_total
	order.pays = _rules.pays
	order.gives_strike_back = _rules.gives_strike_back
	return order


## Distinct flavours off the menu, in menu order so two tickets asking for the same
## pair read the same way round.
func _pick_flavours(how_many: int) -> Array[PizzaFlavour]:
	var indices: Array[int] = []
	for i in _menu.count():
		indices.append(i)
	# Drawn without replacement, so a ticket never names the same flavour twice.
	for _drop in maxi(0, indices.size() - how_many):
		indices.remove_at(_rng.randi_range(0, indices.size() - 1))
	indices.sort()

	var out: Array[PizzaFlavour] = []
	for i in indices:
		out.append(_menu.flavour_at(i))
	return out
