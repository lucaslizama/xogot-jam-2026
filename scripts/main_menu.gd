extends Control

## Scene loaded when the player presses Start.
@export_file("*.tscn") var game_scene: String = "res://scenes/pizza_game.tscn"

@onready var menu_container: VBoxContainer = $MenuContainer
@onready var credits_page: Control = $CreditsPage
@onready var start_button: Button = $MenuContainer/StartButton
@onready var credits_button: Button = $MenuContainer/CreditsButton
@onready var back_button: Button = $CreditsPage/CreditsContainer/BackButton


func _ready() -> void:
	start_button.pressed.connect(_start_game)
	credits_button.pressed.connect(_show_credits)
	back_button.pressed.connect(_show_menu)
	_show_menu()


func _start_game() -> void:
	if game_scene.is_empty() or not ResourceLoader.exists(game_scene):
		push_warning("Game scene not set or missing: %s" % game_scene)
		return
	get_tree().change_scene_to_file(game_scene)


func _show_credits() -> void:
	menu_container.visible = false
	credits_page.visible = true


func _show_menu() -> void:
	credits_page.visible = false
	menu_container.visible = true
