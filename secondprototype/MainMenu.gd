extends Control

const GAME_SCENE := "res://Game.tscn"
const TUTORIAL_SCENE := "res://Tutorial.tscn"

@onready var new_game_button = find_child("NewGameButton", true, false)
@onready var load_game_button = find_child("LoadGameButton", true, false)
@onready var tutorial_button = find_child("TutorialButton", true, false)
@onready var quit_button = find_child("QuitButton", true, false)
@onready var player_count_option = find_child("PlayerCountOption", true, false)


func _ready():
	if player_count_option == null:
		push_error("PlayerCountOption not found. Check the node is named exactly PlayerCountOption.")
		return

	if new_game_button == null:
		push_error("NewGameButton not found.")
		return

	if load_game_button == null:
		push_error("LoadGameButton not found.")
		return

	if tutorial_button == null:
		push_error("TutorialButton not found.")
		return

	if quit_button == null:
		push_error("QuitButton not found.")
		return

	player_count_option.clear()
	player_count_option.add_item("2 Players", 2)
	player_count_option.add_item("3 Players", 3)
	player_count_option.add_item("4 Players", 4)
	player_count_option.select(0)

	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_new_game_pressed():
	GameState.selected_player_count = player_count_option.get_item_id(player_count_option.selected)
	GameState.load_requested = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_load_game_pressed():
	if not FileAccess.file_exists(GameState.SAVE_PATH):
		print("No save file found.")
		return

	GameState.load_requested = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_tutorial_pressed():
	get_tree().change_scene_to_file(TUTORIAL_SCENE)


func _on_quit_pressed():
	get_tree().quit()
