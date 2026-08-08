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

@export_group("Ground and sky")
@export var sky_top: Color = Color(0.11, 0.09, 0.19)
@export var sky_bottom: Color = Color(0.29, 0.18, 0.33)
@export var road: Color = Color(0.15, 0.14, 0.17)
@export var verge: Color = Color(0.19, 0.21, 0.17)
## How far back the road surface reaches, in world units.
@export_range(5.0, 400.0, 1.0) var road_depth: float = 14.0

var _travelled: float = 0.0


## Told how far the world has slid, so the rows can be offset by it.
func set_travelled(distance_travelled: float) -> void:
	_travelled = distance_travelled
	queue_redraw()


func _draw() -> void:
	if projection == null:
		return
	var view := get_viewport_rect().size

	draw_rect(Rect2(Vector2.ZERO, Vector2(view.x, projection.horizon_y)), sky_top)
	draw_rect(Rect2(Vector2(0.0, projection.horizon_y * 0.55),
		Vector2(view.x, projection.horizon_y * 0.45)), sky_bottom)

	for layer in layers:
		if layer != null:
			_draw_layer(layer, view)

	_draw_ground(view)


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
		draw_rect(Rect2(base.x - half, top.y, half * 2.0, base.y - top.y), layer.colour)


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
