@tool
class_name CheckeredButton
extends Button

## A square button ringed by a red-and-white checked border — the pizzeria
## tablecloth. Drawn in code because a StyleBox cannot checker an edge.
##
## A script's _draw paints over a Button's own text, so the label is drawn here
## too, last, on top of the fill and ring. Its colour is the one thing a win and
## a loss change: green for "Next street", red for "Try again". @tool means the
## border shows on the editor canvas as well.

@export_group("Checker")
@export var check_a: Color = Color(0.921569, 0.337255, 0.294118)
@export var check_b: Color = Color(1, 1, 0.921569)
## Side of one check square, in pixels. The ring is one check thick.
@export_range(6.0, 60.0, 1.0) var check_size: float = 22.0:
	set(value):
		check_size = value
		queue_redraw()
## The panel behind the label, inside the checked ring.
@export var fill: Color = Color(1, 1, 0.921569):
	set(value):
		fill = value
		queue_redraw()

var _hover: bool = false


func _ready() -> void:
	# No stylebox and no built-in label: everything is drawn below, so nothing
	# paints a pill behind the checks and the words never hide under the ring.
	var clear := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, clear)
	if not mouse_entered.is_connected(_on_enter):
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)
	queue_redraw()


func _on_enter() -> void:
	_hover = true
	queue_redraw()


func _on_exit() -> void:
	_hover = false
	queue_redraw()


func _draw() -> void:
	# Pressing darkens the whole button, hovering lifts it a touch, so a tap is
	# answered even though the shape never moves.
	var dim := 0.88 if button_pressed else (1.06 if _hover else 1.0)
	Checkered.draw(self, size, check_size, fill, check_a, check_b, dim)
	_draw_label(dim)


func _draw_label(dim: float) -> void:
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
	var pos := Vector2((size.x - measured.x) * 0.5, (size.y - measured.y) * 0.5 + font.get_ascent(font_size))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, _shade(colour, dim))


func _shade(c: Color, dim: float) -> Color:
	return Color(c.r * dim, c.g * dim, c.b * dim, c.a)
