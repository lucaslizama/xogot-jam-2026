class_name Credits
extends Control

## The credits page: who made the game, and for what.
##
## It owns nothing but its Back button. Names and roles are authored in the scene as
## plain labels, so a credit is added by duplicating one and typing into it.
##
## The menu draws the street and its scrim once and leaves them up while pages come
## and go, so this page has no background of its own and opened alone showed an
## empty canvas. [code]EditorPreview[/code] is a second copy of that background for
## the canvas only: this is not a tool script, so it never runs in the editor and
## the preview stays; at run time the first thing here is to free it.

signal back_pressed

@onready var _back: Button = %BackButton
@onready var _editor_preview: Control = $EditorPreview


func _ready() -> void:
	_editor_preview.queue_free()
	_back.pressed.connect(func() -> void: back_pressed.emit())
