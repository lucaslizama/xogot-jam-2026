class_name StrikeDots
extends Control

## The only readout on the screen. A dot for every miss still allowed; it turns
## into a cross when one is spent.
##
## The dots are authored in the scene, not spawned here, so their art, size and
## spacing belong to whoever is looking at the screen. That also makes the scene
## the authority on how many strikes a level can ask for.
##
## Each dot draws itself; see StrikeDot for why they are shapes and not glyphs.

@onready var _dots: Control = %Dots


## How many strikes the scene can actually draw. LevelState clamps to this.
func slot_count() -> int:
	return _dots.get_child_count()


func show_strikes(left: int) -> void:
	var slots := _dots.get_children()
	for i in slots.size():
		var dot := slots[i] as StrikeDot
		if dot == null:
			continue
		# Spent from the right, so the ones you have left sit together.
		dot.show_spent(i >= left)
