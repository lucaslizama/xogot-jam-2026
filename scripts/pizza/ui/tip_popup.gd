class_name TipPopup
extends Control

## The word that appears where a pizza landed: how well it went, what it paid,
## and how long the run is now.
##
## One popup, reused. Only one pizza is ever in the air, so only one throw can
## resolve at a time, and a second one arriving simply takes the popup over. The
## rows are authored in the scene; this places it, fills it in and floats it.
##
## Nothing here is a size or a colour. The look lives in tip_popup.tscn and in the
## theme, so what a bullseye looks like is changed without opening a script.

@export_group("Float")
## How far it drifts up while fading, in pixels.
@export_range(0.0, 400.0, 5.0) var rise: float = 110.0
## How long it lasts. Long enough to read, short enough not to still be there when
## the next pizza lands.
@export_range(0.1, 3.0, 0.05) var linger: float = 0.85
## How long it takes to swell in on arrival. The pop is what makes a bullseye feel
## like an event rather than a caption.
@export_range(0.0, 0.6, 0.01) var pop_duration: float = 0.14
@export_range(1.0, 2.0, 0.01) var pop_scale: float = 1.35

@export_group("Colours")
## One per tier, best first. A bullseye should be the colour the drop point was,
## so the reward closes on the thing you aimed at.
## Through the window is the best throw in the game, so it gets the warm light of
## the window itself rather than the drop point's cool blue.
@export var colour_window: Color = Color(1, 0.894118, 0.470588)
@export var colour_bullseye: Color = Color(0.301961, 0.65098, 1)
@export var colour_nice: Color = Color(1, 0.894118, 0.470588)
@export var colour_scraped: Color = Color(0.760784, 0.760784, 0.819608)
## Said when a run ends, so it reads as a loss rather than as a score.
@export var colour_streak_lost: Color = Color(0.921569, 0.337255, 0.294118)

@onready var _tier: Label = %Tier
@onready var _tip: Label = %Tip
@onready var _streak: Label = %Streak

var _tween: Tween


func _ready() -> void:
	hide()


## Show what a delivery earned, at the point on screen where it landed.
func show_tip(at: Vector2, heading: String, tip: String, streak: String,
		colour: Color) -> void:
	_tier.text = heading
	_tier.add_theme_color_override(&"font_color", colour)
	_tip.text = tip
	_tip.visible = not tip.is_empty()
	_streak.text = streak
	_streak.visible = not streak.is_empty()
	_play(at)


## Show a plain word with no tip attached, for a run coming to an end.
func show_message(at: Vector2, message: String, colour: Color) -> void:
	if message.is_empty():
		return
	_tier.text = message
	_tier.add_theme_color_override(&"font_color", colour)
	_tip.visible = false
	_streak.visible = false
	_play(at)


func _play(at: Vector2) -> void:
	# A throw landing while the last one is still floating takes the popup over
	# rather than the two fighting over it.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	position = at - size * 0.5
	modulate.a = 1.0
	scale = Vector2.ONE * pop_scale
	pivot_offset = size * 0.5
	show()

	# Deliberately not awaited. A tween the game waits on is a tween still held if
	# the scene goes away mid-float, and that shows up as a leaked instance.
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, pop_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "position:y", position.y - rise, linger) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, linger) \
		.set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)


## The colour that goes with a tier, so the caller does not have to know the map.
func colour_for(tier: ScoreRules.ThrowTier) -> Color:
	match tier:
		ScoreRules.ThrowTier.WINDOW:
			return colour_window
		ScoreRules.ThrowTier.BULLSEYE:
			return colour_bullseye
		ScoreRules.ThrowTier.NICE:
			return colour_nice
		_:
			return colour_scraped
