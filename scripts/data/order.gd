class_name Order
extends Resource

## What the customer asked for: the whole run, start to finish.

## Name shown when the order comes in, e.g. "Burger and fries".
@export var display_name: String = "Order"

## One or two dishes. Difficulty ramps with each dish completed.
@export var dishes: Array[Dish] = []
