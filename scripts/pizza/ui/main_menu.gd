extends Control

## Scene loaded when the player presses Start.
@export_file("*.tscn") var game_scene: String = "res://scenes/pizza_game.tscn"

## How the build is named in the corner. %s is the version the project records,
## which the release workflow stamps with the tag it is building, so what is on
## screen is the build itself saying which one it is.
##
## It earns its place: twice in one evening we chased art that was already
## published and turned out to be a browser serving yesterday's build. A number on
## screen settles that in a second instead of an hour.
@export var version_format: String = "v%s"

@onready var menu_container: VBoxContainer = $MenuContainer
@onready var credits_page: Credits = $CreditsPage
@onready var how_to_play_page: HowToPlay = $HowToPlayPage
@onready var settings_page: SettingsPage = $SettingsPage
@onready var start_button: Button = $MenuContainer/StartButton
@onready var how_to_play_button: Button = $MenuContainer/HowToPlayButton
@onready var settings_button: Button = $MenuContainer/SettingsButton
@onready var credits_button: Button = $MenuContainer/CreditsButton
@onready var version_label: Label = %Version


func _ready() -> void:
	start_button.pressed.connect(_start_game)
	how_to_play_button.pressed.connect(_show_how_to_play)
	settings_button.pressed.connect(_show_settings)
	credits_button.pressed.connect(_show_credits)
	credits_page.back_pressed.connect(_show_menu)
	how_to_play_page.back_pressed.connect(_show_menu)
	settings_page.back_pressed.connect(_show_menu)
	_alternate_box_flips()
	_show_version()
	_show_menu()


## Say which build this is. Read from the project rather than written down here,
## so it cannot disagree with the build it is printed on.
func _show_version() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	version_label.visible = not version.is_empty()
	version_label.text = version_format % version


## Every other box in the column is mirrored left to right, so the three read as a
## stack of boxes rather than one box printed three times. Worked out from position
## in the column rather than set on each button, so a fourth alternates on its own;
## the scene carries the same values so the editor canvas shows what the game will.
func _alternate_box_flips() -> void:
	var index := 0
	for child in menu_container.get_children():
		var box := child as PizzaBoxButton
		if box == null:
			continue
		box.flip_art_h = index % 2 == 1
		index += 1


func _start_game() -> void:
	if game_scene.is_empty() or not ResourceLoader.exists(game_scene):
		push_warning("Game scene not set or missing: %s" % game_scene)
		return
	get_tree().change_scene_to_file(game_scene)


## One page at a time, over the street the menu leaves standing. Written out rather
## than looped, because there are three of them and a list of pages to hide reads
## worse than saying which one is up.
func _show_credits() -> void:
	_show_page(credits_page)


func _show_how_to_play() -> void:
	_show_page(how_to_play_page)


func _show_settings() -> void:
	_show_page(settings_page)


func _show_page(page: Control) -> void:
	menu_container.visible = false
	for other in [credits_page, how_to_play_page, settings_page]:
		other.visible = other == page


func _show_menu() -> void:
	credits_page.visible = false
	how_to_play_page.visible = false
	settings_page.visible = false
	menu_container.visible = true
