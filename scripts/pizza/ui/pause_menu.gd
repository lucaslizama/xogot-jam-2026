class_name PauseMenu
extends Control

## Stopping the street, and the two places you can go from there.
##
## It owns the pause itself: opening it sets [member SceneTree.paused] and closing it
## clears it, so nothing else in the game has to know it happened. Everything with a
## rule in it is pausable, so the street stops scrolling, the flight stops advancing
## and a touch cannot reach the pizza while this is up. This node is the exception,
## running always, because a pause menu that pauses itself cannot be dismissed.
##
## Leaving is not its decision. Changing scene is the game's to do, so the button
## only says it was pressed and [PizzaGame] does the rest. What this does guarantee
## is that the tree is running again before it says so: a scene loaded into a paused
## tree comes up frozen, and the menu it loads has no pause button to get out with.
##
## The settings page is the one the main menu shows, instanced here rather than
## copied. It draws no background of its own by design, which is exactly what suits
## it here: the scrim behind it is already up, so the street stays dimmed behind the
## sliders instead of a second panel appearing over the first.

## The pause was taken back. The street should carry on.
signal resumed
## The player asked to leave the street. The tree is already unpaused by the time
## this arrives, so whoever handles it can change scene without thinking about it.
signal leave_pressed

@onready var _button: Button = %PauseButton
@onready var _overlay: Control = %Overlay
@onready var _panel: Control = %Panel
@onready var _settings: SettingsPage = %SettingsPage
@onready var _resume: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu: Button = %MenuButton


func _ready() -> void:
	_button.pressed.connect(open)
	_resume.pressed.connect(close)
	_settings_button.pressed.connect(_show_settings)
	_menu.pressed.connect(_leave)
	_settings.back_pressed.connect(_show_buttons)
	_overlay.visible = false
	_show_buttons()


## Escape as well as the button, because the browser build is played on a desktop as
## often as on a phone and a keyboard expects it. The same key both ways, so it
## closes what it opened.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _overlay.visible:
		close()
	elif _button.visible:
		open()
	get_viewport().set_input_as_handled()


## Whether the street can be paused at all. Off while the round is over: the result
## card is its own screen with its own way onward, and a pause menu over the top of
## it would offer to resume a street that has finished.
##
## Turning it off closes anything already open rather than leaving the player looking
## at a menu whose button has gone.
func allow_pausing(allowed: bool) -> void:
	_button.visible = allowed
	if not allowed and _overlay.visible:
		close()


func is_open() -> bool:
	return _overlay.visible


func open() -> void:
	if _overlay.visible:
		return
	_show_buttons()
	_overlay.visible = true
	_button.visible = false
	get_tree().paused = true


func close() -> void:
	if not _overlay.visible:
		return
	get_tree().paused = false
	_overlay.visible = false
	_button.visible = true
	resumed.emit()


func _show_settings() -> void:
	_panel.visible = false
	_settings.visible = true


func _show_buttons() -> void:
	_settings.visible = false
	_panel.visible = true


## Unpause first, then say so. The other order hands a paused tree to whatever loads
## next, which arrives frozen with nothing on it able to move.
func _leave() -> void:
	get_tree().paused = false
	_overlay.visible = false
	_button.visible = true
	leave_pressed.emit()
