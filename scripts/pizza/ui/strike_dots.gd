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


## The y below which nothing else may sit, in this layer's own coordinates.
##
## Measured rather than read off the scene: the row is a container, so if the dots
## are made bigger or a sixth is added it grows past the height authored for it,
## and anything placed under it by a number typed in by hand ends up underneath the
## dots instead of below them. Whoever needs to clear this row asks it how tall it
## actually is.
func bottom_edge() -> float:
	var height := maxf(_dots.size.y, _dots.get_combined_minimum_size().y)
	return _dots.position.y + height


func show_strikes(left: int) -> void:
	var slots := _dots.get_children()
	for i in slots.size():
		var dot := slots[i] as StrikeDot
		if dot == null:
			continue
		# Spent from the right, so the ones you have left sit together.
		dot.show_spent(i >= left)
