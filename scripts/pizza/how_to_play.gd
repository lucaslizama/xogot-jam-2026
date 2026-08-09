class_name HowToPlay
extends Control

## The how-to-play page: the throw explained in pictures, because it is a gesture
## and a gesture is quicker shown than described.
##
## The page owns nothing but its Back button. Every step is authored in the scene
## as a [HowToStep], so a step is added by duplicating one and its picture is
## replaced by dropping a file into the step's art slot. Nothing here has to
## change for either.

signal back_pressed

@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.pressed.connect(func() -> void: back_pressed.emit())
