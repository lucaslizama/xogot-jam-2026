class_name HowToPlay
extends Control

## The how-to-play page: the throw explained in pictures, because it is a gesture
## and a gesture is quicker shown than described.
##
## The page owns nothing but its Back button. Every step is authored in the scene
## as a [HowToStep], so a step is added by duplicating one and its picture is
## replaced by dropping a file into the step's art slot. Nothing here has to
## change for either.
##
## The Back button sits outside the [ScrollContainer], pinned above it, and that
## is the reason this note exists rather than a comment in the scene, where it
## would be deleted the next time the file is saved.
##
## It used to be the last thing in the scrolling column, so leaving the page meant
## reading it first, or scrolling past six steps to find the way out. The way out
## is not a step. Every step added pushed it further away, which is a page that
## gets harder to leave the more it has to say.
##
## Pinning it costs the height of one button at the top of the page: the scroll
## starts below it and they cannot overlap at any scroll position, which a button
## floating over the content would eventually do. Same size as every other button
## in the game, so the drawn box keeps the proportions the art was made for.

signal back_pressed

@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.pressed.connect(func() -> void: back_pressed.emit())
