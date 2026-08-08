class_name Dish
extends Resource

## One plate on the order. Every ingredient completes its own journey, then the
## dish is cooked once from whatever arrived.

## Name shown on the HUD, e.g. "Hamburger".
@export var display_name: String = "Dish"

## Harvested and transported in turn, in this order, before the dish is cooked.
@export var ingredients: Array[Ingredient] = []

## Played once, after every ingredient has arrived.
@export var cook_game: MinigameInfo
