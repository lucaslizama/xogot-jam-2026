class_name StrikeDots
extends Control

## The only readout on the screen. A dot for every miss still allowed; it turns
## into a cross when one is spent.
##
## The dots are authored in the scene, not spawned here, so their art, size and
## spacing belong to whoever is looking at the screen. That also makes the scene
## the authority on how many strikes a level can ask for.
##
## The scene carries more dots than any street asks for, as headroom, so a street
## has to say how many it dealt before the row means anything: see
## [method show_granted]. The spares are hidden rather than drawn as spent, the same
## way the pizza stack hides the boxes a level is not carrying.
##
## Each dot draws itself; see StrikeDot for why they are shapes and not glyphs.

@onready var _dots: Control = %Dots


## How many strikes the scene can actually draw. LevelState clamps to this.
func slot_count() -> int:
	return _dots.get_child_count()


## How many chances this street dealt. Slots past it are hidden, because they were
## never dealt and a cross means a miss the player has had.
##
## Without this the row read as though the street had already been half lost before
## the first throw: the scene carries five dots as headroom, no street asks for more
## than four, and every spare one sat there as a cross. Which strikes are spent is a
## question about this street, so the answer arrives when a street begins rather
## than being read off the scene once.
func show_granted(granted: int) -> void:
	var dealt := clampi(granted, 0, slot_count())
	var slots := _dots.get_children()
	for i in slots.size():
		var dot := slots[i] as CanvasItem
		if dot != null:
			dot.visible = i < dealt


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
