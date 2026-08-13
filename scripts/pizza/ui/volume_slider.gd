@tool
class_name VolumeSlider
extends Control

## A slider drawn the way the rest of this game is drawn, and big enough for a
## thumb.
##
## Godot's [HSlider] is built for a mouse: its grabber is a handful of pixels on a
## viewport 1170 across, which on a phone is a target you miss more often than you
## hit. This is the same control with the track, the fill and the knob painted by
## [method CanvasItem.draw_rect] and [method CanvasItem.draw_circle], sized in the
## same space as everything else on screen, so the knob is as wide as a fingertip
## because it was authored that way.
##
## Input arrives through [method Control._gui_input], where a position is already
## local to this control. Nothing here maps coordinates by hand, which is the part
## the street had to learn twice.
##
## The value is a fraction from 0 to 1, which is what [GameVolume] wants and what a
## person means by half volume. @tool so the slider is visible on the editor canvas
## rather than being an empty rectangle until the game runs.

## Emitted while the finger is still down, not only when it lifts. Volume is judged
## by ear, and a slider that stays silent until released is dragged twice.
signal value_changed(value: float)

@export_range(0.0, 1.0, 0.01) var value: float = 1.0:
	set(to):
		var was := value
		value = clampf(to, 0.0, 1.0)
		queue_redraw()
		if not is_equal_approx(was, value):
			value_changed.emit(value)

@export_group("Look")
## The groove the knob runs in.
@export var track: Color = Color(1, 1, 0.921569, 0.25):
	set(to):
		track = to
		queue_redraw()
## The part of the groove behind the knob: how much of it is turned on.
@export var fill: Color = Color(0.235294, 0.639216, 0.439216):
	set(to):
		fill = to
		queue_redraw()
@export var knob: Color = Color(1, 1, 0.921569):
	set(to):
		knob = to
		queue_redraw()
@export_range(4.0, 60.0, 1.0) var track_thickness: float = 18.0:
	set(to):
		track_thickness = to
		queue_redraw()
## Half the knob's width. Also what the control reserves at each end, so the knob
## stays inside its own rectangle at 0 and at 1 instead of hanging over the edge.
@export_range(10.0, 80.0, 1.0) var knob_radius: float = 34.0:
	set(to):
		knob_radius = to
		update_minimum_size()
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(knob_radius * 6.0, knob_radius * 2.0)


## Both a tap and a drag set the value from where the finger is: on a touch screen
## there is no such thing as grabbing the knob first, and asking for one would make
## the small target the point again.
func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_set_from_x(button.position.x)
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_set_from_x(motion.position.x)
		accept_event()


func _set_from_x(x: float) -> void:
	var travel := _travel()
	if travel <= 0.0:
		return
	value = (x - knob_radius) / travel


## How far the middle of the knob may move, which is the width less the room kept
## for the knob at either end.
func _travel() -> float:
	return maxf(size.x - knob_radius * 2.0, 0.0)


func _draw() -> void:
	var middle := size.y * 0.5
	var left := knob_radius
	var right := size.x - knob_radius
	var at := left + _travel() * value
	var groove := Rect2(left, middle - track_thickness * 0.5, right - left, track_thickness)
	draw_rect(groove, track)
	if at > left:
		draw_rect(Rect2(groove.position, Vector2(at - left, groove.size.y)), fill)
	draw_circle(Vector2(at, middle), knob_radius, knob, true)
