@tool
class_name Backdrop
extends Node2D

## Sky, road and the rows of silhouettes behind the street.
##
## The rows are a pattern rather than a set of objects, because the street is
## endless: what a row is, rather than where each of its buildings is, lives on the
## layer resources.
##
## Every building is a node: one per slot across the visible span, placed and
## haze-tinted here, and freed as it scrolls off. Five a row are on screen at once,
## which is what makes that affordable, and a building that is a node can carry a
## shader, an animation or a script that a rectangle drawn into a box never could.
##
## A row whose layer carries no art gets a [Placeholder2D] standing in at the same
## size and colour, which is the same box the row used to be drawn as. Nodes either
## way, deliberately: while some rows were drawn and others instanced, the drawn
## ones always painted in front, because a parent draws before its children. A row
## given art went behind the rows still waiting for it.
##
## [code]@tool[/code] so a row can be seen while it is being tuned. In the editor it
## stands at a travelled distance of zero, which is simply where the street starts.
## The buildings are added without an owner, so they belong to the running scene and
## are never written into the .tscn by an editor save.

@export var projection: StreetProjection
## Rows behind the street, furthest first. Each is a resource you can open.
@export var layers: Array[BackdropLayer] = []

@export_group("Ground")
## The sky above the horizon belongs to the NightSky shader, which paints its
## gradient and scatters the stars. Drawing it here as well would cover them.
@export var road: Color = Color(0.152941, 0.152941, 0.211765)
@export var verge: Color = Color(0.196078, 0.243137, 0.309804)
## How far back the road surface reaches, in world units.
@export_range(5.0, 400.0, 1.0) var road_depth: float = 18.0

@export_group("Road markings")
## Without these the road is a flat band and the only thing saying the rider is
## moving is the houses going by. Marks on the road say it directly, and they
## come free from the same scroll the houses use.
@export var lane_colour: Color = Color(1, 0.894118, 0.470588, 0.65)
## How far back from the rider the marks are painted.
@export_range(0.5, 100.0, 0.5) var lane_distance: float = 7.0
## Length of one mark and the gap to the next, in world units.
@export_range(0.5, 60.0, 0.5) var lane_dash: float = 7.0
@export_range(0.5, 60.0, 0.5) var lane_gap: float = 9.0
@export_range(1.0, 60.0, 0.5) var lane_thickness: float = 1.4

var _travelled: float = 0.0
## The buildings standing right now, by the row and the slot along it they fill.
var _standing: Dictionary = {}
## One holder per row, in the order the rows are listed. Rows have to paint
## furthest first and there is no room in z to say so: this node sits at -4095,
## one step in front of the sky and one behind the road, so a row given a z of its
## own would climb straight over the tarmac. Tree order says it instead, which is
## what the drawing did when it was a loop.
var _rows: Array[Node2D] = []
## So a layer whose art will not instance says so once, not every frame.
var _complained: bool = false


## Told how far the world has slid, so the rows can be offset by it.
func set_travelled(distance_travelled: float) -> void:
	_travelled = distance_travelled
	_stand_up_buildings()


func _ready() -> void:
	# Nothing tells the editor the world moved, so while the scene is open the rows
	# are rebuilt each frame as their numbers are edited. In the game set_travelled
	# does it, when it changes.
	set_process(Engine.is_editor_hint())
	_stand_up_buildings()


func _process(_delta: float) -> void:
	_stand_up_buildings()


# --- the rows that are nodes -------------------------------------------------

## Give every building in every row a node, place it, and drop the ones that have
## scrolled out of the span. The same shape as the street's own
## house syncing, for the same reason: what is on screen is a moving window over
## something endless.
func _stand_up_buildings() -> void:
	if projection == null or not is_inside_tree():
		return
	var view := get_viewport_rect().size
	_make_rows()
	var live := {}
	for row in layers.size():
		var layer: BackdropLayer = layers[row]
		if layer == null:
			continue
		var stride: float = layer.width + layer.gap
		if stride <= 0.001:
			continue
		var shrink := projection.scale_at(layer.distance)
		var half_span: float = (view.x * 0.6) / maxf(0.001, projection.pixels_per_unit * shrink)
		for i in range(int(floor((-half_span + _travelled) / stride)),
				int(ceil((half_span + _travelled) / stride)) + 1):
			var slot := Vector2i(row, i)
			var building := _building_for(slot, layer)
			if building == null:
				break
			_place_building(building, layer, i, shrink)
			live[slot] = true

	for slot in _standing.keys():
		if not live.has(slot):
			(_standing[slot] as Node).queue_free()
			_standing.erase(slot)


## The node filling one slot, made if it is not there yet. Remade if the row has
## been pointed at a different scene since, which is what happens the moment an
## artist assigns one.
func _building_for(slot: Vector2i, layer: BackdropLayer) -> Node2D:
	var building: Node2D = _standing.get(slot)
	if building != null and _made_from(building) == layer.art:
		return building
	if building != null:
		building.queue_free()
		_standing.erase(slot)
	var made: Node2D = null
	if layer.art != null:
		made = layer.art.instantiate() as Node2D
		if made == null:
			if not _complained:
				_complained = true
				push_warning("Backdrop: a layer's art has a root that is not a Node2D, so that row cannot be stood up.")
			return null
	else:
		made = _stand_in(layer)
	if layer.art != null:
		made.set_meta(&"backdrop_art", layer.art)
	# Under its row's holder rather than straight onto this node, so a row that is
	# further away keeps painting first however the buildings come and go. No owner,
	# so none of it is written into the .tscn by an editor save.
	_rows[slot.x].add_child(made)
	_standing[slot] = made
	return made


func _place_building(building: Node2D, layer: BackdropLayer, i: int, shrink: float) -> void:
	var stride: float = layer.width + layer.gap
	var world_side: float = float(i) * stride - _travelled
	# The same stable pseudo-random height the drawn rows use, so a row does not
	# change shape when it is given art. Applied as a squash rather than a
	# different rectangle, since a building is now a picture being scaled.
	var wobble: float = fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
	building.position = projection.project(world_side, 0.0, layer.distance)
	building.scale = Vector2(shrink, shrink * (1.0 - layer.height_variation * wobble))
	# By where the row sits in the list, furthest first, rather than by its
	# distance. Distance would be the obvious number and is the wrong one: these
	# are siblings under one node, and all that matters is that a nearer row paints
	# over a further one.
	building.modulate = projection.haze_tint(layer.distance)


## A holder for each row, made once and in order. Their order in the tree is the
## order the rows paint in.
func _make_rows() -> void:
	while _rows.size() < layers.size():
		var holder := Node2D.new()
		holder.name = "Row%d" % _rows.size()
		add_child(holder)
		_rows.append(holder)


## What scene a standing building was made from, or null for a stand-in box.
##
## Guarded rather than asked with a default, because get_meta's default is itself
## null: passing one is indistinguishable from passing none, and the engine errors
## on the missing key instead of handing the default back.
func _made_from(building: Node2D) -> Variant:
	return building.get_meta(&"backdrop_art") if building.has_meta(&"backdrop_art") else null


## The box a row stands as until somebody draws it a building: the same size and
## colour it used to be drawn as, with the outline switched off, because a skyline
## silhouette never had one.
func _stand_in(layer: BackdropLayer) -> Placeholder2D:
	var box := Placeholder2D.new()
	box.size = Vector2(layer.width, layer.height) * projection.pixels_per_unit
	box.anchor = Vector2(0.5, 1.0)
	box.colour = layer.colour
	box.outline = Color(0, 0, 0, 0)
	return box
