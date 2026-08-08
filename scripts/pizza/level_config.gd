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

@export_group("The street")
## How fast the world slides past, in world units per second.
@export_range(0.0, 80.0, 0.5) var street_speed: float = 13.0
## Gap between one house and the next, along the street.
@export_range(1.0, 60.0, 0.5) var gap_min: float = 11.0
@export_range(1.0, 60.0, 0.5) var gap_max: float = 19.0
## How far back from the road houses sit. Further is a harder throw.
@export_range(1.0, 120.0, 0.5) var distance_min: float = 16.0
@export_range(1.0, 120.0, 0.5) var distance_max: float = 30.0
## How generous a drop point is.
@export_range(0.5, 20.0, 0.1) var drop_radius: float = 3.2
## Fraction of houses that actually want a pizza. The rest are scenery, and
## keep the street from reading as a shooting gallery.
@export_range(0.0, 1.0, 0.05) var waiting_chance: float = 0.62

@export_group("Streaming")
## Houses are kept stocked out to this far ahead along the street.
@export_range(20.0, 400.0, 5.0) var spawn_ahead: float = 90.0
## And dropped once they fall this far behind the rider.
@export_range(-200.0, 0.0, 1.0) var despawn_behind: float = -40.0
