class_name GameDaylight
extends Node

## The hour of the day, and everything it paints.
##
## A street carries a [TimeOfDay]; crossing from one street to the next crosses
## the sky rather than cutting to it. This owns that crossing and hands the
## palette to the four things that use it: the sky shader, the road shader, the
## projection's haze and the backdrop's tint.
##
## It lives here rather than in the game because the menu's decorative street runs
## exactly the same cycle behind the title. The two carried a copy each, twenty-nine
## identical lines of them, which is two places to remember when a shader gains a
## parameter. Ask a host what its hour is and it asks this.

## How long the sky takes to cross from one street's hour to the next. The sun
## should be seen coming up, not be found already up.
@export_range(0.0, 12.0, 0.1) var crossfade: float = 2.5

@export_group("What it paints")
## The three nodes whose look the hour decides, as paths from this node. Defaulted
## to the sibling names both scenes use.
@export var sky_path: NodePath = ^"../Sky"
@export var street_path: NodePath = ^"../Street"
@export var backdrop_path: NodePath = ^"../Backdrop"

## The haze belongs to the projection, because the houses and the skyline ask it
## for their tint. Changing the hour changes those without either knowing about
## hours. Set by whoever owns this, since they own the projection too.
var projection: StreetProjection

var _hour: TimeOfDay
var _from: TimeOfDay
var _to: TimeOfDay
var _blend: float = 1.0


## Start crossing to a street's hour. The first street simply is its hour; every
## one after that is arrived at from wherever the last one left the sky.
func begin(hour: TimeOfDay) -> void:
	if hour == null:
		return
	_from = _hour if _hour != null else hour
	_to = hour
	_blend = 0.0 if _hour != null and crossfade > 0.0 else 1.0
	_paint(_from.blended_with(_to, _blend))


func advance(delta: float) -> void:
	if _blend >= 1.0 or _to == null:
		return
	_blend = minf(1.0, _blend + delta / maxf(0.01, crossfade))
	_paint(_from.blended_with(_to, _blend))


## What the hour multiplies the world by, for anything tinting itself. White until
## an hour has been set, so a scene with no daylight draws its own colours.
func world_tint() -> Color:
	return _hour.world_tint if _hour != null else Color.WHITE


## The hour as it stands, part way through a crossing rather than either end of it.
func hour() -> TimeOfDay:
	return _hour


func _paint(hour: TimeOfDay) -> void:
	_hour = hour

	var sky_node := get_node_or_null(sky_path) as CanvasItem
	var sky := sky_node.material as ShaderMaterial if sky_node != null else null
	if sky != null:
		sky.set_shader_parameter("top_colour", hour.sky_top)
		sky.set_shader_parameter("horizon_colour", hour.sky_horizon)
		sky.set_shader_parameter("star_brightness", hour.star_brightness)
		sky.set_shader_parameter("star_chance", hour.star_chance)

	var street_node := get_node_or_null(street_path) as CanvasItem
	var road := street_node.material as ShaderMaterial if street_node != null else null
	if road != null:
		road.set_shader_parameter("asphalt", hour.asphalt)
		road.set_shader_parameter("asphalt_grain", hour.asphalt_grain)
		road.set_shader_parameter("verge_colour", hour.verge)
		road.set_shader_parameter("lane_colour", hour.lane)
		road.set_shader_parameter("haze_colour", hour.haze_colour)
		road.set_shader_parameter("haze_strength", hour.haze_strength)

	if projection != null:
		projection.haze_colour = hour.haze_colour
		projection.haze_strength = hour.haze_strength

	var backdrop := get_node_or_null(backdrop_path) as CanvasItem
	if backdrop != null:
		backdrop.modulate = hour.world_tint
		backdrop.queue_redraw()
