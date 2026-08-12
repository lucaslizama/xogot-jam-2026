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
@export var lost_body: String = "%d delivered before it all hit the pavement."
## What the street paid. The first %d is the tips, the second the longest run of
## deliveries without a miss.
@export var tips_line: String = "$%d in tips, best run of %d"
## What the shop's orders came to. The first %d is how many were filled, the second
## how many were written. Said only on a street that wrote any, so a street with no
## orders on it does not report nought out of nought.
@export var orders_line: String = "%d of %d orders filled"
## Said instead when every one of them was filled, because that is worth more than
## a fraction the player has to notice reads the same top and bottom.
@export var orders_all_line: String = "Every order filled"
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
@export var won_accent: Color = Color(0.301961, 0.65098, 1)
@export var won_button_colour: Color = Color(0.301961, 0.65098, 1)
## And these on a loss. A clear red reads as a stop; the earlier rose was too
## washed out to read against the box.
@export var lost_accent: Color = Color(0.921569, 0.337255, 0.294118)
@export var lost_button_colour: Color = Color(0.921569, 0.337255, 0.294118)

@export_group("Button letters")
## The checked button's label goes green to go on, red to try again — the two
## colours a diner reads without thinking.
@export var won_button_text: Color = Color(0.235294, 0.639216, 0.439216)
@export var lost_button_text: Color = Color(0.921569, 0.337255, 0.294118)

@onready var _panel: PanelContainer = $Panel
@onready var _heading: Label = %Heading
@onready var _body: Label = %Body
@onready var _tips: Label = %Tips
@onready var _orders: Label = %Orders
@onready var _level: Label = %LevelLabel
@onready var _pizza: PizzaIcon = %Pizza
@onready var _again: Button = %AgainButton

var _won: bool = false


func _ready() -> void:
	_again.pressed.connect(func() -> void: again_pressed.emit())


func show_result(won: bool, delivered: int, level_number: int, tips: int = 0,
		best_streak: int = 0, orders_filled: int = 0, orders_written: int = 0) -> void:
	_won = won
	_heading.text = won_heading if won else lost_heading
	_body.text = (won_body if won else lost_body) % delivered
	# A street where nothing was scored has nothing to say about tips, and an
	# empty line on the card reads as something missing rather than as nothing.
	_tips.visible = tips > 0
	_tips.text = tips_line % [tips, best_streak]
	_show_orders(orders_filled, orders_written)
	_level.text = level_stamp % level_number
	_again.text = won_button if won else lost_button
	_pizza.set_dropped(not won)
	_apply_accent(won)
	show()


## What the shop's orders came to. Silent on a street that never wrote one, which
## is how the first street is authored, rather than reporting nought out of nought
## and leaving the player to wonder what they missed.
func _show_orders(filled: int, written: int) -> void:
	_orders.visible = written > 0
	if written <= 0:
		return
	_orders.text = orders_all_line if filled >= written else orders_line % [filled, written]


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
