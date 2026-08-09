class_name ResultCard
extends Control

## Shown when the stack runs out or the last strike is spent.
##
## Left visible in the scene so opening it in the editor shows a real card;
## the game hides it before the first frame is drawn.

signal again_pressed

@export_group("Wording")
@export var won_heading: String = "GOOD JOB!"
@export var lost_heading: String = "YOU'RE FIRED!"
## %d is the number of deliveries that landed.
@export var won_body: String = "%d delivered."
@export var lost_body: String = "%d delivered before they stopped answering."
@export var won_button: String = "Next street"
@export var lost_button: String = "Try again"
## The street badge, %d being the street's number. Two lines, because the badge is
## a disc and a disc holds a squarish block of text with far less wasted room than
## a single wide line.
@export var level_stamp: String = "Street\n%d"

@export_group("Accents")
## The box lid's tape, the heading and the delivery stamp take this on a win.
## Cyan is the brand's "good": it is the colour of an open drop point, so a win
## closes on the colour you were aiming at.
@export var won_accent: Color = Color(0.23529412, 0.7058824, 0.8980392)
@export var won_button_colour: Color = Color(0.23529412, 0.7058824, 0.8980392)
## And these on a loss. A clear red reads as a stop; the earlier rose was too
## washed out to read against the box.
@export var lost_accent: Color = Color(0.83137256, 0.15686275, 0.13725491)
@export var lost_button_colour: Color = Color(0.83137256, 0.15686275, 0.13725491)

@export_group("Button letters")
## The checked button's label goes green to go on, red to try again — the two
## colours a diner reads without thinking.
@export var won_button_text: Color = Color(0.16078432, 0.6784314, 0.34117648)
@export var lost_button_text: Color = Color(0.83137256, 0.15686275, 0.13725491)

@onready var _panel: PanelContainer = $Panel
@onready var _heading: Label = %Heading
@onready var _body: Label = %Body
@onready var _level: Label = %LevelLabel
@onready var _pizza: PizzaIcon = %Pizza
@onready var _again: Button = %AgainButton

var _won: bool = false


func _ready() -> void:
	_again.pressed.connect(func() -> void: again_pressed.emit())


func show_result(won: bool, delivered: int, level_number: int) -> void:
	_won = won
	_heading.text = won_heading if won else lost_heading
	_body.text = (won_body if won else lost_body) % delivered
	_level.text = level_stamp % level_number
	_again.text = won_button if won else lost_button
	_pizza.set_dropped(not won)
	_apply_accent(won)
	show()


## Recolour the card to match the outcome, so a win and a loss are told apart at
## a glance and not only by reading. Every piece coloured here is a copy of the
## authored style, so the scene the designer opens is left untouched.
func _apply_accent(won: bool) -> void:
	var accent := won_accent if won else lost_accent
	var button := won_button_colour if won else lost_button_colour

	_heading.add_theme_color_override("font_color", accent)

	# The box lid's tape reads as the outcome: cyan "delivered", rose "dropped".
	var panel := (_panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	if panel != null:
		panel.border_color = accent
		_panel.add_theme_stylebox_override("panel", panel)

	# The street badge is a white disc ringed in red and green, drawn by the badge
	# itself with black letters, so it reads the same on a win and a loss.

	# The checked button carries the outcome in its letters: green to go on to
	# the next street, red to try the lost one again. The red-and-white border is
	# drawn by the button itself and is the same either way.
	var letters := won_button_text if won else lost_button_text
	_again.add_theme_color_override("font_color", letters)
	_again.add_theme_color_override("font_hover_color", letters)
	_again.add_theme_color_override("font_pressed_color", letters)


func was_won() -> bool:
	return _won
