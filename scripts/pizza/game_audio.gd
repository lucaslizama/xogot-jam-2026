class_name GameAudio
extends Node

## Plays the sound bank.
##
## Holds a handful of players and uses them in turn, so one sound never cuts
## another off. A throw, its landing and a strike can all be ringing at once,
## which in a game this quick they regularly are.

@export var bank: SoundBank
## How many sounds may ring at once. Beyond this the oldest is taken over.
@export_range(1, 16) var voices: int = 8

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in voices:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		add_child(player)
		_players.append(player)


## Play one of the clips filed under `event`. Naming an entry that does not
## exist is a mistake worth hearing about; an entry that is simply empty is not.
func play(event: StringName) -> void:
	if bank == null or _players.is_empty():
		return
	if not (event in bank):
		push_warning("GameAudio: the sound bank has no entry called '%s'." % event)
		return

	var clips: Array = bank.get(event)
	if clips.is_empty():
		return

	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = clips[_rng.randi_range(0, clips.size() - 1)]
	player.volume_db = bank.volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-bank.pitch_wander, bank.pitch_wander)
	player.play()
