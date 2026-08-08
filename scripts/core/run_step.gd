class_name RunStep
extends RefCounted

## One entry in the flattened run: which minigame, and what it is about.
##
## Built once by RunDirector from the Order, so the sequence can be inspected
## and logged as a whole rather than discovered as it plays.

var info: MinigameInfo
var dish: Dish
## Null for cooking steps, which are about the dish rather than one ingredient.
var ingredient: Ingredient
## Which dish this belongs to, counting from 0. Drives the difficulty ramp.
var dish_index: int = 0
## True on the last step of a dish — clearing it means the plate is served.
var is_final_step_of_dish: bool = false


func _init(p_info: MinigameInfo, p_dish: Dish, p_ingredient: Ingredient, p_dish_index: int) -> void:
	info = p_info
	dish = p_dish
	ingredient = p_ingredient
	dish_index = p_dish_index


func describe() -> String:
	var about := ingredient.display_name if ingredient != null else dish.display_name
	return "%s (%s)" % [info.display_name, about]
