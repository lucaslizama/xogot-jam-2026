class_name StrikeDots
extends Control

## The only readout on the screen. A dot for every miss still allowed; it turns
## into a cross when one is spent.
##
## The dots are authored in the scene, not spawned here, so their art, size and
## spacing belong to whoever is looking at the screen. That also makes the scene
## the authority on how many strikes a level can ask for.

@export var clean_glyph: String = "●"
@export var spent_glyph: String = "✕"
@export var clean_colour: Color = Color(1.0, 0.98, 0.9)
@export var spent_colour: Color = Color(0.85, 0.27, 0.33)

@onready var _dots: Control = %Dots


## How many strikes the scene can actually draw. LevelState clamps to this.
func slot_count() -> int:
	return _dots.get_child_count()


func show_strikes(left: int) -> void:
	var slots := _dots.get_children()
	for i in slots.size():
		var dot := slots[i] as Label
		if dot == null:
			continue
		# Dots are spent from the right, so the ones you have left sit together.
		var clean := i < left
		dot.text = clean_glyph if clean else spent_glyph
		dot.add_theme_color_override("font_color", clean_colour if clean else spent_colour)
