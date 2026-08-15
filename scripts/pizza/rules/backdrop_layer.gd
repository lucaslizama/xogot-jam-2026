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
@export var colour: Color = Color(0.152941, 0.152941, 0.211765)
## One silhouette, as a scene. Leave it empty and a plain box stands in.
##
## A scene rather than a texture so a building back here can carry a shader, an
## animation or a script. [Backdrop] instances one per slot across the row, five a
## row on screen, and applies the row's scale and haze on top.
##
## Author it bottom-centred on its origin, [member width] by [member height] world
## units at the projection's pixels per unit.
@export var art: PackedScene
