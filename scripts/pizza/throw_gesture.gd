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
## Movements shorter than this are noise and are not counted as turning.
const MIN_SEGMENT: float = 4.0

var _points: Array[Vector2] = []
var _times: Array[float] = []
var _windup: float = 0.0
var _last_direction: Vector2 = Vector2.ZERO
var _active: bool = false


func begin(position: Vector2, time: float) -> void:
	_points = [position]
	_times = [time]
	_windup = 0.0
	_last_direction = Vector2.ZERO
	_active = true


func update(position: Vector2, time: float) -> void:
	if not _active:
		return

	var previous: Vector2 = _points[_points.size() - 1]
	var segment := position - previous
	if segment.length() >= MIN_SEGMENT:
		var direction := segment.normalized()
		if _last_direction != Vector2.ZERO:
			# Signed angle between one step and the next. Summed over the whole
			# gesture this is its total turning: zero for a straight drag, one
			# full turn per circle of the finger.
			_windup += _last_direction.angle_to(direction)
		_last_direction = direction

	_points.append(position)
	_times.append(time)
	_trim(time)


## Finish the drag. Returns the flick velocity in pixels per second.
func release(position: Vector2, time: float) -> Vector2:
	update(position, time)
	_active = false
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


func is_active() -> bool:
	return _active


func _trim(now: float) -> void:
	# Keep at least two samples so a release always has something to divide by.
	while _times.size() > 2 and now - _times[0] > FLICK_WINDOW:
		_times.remove_at(0)
		_points.remove_at(0)
