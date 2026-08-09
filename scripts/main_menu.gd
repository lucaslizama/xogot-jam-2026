extends Control

## Scene loaded when the player presses Start.
@export_file("*.tscn") var game_scene: String = "res://scenes/pizza_game.tscn"

@onready var menu_container: VBoxContainer = $MenuContainer
@onready var credits_page: Control = $CreditsPage
@onready var how_to_play_page: HowToPlay = $HowToPlayPage
@onready var start_button: Button = $MenuContainer/StartButton
@onready var how_to_play_button: Button = $MenuContainer/HowToPlayButton
@onready var credits_button: Button = $MenuContainer/CreditsButton
@onready var back_button: Button = $CreditsPage/CreditsContainer/BackButton


func _ready() -> void:
	start_button.pressed.connect(_start_game)
	how_to_play_button.pressed.connect(_show_how_to_play)
	credits_button.pressed.connect(_show_credits)
	back_button.pressed.connect(_show_menu)
	how_to_play_page.back_pressed.connect(_show_menu)
	_alternate_box_flips()
	_show_menu()


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


func _show_credits() -> void:
	menu_container.visible = false
	how_to_play_page.visible = false
	credits_page.visible = true


func _show_how_to_play() -> void:
	menu_container.visible = false
	credits_page.visible = false
	how_to_play_page.visible = true


func _show_menu() -> void:
	credits_page.visible = false
	how_to_play_page.visible = false
	menu_container.visible = true
