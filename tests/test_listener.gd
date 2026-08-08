extends Node
var seen: Array[Vector2] = []
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		seen.append(event.position)
