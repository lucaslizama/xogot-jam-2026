class_name SettingsPage
extends Control

## The settings page: one slider per audio bus.
##
## Built like the credits page, and for the same reasons. The street and its scrim
## are drawn once by the main menu and left up while the pages come and go, so this
## page draws no background of its own; [code]EditorPreview[/code] is a second copy
## of that background for the editor only, freed the moment the game runs, so that
## opening this scene on its own shows it against what it will actually sit on.
##
## The sliders are [VolumeSlider], not [HSlider], because this is a touch game and
## the built-in grabber is a few pixels wide. They deal in a fraction from 0 to 1,
## which is what [GameVolume] wants; the label beside each one turns that into the
## percentage a person reads.

signal back_pressed

## What sits beside each slider. %d is the level as a percentage.
@export var readout_format: String = "%d%%"

@onready var _back: Button = %BackButton
@onready var _editor_preview: Control = $EditorPreview
@onready var _music_slider: VolumeSlider = %MusicSlider
@onready var _sfx_slider: VolumeSlider = %SoundSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SoundValue


func _ready() -> void:
	_editor_preview.queue_free()
	_back.pressed.connect(func() -> void: back_pressed.emit())
	_bind(_music_slider, _music_value, GameVolume.MUSIC)
	_bind(_sfx_slider, _sfx_value, GameVolume.SFX)


## Show what the bus is set to now, then follow the finger. The slider is set
## before its signal is connected, so putting it where the setting already is does
## not count as the player changing it and write the file back for nothing.
func _bind(slider: VolumeSlider, value: Label, bus: StringName) -> void:
	slider.value = GameVolume.get_level(bus)
	_show_level(value, slider.value)
	slider.value_changed.connect(func(level: float) -> void:
		GameVolume.set_level(bus, level)
		_show_level(value, level))


func _show_level(value: Label, level: float) -> void:
	value.text = readout_format % roundi(level * 100.0)
