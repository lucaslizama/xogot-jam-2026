class_name StreetSurface
extends ColorRect

## The road, drawn by a shader that inverts the projection per pixel.
##
## Its only job here is to keep the shader's copy of the camera in step with the
## projection resource, and to tell it how far the world has travelled. Those
## numbers exist in exactly one place; this hands them over rather than keeping
## a second set that could drift.
##
## Which is why data/street_material.tres holds the road's look and none of the
## camera: no screen size, no horizon, no focal length, no haze. Every one of those
## is pushed in below from the projection, so a copy stored on the material would be
## overwritten a frame later while still being what the canvas showed. Both scenes
## point at that one material, so the road is tuned once and both the menu and the
## game get it. They each carried a copy of their own until the pavement in one
## quietly stopped matching the pavement in the other.
##
## The consequence worth knowing: on the canvas, with nothing running, the shader
## falls back to its own defaults for the camera. They are written to match the
## projection's defaults, so the preview is right until somebody changes the
## projection, and then it is the preview that is wrong rather than the game.

## Assigned by the game. Refits on assignment because a child's _ready runs
## before its parent's, so this cannot wait until startup to be told.
@export var projection: StreetProjection:
	set(value):
		projection = value
		if is_inside_tree():
			_push_camera()


func _ready() -> void:
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)


## Told every frame by the game, the same figure the houses scroll by.
func set_travelled(distance_travelled: float) -> void:
	var shader := material as ShaderMaterial
	if shader != null:
		shader.set_shader_parameter("travelled", distance_travelled)


func _fit_to_screen() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_push_camera()


func _push_camera() -> void:
	var shader := material as ShaderMaterial
	if shader == null or projection == null:
		return
	shader.set_shader_parameter("screen_size", size)
	shader.set_shader_parameter("horizon_y", projection.horizon_y)
	shader.set_shader_parameter("near_ground_y", projection.near_ground_y)
	shader.set_shader_parameter("centre_x", projection.centre_x)
	shader.set_shader_parameter("focal", projection.focal_length)
	shader.set_shader_parameter("pixels_per_unit", projection.pixels_per_unit)
	shader.set_shader_parameter("haze_colour", projection.haze_colour)
	shader.set_shader_parameter("haze_from", projection.haze_from)
	shader.set_shader_parameter("haze_full", projection.haze_full)
	shader.set_shader_parameter("haze_strength", projection.haze_strength)
