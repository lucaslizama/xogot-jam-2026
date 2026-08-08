class_name ResultCard
extends Control

## Shown when the stack runs out or the last strike is spent.
##
## Left visible in the scene so opening it in the editor shows a real card;
## the game hides it before the first frame is drawn.

signal again_pressed

@export_group("Wording")
@export var won_heading: String = "ROUND DONE"
@export var lost_heading: String = "SACKED"
## %d is the number of deliveries that landed.
@export var won_body: String = "%d delivered."
@export var lost_body: String = "%d delivered before they stopped answering."
@export var won_button: String = "Next street"
@export var lost_button: String = "Try again"

@onready var _heading: Label = %Heading
@onready var _body: Label = %Body
@onready var _level: Label = %LevelLabel
@onready var _again: Button = %AgainButton

var _won: bool = false


func _ready() -> void:
	_again.pressed.connect(func() -> void: again_pressed.emit())


func show_result(won: bool, delivered: int, level_number: int) -> void:
	_won = won
	_heading.text = won_heading if won else lost_heading
	_body.text = (won_body if won else lost_body) % delivered
	_level.text = "Street %d" % level_number
	_again.text = won_button if won else lost_button
	show()


func was_won() -> bool:
	return _won
