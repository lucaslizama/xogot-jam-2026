class_name TiltInput
extends Node

## Device tilt as a -1..1 vector, with a keyboard fallback for desktop.
##
## Registered as the "Tilt" autoload so minigames running inside a SubViewport
## can reach it without a node path. Without the fallback every tilt minigame
## would only be testable on the iPad, which is far too slow a loop for a jam.
##
## The gravity-axis mapping below is a guess until it has been checked on real
## hardware — it is exported precisely so it can be corrected in the editor
## rather than in code.

enum Axis { X, Y, Z }

@export_group("Device")
## Which gravity axis drives left/right, and which drives up/down. Device axes
## differ by platform and orientation; fix these here after a hardware test.
@export var horizontal_axis: Axis = Axis.X
@export var vertical_axis: Axis = Axis.Z
@export var invert_horizontal: bool = false
@export var invert_vertical: bool = false
## Gravity component (m/s^2) that reads as full deflection. Lower is twitchier.
@export_range(1.0, 9.8, 0.1) var full_tilt_gravity: float = 4.5
## Tilt below this reads as zero, so a hand held still does not drift.
@export_range(0.0, 0.5, 0.01) var deadzone: float = 0.08
## Per-frame smoothing. 0.0 is raw and jittery, 0.9 is heavy and laggy.
@export_range(0.0, 0.95, 0.05) var smoothing: float = 0.4

@export_group("Desktop fallback")
## Used whenever the device reports no gravity at all — i.e. in the editor.
@export var fallback_left: Key = KEY_LEFT
@export var fallback_right: Key = KEY_RIGHT
@export var fallback_up: Key = KEY_UP
@export var fallback_down: Key = KEY_DOWN

var _tilt: Vector2 = Vector2.ZERO
var _on_fallback: bool = true


func _process(delta: float) -> void:
	var raw := _read_raw()
	# Frame-rate independent smoothing: `smoothing` is the fraction of the old
	# value still present after 1/60s, whatever the real frame time.
	var blend: float = 1.0 - pow(smoothing, delta * 60.0) if smoothing > 0.0 else 1.0
	_tilt = _tilt.lerp(raw, clampf(blend, 0.0, 1.0))


## Current tilt, -1..1 on each axis. +x is right across the screen, +y is down.
func get_tilt() -> Vector2:
	return _tilt


## True when no accelerometer was found and the keyboard is driving this.
## Show it somewhere during development so a dead sensor is not mistaken for a
## steady hand.
func is_using_fallback() -> bool:
	return _on_fallback


func _read_raw() -> Vector2:
	var gravity := Input.get_gravity()
	_on_fallback = gravity.is_zero_approx()
	if _on_fallback:
		return _read_keys()

	var raw := Vector2(
		_component(gravity, horizontal_axis) * (-1.0 if invert_horizontal else 1.0),
		_component(gravity, vertical_axis) * (-1.0 if invert_vertical else 1.0),
	) / full_tilt_gravity
	return _deadzoned(raw.limit_length(1.0))


func _read_keys() -> Vector2:
	var raw := Vector2(
		float(Input.is_physical_key_pressed(fallback_right)) - float(Input.is_physical_key_pressed(fallback_left)),
		float(Input.is_physical_key_pressed(fallback_down)) - float(Input.is_physical_key_pressed(fallback_up)),
	)
	return raw.limit_length(1.0)


func _deadzoned(raw: Vector2) -> Vector2:
	if raw.length() <= deadzone:
		return Vector2.ZERO
	# Rescale past the deadzone so the first responsive input is not a jump.
	return raw.normalized() * ((raw.length() - deadzone) / (1.0 - deadzone))


func _component(vector: Vector3, axis: Axis) -> float:
	match axis:
		Axis.X:
			return vector.x
		Axis.Y:
			return vector.y
		_:
			return vector.z
