class_name PizzaFlight
extends RefCounted

## One pizza in the air. Pure arithmetic with no nodes in it, so the whole of
## the throw can be tested without drawing anything.
##
## Axes: `side` runs along the street, positive to the right, and is the axis
## the world scrolls down. `distance` runs across the street away from the road,
## toward the houses, and is what power buys. `height` is off the ground.
##
## A pizza does not scroll with the street, because it keeps the bike's speed
## when it leaves your hands. In the rider's frame that means the houses slide
## past underneath it, so throws have to lead a moving target.

var side: float = 0.0
var height: float = 0.0
var distance: float = 0.0

var _side_speed: float = 0.0
var _fall_speed: float = 0.0
var _forward_speed: float = 0.0
var _spin: float = 0.0
var _landed: bool = false
var _tuning: PizzaPhysics


func _init(tuning: PizzaPhysics, launch: Dictionary) -> void:
	_tuning = tuning
	height = tuning.release_height
	_forward_speed = launch.get("forward_speed", 0.0)
	_side_speed = launch.get("aim_speed", 0.0)
	_spin = launch.get("spin", 0.0)
	# Negative fall speed is upward: the throw arcs before it drops.
	_fall_speed = -launch.get("lift_speed", 0.0)


## Advance the flight. Returns true on the frame the pizza reaches the ground,
## after which position holds the landing spot and further steps do nothing.
func step(delta: float) -> bool:
	if _landed:
		return false

	# Spin pushes sideways in proportion to how fast the pizza is still going
	# forward. Since spin bleeds away, the sideways push fades while the speed
	# it built up does not: the flight bananas out early and then holds a
	# straight diagonal. That settling is what makes a curve aimable at all,
	# rather than an ever-tightening spiral.
	_side_speed += _spin * _tuning.spin_curve * (_forward_speed / maxf(1.0, _tuning.max_forward_speed)) * delta
	_spin = move_toward(_spin, 0.0, _tuning.spin_decay * delta)
	_forward_speed = maxf(0.0, _forward_speed - _forward_speed * _tuning.forward_drag * delta)
	_fall_speed += _tuning.gravity * delta

	side += _side_speed * delta
	distance += _forward_speed * delta
	height -= _fall_speed * delta

	if height <= 0.0:
		height = 0.0
		_landed = true
		return true
	return false


func has_landed() -> bool:
	return _landed


## How fast the pizza is turning, for spinning the sprite while it flies.
func current_spin() -> float:
	return _spin


## Run a whole throw at once and hand back where it went, as (side, height,
## distance) samples ending on the ground. Used to draw the aim preview, so the
## line the player sees is produced by exactly the same maths that will fly.
static func trace(tuning: PizzaPhysics, launch: Dictionary, samples: int = 26) -> PackedVector3Array:
	var path := PackedVector3Array()
	var flight := PizzaFlight.new(tuning, launch)
	var step := 1.0 / 120.0
	var guard := 0
	var taken := 0
	while guard < 20000:
		guard += 1
		var landed := flight.step(step)
		taken += 1
		# Thin the samples out so a long throw is not a thousand points.
		if landed or taken % 5 == 0:
			path.append(Vector3(flight.side, flight.height, flight.distance))
		if landed:
			break
	if path.size() > samples:
		var thinned := PackedVector3Array()
		var stride: float = float(path.size() - 1) / float(samples - 1)
		for i in samples:
			thinned.append(path[mini(path.size() - 1, int(round(float(i) * stride)))])
		return thinned
	return path
