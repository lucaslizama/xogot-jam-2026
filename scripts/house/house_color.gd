extends Sprite2D

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

func _ready() -> void:
	# --- FLIP RANDOMIZATION ---
	# 50/50 chance to flip the sprite horizontally
	if randomize_flip_h:
		flip_h = randi() % 2 == 0

	# --- FRAME RANDOMIZATION ---
	# Calculates total frames based on the sprite's grid and picks a random index
	if randomize_frame:
		var total_frames: int = hframes * vframes
		if total_frames > 1:
			frame = randi_range(0, total_frames - 1)

	# --- MATERIAL RANDOMIZATION ---
	# Check if we actually need to manipulate the material
	var needs_color_randomization: bool = randomize_r or randomize_g or randomize_b
	
	if needs_color_randomization and material != null:
		if palette.is_empty():
			push_warning("Color randomization enabled on Sprite2D but the palette array is empty.")
			return
			
		# Duplicate so this instance gets unique shader values
		material = material.duplicate()
		
		if randomize_r:
			material.set_shader_parameter("color_r", _get_random_palette_color())
		if randomize_g:
			material.set_shader_parameter("color_g", _get_random_palette_color())
		if randomize_b:
			material.set_shader_parameter("color_b", _get_random_palette_color())

func _get_random_palette_color() -> Color:
	return palette.pick_random()
