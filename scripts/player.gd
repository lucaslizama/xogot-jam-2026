extends CharacterBody2D

## Speed the player moves toward the touch target, in pixels/second.
@export var speed: float = 900.0
## Stop moving once within this distance of the target.
@export var arrive_threshold: float = 8.0

var _target: Vector2 = position
var _active: bool = false


func _ready() -> void:
	_target = position


func _unhandled_input(event: InputEvent) -> void:
	# Touch: begin/aim on press, release stops
	if event is InputEventScreenTouch:
		if event.pressed:
			_active = true
			_target = event.position
		else:
			_active = false
	elif event is InputEventScreenDrag:
		_target = event.position


func _physics_process(delta: float) -> void:
	if not _active:
		velocity = Vector2.ZERO
		return

	var to_target := _target - global_position
	var distance := to_target.length()
	if distance <= arrive_threshold:
		velocity = Vector2.ZERO
		return

	# Never travel further in one tick than the distance left, or the body overshoots the
	# target and oscillates around it instead of settling. At 60 Hz a speed of 1800 moves
	# 30 px per tick, which alone can never land inside an 8 px arrive_threshold.
	var step_speed := minf(speed, distance / delta)
	velocity = to_target / distance * step_speed
	move_and_slide()
