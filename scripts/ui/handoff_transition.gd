class_name HandoffTransition
extends Control

## The beat between minigames: hands pass the ingredient on, and a card tells
## the player what is coming so they can get ready.
##
## It doubles as the loading window — the next minigame is instanced after this
## finishes, so any hitch hides behind the animation.

## Emitted when the transition is done and the next minigame may start.
signal finished

@export_group("Timing")
## How long the hands take to pass the ingredient across.
@export_range(0.05, 3.0, 0.05) var handoff_duration: float = 0.45
## How long the get-ready card is held on screen before play begins.
@export_range(0.05, 3.0, 0.05) var card_duration: float = 0.85
## Fade in and out either side of the card.
@export_range(0.0, 1.0, 0.05) var fade_duration: float = 0.15

@export_group("Wording")
## Shown above the verb, e.g. "Potatoes". Hidden when the step has no
## ingredient, as cooking steps are about the dish.
@export var about_prefix: String = ""

@onready var _verb: Label = %Verb
@onready var _hint: Label = %Hint
@onready var _about: Label = %About
@onready var _hands: Control = %Hands


func _ready() -> void:
	modulate.a = 0.0
	visible = false


## Play the handoff and the get-ready card for the coming step, then return.
## Awaitable: `await transition.play(step)`.
func play(step: RunStep) -> void:
	_verb.text = step.info.prompt_verb
	_hint.text = step.info.control_hint
	var about := step.ingredient.display_name if step.ingredient != null else step.dish.display_name
	_about.text = about_prefix + about

	visible = true
	modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	# The hands sweep across while the card is still fading in.
	tween.parallel().tween_property(_hands, "position:x", _hands_travel(), handoff_duration)\
		.from(-_hands_travel()).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(card_duration)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tween.finished

	visible = false
	finished.emit()


func _hands_travel() -> float:
	# Sweep proportional to the screen so it reads the same on any device.
	return size.x * 0.5
