class_name Backdrop
extends Node2D

## Sky, road and the rows of silhouettes behind the street.
##
## The rows are drawn rather than authored as nodes because the street is
## endless: what would be authored is a pattern, not a set of objects, and the
## pattern's numbers are exported on the layer resources instead.

@export var projection: StreetProjection
## Rows behind the street, furthest first. Each is a resource you can open.
@export var layers: Array[BackdropLayer] = []

@export_group("Ground")
## The sky above the horizon belongs to the NightSky shader, which paints its
## gradient and scatters the stars. Drawing it here as well would cover them.
@export var road: Color = Color(0.15, 0.14, 0.17)
@export var verge: Color = Color(0.19, 0.21, 0.17)
## How far back the road surface reaches, in world units.
@export_range(5.0, 400.0, 1.0) var road_depth: float = 18.0

@export_group("Road markings")
## Without these the road is a flat band and the only thing saying the rider is
## moving is the houses going by. Marks on the road say it directly, and they
## come free from the same scroll the houses use.
@export var lane_colour: Color = Color(0.78, 0.74, 0.55, 0.65)
## How far back from the rider the marks are painted.
@export_range(0.5, 100.0, 0.5) var lane_distance: float = 7.0
## Length of one mark and the gap to the next, in world units.
@export_range(0.5, 60.0, 0.5) var lane_dash: float = 7.0
@export_range(0.5, 60.0, 0.5) var lane_gap: float = 9.0
@export_range(1.0, 60.0, 0.5) var lane_thickness: float = 1.4

var _travelled: float = 0.0


## Told how far the world has slid, so the rows can be offset by it.
func set_travelled(distance_travelled: float) -> void:
	_travelled = distance_travelled
	queue_redraw()


func _draw() -> void:
	if projection == null:
		return
	var view := get_viewport_rect().size

	for layer in layers:
		if layer != null:
			_draw_layer(layer, view)

	_draw_ground(view)
	_draw_road_markings(view)


func _draw_layer(layer: BackdropLayer, view: Vector2) -> void:
	var scale := projection.scale_at(layer.distance)
	var stride: float = layer.width + layer.gap
	if stride <= 0.001:
		return

	# Only the visible span is drawn, so a far row does not cost more than a
	# near one just because more of the world fits on screen behind it.
	var half_span: float = (view.x * 0.6) / maxf(0.001, projection.pixels_per_unit * scale)
	var first: int = int(floor((-half_span + _travelled) / stride))
	var last: int = int(ceil((half_span + _travelled) / stride))

	for i in range(first, last + 1):
		var world_side: float = float(i) * stride - _travelled
		# A stable pseudo-random height per silhouette, so the skyline does not
		# shimmer as it scrolls.
		var wobble: float = fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var height: float = layer.height * (1.0 - layer.height_variation * wobble)
		var base := projection.project(world_side, 0.0, layer.distance)
		var top := projection.project(world_side, height, layer.distance)
		var half: float = layer.width * 0.5 * projection.pixels_per_unit * scale
		var box := Rect2(base.x - half, top.y, half * 2.0, base.y - top.y)
		var tint := projection.haze_tint(layer.distance)
		if layer.art != null:
			draw_texture_rect(layer.art, box, false, tint)
		else:
			draw_rect(box, layer.colour * tint)


## Dashes painted along the road, scrolling with the world. Only the span that
## can be seen is drawn, so a mark far up the street costs nothing.
func _draw_road_markings(view: Vector2) -> void:
	var stride: float = lane_dash + lane_gap
	if stride <= 0.001 or lane_colour.a <= 0.0:
		return
	var scale := projection.scale_at(lane_distance)
	var half_span: float = (view.x * 0.75) / maxf(0.001, projection.pixels_per_unit * scale)
	var first: int = int(floor((-half_span + _travelled) / stride))
	var last: int = int(ceil((half_span + _travelled) / stride))

	var tint := projection.haze_tint(lane_distance)
	for i in range(first, last + 1):
		var from_side: float = float(i) * stride - _travelled
		var a := projection.project(from_side, 0.0, lane_distance)
		var b := projection.project(from_side + lane_dash, 0.0, lane_distance)
		draw_line(a, b, lane_colour * tint, lane_thickness * projection.pixels_per_unit * scale)


func _draw_ground(view: Vector2) -> void:
	# The road is a band between the rider's line and the far verge, drawn as a
	# trapezoid because the far edge is narrower than the near one.
	var near_y: float = projection.project(0.0, 0.0, 0.0).y
	var far_y: float = projection.project(0.0, 0.0, road_depth).y
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, far_y), Vector2(view.x, far_y),
		Vector2(view.x, view.y), Vector2(0.0, view.y),
	]), road)
	draw_rect(Rect2(0.0, far_y - 6.0, view.x, 6.0), verge)
	draw_rect(Rect2(0.0, near_y, view.x, maxf(0.0, view.y - near_y)), road.darkened(0.25))
