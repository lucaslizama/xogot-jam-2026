class_name LevelState
extends Node

## Pizzas left and strikes left, and the rules about when a round is over.
##
## Both numbers are shown by the world rather than by a readout: the stack on
## the bike is the pizzas, the dots along the top are the strikes. This node
## just owns the truth they draw.

signal pizzas_changed(left: int)
signal strikes_changed(left: int)
## Fires once. `won` is true when the stack ran out with a strike still clean.
signal round_ended(won: bool, delivered: int)

var pizzas_left: int = 0
var strikes_left: int = 0
var delivered: int = 0

var _config: LevelConfig
var _max_strikes: int = 8
var _over: bool = false


## Tell the state how many strike dots the scene actually has. A level asking
## for more than the scene can draw is clamped and reported, rather than
## silently giving the player invisible chances.
func bind_strike_capacity(slots: int) -> void:
	_max_strikes = maxi(1, slots)


func begin(config: LevelConfig) -> void:
	_config = config
	_over = false
	delivered = 0
	pizzas_left = maxi(1, config.pizzas_in_stack)
	strikes_left = clampi(config.strikes, 1, _max_strikes)
	if config.strikes > _max_strikes:
		push_warning("LevelState: level asks for %d strikes but the scene only has %d dots; clamping. Add dots in the scene to raise the ceiling."
			% [config.strikes, _max_strikes])
	pizzas_changed.emit(pizzas_left)
	strikes_changed.emit(strikes_left)


## A pizza has left the bike. Called on the throw, not on the landing, so the
## stack shrinks the moment it is thrown.
func spend_pizza() -> void:
	if _over or pizzas_left <= 0:
		return
	pizzas_left -= 1
	pizzas_changed.emit(pizzas_left)


## True while there is still a pizza on the bike to throw.
func can_throw() -> bool:
	return not _over and pizzas_left > 0


func note_delivery() -> void:
	if _over:
		return
	delivered += 1


func note_miss() -> void:
	if _over:
		return
	strikes_left = maxi(0, strikes_left - 1)
	strikes_changed.emit(strikes_left)
	if strikes_left == 0:
		_finish(false)


## Called once the last thrown pizza has landed. The round is only won here,
## never earlier: the final throw still has to resolve.
func note_flight_settled() -> void:
	if _over or pizzas_left > 0:
		return
	_finish(true)


func is_over() -> bool:
	return _over


func _finish(won: bool) -> void:
	if _over:
		return
	_over = true
	round_ended.emit(won, delivered)
