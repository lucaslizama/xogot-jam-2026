class_name GameMusic
extends AudioStreamPlayer

## The music bed, under everything else.
##
## Plays on the Music bus rather than Master, which is what lets the menu silence
## the music and leave the effects alone. The bus is named in the scene; see
## [GameVolume] for the pair of them and where the choice is kept.
##
## Two ways to give it a track, and they are not the same thing.
##
## [member track] is the real slot: a stream in the repository, licensed, credited
## in the credits page, and part of the build.
##
## [member audition_path] is for trying a track out before any of that is true. It
## is a path rather than a resource reference on purpose: a scene that references a
## missing file fails to load, so a scene pointing at a folder that only exists on
## one machine would break the build for everybody else and in CI. A path that
## resolves to nothing is simply ignored, and the game plays silent.
##
## The folder it points into is ignored by git, which is what keeps an audition out
## of a release: the published build is exported from a clean checkout, so a file
## that was never committed cannot be in it. Auditioning is a local act by
## construction rather than by anybody remembering.

## The track that ships. Takes precedence over any audition. This is what the menu
## and the settings page play, and what a level falls back to when it has no track
## of its own.
@export var track: AudioStream

## A track per level, in the same order as [member PizzaGame.levels]. A level past
## the end of this array, or a slot left empty, keeps playing [member track] — which
## is why speeding the music up is a property of the level rather than of a file:
## three streets can sound like one tune getting hurried without three recordings
## existing.
@export var level_tracks: Array[AudioStream] = []

@export_group("Auditioning")
## Tried when [member track] is empty. Drop a file at this path to hear it under
## the game; delete it and the game is quiet again.
##
## A level looks for its own file beside this one, numbered from 1: with the default
## below, street two plays `music_2.mp3` if that file exists and this one otherwise.
@export_file("*.ogg", "*.mp3", "*.wav") var audition_path: String = "res://sounds/audition/music.mp3"
## Said in the output when an audition is what is playing, so a recording or a
## screen share cannot be mistaken for the finished thing.
@export var announce_auditions: bool = true

@export_group("Feel")
## Music that starts at full volume announces itself. A second or two of fade lets
## it arrive under the game instead of in front of it.
@export_range(0.0, 6.0, 0.1) var fade_in: float = 1.6
## Where the fade ends up. Kept apart from [member AudioStreamPlayer.volume_db] so
## the fade has a target to climb to and the scene still owns the level.
@export_range(-60.0, 6.0, 0.5) var level_db: float = -16.0
## How long a change of street takes to swap tracks. The old one is faded out and
## the new one faded in over this, so a street beginning is a turn in the music
## rather than a cut.
@export_range(0.0, 4.0, 0.1) var crossfade: float = 0.9

var _tween: Tween
## Said once a run, not once a scene. The tests build the game two dozen times over
## and the notice buried their output.
static var _announced: bool = false


func _ready() -> void:
	# Before a note is played, so a player who turned the music down last time does
	# not hear the first second of it at full level while the setting is read.
	GameVolume.load_saved()
	var first := stream if stream != null else _pick_track()
	if first == null:
		return
	_begin(first, fade_in)


## Play what this level should sound like: its own track if it has one, and at the
## speed the level asks for. Called by [PizzaGame] as each street begins.
##
## [param speed] multiplies both tempo and pitch, because that is what an audio
## stream does when it is played faster. Small numbers, then: the levels ask for a
## few per cent, which reads as the evening getting busier. Past about 1.2 it stops
## sounding like a band playing faster and starts sounding like a cassette.
func play_for_level(index: int, speed: float = 1.0) -> void:
	pitch_scale = maxf(speed, 0.01)
	var wanted := _track_for_level(index)
	if wanted == null or wanted == stream:
		# Same tune, only quicker. Nothing to fade: swapping the stream would restart
		# it from the top and make the change a jolt rather than a lift.
		if not playing and wanted != null:
			_begin(wanted, fade_in)
		return
	_begin(wanted, crossfade)


## The shipping track if there is one, otherwise whatever is sitting in the
## audition folder, otherwise nothing.
func _pick_track() -> AudioStream:
	if track != null:
		return track
	return _audition(audition_path)


## What level [param index] plays: its own slot if the array has one and it is
## filled, otherwise its own audition file if one has been dropped in beside the
## default, otherwise whatever the menu is playing.
func _track_for_level(index: int) -> AudioStream:
	if index >= 0 and index < level_tracks.size() and level_tracks[index] != null:
		return level_tracks[index]
	# A numbered audition wins over the shipping track here, unlike [member track]
	# against [member audition_path]: the slot for this street is empty, and a file
	# dropped in to fill it is the only thing saying what it should sound like.
	var beside := _audition(_numbered(audition_path, index + 1))
	if beside != null:
		return beside
	return _pick_track()


## `music.mp3` and street two gives `music_2.mp3`. A path with no extension is left
## alone rather than guessed at.
func _numbered(path: String, number: int) -> String:
	var extension := path.get_extension()
	if extension.is_empty():
		return path
	return "%s_%d.%s" % [path.get_basename(), number, extension]


func _audition(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var found := load(path) as AudioStream
	if found != null and announce_auditions and not _announced:
		_announced = true
		print("GameMusic: auditioning %s. Not committed, so not in any build." % path)
	return found


## Put a stream on and bring it up over [param seconds]. Whatever was playing is
## taken down over the same time first, so the two cross rather than one cutting the
## other off. A tween already running is killed: two fades arguing over one volume
## leaves it wherever the loser stopped.
func _begin(next: AudioStream, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not playing or seconds <= 0.0:
		stream = next
		_make_it_loop()
		volume_db = level_db if seconds <= 0.0 else -60.0
		play()
		if seconds > 0.0:
			_tween = create_tween()
			_tween.tween_property(self, "volume_db", level_db, seconds)
		return
	var half := seconds * 0.5
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", -60.0, half)
	_tween.tween_callback(func() -> void:
		stream = next
		_make_it_loop()
		play())
	_tween.tween_property(self, "volume_db", level_db, half)


## Set on whichever stream types have the property. Done by name rather than by
## checking each class, so a format nobody has used yet is handled too.
func _make_it_loop() -> void:
	if &"loop" in stream:
		stream.set(&"loop", true)
