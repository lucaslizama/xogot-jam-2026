@tool
extends Sprite2D

## Draws one house: which building it is, which way round, and what colour its
## masked channels are tinted.
##
## Nothing is decided here. The building and the flip come from the street, because
## the window a pizza goes through is painted into one particular building and the
## throw is judged against it. The colour comes from a seed [HouseView] hands out,
## the same one to every state, or delivering a pizza would repaint the house. A
## sprite standing alone picks for itself in [method _ready] and is superseded the
## moment a house speaks.
##
## A tool script, so the House node's preview_look shows the building it names on
## the canvas. It does deliberately less at edit time: see [method _apply_look].

@export_category("Sprite Settings")
## Whether this sprite shows the building the house turned out to be. Off, and it
## always draws frame 0 whatever the street said.
##
## Not a randomizer, despite where the value comes from: the street picks the
## building, because it also has to place the windows a pizza can go through and
## those have to be the same building.
@export var follow_house_look: bool = false
## Whether this sprite is mirrored when the house is.
@export var follow_house_mirror: bool = false

@export_category("Palette Settings")
@export var palette: Array[Color]

@export_category("Channel Randomization")
## Toggle randomization for the Red channel mask
@export var randomize_r: bool = false
## Toggle randomization for the Green channel mask
@export var randomize_g: bool = false
## Toggle randomization for the Blue channel mask
@export var randomize_b: bool = false

var _tint_seed: int = 0
var _frame_index: int = 0
var _flip: bool = false
## The copy of the material this sprite owns, made once. Being told a look again
## must not stack another duplicate on top of the last one.
var _own_material: ShaderMaterial = null
## So a sheet that does not match the window table says so once, not every house.
var _complained: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		# Nothing to roll on the canvas. The House above says which building to
		# show through its preview, and a sprite that picked its own would flicker
		# to a different one every time the scene was opened.
		return
	# A look of this sprite's own, for a sprite standing on its own. Children are
	# ready before their parents, so a HouseView always speaks after this.
	set_house_look(randi(), -1, false, 0)


## Told by [HouseView].
##
## `frame_index` below zero means nobody has decided, so pick from the seed; that
## is the standing-alone case and never happens in the game. `look_count` is how
## many buildings the window table describes, and is only used to notice a sheet
## that does not match it.
func set_house_look(tint_seed: int, frame_index: int, flip: bool, look_count: int) -> void:
	_tint_seed = tint_seed
	var total: int = maxi(1, hframes * vframes)
	_warn_if_sheet_disagrees(total, look_count)
	if frame_index < 0:
		_frame_index = _pick(1, total)
		_flip = _pick(0, 2) == 0
	else:
		_frame_index = clampi(frame_index, 0, total - 1)
		_flip = flip
	_apply_look()


## The building and the way round are applied everywhere, including the editor
## canvas, because showing them is the whole point of the House node's preview.
##
## The colour is not. Painting it means duplicating the material and putting the
## copy back on this node, and at edit time that is a change to the scene: save it
## once and every house is carrying its own copy of a material that was meant to be
## shared. The canvas shows the building in the palette's stock colours instead,
## which is the one thing about a preview worth giving up.
func _apply_look() -> void:
	if follow_house_mirror:
		flip_h = _flip
	if follow_house_look:
		frame = _frame_index

	if Engine.is_editor_hint():
		return
	if not (randomize_r or randomize_g or randomize_b):
		return
	if material == null:
		push_warning("%s: colour randomization is on but there is no material to set it on."
			% name)
		return
	if palette.is_empty():
		push_warning("%s: colour randomization is on but the palette array is empty." % name)
		return

	if _own_material == null:
		# Duplicate so this instance gets unique shader values.
		_own_material = material.duplicate() as ShaderMaterial
		material = _own_material
	if randomize_r:
		_own_material.set_shader_parameter("color_r", palette[_pick(2, palette.size())])
	if randomize_g:
		_own_material.set_shader_parameter("color_g", palette[_pick(3, palette.size())])
	if randomize_b:
		_own_material.set_shader_parameter("color_b", palette[_pick(4, palette.size())])


## A sheet with more buildings on it than the window table describes will never
## show the extra ones, since the street only ever picks a building it knows the
## window of. Worth saying, because the symptom is a building quietly missing from
## the game rather than anything going wrong.
func _warn_if_sheet_disagrees(total: int, look_count: int) -> void:
	if _complained or look_count <= 0 or not follow_house_look or total == look_count:
		return
	_complained = true
	push_warning(("%s: the sheet has %d frames but the window table describes %d. "
		+ "Only the first %d will ever be drawn, and any window past them is unused.")
		% [name, total, look_count, mini(total, look_count)])


## One choice out of `count`, decided by the seed and by which choice it is.
##
## A stream of numbers taken in order would do, until two sprites given the same
## seed have different toggles set: the one not tinting its red channel would take
## one fewer number and every later choice would slide. Salting per choice keeps
## the waiting and served sprites painted the same colour whatever else differs.
func _pick(salt: int, count: int) -> int:
	if count <= 1:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(_tint_seed, salt))
	return rng.randi_range(0, count - 1)
