@tool
class_name PizzaBoxButton
extends Button

## A menu button shaped like a pizza box seen edge-on.
##
## Placeholder art in the house style: the box is drawn from exported sizes and
## colours so it can be tuned in the editor before any real art exists. Assign a
## texture to [member art] and the drawing steps aside, the label staying on top.
##
## The look is a shallow slab — the base, a lid sitting slightly proud of it with
## a seam between them, and the little front tab a takeaway box tucks closed. The
## whole thing tilts a touch and lifts on hover, and presses down when tapped,
## so it reads as a physical box being picked up.

@export_group("Box")
@export var lid: Color = Color(0.78, 0.6, 0.38)
@export var base: Color = Color(0.62, 0.45, 0.27)
@export var edge: Color = Color(0.42, 0.3, 0.17)
## The greasy translucent window some boxes have, drawn on the lid.
@export var window: Color = Color(0.96, 0.86, 0.55, 0.22)
@export_range(0.0, 40.0, 0.5) var corner: float = 14.0
@export_range(2.0, 24.0, 0.5) var outline: float = 5.0
## How tall the base slab is as a fraction of the button. The lid takes the rest.
@export_range(0.1, 0.6, 0.01) var base_fraction: float = 0.28

@export_group("Feel")
## Degrees the box tilts, for a hand-stacked look rather than a placed sticker.
@export_range(-8.0, 8.0, 0.5) var tilt: float = -2.0
## Pixels the whole box lifts under a hover.
@export_range(0.0, 24.0, 1.0) var hover_lift: float = 8.0
## Pixels it sinks when pressed.
@export_range(0.0, 24.0, 1.0) var press_drop: float = 6.0

@export_group("Art, when it arrives")
## Fills the button rect. Leave empty for the drawn placeholder box.
@export var art: Texture2D
@export var art_hover: Texture2D
@export var art_pressed: Texture2D
## Mirrors the picture left to right. The menu alternates this down its column so
## a row of boxes reads as a stack of them and not as one sticker repeated. Only
## the picture turns; the words on it stay the right way round.
@export var flip_art_h: bool = false:
	set(value):
		flip_art_h = value
		queue_redraw()

var _hover: bool = false


func _ready() -> void:
	# The label rides on top of _draw; clearing the styleboxes stops the theme
	# painting a pill behind the box. @tool means this also runs in the editor,
	# so the boxes show on the canvas; the guard keeps the signals connected once.
	var clear := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, clear)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)
	queue_redraw()


func _on_mouse_entered() -> void:
	_hover = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hover = false
	queue_redraw()


func _draw() -> void:
	var offset := Vector2.ZERO
	if button_pressed:
		offset.y = press_drop
	elif _hover:
		offset.y = -hover_lift

	var centre := size * 0.5 + offset
	var angle := deg_to_rad(tilt)
	var half := size * 0.5
	# Everything below is drawn about the centre, so the transform tilts it whole.
	# The flip rides in that same transform, which is why the picture is drawn
	# under one and the words under another: a mirrored label reads backwards.
	if art != null:
		draw_set_transform(centre, angle, Vector2(-1.0, 1.0) if flip_art_h else Vector2.ONE)
		_draw_art(half)
	else:
		draw_set_transform(centre, angle, Vector2.ONE)
		_draw_box(half)
	# The label has to be drawn here, on top of the box: a script's _draw paints
	# over the Button's own text, so left to the theme the words vanish under the
	# lid. Drawn last, they sit on the box and tilt and lift with it.
	draw_set_transform(centre, angle, Vector2.ONE)
	_draw_label(offset)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_label(offset: Vector2) -> void:
	if text.is_empty():
		return
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var colour := get_theme_color("font_color")
	if button_pressed:
		colour = get_theme_color("font_pressed_color")
	elif _hover:
		colour = get_theme_color("font_hover_color")
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
	# Centred on the box. The drawn placeholder is nudged up so the words ride the
	# lid rather than the seam; a real box is its own picture, and where its lid
	# falls is nobody's business here, so the words simply sit in the middle.
	var lift: float = 0.0 if art != null else size.y * base_fraction * 0.5
	var baseline := Vector2(-measured.x * 0.5, font.get_ascent(font_size) - measured.y * 0.5 - lift)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, colour)


func _draw_box(half: Vector2) -> void:
	var w := half.x * 2.0
	var h := half.y * 2.0
	var base_h: float = h * base_fraction
	var lid_h: float = h - base_h

	# Lid: the tall panel on top, with a soft grease window and a seam beneath.
	var lid_rect := Rect2(-half.x, -half.y, w, lid_h)
	_slab(lid_rect, lid)
	var win := lid_rect.grow(-w * 0.14)
	win.size.y = lid_h * 0.42
	win.position.y = lid_rect.position.y + lid_h * 0.2
	draw_rect(win, window)

	# Base: the shorter slab the lid closes onto.
	var base_rect := Rect2(-half.x, -half.y + lid_h, w, base_h)
	_slab(base_rect, base)

	# The seam where lid meets base, and the little front tab in its middle.
	var seam_y := -half.y + lid_h
	draw_line(Vector2(-half.x + corner, seam_y), Vector2(half.x - corner, seam_y), edge, outline)
	var tab_w := w * 0.22
	var tab := Rect2(-tab_w * 0.5, seam_y - base_h * 0.28, tab_w, base_h * 0.5)
	_slab(tab, base.lightened(0.06))


## A rounded, outlined panel — one flap of the box.
func _slab(rect: Rect2, fill: Color) -> void:
	draw_rect(rect, fill)
	# A rounded outline drawn as a stroked rect; corner only softens the seam and
	# tab visually, the fill stays square which reads fine at this size.
	draw_rect(rect, edge, false, outline)


## The art keeps its own shape and is centred in the button, so a box drawn to
## any proportions goes in without being stretched to the button's.
func _draw_art(half: Vector2) -> void:
	var tex := art
	if button_pressed and art_pressed != null:
		tex = art_pressed
	elif _hover and art_hover != null:
		tex = art_hover
	var art_size := tex.get_size()
	if art_size.x <= 0.0 or art_size.y <= 0.0:
		return
	var fit := minf(size.x / art_size.x, size.y / art_size.y)
	var drawn := art_size * fit
	draw_texture_rect(tex, Rect2(-drawn * 0.5, drawn), false)
