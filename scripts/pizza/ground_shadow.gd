class_name GroundShadow
extends Node2D

## The pizza's shadow on the road.
##
## This is the single cheapest thing that makes a fake-3D throw readable. Without
## it a box high and close looks identical to one low and far away, and the
## player has no way to tell how the throw is going until it lands.

@export var colour: Color = Color(0.0, 0.0, 0.0, 0.35)
## Radius at the rider's own distance, in pixels. Scale comes from the game.
@export_range(2.0, 200.0, 1.0) var radius: float = 30.0
## How flat the shadow lies. 1.0 is a circle facing the camera.
@export_range(0.05, 1.0, 0.01) var squash: float = 0.34


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, radius, colour)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
