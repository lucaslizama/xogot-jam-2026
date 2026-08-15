extends Sprite2D

## Picks which building this sprite is, which way round it faces, and what colour
## its masked channels are tinted, from one seed.
##
## Everything is derived from [method set_house_look]'s seed rather than drawn
## fresh, because a house is drawn by more than one node: [HouseView] holds a
## separate node for waiting, served and scenery, and each has its own sprite. If
## each rolled its own dice, delivering a pizza would turn the house into a
## different building, flipped the other way and painted another colour. The house
## hands every state the same seed, so they agree.

@export_category("Sprite Settings")
## Toggle randomization of the sprite's starting frame
@export var randomize_frame: bool = false
## Toggle randomization of flipping the sprite horizontally (X axis)
@export var randomize_flip_h: bool = false

@export_category("Palette Settings")
@export var palette: Array[Color]

@export_category("Channel Randomization")
## Toggle randomization for the Red channel mask
@export var randomize_r: bool = false
## Toggle randomization for the Green channel mask
@export var randomize_g: bool = false
## Toggle randomization for the Blue channel mask
@export var randomize_b: bool = false

var _look_seed: int = 0
## The copy of the material this sprite owns, made once. Re-picking a look must
## not stack another duplicate on top of the last one.
var _own_material: ShaderMaterial = null


func _ready() -> void:
	# A look of this sprite's own, for a sprite standing on its own. Children are
	# ready before their parents, so a HouseView always speaks after this and
	# always replaces it with the seed shared across the house's states.
	set_house_look(randi())


## Told by [HouseView], with the same seed given to every state of the house.
func set_house_look(look_seed: int) -> void:
	_look_seed = look_seed
	_apply_look()


func _apply_look() -> void:
	if randomize_flip_h:
		flip_h = _pick(0, 2) == 0

	if randomize_frame:
		var total_frames: int = hframes * vframes
		if total_frames > 1:
			frame = _pick(1, total_frames)

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


## One choice out of `count`, decided by the seed and by which choice it is.
##
## A stream of numbers taken in order would do, until two sprites given the same
## seed have different toggles set: the one not tinting its red channel would take
## one fewer number and every later choice would slide. Salting per choice keeps
## the waiting and served sprites on the same building whatever else differs.
func _pick(salt: int, count: int) -> int:
	if count <= 1:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(_look_seed, salt))
	return rng.randi_range(0, count - 1)
