class_name Credits
extends Control

## The credits page: who made the game, and for what.
##
## The page owns nothing but its Back button. Every name and role is authored in
## the scene as a plain label, so a credit is added by duplicating one and typing
## into it. Nothing here has to change for that.
##
## In the game the street and its scrim are drawn once by the main menu and left
## up while the pages come and go, so this page draws no background of its own.
## Opened on its own that left an empty canvas, with no way to see the credits
## against what they will actually sit on. [code]EditorPreview[/code] is a second
## copy of that background for the editor only: this script is not a [code]@tool[/code]
## script, so it never runs there and the preview stays visible, and at run time
## the first thing done here is to free it. Nothing of it survives into the game.

signal back_pressed

@onready var _back: Button = %BackButton
@onready var _editor_preview: Control = $EditorPreview


func _ready() -> void:
	_editor_preview.queue_free()
	_back.pressed.connect(func() -> void: back_pressed.emit())
