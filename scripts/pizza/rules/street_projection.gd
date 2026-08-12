class_name StreetProjection
extends Resource

## Turns the street's three numbers into screen pixels.
##
## Kept apart from the flight maths so the camera can be reframed, the horizon
## moved or the whole scene made shallower or deeper, without any of that
## touching how a pizza flies.

@export_group("Camera")
## Screen row the street converges to. Everything infinitely far away sits here.
@export_range(0.0, 3000.0, 1.0) var horizon_y: float = 900.0
## Screen row the ground sits on at the rider's own distance.
@export_range(0.0, 4000.0, 1.0) var near_ground_y: float = 2100.0
## Screen column the rider's line runs down.
@export_range(0.0, 3000.0, 1.0) var centre_x: float = 585.0
## Larger values flatten the perspective; smaller ones exaggerate it.
@export_range(1.0, 400.0, 1.0) var focal_length: float = 28.0
## Pixels per world unit at the rider's own distance.
@export_range(1.0, 400.0, 1.0) var pixels_per_unit: float = 46.0

@export_group("Haze")
## Distant things are tinted towards this, which is the oldest depth cue there
## is and the only one that survives whatever art turns up: it multiplies over a
## finished sprite exactly as it does over a placeholder box. Set it near the sky
## so the far end of the street sinks into it.
@export var haze_colour: Color = Color(0.278431, 0.231373, 0.470588)
## Nothing nearer than this is tinted at all.
@export_range(0.0, 300.0, 1.0) var haze_from: float = 18.0
## By this distance the tint is at full strength.
@export_range(1.0, 800.0, 1.0) var haze_full: float = 260.0
## How much of the tint is applied at full strength. 1.0 would bury the far row.
@export_range(0.0, 1.0, 0.05) var haze_strength: float = 0.75


## How much smaller something is at the given distance. 1.0 at the rider.
func scale_at(distance: float) -> float:
	return focal_length / maxf(0.001, focal_length + distance)


## How strongly the haze takes hold at a given distance, 0 to 1.
func haze_at(distance: float) -> float:
	var span: float = maxf(0.01, haze_full - haze_from)
	return clampf((distance - haze_from) / span, 0.0, 1.0) * haze_strength


## The tint to multiply over anything sitting at this distance.
func haze_tint(distance: float) -> Color:
	return Color.WHITE.lerp(haze_colour, haze_at(distance))


## Where a point in the street lands on screen.
func project(side: float, height: float, distance: float) -> Vector2:
	var scale := scale_at(distance)
	var ground_row: float = horizon_y + (near_ground_y - horizon_y) * scale
	return Vector2(
		centre_x + side * pixels_per_unit * scale,
		ground_row - height * pixels_per_unit * scale,
	)
