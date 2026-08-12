@tool
class_name StrikeDot
extends Control

## One strike marker: a filled dot while the miss is still available, a cross
## once it has been spent.
##
## Drawn rather than typed. These were the characters U+25CF and U+2715, which
## the desktop and Android builds render fine because the operating system
## supplies a fallback font containing them. A browser has no system fonts to
## fall back on, so the web build drew the hex code in a box instead. Shapes have
## no such dependency and read the same everywhere.
##
## Drawn in the editor as well as in the game, so the row of chances can be judged
## without running anything. The editor shows the unspent side; the cross only
## appears once [method show_spent] is called at runtime.

@export_group("Art, when it arrives")
## Square images, drawn to fill the control. Leave empty for the shapes below.
@export var art_clean: Texture2D
@export var art_spent: Texture2D

@export_group("While they are still shapes")
@export var clean_colour: Color = Color(1, 1, 0.921569)
@export var spent_colour: Color = Color(0.921569, 0.337255, 0.294118)
## Radius of the dot, as a fraction of the smaller side.
@export_range(0.1, 0.5, 0.01) var dot_radius: float = 0.36
## Half-length of each arm of the cross, as a fraction of the smaller side.
@export_range(0.1, 0.5, 0.01) var cross_reach: float = 0.36
## Thickness of the cross bars, as a fraction of the smaller side.
@export_range(0.02, 0.3, 0.01) var cross_thickness: float = 0.11

var _spent: bool = false


func show_spent(spent: bool) -> void:
	if spent == _spent:
		return
	_spent = spent
	queue_redraw()


func _draw() -> void:
	var art := art_spent if _spent else art_clean
	if art != null:
		draw_texture_rect(art, Rect2(Vector2.ZERO, size), false)
		return
	var span: float = minf(size.x, size.y)
	var centre := size * 0.5
	if not _spent:
		draw_circle(centre, span * dot_radius, clean_colour)
		return

	var reach: float = span * cross_reach
	var thick: float = span * cross_thickness
	for angle in [PI * 0.25, -PI * 0.25]:
		draw_set_transform(centre, angle, Vector2.ONE)
		draw_rect(Rect2(-reach, -thick * 0.5, reach * 2.0, thick), spent_colour)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
