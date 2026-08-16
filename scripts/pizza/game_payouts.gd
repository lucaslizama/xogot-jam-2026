class_name GamePayouts
extends Node

## Everything the player is told about money: the bills, the words over the throw,
## and the running total in the corner.
##
## A tip nobody sees is a number going up in a corner, and the corner is not where
## anyone is looking. So a throw's worth is said where it landed, and this owns the
## three things that say it: the burst of bills, the popup, and the total.
##
## It keeps where the last throw landed, because every popup here is anchored to it
## and nothing else in the game needs to know.

@onready var _tips: Label = %Tips
@onready var _tip_popup: TipPopup = %TipPopup
@onready var _money: MoneyBurst = %MoneyBurst

var _state: LevelState
var _last_landing: Vector2 = Vector2.ZERO


## Take the round's bookkeeping and listen to it. The total and a lost streak are
## the round's news rather than the throw's, so they arrive as signals.
func bind(state: LevelState) -> void:
	_state = state
	if _state == null:
		return
	_state.tips_changed.connect(_show_total)
	_state.streak_lost.connect(_on_streak_lost)


## Where the throw ended, kept so a popup can be put at the spot the player was
## looking at rather than somewhere generic.
func note_landing(at: Vector2) -> void:
	_last_landing = at


## Say what the throw earned, where it landed.
func pay_throw(at: Vector2, tier: ScoreRules.ThrowTier, award: int, streak: int) -> void:
	# The bills go up before the words do, and there are more for a better throw.
	# Across the room the burst is the only part anyone can read, so it has to be
	# the part that says how it went.
	_money.burst(at, _money.bills_for(tier))
	var rules: ScoreRules = _state.scoring if _state != null else null
	if rules == null:
		return
	var run := ""
	if rules.streak_is_paying(streak):
		run = rules.label_streak % streak
	_tip_popup.show_tip(at, rules.label_for(tier), rules.label_tip % award, run,
		_tip_popup.colour_for(tier))


## A filled order pays into the same purse, so it throws the same bills, at the
## spot the throw that filled it landed. The words for it are the ticket's own.
func celebrate_order() -> void:
	_money.burst(_last_landing, _money.bills_for(ScoreRules.ThrowTier.WINDOW))


## A run ending is worth saying only when it was long enough to have been worth
## keeping. The popup goes where the miss happened, so it reads as the consequence
## of that throw rather than as an announcement.
func _on_streak_lost(had: int) -> void:
	var rules: ScoreRules = _state.scoring if _state != null else null
	if rules == null:
		return
	# The wording may or may not want the number in it, so both spellings work and
	# neither crashes the round over a format string.
	var said := rules.label_streak_lost
	if said.contains("%d"):
		said = said % had
	_tip_popup.show_message(_last_landing, said, _tip_popup.colour_streak_lost)


func _show_total(total: int) -> void:
	if _state == null or _state.scoring == null:
		return
	_tips.text = _state.scoring.label_total % total
