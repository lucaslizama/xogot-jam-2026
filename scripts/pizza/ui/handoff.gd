class_name Handoff
extends Control

## The moment the street is named after: you finish your last delivery, the next
## rider pulls alongside, and the bag goes across.
##
## Shown only on a street cleared, and only for a beat, before the result card
## says what it paid. A street lost has nothing to hand on, so it goes straight to
## the card.
##
## Everything is placed in handoff.tscn: where each rider stands, where the box
## starts, where it ends. This owns only the timing and the order of it, so the
## staging can be rearranged on the canvas without opening a script.
##
## Both riders are instances of scenes/rider.tscn rather than copies of her values:
## the artist changes her in one place and the street, this beat and both slots
## follow. The rider leaving is the one you have been playing, and she suits that
## slot as drawn, facing right with the box travelling rightwards.
##
## The one arriving is the same scene twice over, which would have her hand the bag
## to herself, so the scene does two things about it. She is mirrored, scale.x
## negative, which turns her to face the rider she is taking it from; because the
## rider's anchor is at her feet, flipping her leaves those feet where they were
## rather than sliding her sideways. And her hues are rotated by the material on the
## node, shaders/rider_recolour.gdshader, which spares her skin and moves everything
## a player reads as which rider this is.
##
## A plain `modulate` tint was tried there first and was not enough. Multiplying
## leaves every hue where it was, so she read as the same girl in different light;
## side by side for a second, nobody would take her for anyone else.
##
## Neither hue is authored here, because the pair has to mean something: the rider
## leaving is wearing the colours you have been playing, and the rider arriving is
## wearing the ones you are about to. [method play] is told both by the game, which
## is the only thing that knows how far into a run you are. The values in the scene
## are what the beat looks like opened on its own in the editor.
##
## Both are staging for a sprite that does not exist yet, and both come off in one
## step when it does: point RiderIn's `idle_art` at the second rider, clear the
## material, and decide then whether she still wants mirroring.
##
## Both scales are the same 0.385, which puts each silhouette at about 234 pixels,
## the height the placeholder box they replaced stood at. Her canvas is 650 square
## with the drawing filling 93% of its height and the rest transparent margin, so
## that scale is smaller than it looks. If she is resized, match the silhouette
## rather than the number, and mirror by negating x only. About 400 pixels is as
## tall as they can both go before they overlap where they stand.
##
## A tap sends it on early. Nobody wants to sit through the same beat three times
## in a run, and a cutscene that cannot be skipped is a cutscene people resent.

## The beat is over, by running its course or by being tapped through.
signal finished

@export_group("Timing")
## How long the riders take to slide into place.
@export_range(0.05, 4.0, 0.05) var ride_in: float = 0.9
## How long the box takes to cross between them.
@export_range(0.05, 4.0, 0.05) var pass_across: float = 1.2
## How long the two sit together once the box has changed hands, before the card.
@export_range(0.0, 4.0, 0.05) var hold: float = 1.2

@export_group("Staging")
## How far off screen each rider begins, as a fraction of the screen's width. The
## leaving rider comes from the left, the arriving one from the right.
@export_range(0.0, 2.0, 0.05) var slide_from: float = 0.75
## How high the box arcs on its way across, in pixels. A box that slides flat
## reads as a shove; one that lifts reads as a pass.
@export_range(0.0, 400.0, 5.0) var pass_arc: float = 90.0

@onready var _scrim: ColorRect = %Scrim
## Both slots are rider instances now, not a rider and a placeholder box, which is
## what lets either of them be recoloured into somebody else.
@onready var _rider_out: RiderView = %RiderOut
@onready var _rider_in: RiderView = %RiderIn
@onready var _box: Node2D = %Box
@onready var _box_target: Node2D = %BoxTarget
@onready var _caption: Label = %Caption

var _playing: bool = false
var _tween: Tween
## Where the scene author put everything, kept so a second run starts where the
## first did rather than from wherever the last one left things.
var _home_rider_out: Vector2
var _home_rider_in: Vector2
var _home_box: Vector2


func _ready() -> void:
	_home_rider_out = _rider_out.position
	_home_rider_in = _rider_in.position
	_home_box = _box.position
	hide()


## Play the beat. Returns immediately; wait on [signal finished].
##
## The two hues are turns round the hue wheel: who is leaving and who is arriving.
## Passing them every time rather than setting them once is deliberate — the beat
## plays three times in a run with a different pair each time, and a colour left over
## from the last street would put the wrong rider on the screen.
func play(leaving_hue: float, arriving_hue: float) -> void:
	if _playing:
		return
	_playing = true
	_reset()
	_rider_out.set_hue(leaving_hue)
	_rider_in.set_hue(arriving_hue)
	show()

	var width: float = size.x if size.x > 1.0 else get_viewport_rect().size.x
	var away := width * slide_from
	_rider_out.position = _home_rider_out - Vector2(away, 0.0)
	_rider_in.position = _home_rider_in + Vector2(away, 0.0)

	_tween = create_tween()
	_tween.tween_property(_rider_out, "position", _home_rider_out, ride_in) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_rider_in, "position", _home_rider_in, ride_in) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# The box goes across in two halves so it can lift on the way, which is what
	# makes it read as handed rather than slid.
	var midpoint: Vector2 = (_home_box + _box_target.position) * 0.5 \
		- Vector2(0.0, pass_arc)
	_tween.tween_property(_box, "position", midpoint, pass_across * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_box, "position", _box_target.position, pass_across * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_interval(hold)
	_tween.tween_callback(_end)


## Send it on early, however far through it is.
func skip() -> void:
	if not _playing:
		return
	_end()


func _end() -> void:
	if not _playing:
		return
	_playing = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	hide()
	finished.emit()


func _reset() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rider_out.position = _home_rider_out
	_rider_in.position = _home_rider_in
	_box.position = _home_box
	_scrim.modulate.a = 1.0
	_caption.visible = not _caption.text.is_empty()


## A tap anywhere sends it on. The control fills the screen and stops input, so
## nothing behind it can be thrown at while the beat is playing.
func _gui_input(event: InputEvent) -> void:
	if not _playing:
		return
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed:
		accept_event()
		skip()


## True while the beat is on screen. Asked by the game, and by the tests.
func is_playing() -> bool:
	return _playing
