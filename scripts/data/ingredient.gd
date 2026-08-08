class_name Ingredient
extends Resource

## One ingredient and the authored route it takes to reach the restaurant.
##
## The route is deliberately hand-written rather than drawn from a pool, so
## pacing is designed: a potato can take two legs while beef takes one.

## Name shown on the handoff card, e.g. "Potatoes".
@export var display_name: String = "Ingredient"

## Played first, once. Where the ingredient comes out of the ground or the herd.
@export var harvest_game: MinigameInfo

## Played in order after harvesting — one entry per leg of this ingredient's
## journey. May be empty for something that starts at the restaurant.
@export var transport_games: Array[MinigameInfo] = []


## Every minigame this ingredient contributes to the run, in play order.
func journey() -> Array[MinigameInfo]:
	var games: Array[MinigameInfo] = []
	if harvest_game != null:
		games.append(harvest_game)
	for leg in transport_games:
		if leg != null:
			games.append(leg)
	return games
