class_name Minigame
extends Node

## Base class every minigame extends. The contract is deliberately tiny:
## the host calls [method begin], the minigame emits [signal finished] once.
##
## The host owns the clock, the countdown and the win/lose sting, so a minigame
## never has to think about them. It also owns the viewport, so a landscape
## minigame is authored landscape and never learns it is being rotated.

## Emitted exactly once, when the minigame resolves. The host frees the scene
## afterwards; do not emit it yourself, call [method succeed] or [method fail].
signal finished(success: bool)

## The situation this minigame was started in. Set by the host before
## [method begin] runs.
var context: MinigameContext

var _resolved: bool = false


## Override this. Called once, after the scene is in the tree and [member
## context] is set. Set up spawners, seed positions, start animations here.
func begin(_ctx: MinigameContext) -> void:
	pass


## Call when the player has won. Safe to call more than once; only the first
## resolution counts.
func succeed() -> void:
	_resolve(true)


## Call when the player has lost. Safe to call more than once.
func fail() -> void:
	_resolve(false)


## True once this minigame has resolved. Useful to stop scoring input during
## the outro.
func is_resolved() -> bool:
	return _resolved


## Called by the host when the clock runs out. Whether that is a win is decided
## by [member MinigameInfo.win_on_timeout], so the minigame stays clock-agnostic.
func notify_timeout(win_on_timeout: bool) -> void:
	_resolve(win_on_timeout)


func _resolve(success: bool) -> void:
	if _resolved:
		return
	_resolved = true
	finished.emit(success)
