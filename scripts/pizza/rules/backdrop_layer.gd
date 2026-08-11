class_name BackdropLayer
extends Resource

## One row of silhouettes behind the street. Parallax falls out of the
## projection for free: a row further away is drawn smaller and slides past more
## slowly, without anything having to be told to move at a different rate.

## How far back this row sits. Larger is slower and smaller.
@export_range(1.0, 2000.0, 1.0) var distance: float = 120.0
## Height of the silhouettes, in world units.
@export_range(1.0, 200.0, 0.5) var height: float = 22.0
## Width of one silhouette and the gap to the next, in world units.
@export_range(1.0, 200.0, 0.5) var width: float = 14.0
@export_range(0.0, 200.0, 0.5) var gap: float = 6.0
## How much the heights vary from one silhouette to the next, 0 for a flat row.
@export_range(0.0, 1.0, 0.05) var height_variation: float = 0.35
@export var colour: Color = Color(0.16, 0.14, 0.24)
## One silhouette, drawn bottom-centred at the width and height above. Leave
## empty and a plain rectangle stands in.
@export var art: Texture2D
