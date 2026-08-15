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
## How high off the ground the wall starts counting. Below this a pizza is
## arriving at the door rather than hitting the house, and the drop point at its
## feet decides. Without it the wall stands in the ring's own doorway: every throw
## accurate enough to reach the drop point has to cross the facade to get there,
## so the wall took them all and a dead centre landing was impossible.
var doorstep: float = 0.0
## Which of the buildings on the sheet this house is, and whether it is drawn
## mirrored. Decided when the street stocks the house, because the window below has
## to match the one painted into that particular picture; the scene that draws it
## is told, rather than choosing for itself and leaving the target somewhere else.
var look: int = 0
var flipped: bool = false
## Every lit window on the front, in world units: x measured across from the middle
## of the house, y up from the ground, each given by its lower-left corner. Empty
## means no window at all, and the whole facade is plain wall.
##
## A list rather than one window, because the buildings are drawn with however many
## windows they were drawn with. Any of them counts: a player aiming at glass they
## can see should not have to know which pane the rules happened to pick.
var windows: Array[Rect2] = []
## False for scenery. Only waiting houses are worth throwing at.
var waiting: bool = true
## Set once a pizza lands in the drop point, so it cannot be served twice.
var served: bool = false


func _init(p_side: float, p_distance: float, p_drop_radius: float, p_waiting: bool,
		p_body: Vector2 = Vector2.ZERO, p_doorstep: float = 0.0,
		p_window: Vector2 = Vector2.ZERO, p_window_centre: float = 0.0,
		p_window_offset: float = 0.0) -> void:
	side = p_side
	distance = p_distance
	drop_radius = p_drop_radius
	waiting = p_waiting
	body = p_body
	doorstep = p_doorstep
	# One window, given the easy way. The street hands over a whole list when it has
	# a table of buildings to read them off; this is for a plain house and for tests
	# that want a single pane and no table to set up.
	if p_window.x > 0.0 and p_window.y > 0.0:
		windows.append(Rect2(p_window_offset - p_window.x * 0.5,
			p_window_centre - p_window.y * 0.5, p_window.x, p_window.y))


## True when this house still wants a pizza.
func is_open() -> bool:
	return waiting and not served


## How far a landing at the given spot was from this drop point.
func miss_by(landed_side: float, landed_distance: float) -> float:
	return Vector2(landed_side - side, landed_distance - distance).length()


## True when a pizza that moved from `from` to `to` went into the front of this
## house. Both are (side, height, distance), the same order the flight traces in.
##
## The house is one flat wall standing at its own distance, as wide as it is drawn
## and reaching from [member doorstep] up to its roof. Squaring off the roof rather
## than following its slope makes the two top corners a little kinder than they
## look, which is the right way round for a throw already committed to.
##
## The wall is therefore the reward for overthrowing, not for aiming: a pizza that
## would have sailed past is caught by it, while one placed on the mat goes to the
## drop point and is worth more.
##
## Taking both ends of the step rather than one point matters: a hard throw covers
## more than a house's width in a single frame and would otherwise pass through it.
func struck_by(from: Vector3, to: Vector3) -> bool:
	return hit_by(from, to) != HouseHit.NONE


## What a pizza moving from `from` to `to` hit, if anything. Prefixed, because a
## bare name in a class can collide with a built-in global enum and the class then
## fails to compile with nothing said about why.
enum HouseHit {
	NONE,
	## The front of the house. It counts, and it is the easiest way to score.
	WALL,
	## Clean through the lit window: small, high, and worth the most.
	WINDOW,
}


func hit_by(from: Vector3, to: Vector3) -> HouseHit:
	if body.x <= 0.0 or body.y <= 0.0:
		return HouseHit.NONE
	# Houses are only ever hit from the road, on the way out. A pizza that starts
	# beyond this one has already passed it.
	var span := to.z - from.z
	if span <= 0.0 or from.z > distance or to.z < distance:
		return HouseHit.NONE
	var t: float = (distance - from.z) / span
	# Signed, because the window is not in the middle of the facade and knowing
	# only how far off centre a pizza was cannot tell the glass from the wall on
	# the other side of the door.
	var across_signed: float = lerpf(from.x, to.x, t) - side
	var across: float = absf(across_signed)
	var at_height: float = lerpf(from.y, to.y, t)

	# The windows are asked about first, since they sit within the wall and a pizza
	# through one should not merely be a pizza against the house. Any of them
	# counts, so a building drawn with three panes is three chances at the good
	# throw rather than one and two decorations.
	var at := Vector2(across_signed, at_height)
	for pane in windows:
		if pane.has_point(at):
			return HouseHit.WINDOW

	if across <= body.x * 0.5 and at_height > doorstep and at_height <= body.y:
		return HouseHit.WALL
	return HouseHit.NONE
