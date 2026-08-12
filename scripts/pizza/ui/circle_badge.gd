@tool
class_name CircleBadge
extends MarginContainer

## The street badge: a white disc ringed in alternating red and green, with the
## street number inside it. A round stamp reads as the sign on a corner rather
## than another panel, and the two colours of the ring are the outcome's colours
## side by side, so the badge is the same on a win and a loss.
##
## It wraps its child (the label), grows to a circle big enough to hold it, and
## paints the disc and ring behind. @tool so the badge shows on the editor canvas.

@export_group("Ring")
## The two colours the ring alternates between.
@export var ring_a: Color = Color(0.921569, 0.337255, 0.294118):
	set(value):
		ring_a = value
		queue_redraw()
@export var ring_b: Color = Color(0.235294, 0.639216, 0.439216):
	set(value):
		ring_b = value
		queue_redraw()
## How thick the ring is, in pixels.
@export_range(2.0, 40.0, 1.0) var ring_thickness: float = 10.0:
	set(value):
		ring_thickness = value
		_fit_margins()
		queue_redraw()
## How many colours the ring is cut into. Even, so the alternation closes.
@export_range(2, 32, 2) var segments: int = 12:
	set(value):
		segments = value
		queue_redraw()

@export_group("Disc")
@export var fill: Color = Color(1, 1, 0.921569):
	set(value):
		fill = value
		queue_redraw()
## Extra room past the ring, so the text is not crowded against it.
@export_range(0.0, 60.0, 1.0) var padding: float = 14.0:
	set(value):
		padding = value
		_fit_margins()
## Widens the disc past what the text strictly needs. The label's own report of
## how much room it wants is a rectangle, and a circle around a rectangle is
## tight at the corners, so a little slack keeps the letters clear of the ring.
@export_range(0.0, 160.0, 2.0) var slack: float = 40.0:
	set(value):
		slack = value
		update_minimum_size()
		queue_redraw()


func _ready() -> void:
	_fit_margins()
	queue_redraw()


## Keep the content clear of the ring: the ring plus the padding on every side.
func _fit_margins() -> void:
	var m := int(ring_thickness + padding)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, m)
	update_minimum_size()


## A circle only clears a rectangle of text if its diameter covers the diagonal,
## so the badge asks for a square that wide and the label sits centred in it. Two
## short lines of text are nearer a square than one long one, so they need much
## less disc: the street number reads better stacked under the word than beside
## it, and the badge comes out smaller for it.
func _get_minimum_size() -> Vector2:
	var inner := Vector2.ZERO
	for child in get_children():
		var c := child as Control
		if c != null and c.visible:
			inner = inner.max(c.get_combined_minimum_size())
	var diameter := inner.length() + 2.0 * (ring_thickness + padding) + slack
	return Vector2(diameter, diameter)


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	if radius <= 0.0:
		return
	draw_circle(centre, radius, fill)
	# The ring is drawn as arcs on the circle's inner edge, alternating colours a
	# segment at a time. Antialiased, or the joins between segments show as steps.
	var ring_radius := radius - ring_thickness * 0.5
	var step := TAU / float(segments)
	for i in segments:
		var colour := ring_a if i % 2 == 0 else ring_b
		draw_arc(centre, ring_radius, i * step, (i + 1) * step, 16, colour, ring_thickness, true)
