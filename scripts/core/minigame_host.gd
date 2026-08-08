class_name MinigameHost
extends Control

## Owns the viewport a minigame plays in, and the clock it plays against.
##
## Minigames are instanced into a SubViewport sized to their authored
## orientation. A landscape minigame gets a genuinely landscape viewport and is
## rotated into the portrait window here, so the device never rotates and the
## minigame never learns about any of it.

## Emitted when the current minigame resolves, by its own hand or by the clock.
signal minigame_finished(success: bool)

@export_group("Design resolution")
## The space portrait minigames are authored in. Everything is letterboxed to
## fit the real window, so authoring stays predictable across devices.
@export var portrait_design_size: Vector2i = Vector2i(1170, 2532)
## The space landscape minigames are authored in — normally the transpose of
## the portrait size.
@export var landscape_design_size: Vector2i = Vector2i(2532, 1170)

@export_group("Rotation")
## Which way landscape games are turned into the portrait window. Flip this if
## turning the device the natural way leaves the game upside down.
@export var landscape_clockwise: bool = true

@onready var _container: SubViewportContainer = $SubViewportContainer
@onready var _viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var _clock: Timer = $Clock

var _current: Minigame
var _info: MinigameInfo


func _ready() -> void:
	_clock.timeout.connect(_on_clock_timeout)
	get_viewport().size_changed.connect(_relayout)

	# SubViewportContainer forwards input on its own, but it was measured inert
	# here and would double-deliver every tap if it ever woke up. Take the job
	# over explicitly: one path, using the same transform the rotation uses, and
	# one that a headless test can actually exercise.
	_container.set_process_unhandled_input(false)
	_container.set_process_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if _current == null:
		return
	# Undo the letterbox, scale and rotation so the minigame sees coordinates in
	# its own authored space and never learns which way up it is.
	#
	# get_global_transform(), not ..._with_canvas(): events reaching
	# _unhandled_input have already been converted out of window space into
	# viewport space, so folding the canvas transform in a second time throws
	# taps tens of thousands of pixels off target.
	var to_local := _container.get_global_transform().affine_inverse()
	_viewport.push_input(event.xformed_by(to_local), true)


## Instance and start a minigame. Any previous one is discarded first.
func play(info: MinigameInfo, ctx: MinigameContext) -> void:
	stop()
	_info = info

	if info == null or info.scene == null:
		push_error("MinigameHost: MinigameInfo '%s' has no scene assigned; skipping as a loss."
			% [info.display_name if info != null else "<null>"])
		_finish(false)
		return

	_apply_orientation(info.is_landscape())

	var node: Node = info.scene.instantiate()
	if not (node is Minigame):
		push_error("MinigameHost: scene for '%s' has a root of type %s; it must extend Minigame. Skipping as a loss."
			% [info.display_name, node.get_class()])
		node.queue_free()
		_finish(false)
		return

	_current = node as Minigame
	_current.context = ctx
	_current.finished.connect(_on_minigame_finished)
	_viewport.add_child(_current)
	_current.begin(ctx)

	_clock.start(maxf(0.1, ctx.duration))


## Discard the running minigame without resolving it.
func stop() -> void:
	_clock.stop()
	if _current != null:
		if _current.finished.is_connected(_on_minigame_finished):
			_current.finished.disconnect(_on_minigame_finished)
		_current.queue_free()
		_current = null
	_info = null


## Seconds left on the current minigame, or 0.0 when nothing is running.
func time_left() -> float:
	return _clock.time_left if not _clock.is_stopped() else 0.0


func _apply_orientation(landscape: bool) -> void:
	var design: Vector2i = landscape_design_size if landscape else portrait_design_size
	_viewport.size = design
	_container.size = Vector2(design)
	_container.pivot_offset = Vector2.ZERO
	_relayout()


func _relayout() -> void:
	if _container == null:
		return
	var design := _container.size
	var landscape := _info != null and _info.is_landscape()

	# Footprint the design box occupies on screen once it has been rotated.
	var footprint := Vector2(design.y, design.x) if landscape else design
	var turn := 0.0
	if landscape:
		turn = PI * 0.5 if landscape_clockwise else -PI * 0.5

	var avail := get_viewport_rect().size
	var fit: float = minf(avail.x / footprint.x, avail.y / footprint.y)
	var drawn := footprint * fit
	var origin := (avail - drawn) * 0.5

	# Rotating about the top-left corner sweeps the box out of frame; push it
	# back by the edge the rotation took away.
	var correction := Vector2.ZERO
	if landscape:
		correction = Vector2(drawn.x, 0.0) if landscape_clockwise else Vector2(0.0, drawn.y)

	_container.scale = Vector2(fit, fit)
	_container.rotation = turn
	_container.position = origin + correction


func _on_minigame_finished(success: bool) -> void:
	_clock.stop()
	_finish(success)


func _on_clock_timeout() -> void:
	if _current == null:
		return
	# The clock does not decide the outcome, the minigame's info does — some
	# games are won by surviving it, others lost by running into it.
	_current.notify_timeout(_info.win_on_timeout)


func _finish(success: bool) -> void:
	minigame_finished.emit(success)
