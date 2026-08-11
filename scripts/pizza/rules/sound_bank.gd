class_name SoundBank
extends Resource

## Every sound the game makes, gathered in one place.
##
## Each entry is a list rather than a single clip. Impacts happen constantly in
## this game, and the same recording played twice in a row is the fastest way to
## make a sound feel cheap; picking from a handful and nudging the pitch each
## time costs nothing and hides that entirely.
##
## An empty list is silence, not an error, so a sound can be left out while the
## rest of the game keeps its voice.

@export_group("Throwing")
## Taking a pizza off the stack.
@export var pick_up: Array[AudioStream] = []
## The moment it leaves your hand.
@export var throw: Array[AudioStream] = []

@export_group("Landing")
## Landing inside a drop point.
@export var delivered: Array[AudioStream] = []
## Hitting anything else.
@export var missed: Array[AudioStream] = []

@export_group("The round")
## A dot turning into a cross.
@export var strike: Array[AudioStream] = []
@export var round_won: Array[AudioStream] = []
@export var round_lost: Array[AudioStream] = []

@export_group("Feel")
@export_range(-40.0, 12.0, 0.5) var volume_db: float = -6.0
## How far the pitch wanders each time, up or down. A little stops repeats
## sounding identical; much starts sounding broken.
@export_range(0.0, 0.5, 0.01) var pitch_wander: float = 0.08
