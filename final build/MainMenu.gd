extends Control

const GAME_SCENE := "res://Game.tscn"
const TUTORIAL_SCENE := "res://Tutorial.tscn"
const MENU_BACKGROUND_PATH = "res://assets/backgrounds/menu_background.png"
const MENU_CLICK_SOUND_PATH = "res://assets/audio/sfx/button_click.ogg"
const MENU_HOVER_SOUND_PATH = "res://assets/audio/sfx/button_hover.ogg"
const MENU_MUSIC_PATH = "res://assets/audio/music/menu_music.ogg"

var menu_click_sound: AudioStream = null
var menu_hover_sound: AudioStream = null
var menu_music_player: AudioStreamPlayer = null

@onready var new_game_button = find_child("NewGameButton", true, false)
@onready var load_game_button = find_child("LoadGameButton", true, false)
@onready var tutorial_button = find_child("TutorialButton", true, false)
@onready var quit_button = find_child("QuitButton", true, false)
@onready var player_count_option = find_child("PlayerCountOption", true, false)


func _ready():
	add_menu_background()
	load_menu_sounds()
	# start_menu_music()

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

	style_menu_buttons()

	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _exit_tree():
	if menu_music_player != null:
		menu_music_player.stop()


func add_menu_background():
	var background_texture: Texture2D = null

	if ResourceLoader.exists(MENU_BACKGROUND_PATH):
		background_texture = load(MENU_BACKGROUND_PATH)
	elif FileAccess.file_exists(MENU_BACKGROUND_PATH):
		var image = Image.load_from_file(MENU_BACKGROUND_PATH)
		if image != null:
			background_texture = ImageTexture.create_from_image(image)

	if background_texture == null:
		print("Missing menu background: ", MENU_BACKGROUND_PATH)
		return

	var background = TextureRect.new()
	background.name = "MenuBackground"
	background.texture = background_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.z_index = -100

	add_child(background)
	move_child(background, 0)


func load_menu_sounds():
	menu_click_sound = load_audio_stream(MENU_CLICK_SOUND_PATH)
	menu_hover_sound = load_audio_stream(MENU_HOVER_SOUND_PATH)


func load_audio_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)

	if not FileAccess.file_exists(path):
		return null

	var extension = path.get_extension().to_lower()

	if extension == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)

	return null


func start_menu_music():
	if DisplayServer.get_name() == "headless":
		return

	if menu_music_player == null:
		menu_music_player = AudioStreamPlayer.new()
		menu_music_player.name = "MenuMusic"
		add_child(menu_music_player)

	if menu_music_player.stream == null:
		menu_music_player.stream = load_audio_stream(MENU_MUSIC_PATH)

	if menu_music_player.stream == null:
		print("Missing menu music: ", MENU_MUSIC_PATH)
		return

	menu_music_player.volume_db = -20.0

	if not menu_music_player.finished.is_connected(_on_menu_music_finished):
		menu_music_player.finished.connect(_on_menu_music_finished)

	if not menu_music_player.playing:
		menu_music_player.play()


func _on_menu_music_finished():
	if menu_music_player != null:
		menu_music_player.play()


func play_menu_click():
	if menu_click_sound == null:
		return

	if not is_inside_tree():
		return

	var audio = AudioStreamPlayer.new()
	audio.stream = menu_click_sound
	audio.volume_db = -10.0
	add_child(audio)

	if not audio.is_inside_tree():
		audio.queue_free()
		return

	audio.finished.connect(audio.queue_free)
	audio.play()


func play_menu_hover():
	if menu_hover_sound == null:
		return

	if not is_inside_tree():
		return

	var audio = AudioStreamPlayer.new()
	audio.stream = menu_hover_sound
	audio.volume_db = -12.0
	add_child(audio)

	if not audio.is_inside_tree():
		audio.queue_free()
		return

	audio.finished.connect(audio.queue_free)
	audio.play()


func style_menu_buttons():
	var buttons = find_children("*", "Button", true, false)

	for button in buttons:
		button.custom_minimum_size = Vector2(230, 48)
		button.pivot_offset = button.custom_minimum_size / 2.0
		button.add_theme_font_size_override("font_size", 22)

		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.05, 0.12, 0.22, 0.92)
		normal_style.border_color = Color(0.35, 0.85, 1.0, 1.0)
		normal_style.set_border_width_all(2)
		normal_style.set_corner_radius_all(12)
		button.add_theme_stylebox_override("normal", normal_style)

		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.12, 0.28, 0.42, 0.96)
		hover_style.border_color = Color(0.8, 1.0, 1.0, 1.0)
		hover_style.set_border_width_all(3)
		hover_style.set_corner_radius_all(12)
		button.add_theme_stylebox_override("hover", hover_style)

		var pressed_style = StyleBoxFlat.new()
		pressed_style.bg_color = Color(0.02, 0.08, 0.14, 1.0)
		pressed_style.border_color = Color(1.0, 0.85, 0.25, 1.0)
		pressed_style.set_border_width_all(2)
		pressed_style.set_corner_radius_all(12)
		button.add_theme_stylebox_override("pressed", pressed_style)

		if not button.pressed.is_connected(play_menu_click):
			button.pressed.connect(play_menu_click)

		if not button.mouse_entered.is_connected(play_menu_hover):
			button.mouse_entered.connect(play_menu_hover)

		if not button.mouse_entered.is_connected(_on_menu_button_mouse_entered.bind(button)):
			button.mouse_entered.connect(_on_menu_button_mouse_entered.bind(button))

		if not button.mouse_exited.is_connected(_on_menu_button_mouse_exited.bind(button)):
			button.mouse_exited.connect(_on_menu_button_mouse_exited.bind(button))


func _on_menu_button_mouse_entered(button: Button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.10)


func _on_menu_button_mouse_exited(button: Button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.12)


func _on_new_game_pressed():
	GameState.selected_player_count = player_count_option.get_item_id(player_count_option.selected)
	GameState.load_requested = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_load_game_pressed():
	if not FileAccess.file_exists(GameState.SAVE_PATH):
		load_game_button.text = "No Save Found"
		await get_tree().create_timer(1.4).timeout
		load_game_button.text = "Load Game"
		return

	GameState.load_requested = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_tutorial_pressed():
	get_tree().change_scene_to_file(TUTORIAL_SCENE)


func _on_quit_pressed():
	get_tree().quit()
