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


func _physics_process(_delta: float) -> void:
	if not _active:
		velocity = Vector2.ZERO
		return

	var to_target := _target - global_position
	if to_target.length() <= arrive_threshold:
		velocity = Vector2.ZERO
	else:
		velocity = to_target.normalized() * speed
	move_and_slide()
