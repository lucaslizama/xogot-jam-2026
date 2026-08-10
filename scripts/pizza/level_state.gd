class_name LevelState
extends Node

## Pizzas left and strikes left, and the rules about when a round is over.
##
## Both numbers are shown by the world rather than by a readout: the stack on
## the bike is the pizzas, the dots along the top are the strikes. This node
## just owns the truth they draw.

signal pizzas_changed(left: int)
signal strikes_changed(left: int)
## A delivery landed. `tier` is how well, `award` what it paid after the streak
## took its cut, and `streak` how many in a row it now is.
signal scored(tier: ScoreRules.ThrowTier, award: int, streak: int)
## Fires when a run long enough to have been worth something ends. A miss after
## one delivery is not worth mentioning; one after six is.
signal streak_lost(had: int)
## The running total changed, whether by a delivery or by the round starting over.
signal tips_changed(total: int)
## Fires once. `won` is true when the stack ran out with a strike still clean.
signal round_ended(won: bool, delivered: int)

## What a delivery is worth. Assigned in the scene, because it is all values.
@export var scoring: ScoreRules

var pizzas_left: int = 0
var strikes_left: int = 0
var delivered: int = 0
## Tips earned this street.
var tips: int = 0
## Deliveries in a row right now, and the longest run this street.
var streak: int = 0
var best_streak: int = 0

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
	tips = 0
	streak = 0
	best_streak = 0
	pizzas_left = maxi(1, config.pizzas_in_stack)
	strikes_left = clampi(config.strikes, 1, _max_strikes)
	if config.strikes > _max_strikes:
		push_warning("LevelState: level asks for %d strikes but the scene only has %d dots; clamping. Add dots in the scene to raise the ceiling."
			% [config.strikes, _max_strikes])
	pizzas_changed.emit(pizzas_left)
	strikes_changed.emit(strikes_left)
	tips_changed.emit(tips)


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


## A pizza arrived. `tier` says how well it went, which is what the tip is worth.
## Returns what it paid, so the caller can show it where the pizza landed.
func note_delivery(tier: ScoreRules.ThrowTier = ScoreRules.ThrowTier.NICE) -> int:
	if _over:
		return 0
	delivered += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	# No rules assigned means no scoring, and the round still plays: the tips are
	# an extra on top of the game, not the game.
	var award := 0
	if scoring != null:
		award = scoring.award_for(tier, streak)
		tips += award
		tips_changed.emit(tips)
	scored.emit(tier, award, streak)
	return award


func note_miss() -> void:
	if _over:
		return
	# Report the run before clearing it, and only when it was worth having.
	if scoring != null and scoring.streak_is_paying(streak):
		streak_lost.emit(streak)
	streak = 0
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
