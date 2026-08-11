class_name GameMusic
extends AudioStreamPlayer

## The music bed, under everything else.
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

## The track that ships. Takes precedence over any audition.
@export var track: AudioStream

@export_group("Auditioning")
## Tried when [member track] is empty. Drop a file at this path to hear it under
## the game; delete it and the game is quiet again.
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

var _tween: Tween
## Said once a run, not once a scene. The tests build the game two dozen times over
## and the notice buried their output.
static var _announced: bool = false


func _ready() -> void:
	if stream == null:
		stream = _pick_track()
	if stream == null:
		return
	# The importer defaults every music file to playing once. A bed that stops after
	# four minutes and never comes back is worse than no bed at all.
	_make_it_loop()
	if fade_in > 0.0:
		volume_db = -60.0
		_tween = create_tween()
		_tween.tween_property(self, "volume_db", level_db, fade_in)
	else:
		volume_db = level_db
	play()


## The shipping track if there is one, otherwise whatever is sitting in the
## audition folder, otherwise nothing.
func _pick_track() -> AudioStream:
	if track != null:
		return track
	if audition_path.is_empty() or not ResourceLoader.exists(audition_path):
		return null
	var found := load(audition_path) as AudioStream
	if found != null and announce_auditions and not _announced:
		_announced = true
		print("GameMusic: auditioning %s. Not committed, so not in any build." % audition_path)
	return found


## Set on whichever stream types have the property. Done by name rather than by
## checking each class, so a format nobody has used yet is handled too.
func _make_it_loop() -> void:
	if &"loop" in stream:
		stream.set(&"loop", true)
