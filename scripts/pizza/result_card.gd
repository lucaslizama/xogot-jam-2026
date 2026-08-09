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

@export_group("Accents")
## The box lid's tape, the heading and the delivery stamp take this on a win.
## Cyan is the brand's "good": it is the colour of an open drop point, so a win
## closes on the colour you were aiming at.
@export var won_accent: Color = Color(0.23529412, 0.7058824, 0.8980392)
@export var won_button_colour: Color = Color(0.23529412, 0.7058824, 0.8980392)
## And these on a loss. A warm rose reads as a stop without shouting like red,
## and still sits in the game's purple-leaning palette.
@export var lost_accent: Color = Color(0.85882354, 0.36078432, 0.45882353)
@export var lost_button_colour: Color = Color(0.6784314, 0.27058825, 0.36078432)

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
	_level.text = "STREET %d" % level_number
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
	_level.add_theme_color_override("font_color", accent)

	# The box lid's tape reads as the outcome: cyan "delivered", rose "dropped".
	var panel := (_panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	if panel != null:
		panel.border_color = accent
		_panel.add_theme_stylebox_override("panel", panel)

	# The delivery stamp's rule matches the tape.
	var stamp := (_level.get_theme_stylebox("normal") as StyleBoxFlat)
	if stamp != null:
		var stamp_copy := stamp.duplicate() as StyleBoxFlat
		stamp_copy.border_color = accent
		_level.add_theme_stylebox_override("normal", stamp_copy)

	# The button is a printed sticker: a solid colour fill inside a white die-cut
	# border, with the label in white on top. The fill carries the outcome, and
	# reads far better under white text than a pale rose did on cream. Hover and
	# press only lighten and darken the fill, the way pressing a label would.
	_again.add_theme_color_override("font_color", Color.WHITE)
	_again.add_theme_color_override("font_hover_color", Color.WHITE)
	_again.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed"]:
		var box := (_again.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		if box == null:
			continue
		var fill := button
		if state == "hover":
			fill = button.lightened(0.1)
		elif state == "pressed":
			fill = button.darkened(0.2)
		box.bg_color = fill
		_again.add_theme_stylebox_override(state, box)


func was_won() -> bool:
	return _won
