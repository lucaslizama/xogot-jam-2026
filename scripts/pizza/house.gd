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
## The house's body in world units: x how wide it is, y how tall it stands. A
## pizza thrown into it counts, so this has to be the size the house is drawn at
## or the player will be hitting something they cannot see. Zero means no body,
## and only the drop point can be hit.
var body: Vector2 = Vector2.ZERO
## False for scenery. Only waiting houses are worth throwing at.
var waiting: bool = true
## Set once a pizza lands in the drop point, so it cannot be served twice.
var served: bool = false


func _init(p_side: float, p_distance: float, p_drop_radius: float, p_waiting: bool,
		p_body: Vector2 = Vector2.ZERO) -> void:
	side = p_side
	distance = p_distance
	drop_radius = p_drop_radius
	waiting = p_waiting
	body = p_body


## True when this house still wants a pizza.
func is_open() -> bool:
	return waiting and not served


## How far a landing at the given spot was from this drop point.
func miss_by(landed_side: float, landed_distance: float) -> float:
	return Vector2(landed_side - side, landed_distance - distance).length()


## True when a pizza that moved from `from` to `to` went into the front of this
## house. Both are (side, height, distance), the same order the flight traces in.
##
## The house is one flat wall standing at its own distance, as wide and as tall as
## it is drawn, roof included. Squaring off the roof rather than following its
## slope makes the two top corners a little kinder than they look, which is the
## right way round for a throw the player has already committed to.
##
## Taking both ends of the step rather than one point matters: a hard throw covers
## more than a house's width in a single frame and would otherwise pass through it.
func struck_by(from: Vector3, to: Vector3) -> bool:
	if body.x <= 0.0 or body.y <= 0.0:
		return false
	# Houses are only ever hit from the road, on the way out. A pizza that starts
	# beyond this one has already passed it.
	var span := to.z - from.z
	if span <= 0.0 or from.z > distance or to.z < distance:
		return false
	var t: float = (distance - from.z) / span
	var at_side: float = lerpf(from.x, to.x, t)
	var at_height: float = lerpf(from.y, to.y, t)
	return (absf(at_side - side) <= body.x * 0.5
		and at_height >= 0.0 and at_height <= body.y)
