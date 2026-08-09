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


## How much smaller something is at the given distance. 1.0 at the rider.
func scale_at(distance: float) -> float:
	return focal_length / maxf(0.001, focal_length + distance)


## Where a point in the street lands on screen.
func project(side: float, height: float, distance: float) -> Vector2:
	var scale := scale_at(distance)
	var ground_row: float = horizon_y + (near_ground_y - horizon_y) * scale
	return Vector2(
		centre_x + side * pixels_per_unit * scale,
		ground_row - height * pixels_per_unit * scale,
	)
