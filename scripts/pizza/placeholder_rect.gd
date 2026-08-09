@tool
class_name PlaceholderRect
extends Control

## A coloured box in the interface that stands in for a picture yet to be drawn.
## The [Placeholder2D] idea, for a Control: assign a texture and the box is gone,
## and nothing else about the layout changes, because the box already occupies
## exactly the space the picture will.
##
## The note written across the box says what the finished picture shows, so the
## page can be read and argued about before any of it is drawn.
##
## A single still is one texture in [member art]. A loop — a flick, a curve, a
## landing — is the same slot with the frames laid out left to right in one strip
## and [member frame_count] set to how many there are; nothing else changes. An
## animated GIF cannot be imported by the engine, so export it as that strip.

@export_group("Art")
## Fills the box, kept to its own aspect and centred. Empty leaves the box.
@export var art: Texture2D:
	set(value):
		art = value
		queue_redraw()
## How many frames [member art] is cut into, side by side. 1 is a still image.
@export_range(1, 64, 1) var frame_count: int = 1:
	set(value):
		frame_count = maxi(1, value)
		_frame = 0
		_elapsed = 0.0
		set_process(frame_count > 1)
		queue_redraw()
@export_range(1.0, 60.0, 1.0) var frames_per_second: float = 8.0

@export_group("While it is still a box")
## What the finished picture shows, written across the placeholder.
@export_multiline var note: String = "":
	set(value):
		note = value
		queue_redraw()
@export var colour: Color = Color(0.88, 0.74, 0.49):
	set(value):
		colour = value
		queue_redraw()
@export var outline: Color = Color(0, 0, 0, 0.35):
	set(value):
		outline = value
		queue_redraw()
@export var note_colour: Color = Color(0.29411766, 0.19607843, 0.10980392):
	set(value):
		note_colour = value
		queue_redraw()
@export_range(8, 96, 1) var note_size: int = 36

var _frame: int = 0
var _elapsed: float = 0.0


func _ready() -> void:
	set_process(frame_count > 1)


func _process(delta: float) -> void:
	_elapsed += delta
	var step := 1.0 / frames_per_second
	if _elapsed < step:
		return
	_elapsed = fmod(_elapsed, step)
	_frame = (_frame + 1) % frame_count
	queue_redraw()


func _draw() -> void:
	if art != null:
		_draw_art()
		return
	draw_rect(Rect2(Vector2.ZERO, size), colour)
	draw_rect(Rect2(Vector2.ZERO, size), outline, false, 4.0)
	_draw_note()


## Fit one frame inside the box without stretching it, and centre what is left
## over, so art drawn to any sensible size lands looking right.
func _draw_art() -> void:
	var frame_size := Vector2(art.get_width() / float(frame_count), art.get_height())
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return
	var fit := minf(size.x / frame_size.x, size.y / frame_size.y)
	var drawn := frame_size * fit
	var dest := Rect2((size - drawn) * 0.5, drawn)
	draw_texture_rect_region(art, dest, Rect2(Vector2(_frame * frame_size.x, 0.0), frame_size))


func _draw_note() -> void:
	if note.is_empty():
		return
	var font := get_theme_font("font", "Label")
	if font == null:
		return
	var width := size.x - 32.0
	var lines := font.get_multiline_string_size(note, HORIZONTAL_ALIGNMENT_CENTER, width, note_size)
	var pos := Vector2(16.0, (size.y - lines.y) * 0.5 + font.get_ascent(note_size))
	draw_multiline_string(font, pos, note, HORIZONTAL_ALIGNMENT_CENTER, width, note_size, -1, note_colour)
