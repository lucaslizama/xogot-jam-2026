@tool
class_name HouseDropPoint
extends Node2D

## The landing ring at a house's feet: where a pizza is meant to go.
##
## Half the houses that go by are scenery, so the eye has to pick the ones that
## want a pizza out of them. A ring that breathes is found faster than a still one,
## and it keeps working whatever art turns up.
##
## The pulse, the ring's real radius and the flat-on-the-ground squash are all
## applied to this node's scale rather than to the drawing, so anything parented
## here breathes, resizes and lies flat with it. Art is authored at [member
## art_radius] pixels across the middle and stretched to whatever the street's ring
## turns out to be.

## How flat the ring lies. 1.0 is a full circle facing the camera; the default is
## the street's own foreshortening.
@export_range(0.05, 1.0, 0.01) var squash: float = 0.38:
	set(value):
		squash = value
		_apply()
## The radius, in pixels, that art parented to this node is drawn at: half of what
## the image measures across. The node is scaled from this to the ring's real
## radius, so a marker authored 200 px across wants 100 here and then fits every
## street. The default is half the size the art brief asks the drop point to be
## drawn at, so a marker made to the brief needs nothing changed.
@export_range(1.0, 2000.0, 1.0) var art_radius: float = 419.0:
	set(value):
		art_radius = value
		_apply()

@export_group("Pulse")
## How fast it breathes, in cycles per second.
@export_range(0.0, 4.0, 0.05) var pulse_rate: float = 1.0
## How much it swells. Too much and the street starts throbbing.
@export_range(0.0, 0.6, 0.01) var pulse_depth: float = 0.16:
	set(value):
		pulse_depth = value
		_apply()

@export_group("Placeholder ring")
## Whether the ring below is drawn at all. Turn it off once real art is parented
## here and the node becomes a plain holder that still pulses and still scales.
@export var draw_ring: bool = true:
	set(value):
		draw_ring = value
		queue_redraw()
@export var open_fill: Color = Color(0.301961, 0.65098, 1, 0.55):
	set(value):
		open_fill = value
		queue_redraw()
@export var served_fill: Color = Color(0.560784, 0.870588, 0.364706, 0.5):
	set(value):
		served_fill = value
		queue_redraw()
@export var rim: Color = Color(1, 1, 0.921569, 0.5):
	set(value):
		rim = value
		queue_redraw()
@export_range(0.0, 16.0, 0.5) var rim_width: float = 4.0:
	set(value):
		rim_width = value
		queue_redraw()

## The radius, in pixels, this node was last told to be. [HouseView] owns the
## preview that decides it before a street has spoken, so there is one preview
## ring size in the scene rather than two that can disagree.
var _radius: float = 621.0
var _served: bool = false
## How far [member art_radius] is being stretched to reach [member _radius] this
## frame, pulse included. Kept so the rim can be drawn back down to a fixed width.
var _stretch: float = 1.0


func _ready() -> void:
	_apply()


## Told by [HouseView]. The radius is in pixels at the house's own scale, since
## the house is what knows how many pixels a world unit is worth.
func show_radius(radius: float, served: bool, animate: bool) -> void:
	_radius = radius
	_served = served
	# Never on the editor canvas. Nothing redraws it there, so the pulse would only
	# be sampled when something else forced a redraw: zoom in and the ring jumps to
	# whatever size the clock happened to be at, which makes the one measurement the
	# preview exists to give a number you cannot trust. Still means true size.
	set_process(animate and pulse_depth > 0.0 and not served
		and not Engine.is_editor_hint())
	_apply()
	queue_redraw()


func _process(_delta: float) -> void:
	_apply()
	# The rim is a fixed width in the house's own pixels, so it has to be redrawn
	# against the beat. Only the placeholder needs this; art parented here rides
	# the scale and does not care.
	if draw_ring and rim_width > 0.0:
		queue_redraw()


## Put the ring's size, its squash and the beat of the moment onto the node's own
## scale, so everything under it moves together. This node's scale belongs to the
## script: setting it in the editor will not survive a frame. Scale art by giving
## it a size and telling this node [member art_radius].
func _apply() -> void:
	# One clock for every house, so the street breathes together rather than each
	# one flickering on its own beat.
	var beat := 1.0
	if is_processing():
		beat += sin(float(Time.get_ticks_msec()) / 1000.0 * TAU * pulse_rate) * pulse_depth
	_stretch = _radius / maxf(0.001, art_radius) * beat
	scale = Vector2(_stretch, _stretch * squash)


func _draw() -> void:
	if not draw_ring:
		return
	draw_circle(Vector2.ZERO, art_radius, served_fill if _served else open_fill)
	if rim_width > 0.0:
		# Divided by the stretch because the node is scaled, and a rim that grew
		# with the ring would be a fat band on a near house and a hairline on a far
		# one. This keeps it the same weight wherever the house is standing.
		draw_arc(Vector2.ZERO, art_radius, 0.0, TAU, 48, rim,
			rim_width / maxf(0.001, _stretch))
