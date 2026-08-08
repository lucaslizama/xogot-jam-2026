class_name RunEndCard
extends Control

## Shown when the order is served or the last heart goes.
##
## Left visible in the scene so opening main.tscn in the editor shows a real,
## populated card; RunDirector hides it in _ready before anything is drawn.

signal replay_requested

@export_group("Wording")
@export var victory_heading: String = "ORDER UP!"
@export var defeat_heading: String = "86'd"
## %d is filled with the number of dishes served.
@export var victory_body: String = "%d dishes out the pass."
@export var defeat_body: String = "You served %d before the kitchen fell apart."

@onready var _heading: Label = %Heading
@onready var _body: Label = %Body
@onready var _again: Button = %AgainButton


func _ready() -> void:
	_again.pressed.connect(func() -> void: replay_requested.emit())


func show_result(victory: bool, dishes_served: int) -> void:
	_heading.text = victory_heading if victory else defeat_heading
	_body.text = (victory_body if victory else defeat_body) % dishes_served
	show()
