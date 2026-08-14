class_name GameVolume
extends RefCounted

## How loud each bus is, and remembering it between runs.
##
## The mixer has two buses under Master, [constant MUSIC] and [constant SFX], so
## either can be turned down without the other. They live in
## `res://default_bus_layout.tres`, which is the path Godot loads a layout from on
## its own: naming it in the project settings as well would be a setting a running
## editor could quietly write back out, and this project has lost settings that way
## before.
##
## Levels are held here as a fraction from 0 to 1, because that is what a slider
## gives and what a person means by "half volume". The bus wants decibels, and the
## conversion is not linear: [method @GlobalScope.linear_to_db] of 0.5 is about
## -6 dB, which is the point of doing it this way round rather than putting a dB
## range on the slider and having its middle sound nearly as loud as its top.
##
## Zero is a mute rather than a very quiet bus. linear_to_db(0) is -inf, which does
## silence it, but muting says what is meant and survives the round trip through the
## config file without an infinity in it.
##
## Everything here is static. The levels live on the AudioServer, which is global
## and survives a scene change, so no autoload is needed to carry a setting from the
## menu into the game — and an autoload would mean editing project.godot, for the
## same reason the bus layout is not named there.

const MUSIC := &"Music"
const SFX := &"SFX"
const BUSES: Array[StringName] = [MUSIC, SFX]

## Where the choice is kept. `user://` rather than the project, because it is this
## player's preference and not something the build ships with.
const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"


## Set a bus's level, 0 for silence and 1 for as loud as it was authored. Saved
## straight away: a player who turns the music down and closes the game has said
## what they want, and asking again next time is not respecting it.
static func set_level(bus: StringName, level: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("GameVolume: no audio bus called '%s'. Is default_bus_layout.tres missing?" % bus)
		return
	level = clampf(level, 0.0, 1.0)
	AudioServer.set_bus_mute(index, is_zero_approx(level))
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
	_save()


static func get_level(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return 1.0
	if AudioServer.is_bus_mute(index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)


## Read the saved levels back onto the buses. Called by whichever screen loads
## first; calling it twice is harmless, which is what lets both the menu and the
## game ask without either having to know whether the other already did.
static func load_saved() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var level := clampf(float(config.get_value(SECTION, String(bus), 1.0)), 0.0, 1.0)
		AudioServer.set_bus_mute(index, is_zero_approx(level))
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))


static func _save() -> void:
	var config := ConfigFile.new()
	# Load first so a future setting stored beside these is not thrown away.
	config.load(SETTINGS_PATH)
	for bus in BUSES:
		config.set_value(SECTION, String(bus), get_level(bus))
	config.save(SETTINGS_PATH)
