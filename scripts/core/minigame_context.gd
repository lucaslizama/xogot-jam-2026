class_name MinigameContext
extends RefCounted

## What the run hands a minigame when it starts. Read-only from the minigame's
## side — it describes the situation, it is not a channel back to the run.

## Seconds this minigame gets, already scaled by the run's difficulty.
var duration: float = 5.0

## 1.0 on the first dish, rising as dishes complete. Use it to scale spawn
## rates or speeds; the clock is already handled for you.
var difficulty: float = 1.0

## The ingredient this minigame is about, e.g. "Potatoes". Empty for cooking
## steps, which are about the dish rather than one ingredient.
var ingredient_name: String = ""

## The dish being worked on, e.g. "Hamburger".
var dish_name: String = ""

## True when the minigame is running in a rotated landscape viewport.
var is_landscape: bool = false
