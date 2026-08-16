@tool
class_name PauseIconButton
extends Button

## The button that stops the street: two bars, drawn rather than written.
##
## It said "Pause" first and that was wrong twice over. A word in a corner has to be
## read, where a pair of bars is understood without reading and without translating;
## and the word came out the theme's default button grey, which against a night sky
## is furniture rather than a control.
##
## Drawn in code for the same reason the strike dots and the result pizza are: it
## occupies exactly the space its picture will, so the layout is settled before any
## art exists, and dropping a file into [member art] makes the drawing step aside
## with nothing else to change.
##
## A script's _draw paints over a Button's own text, which is why this carries none:
## see [CheckeredButton], which draws its label back on top for the same reason.

## The finished icon, when there is one. Stretched to the button, so art drawn to
## this button's size lands unchanged.
@export var art: Texture2D:
	set(value):
		art = value
		queue_redraw()

@export_group("While it is still two bars")
## Near white, the colour the theme gives its captions, because this sits over a
## night sky and has to be legible before it is pretty.
@export var colour: Color = Color(1, 1, 0.921569):
	set(value):
		colour = value
		queue_redraw()
## How wide one bar is, as a fraction of the button.
@export_range(0.02, 0.4, 0.01) var bar_width: float = 0.13:
	set(value):
		bar_width = value
		queue_redraw()
## And how tall, as a fraction of the button's height.
@export_range(0.1, 1.0, 0.01) var bar_height: float = 0.46:
	set(value):
		bar_height = value
		queue_redraw()
## The gap between the two, as a fraction of the button's width.
@export_range(0.0, 0.4, 0.01) var bar_gap: float = 0.11:
	set(value):
		bar_gap = value
		queue_redraw()


func _draw() -> void:
	if art != null:
		draw_texture_rect(art, Rect2(Vector2.ZERO, size), false)
		return
	var bar := Vector2(size.x * bar_width, size.y * bar_height)
	var middle := size * 0.5
	var step := (bar.x + size.x * bar_gap) * 0.5
	for side in [-1.0, 1.0]:
		var corner := Vector2(middle.x + side * step - bar.x * 0.5, middle.y - bar.y * 0.5)
		draw_rect(Rect2(corner, bar), colour)
