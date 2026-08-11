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
## Nothing here is a size or a font. What it says lives in the exports below, what
## it looks like lives in order_ticket.tscn and the theme.

@export_group("Wording")
## One line of the ticket. Three numbers in order: how many have arrived, how many
## are wanted, and what they are.
@export var line_format: String = "%d/%d  %s"
## Said across the ticket when it is filled, and when it runs out. The second is
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
@export var line_owed: Color = Color(0.94, 0.89, 0.83)
@export var line_filled: Color = Color(0.35, 0.87, 0.47)
## The clock, and what it turns into as it runs down.
@export var clock_calm: Color = Color(0.36, 0.71, 0.9)
@export var clock_urgent: Color = Color(0.9, 0.32, 0.28)
## Below this much of the clock left, it is the urgent colour.
@export_range(0.0, 1.0, 0.01) var urgent_below: float = 0.3

@export_group("Timing")
## How long the ticket takes to slide in and out.
@export_range(0.0, 1.0, 0.01) var arrive_duration: float = 0.25
## How long the verdict sits there once the ticket is settled, before it leaves.
@export_range(0.0, 3.0, 0.05) var verdict_linger: float = 1.1
## How far to the left the ticket sits while it is away.
@export_range(0.0, 1200.0, 10.0) var hide_offset: float = 620.0

@onready var _lines: VBoxContainer = %Lines
@onready var _verdict: Label = %Verdict
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
	_verdict.hide()
	visible = false


## How many lines the scene can actually draw. OrderRules is clamped to this.
func line_capacity() -> int:
	return _lines.get_child_count()


## A new ticket. Fills the rows in, hides the surplus, and slides it in.
func show_order(order: PizzaOrder) -> void:
	_verdict.hide()
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


## Say how it went, then take the ticket away. The same move either way, because
## either way the ticket is finished with; only the words and the colour differ.
func close_order(wording: String, colour: Color, paid: int, gave_strike_back: bool) -> void:
	var said := wording
	if paid > 0 and not paid_format.is_empty():
		said += "  " + paid_format % paid
	if gave_strike_back and not strike_back_wording.is_empty():
		said += "  " + strike_back_wording
	_verdict.text = said
	_verdict.add_theme_color_override(&"font_color", colour)
	_verdict.show()

	_kill_tween()
	# Deliberately not awaited. A tween the game waits on is a tween still held if
	# the scene goes away mid-slide, which is reported as a leaked instance and
	# reads exactly like a bug in the game.
	_tween = create_tween()
	_tween.tween_interval(verdict_linger)
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
	_verdict.hide()
	modulate.a = 0.0
	position.x = _home_x - hide_offset


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _fill_lines(order: PizzaOrder) -> void:
	var rows := _lines.get_children()
	for i in rows.size():
		var row := rows[i] as Label
		if row == null:
			continue
		if i >= order.line_count():
			row.visible = false
			continue
		var counts := order.line(i)
		var flavour := order.wants[i]
		row.visible = true
		row.text = line_format % [counts.y, counts.x, flavour.display_name]
		row.add_theme_color_override(&"font_color",
			line_filled if order.line_is_filled(i) else line_owed)


## The bar is sized rather than scaled, so the rounded ends of the art that will
## one day replace it do not stretch as it shrinks.
func _show_clock(order: PizzaOrder) -> void:
	var left := order.fraction_left()
	_clock.size = Vector2(_clock_track.size.x * left, _clock_track.size.y)
	_clock.color = clock_urgent if left <= urgent_below else clock_calm
