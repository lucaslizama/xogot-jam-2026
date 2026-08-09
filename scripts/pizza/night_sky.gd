class_name NightSky
extends ColorRect

## The sky behind everything, drawn by a shader.
##
## Its only job in code is to keep the shader's idea of where the horizon sits
## in step with the projection's. Those are the same line, and a sky whose stars
## spill onto the road gives the game away immediately.

## A child's _ready runs before its parent's, so the game cannot have handed
## this over yet when this node starts. Refitting on assignment means it does not
## matter which of them gets there first.
@export var projection: StreetProjection:
	set(value):
		projection = value
		if is_inside_tree():
			_fit_to_screen()


func _ready() -> void:
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)


func _fit_to_screen() -> void:
	var screen := get_viewport_rect().size
	position = Vector2.ZERO
	size = screen
	if projection == null or material == null:
		return
	(material as ShaderMaterial).set_shader_parameter(
		"horizon", projection.horizon_y / maxf(1.0, screen.y))
