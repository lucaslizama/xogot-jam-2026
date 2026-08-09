class_name PizzaPhysics
extends Resource

## Everything about how a thrown pizza behaves, in one resource a designer can
## open and retune without touching code.
##
## The world is a flat drawing pretending to have depth, so positions are kept
## as three plain numbers rather than a Vector3: sideways offset from the
## rider's line, height off the ground, and distance up the street. Only the
## projection resource knows how those become pixels.

@export_group("Flight")
## Downward pull, in world units per second squared.
@export_range(1.0, 200.0, 0.5) var gravity: float = 133.0
## Height the pizza leaves the rider's hands at.
@export_range(0.0, 10.0, 0.1) var release_height: float = 7.0
## Fraction of forward speed bled off per second. 0 keeps it constant.
@export_range(0.0, 2.0, 0.01) var forward_drag: float = 0.25

@export_group("Throw mapping")
## Finger speed, in screen pixels per second, that maps to a full-power throw.
@export_range(200.0, 20000.0, 50.0) var full_power_flick: float = 9000.0
## Forward speed of a full-power throw, in world units per second.
@export_range(1.0, 200.0, 0.5) var max_forward_speed: float = 112.0
## Shapes how flick speed becomes power. Distance grows with the SQUARE of
## power, because power buys both forward speed and hang time, so a straight
## mapping wastes most of the flick range on throws that sail past everything.
## Around 0.5 undoes that and makes distance roughly linear in flick speed.
@export_range(0.2, 2.0, 0.05) var power_curve: float = 0.85
## Upward speed of a full-power throw. Without this the pizza is dropped rather
## than lobbed: it would be on the ground in about a third of a second, too
## quick to watch and too quick for spin to do anything.
@export_range(0.0, 120.0, 0.5) var max_lift_speed: float = 60.0
## A release slower than this is a fumble, not a throw: the pizza stays on the
## bike and no box is spent. Without it every stray tap costs a pizza.
@export_range(0.0, 3000.0, 10.0) var min_throw_flick: float = 260.0
## A throw can never be feebler than this fraction of full power, so a nervous
## flick still leaves the bike.
@export_range(0.0, 1.0, 0.01) var min_power: float = 0.12
## How far sideways the aim swings at the extremes of a flick's direction.
@export_range(0.0, 60.0, 0.5) var max_aim_speed: float = 44.0

@export_group("Spin")
## Radians of accumulated wind-up that count as a full-strength spin. One full
## circle of the finger is about 6.28.
@export_range(0.5, 25.0, 0.1) var full_spin_windup: float = 4.2
## Wind-up below this counts as none at all. Carrying the pizza around the
## screen racks up small turns that were never an attempt to curve anything;
## without a deadzone the pizza twitches left and right in your hand and picks
## up curve nobody asked for.
@export_range(0.0, 4.0, 0.05) var spin_deadzone: float = 1.3
## Sideways push a full spin gives, scaled by how fast the pizza is still
## travelling forward. Sets how far a fully wound throw can bend.
@export_range(0.0, 400.0, 1.0) var spin_curve: float = 280.0
## How fast wind-up drains while the pizza is held, in radians a second. Without
## it the pizza spins forever off one flick of the wrist; with it the player has
## to keep circling to keep the curve loaded, and letting go of the motion winds
## the spin down.
@export_range(0.0, 20.0, 0.1) var windup_bleed: float = 3.5
## Spin bleeds away at this fraction per second, so late flight straightens out.
@export_range(0.0, 4.0, 0.05) var spin_decay: float = 1.4


## Turn a released flick into launch values. `flick` is the finger's velocity at
## release in screen pixels per second, with +y pointing down the screen, so a
## throw up the street has a negative y. `windup` is the total signed angle the
## gesture swept, in radians.
func launch_from(flick: Vector2, windup: float) -> Dictionary:
	# Only the up-screen part of the flick is power; a purely sideways swipe is
	# not a throw, it is a flourish.
	var up_speed: float = maxf(0.0, -flick.y)
	var power: float = clampf(up_speed / full_power_flick, 0.0, 1.0)
	power = lerpf(min_power, 1.0, pow(power, power_curve))

	# Aim comes from how far the flick leaned off vertical, not its raw width,
	# so a fast throw and a slow one with the same lean go to the same place.
	var lean: float = 0.0
	if up_speed > 1.0:
		lean = clampf(flick.x / up_speed, -1.0, 1.0)

	return {
		"forward_speed": max_forward_speed * power,
		"lift_speed": max_lift_speed * power,
		"aim_speed": max_aim_speed * lean,
		"spin": spin_from(windup),
	}


## How much spin a gesture's total turning is worth, from -1 to 1. Past the
## deadzone it climbs to full strength at [member full_spin_windup]. The pizza
## in your hand is turned by this same number, so what you see is what it does.
func spin_from(windup: float) -> float:
	var past_deadzone: float = maxf(0.0, absf(windup) - spin_deadzone)
	var span: float = maxf(0.01, full_spin_windup - spin_deadzone)
	return signf(windup) * clampf(past_deadzone / span, 0.0, 1.0)
