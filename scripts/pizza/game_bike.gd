class_name GameBike
extends AudioStreamPlayer

## The scooter under the rider, running for as long as a street is.
##
## It has a bus of its own, Bike, and that bus sends to SFX rather than to Master.
## Both halves of that matter. Going through SFX means the effects slider a player
## already has still turns the engine down with everything else, so no third slider
## has to appear on the settings page. Having its own bus means the engine can be
## balanced against the throws and the impacts without touching any of them, which is
## the one thing a continuous sound needs that a one-shot does not: it is under
## everything, all the time, and a decibel too loud is a decibel a player hears for
## the whole run. That balance lives on the bus in default_bus_layout.tres, not here.
##
## Deliberately not saved with the player's own levels. [GameVolume] restores only the
## buses it lists, and Bike is not one of them, so the authored figure is what every
## run starts from. Listing it there would freeze whatever the bus happened to be at
## into the player's config file the first time they moved any slider, and after that
## changing the authored level would do nothing for them.
##
## Silent until a clip is dropped in, and a missing one is not an error: the game
## sounds exactly as it did before this existed, the same way every empty art slot
## draws a placeholder instead of failing.
##
## Worth reading before choosing that clip. Phone speakers give up somewhere around
## 400 Hz, and an engine is the worst case there is for it: a car rumble sits almost
## entirely below that line and arrives as nothing at all. A small scooter buzzes
## higher, which is the reason to look for a moped rather than a car, and the reason
## not to reach for the pitch-up trick that rescued the impacts, because an engine
## pitched far enough up to clear the line stops being an engine. sounds/CREDITS.md
## records the measurements taken for every other sound here, and how to take them.

## The engine loop that ships: a stream in the repository, licensed, and credited.
## Looped by this node whether or not the file says to, so a clip that was cut as a
## one-shot still runs continuously.
@export var engine: AudioStream

@export_group("Auditioning")
## Tried when [member engine] is empty, so a candidate can be heard under the game
## before anybody decides whether it is the one.
##
## A path rather than a resource reference, and pointing into a folder git ignores,
## for the reasons [GameMusic] gives at greater length: a scene referencing a file
## that exists on one machine breaks the build everywhere else, whereas a path that
## resolves to nothing is simply ignored. An audition therefore cannot reach a
## release, because the published build is exported from a clean checkout.
@export_file("*.ogg", "*.mp3", "*.wav") var audition_path: String = "res://sounds/audition/bike.ogg"
## Said in the output when an audition is what is running, so a screen share cannot
## mistake it for the finished thing.
@export var announce_auditions: bool = true

@export_group("Feel")
## Where the engine settles. Kept apart from [member AudioStreamPlayer.volume_db] so
## a fade has somewhere to climb to and this stays the authored level. The balance
## against other effects belongs on the bus; this is the clip's own level.
@export_range(-60.0, 6.0, 0.5) var level_db: float = -4.0
## An engine that arrives at full level announces itself. A moment of fade lets it
## start as though it had been running all along.
@export_range(0.0, 4.0, 0.1) var fade_in: float = 0.8
## And winding down when the street is over, rather than cutting out under the card.
@export_range(0.0, 4.0, 0.1) var fade_out: float = 0.6

## How much of the street's speed reaches the pitch, 0 for none and 1 for all of it.
##
## The streets already ask the music to play faster as the evening gets on. Feeding
## the same figure here makes the scooter strain along with it, which is free: no
## second recording, no code deciding anything. Left at nothing because it changes
## how the game sounds and that is a decision to make with the clip in, by ear;
## raising it to 1 is the whole change.
@export_range(0.0, 1.0, 0.05) var street_speed_gain: float = 0.0

var _tween: Tween
static var _announced: bool = false


## Start the engine for a street, at the speed that street runs at. Called by
## [PizzaGame] as each one begins; calling it again while it is already running only
## changes the pitch, because restarting the stream would be an audible hiccup in a
## sound whose whole job is to be continuous.
func ride_at(speed: float) -> void:
	pitch_scale = maxf(lerpf(1.0, speed, street_speed_gain), 0.01)
	var clip := _pick_engine()
	if clip == null:
		return
	if playing and stream == clip:
		return
	_kill_tween()
	stream = clip
	_make_it_loop()
	volume_db = -60.0 if fade_in > 0.0 else level_db
	play()
	if fade_in > 0.0:
		_tween = create_tween()
		_tween.tween_property(self, "volume_db", level_db, fade_in)


## Wind down and stop. The street is over and the result card is coming up; an engine
## still running under it reads as the game not having noticed.
func pull_up() -> void:
	if not playing:
		return
	_kill_tween()
	if fade_out <= 0.0:
		stop()
		return
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", -60.0, fade_out)
	_tween.tween_callback(stop)


## The shipping clip if there is one, otherwise whatever is sitting in the audition
## folder, otherwise nothing at all.
func _pick_engine() -> AudioStream:
	if engine != null:
		return engine
	if audition_path.is_empty() or not ResourceLoader.exists(audition_path):
		return null
	var found := load(audition_path) as AudioStream
	if found != null and announce_auditions and not _announced:
		_announced = true
		print("GameBike: auditioning %s. Not committed, so not in any build." % audition_path)
	return found


## Set by name rather than by checking each stream class, so a format nobody has used
## here yet loops too.
func _make_it_loop() -> void:
	if stream != null and &"loop" in stream:
		stream.set(&"loop", true)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
