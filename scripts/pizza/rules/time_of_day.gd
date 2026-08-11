class_name TimeOfDay
extends Resource

## A whole palette for one hour of the day, from the sky down to the tarmac.
##
## The colours in the scene all funnel through a handful of places: two shaders,
## the haze the projection hands out, and one tint over everything solid. Putting
## them in a resource means an hour can be authored and previewed as a thing,
## rather than being a set of numbers scattered across scenes that have to be
## changed together and in step.

@export var display_name: String = "Night"

@export_group("Sky")
@export var sky_top: Color = Color(0.055, 0.043, 0.125)
@export var sky_horizon: Color = Color(0.29, 0.18, 0.33)
## Stars go out as the sky comes up. Zero is broad daylight.
@export_range(0.0, 4.0, 0.05) var star_brightness: float = 1.4
## Thinning them out as well as dimming them stops dawn looking like a fade.
@export_range(0.0, 1.0, 0.01) var star_chance: float = 0.12

@export_group("Air")
## What distance recedes into. Everything solid is tinted towards this.
@export var haze_colour: Color = Color(0.42, 0.36, 0.58)
@export_range(0.0, 1.0, 0.05) var haze_strength: float = 0.75

@export_group("Ground")
@export var asphalt: Color = Color(0.15, 0.14, 0.17)
@export var asphalt_grain: Color = Color(0.21, 0.20, 0.24)
@export var verge: Color = Color(0.19, 0.21, 0.17)
@export var lane: Color = Color(0.78, 0.74, 0.55, 0.7)

@export_group("Everything solid")
## Multiplied over the houses and the skyline, so the whole world warms with the
## sky instead of the sky changing above an unchanged street.
@export var world_tint: Color = Color(1.0, 1.0, 1.0)


## A palette part way between this one and another. Dawn is not a switch, so the
## game crosses from one hour to the next rather than cutting.
func blended_with(other: TimeOfDay, amount: float) -> TimeOfDay:
	if other == null:
		return self
	var t := clampf(amount, 0.0, 1.0)
	var mix := TimeOfDay.new()
	mix.display_name = "%s to %s" % [display_name, other.display_name]
	mix.sky_top = sky_top.lerp(other.sky_top, t)
	mix.sky_horizon = sky_horizon.lerp(other.sky_horizon, t)
	mix.star_brightness = lerpf(star_brightness, other.star_brightness, t)
	mix.star_chance = lerpf(star_chance, other.star_chance, t)
	mix.haze_colour = haze_colour.lerp(other.haze_colour, t)
	mix.haze_strength = lerpf(haze_strength, other.haze_strength, t)
	mix.asphalt = asphalt.lerp(other.asphalt, t)
	mix.asphalt_grain = asphalt_grain.lerp(other.asphalt_grain, t)
	mix.verge = verge.lerp(other.verge, t)
	mix.lane = lane.lerp(other.lane, t)
	mix.world_tint = world_tint.lerp(other.world_tint, t)
	return mix
