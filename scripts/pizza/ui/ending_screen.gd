class_name EndingScreen
extends Control

## The end of the night, after the last street is cleared.
##
## The result card reports a street; this reports the run. It exists because there
## was nothing here before: winning the last street clamped the level index and put
## the player back on street three for ever, so the game had no way of admitting it
## had been finished.
##
## What it says leans on the daylight the streets already cross. Street one is
## delivered at night, street two at sunrise, street three in daylight, so a player
## who clears all three has literally ridden until morning. That is the ending the
## game already had; this only says it out loud.
##
## Numbers are for the whole run rather than the last street, retries included. A
## night you had to try twice is still the night you had.

## Start again from the first street, as a new run.
signal again_pressed
## Leave for the front menu.
signal menu_pressed

@export_group("Wording")
@export var heading: String = "SUN'S UP!"
## %d is how many streets were cleared.
@export var body: String = "%d streets, and you rode every one."
## In order: the night's tips, and the longest run of deliveries in it.
@export var tips_line: String = "$%d in tips, best run of %d"
## Filled and written. Empty either line to say nothing.
@export var orders_line: String = "%d of %d orders filled"
## When every one of them was filled, which deserves better than a fraction.
@export var orders_all_line: String = "Every order filled"
@export var again_button: String = "Ride again"
@export var menu_button: String = "Main menu"

@onready var _heading: Label = %EndHeading
@onready var _body: Label = %EndBody
@onready var _tips: Label = %EndTips
@onready var _orders: Label = %EndOrders
@onready var _again: Button = %RideAgainButton
@onready var _menu: Button = %EndMenuButton


func _ready() -> void:
	hide()
	_again.pressed.connect(func() -> void: again_pressed.emit())
	_menu.pressed.connect(func() -> void: menu_pressed.emit())


## Put the night on screen. Called once, by the game, when the last street is done.
func show_run(streets: int, tips: int, best_streak: int, filled: int, written: int) -> void:
	_heading.text = heading
	_body.text = body % streets
	_tips.text = tips_line % [tips, best_streak]
	_tips.visible = not tips_line.is_empty()
	_show_orders(filled, written)
	_again.text = again_button
	_menu.text = menu_button
	show()


## A run that was never asked for an order says nothing about orders, rather than
## reporting nought out of nought as though it had failed at something.
func _show_orders(filled: int, written: int) -> void:
	if written <= 0 or orders_line.is_empty():
		_orders.visible = false
		return
	_orders.visible = true
	_orders.text = orders_all_line if filled >= written and not orders_all_line.is_empty() \
		else orders_line % [filled, written]
