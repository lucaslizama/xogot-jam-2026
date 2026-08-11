class_name ThrowGesture
extends RefCounted

## Watches one drag and reports what kind of throw it was.
##
## Two things come out of it. The flick is how fast the finger was moving when
## it left the screen, which becomes power and aim. The wind-up is the total
## signed angle the gesture turned through, which becomes spin.
##
## Using total turning for spin means the deliberate version and the accidental
## one are the same measurement: circling the pizza before flicking racks up a
## lot of turning, a hooked flick racks up a little, and a straight drag racks
## up none. One number, so there is only ever one curve behaviour to tune.

## Samples older than this are dropped, so the flick reflects the last instant
## of the drag rather than its whole history.
const FLICK_WINDOW: float = 0.09
## How far the finger must travel before another direction reading is taken.
##
## Readings are taken per distance travelled rather than per touch sample, and
## that distinction is the whole ballgame. A phone reporting at 120 Hz sends
## steps of a couple of pixels; comparing those directly is all noise, and
## discarding them instead threw away the entire gesture. Aggregating to a fixed
## arc gives the same answer whatever rate the device samples at.
const MIN_ARC: float = 8.0
## The most one reading may turn and still count as circling.
##
## Reversing direction registers as a full half turn in a single reading, and
## which way it lands is decided by a pixel of sideways noise. Dragging the
## pizza straight up and down therefore banked random half turns of wind-up.
## Circling turns gradually: at this reading distance even a tight circle turns
## a fraction of a radian at a time, so anything sharper is a corner, not a
## curve, and counts for nothing.
const MAX_TURN_PER_READING: float = 0.8

var _points: Array[Vector2] = []
var _times: Array[float] = []
var _windup: float = 0.0
var _last_direction: Vector2 = Vector2.ZERO
## Where the last direction reading was taken from.
var _anchor: Vector2 = Vector2.ZERO
var _active: bool = false


func begin(position: Vector2, time: float) -> void:
	_points = [position]
	_times = [time]
	_windup = 0.0
	_last_direction = Vector2.ZERO
	_anchor = position
	_active = true


func update(position: Vector2, time: float) -> void:
	if not _active:
		return

	if position.distance_to(_anchor) >= MIN_ARC:
		var direction := (position - _anchor).normalized()
		if _last_direction != Vector2.ZERO:
			# Signed angle between one reading and the next. Summed over the
			# whole gesture this is its total turning: zero for a straight drag,
			# one full turn per circle of the finger.
			var turn := _last_direction.angle_to(direction)
			if absf(turn) <= MAX_TURN_PER_READING:
				_windup += turn
		_last_direction = direction
		_anchor = position

	_points.append(position)
	_times.append(time)
	_trim(time)


## Finish the drag. Returns the flick velocity in pixels per second.
func release(position: Vector2, time: float) -> Vector2:
	update(position, time)
	_active = false
	return current_flick()


## The flick this drag would throw with if it ended right now, without ending
## it. The aim preview asks this every frame.
func current_flick() -> Vector2:
	if _points.size() < 2:
		return Vector2.ZERO
	var span: float = _times[_times.size() - 1] - _times[0]
	if span <= 0.0001:
		return Vector2.ZERO
	return (_points[_points.size() - 1] - _points[0]) / span


## Total signed angle the gesture turned through, in radians. Positive is
## clockwise on screen.
func windup() -> float:
	return _windup


## Bleed wind-up away, in radians. Called every frame while the gesture is held,
## so the reading reflects how fast the finger is circling *now* rather than
## everything it has ever done. Stop circling and the spin runs down.
func bleed(radians: float) -> void:
	_windup = move_toward(_windup, 0.0, maxf(0.0, radians))


## Cap the wind-up. Spin saturates well before a finger stops circling, and
## without a cap all that surplus has to drain away before the player sees the
## spin react at all, which reads as the wind-up having stuck.
func limit(max_radians: float) -> void:
	_windup = clampf(_windup, -max_radians, max_radians)


func is_active() -> bool:
	return _active


func _trim(now: float) -> void:
	# Keep at least two samples so a release always has something to divide by.
	while _times.size() > 2 and now - _times[0] > FLICK_WINDOW:
		_times.remove_at(0)
		_points.remove_at(0)
