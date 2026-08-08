class_name Hud
extends Control

## Hearts and the current dish. Lives on the persistent layer, above whatever
## minigame is playing.
##
## The heart slots are authored in hud.tscn rather than spawned here, so their
## art, spacing and count are a designer's business. That makes the scene the
## authority on how many hearts can exist — see [method slot_count].

## Applied to hearts already spent. Dimming rather than hiding keeps the row
## from reflowing every time one is lost.
@export var spent_heart_modulate: Color = Color(1.0, 1.0, 1.0, 0.15)
## Applied to hearts still in hand.
@export var full_heart_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)

@onready var _hearts: Control = %Hearts
@onready var _dish_label: Label = %DishLabel


## How many hearts the authored scene can actually draw. RunState clamps to it.
func slot_count() -> int:
	return _hearts.get_child_count()


func show_hearts(hearts: int) -> void:
	var slots := _hearts.get_children()
	for i in slots.size():
		var slot := slots[i] as CanvasItem
		if slot == null:
			continue
		slot.modulate = full_heart_modulate if i < hearts else spent_heart_modulate


func set_dish_text(text: String) -> void:
	_dish_label.text = text
