extends Control

## Scene loaded when the player presses Start.
@export_file("*.tscn") var game_scene: String = "res://scenes/pizza_game.tscn"

@onready var start_button: Button = $MenuContainer/StartButton


func _ready() -> void:
	start_button.pressed.connect(_start_game)


func _start_game() -> void:
	if game_scene.is_empty() or not ResourceLoader.exists(game_scene):
		push_warning("Game scene not set or missing: %s" % game_scene)
		return
	get_tree().change_scene_to_file(game_scene)
