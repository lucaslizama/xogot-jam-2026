class_name OrderTicket
extends Control

## The ticket from the shop, on screen: what is wanted, how much of it has arrived,
## and how long there is left.
##
## The lines are authored in the scene rather than spawned here, the same way the
## strike dots are, so their size, spacing and font belong to whoever is looking at
## the screen. That also makes the scene the authority on how many lines a ticket
## may have: a rules file asking for more kinds than there are rows gets clamped and
## told about it, rather than quietly asking for a flavour the player cannot see.
##
## Each row is a box holding two things: an [code]Icon[/code] showing the flavour and
## a [code]Text[/code] label saying how many of it are wanted. Both are found by name,
## so a row can be rearranged, resized or reordered on the canvas without touching
## this file; how big the icon is and how far it sits from the words are the scene's
## business. A row missing its label says so at startup rather than coming up blank.
##
## Nothing here is a size or a font. What it says lives in the exports below, what
## it looks like lives in order_ticket.tscn and the theme.
##
## The verdict is no longer written on the card. It was, and nobody read it: an order
## is filled by a throw, and while a pizza is in the air the player is watching the
## far end of the street, not a card in the top corner. The wording still lives here,
## because it is the ticket's own words and this is where a designer looks for them,
## but the saying of it is the OrderPopup's job, over the rider. All this does when a
## ticket is finished is hold still long enough for the rows to be read and leave.

@export_group("Wording")
## One line of the ticket. Three numbers in order: how many have arrived, how many
## are wanted, and what they are.
@export var line_format: String = "%d/%d  %s"
## Said over the rider when the ticket is filled, and when it runs out. The second is
## deliberately mild: losing an order costs nothing but the bonus, and language that
## reads like a punishment would say otherwise.
@export var filled_wording: String = "ORDER UP!"
@export var expired_wording: String = "Order gone"
## What filling it paid, alongside the words. Empty to say nothing.
@export var paid_format: String = "+$%d"
## Added when the order also handed a chance back, which is worth more than the
## money and should not be left for the player to notice on their own.
@export var strike_back_wording: String = "+1 chance"

@export_group("Colours")
## A line still owed, and a line that has been filled.
@export var line_owed: Color = Color(1, 1, 0.921569)
@export var line_filled: Color = Color(0.560784, 0.870588, 0.364706)
## The clock, and what it turns into as it runs down.
@export var clock_calm: Color = Color(0.301961, 0.65098, 1)
@export var clock_urgent: Color = Color(0.921569, 0.337255, 0.294118)
## Below this much of the clock left, it is the urgent colour.
@export_range(0.0, 1.0, 0.01) var urgent_below: float = 0.3

@export_group("Timing")
## How long the ticket takes to slide in and out.
@export_range(0.0, 1.0, 0.01) var arrive_duration: float = 0.25
## How long a finished ticket stays put before it leaves, so the row that just turned
## green can be read. What it earned is said over the rider meanwhile.
@export_range(0.0, 3.0, 0.05) var finished_linger: float = 1.1
## How far to the left the ticket sits while it is away.
@export_range(0.0, 1200.0, 10.0) var hide_offset: float = 620.0

@onready var _lines: VBoxContainer = %Lines
@onready var _clock: ColorRect = %Clock
@onready var _clock_track: Control = %ClockTrack

var _tween: Tween
## Where the ticket sits when it is on screen, read off the scene so the scene keeps
## deciding where that is.
var _home_x: float = 0.0


func _ready() -> void:
	_home_x = position.x
	position.x = _home_x - hide_offset
	modulate.a = 0.0
	visible = false
	_check_the_rows_can_be_written()


## Said once, at startup, rather than every time a ticket is filled in.
##
## A row is two nodes in the scene and this reaches them by name, so rearranging a
## row is easy and breaking one is silent: a missing label writes nothing, and a
## ticket with blank lines looks like the orders themselves have gone wrong. Better
## to name the row that cannot be written than to leave somebody reading the board.
func _check_the_rows_can_be_written() -> void:
	for row in _lines.get_children():
		if row.get_node_or_null(^"Text") == null:
			push_warning(("OrderTicket: row %s has no Text label, so what the order "
				+ "wants cannot be written on it. Each row in order_ticket.tscn wants "
				+ "a Text label, and an Icon beside it to show the flavour.") % row.name)


## How many lines the scene can actually draw. OrderRules is clamped to this.
func line_capacity() -> int:
	return _lines.get_child_count()


## A new ticket. Fills the rows in, hides the surplus, and slides it in.
func show_order(order: PizzaOrder) -> void:
	_fill_lines(order)
	_show_clock(order)
	visible = true
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "position:x", _home_x, arrive_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, arrive_duration)


## A delivery was marked off. Only the rows change; the ticket stays put.
func update_order(order: PizzaOrder) -> void:
	_fill_lines(order)


## Called every frame while a ticket is up, so the clock runs down smoothly rather
## than in steps whenever something else happens.
func show_clock_of(order: PizzaOrder) -> void:
	if order == null or not visible:
		return
	_show_clock(order)


## What filling one paid, worded, for whoever is saying so. Empty when there was
## nothing to pay or the ticket is set to say nothing about it.
func paid_line(paid: int) -> String:
	if paid <= 0 or paid_format.is_empty():
		return ""
	return paid_format % paid


## Hold still for a moment, then take the ticket away. The same move whether it was
## filled or lost, because either way the ticket is finished with; what happened is
## said elsewhere, and the rows already show which it was.
func close_order() -> void:
	_kill_tween()
	# Deliberately not awaited. A tween the game waits on is a tween still held if
	# the scene goes away mid-slide, which is reported as a leaked instance and
	# reads exactly like a bug in the game.
	_tween = create_tween()
	_tween.tween_interval(finished_linger)
	_tween.tween_property(self, "position:x", _home_x - hide_offset, arrive_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, arrive_duration)
	_tween.tween_callback(_park)


## Off screen at once, with nothing said. For a street ending under an open ticket,
## where a verdict would read as the player having failed it.
func clear() -> void:
	_kill_tween()
	_park()


func _park() -> void:
	visible = false
	modulate.a = 0.0
	position.x = _home_x - hide_offset


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _fill_lines(order: PizzaOrder) -> void:
	var rows := _lines.get_children()
	for i in rows.size():
		var row := rows[i] as Control
		if row == null:
			continue
		if i >= order.line_count():
			row.visible = false
			continue
		var counts := order.line(i)
		var flavour := order.wants[i]
		row.visible = true

		var text := row.get_node_or_null(^"Text") as Label
		if text != null:
			text.text = line_format % [counts.y, counts.x, flavour.display_name]
			text.add_theme_color_override(&"font_color",
				line_filled if order.line_is_filled(i) else line_owed)

		# The name stays even with a picture beside it. A flavour has to be readable
		# to somebody who cannot tell its colours apart, which is the same reason the
		# pizzas differ by how many toppings they have and not only by hue.
		var icon := row.get_node_or_null(^"Icon") as TextureRect
		if icon != null:
			icon.texture = flavour.icon
			# A flavour that brought no icon leaves no gap where one would have been.
			icon.visible = flavour.icon != null


## The bar is sized rather than scaled, so the rounded ends of the art that will
## one day replace it do not stretch as it shrinks.
func _show_clock(order: PizzaOrder) -> void:
	var left := order.fraction_left()
	_clock.size = Vector2(_clock_track.size.x * left, _clock_track.size.y)
	_clock.color = clock_urgent if left <= urgent_below else clock_calm
