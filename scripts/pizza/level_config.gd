class_name LevelConfig
extends Resource

## One level's worth of tuning. The three knobs that actually change how a level
## feels are the strike budget, how many pizzas you get against how many houses
## are waiting, and how fast the street moves. Everything else is shape.

@export_group("The round")
## Pizzas on the bike. This is also the level's length: it ends when they run out.
@export_range(1, 40) var pizzas_in_stack: int = 10
## Misses allowed before the round is lost. Clamped to the dots the scene has.
@export_range(1, 8) var strikes: int = 3

## The hour this street is delivered in. The game crosses to it from whatever
## the last street was, so the sun comes up over the course of a run.
@export var time_of_day: TimeOfDay

@export_group("The street")
## How fast the world slides past, in world units per second.
@export_range(0.0, 80.0, 0.5) var street_speed: float = 33.0
## Gap between one house and the next, along the street.
@export_range(1.0, 60.0, 0.5) var gap_min: float = 28.0
@export_range(1.0, 60.0, 0.5) var gap_max: float = 49.0
## How far back from the road houses sit. Further is a harder throw.
@export_range(1.0, 120.0, 0.5) var distance_min: float = 55.0
@export_range(1.0, 120.0, 0.5) var distance_max: float = 82.0
## How generous a drop point is.
@export_range(0.5, 20.0, 0.1) var drop_radius: float = 12.5
## Fraction of houses that actually want a pizza. The rest are scenery, and
## keep the street from reading as a shooting gallery.
@export_range(0.0, 1.0, 0.05) var waiting_chance: float = 0.62

@export_group("Streaming")
## Houses are kept stocked out to this far ahead along the street.
@export_range(20.0, 800.0, 5.0) var spawn_ahead: float = 230.0
## And dropped once they fall this far behind the rider.
@export_range(-400.0, 0.0, 1.0) var despawn_behind: float = -100.0
