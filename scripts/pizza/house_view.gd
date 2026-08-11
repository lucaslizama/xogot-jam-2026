@tool
class_name HouseView
extends Node2D

## Draws one house. Placeholder art: everything here is rectangles and a circle,
## drawn from exported sizes so the shape can be nudged in the editor before any
## real art exists.
##
## Assign the art slots below and the drawing stops: a house becomes its picture,
## with nothing to delete first. The exported sizes are the ones to hand an
## artist, because they are the space each image will occupy.
##
## The node's origin is the point where the house meets the ground, because that
## is the point the street projects. Scale comes from the parent, which knows
## how far away this house is.
##
## A tool script, so the house draws itself on the editor canvas. Opening
## house.tscn shows the house rather than an empty node, and nudging a wall or a
## colour is answered on the spot instead of after a run.

@export_group("Shape, in world units")
@export_range(1.0, 30.0, 0.1) var width: float = 20.5
@export_range(1.0, 30.0, 0.1) var wall_height: float = 12.8
@export_range(0.0, 15.0, 0.1) var roof_height: float = 6.7
## Pixels per world unit at the rider's distance. Must match the projection
## resource, or houses will not sit at the size the street expects.
@export_range(1.0, 400.0, 1.0) var pixels_per_unit: float = 46.0

@export_group("Drop point")
## Roughly half the houses that go by are scenery, so the eye has to find the
## ones that want a pizza among them. A drop point that breathes is found
## faster than a still one, and unlike anything drawn it keeps working whatever
## art turns up.
@export_range(0.0, 4.0, 0.05) var pulse_rate: float = 1.0
## Whether the landing ring is drawn at all. The game wants it; a decorative
## street with nothing to aim at, like the menu behind the title, does not.
@export var show_drop_points: bool = true
## How much it swells and brightens. Too much and the street starts throbbing.
@export_range(0.0, 0.6, 0.01) var pulse_depth: float = 0.16

@export_group("Art, when it arrives")
## Drawn bottom-centred on the ground point, filling width by wall plus roof.
## Leave empty and the placeholder shapes are drawn instead.
@export var art_waiting: Texture2D
@export var art_served: Texture2D
@export var art_scenery: Texture2D
## Lies flat on the ground, a square image the width of twice the drop radius.
@export var art_drop_marker: Texture2D

@export_group("Colours")
@export var wall_waiting: Color = Color(0.62, 0.44, 0.36)
@export var wall_scenery: Color = Color(0.28, 0.26, 0.32)
@export var wall_served: Color = Color(0.34, 0.47, 0.32)
@export var roof: Color = Color(0.36, 0.22, 0.24)
@export var window_lit: Color = Color(1.0, 0.85, 0.45)
@export var drop_open: Color = Color(0.24, 0.71, 0.9, 0.55)
@export var drop_served: Color = Color(0.45, 0.85, 0.5, 0.5)

@export_group("Editor preview")
## What the house shows on the canvas when no street is driving it. The game
## overrides all three the moment it runs, so these cost nothing at play time and
## let the scene be opened on a house that is waiting, one that has been served or
## a piece of scenery, without running anything.
@export var preview_waiting: bool = true:
	set(value):
		preview_waiting = value
		_apply_preview()
@export var preview_served: bool = false:
	set(value):
		preview_served = value
		_apply_preview()
## Matches street_1's drop radius, so the ring on the canvas is the size the ring
## in the game will be rather than a stand-in.
@export_range(0.0, 30.0, 0.1) var preview_drop_radius: float = 13.5:
	set(value):
		preview_drop_radius = value
		_apply_preview()

var _waiting: bool = true
var _served: bool = false
var _drop_radius: float = 3.2
## Whether a street has ever spoken. Until it has, the preview values stand, and
## the first thing the street says is always applied however much it looks like
## what is already there.
var _stated: bool = false


func _ready() -> void:
	# Only a house still waiting has anything to animate, and on the editor canvas
	# nothing does: a street of houses all pulsing would make the viewport work for
	# no reason while somebody is trying to place a wall.
	set_process(false)
	if not _stated:
		_apply_preview()


## Show what the exported preview says, for as long as nothing else has spoken.
func _apply_preview() -> void:
	if _stated:
		return
	_waiting = preview_waiting
	_served = preview_served
	_drop_radius = preview_drop_radius
	queue_redraw()


## Told by the street each frame. Redraws only when something actually changed,
## since most houses are static most of the time.
func show_state(waiting: bool, served: bool, drop_radius: float) -> void:
	# The first word from the street is always acted on. Skipping it because it
	# happened to match the preview would leave the pulse switched off for the
	# life of the house, and the only sign would be a drop point that never
	# breathed on a street where every value looked right.
	if _stated and waiting == _waiting and served == _served \
			and is_equal_approx(drop_radius, _drop_radius):
		return
	_stated = true
	_waiting = waiting
	_served = served
	_drop_radius = drop_radius
	set_process(show_drop_points and pulse_depth > 0.0 and _waiting and not _served)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_drop_point()
	_draw_body()


func _draw_body() -> void:
	var art := art_scenery
	if _waiting:
		art = art_served if _served else art_waiting
	if art != null:
		var w := width * pixels_per_unit
		var h := (wall_height + roof_height) * pixels_per_unit
		draw_texture_rect(art, Rect2(-w * 0.5, -h, w, h), false)
		return
	_draw_placeholder_body()


func _draw_placeholder_body() -> void:
	var half := width * 0.5 * pixels_per_unit
	var wall := wall_height * pixels_per_unit
	var peak := roof_height * pixels_per_unit
	var body := wall_scenery
	if _waiting:
		body = wall_served if _served else wall_waiting
	draw_rect(Rect2(-half, -wall, half * 2.0, wall), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half, -wall), Vector2(half, -wall), Vector2(0.0, -wall - peak),
	]), roof)

	# A lit window is how a house says it is still waiting, without a HUD.
	if _waiting and not _served:
		var w := half * 0.42
		draw_rect(Rect2(-w * 0.5, -wall * 0.72, w, wall * 0.34), window_lit)


## The drop point lies on the ground, so it is squashed vertically to read as
## flat rather than as a disc facing the camera.
func _draw_drop_point() -> void:
	if not show_drop_points or not _waiting:
		return
	# One clock for every house, so the street breathes together rather than
	# each one flickering on its own beat.
	#
	# Never on the editor canvas. Nothing redraws it there, so the pulse would only
	# be sampled when something else forced a redraw: zoom in and the ring jumps to
	# whatever size the clock happened to be at, which makes the one measurement the
	# preview exists to give a number you cannot trust. Still means true size.
	var beat := 1.0
	if pulse_depth > 0.0 and not _served and not Engine.is_editor_hint():
		beat += sin(float(Time.get_ticks_msec()) / 1000.0 * TAU * pulse_rate) * pulse_depth
	var radius := _drop_radius * pixels_per_unit * beat
	if art_drop_marker != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
		draw_texture_rect(art_drop_marker, Rect2(-radius, -radius, radius * 2.0, radius * 2.0), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius, drop_served if _served else drop_open)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
