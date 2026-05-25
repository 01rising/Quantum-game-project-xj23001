extends Control

const MAIN_MENU_SCENE := "res://MainMenu.tscn"

@onready var back_button = $BackButton


func _ready():
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed():
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
