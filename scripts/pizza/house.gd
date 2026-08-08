class_name House
extends RefCounted

## One house on the street, as data. The scene that draws it reads these; it
## does not own them, because the street has to reason about houses that are
## not on screen yet.

## Position along the street. Falls as the world scrolls past the rider.
var side: float = 0.0
## How far back from the road the house sits. Fixed for its whole life.
var distance: float = 20.0
## How close a landing has to be to count as delivered.
var drop_radius: float = 3.0
## False for scenery. Only waiting houses are worth throwing at.
var waiting: bool = true
## Set once a pizza lands in the drop point, so it cannot be served twice.
var served: bool = false


func _init(p_side: float, p_distance: float, p_drop_radius: float, p_waiting: bool) -> void:
	side = p_side
	distance = p_distance
	drop_radius = p_drop_radius
	waiting = p_waiting


## True when this house still wants a pizza.
func is_open() -> bool:
	return waiting and not served


## How far a landing at the given spot was from this drop point.
func miss_by(landed_side: float, landed_distance: float) -> float:
	return Vector2(landed_side - side, landed_distance - distance).length()
