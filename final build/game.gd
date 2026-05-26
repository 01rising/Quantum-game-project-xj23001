extends Node2D

const BOARD_BACKGROUND_PATH = "res://assets/backgrounds/board_background.png"
const GAMEPLAY_MUSIC_PATH = "res://assets/audio/music/gameplay_music.ogg"

var plane_position: int = 0
var score: int = 0
var gameplay_music_player: AudioStreamPlayer = null

var player_positions = [0, 0]
var player_scores = [0, 0]
var player_in_airport: Array[bool] = []
var player_aid_loadouts: Array[String] = []
var current_player: int = 0
@export_range(2, 4, 1) var player_count: int = 2

@export var target_score: int = 6

var possible_aid_loadouts = [
	"Water Rescue",
	"Fire Response",
	"Medical Supplies",
	"Repair Team",
	"Food Aid"
]

var aid_icon_paths = {
	"Water Rescue": "res://assets/icons/aid/water_rescue.png",
	"Fire Response": "res://assets/icons/aid/fire_response.png",
	"Medical Supplies": "res://assets/icons/aid/medical_supplies.png",
	"Repair Team": "res://assets/icons/aid/repair_team.png",
	"Food Aid": "res://assets/icons/aid/food_aid.png"
}

var crisis_legend_panel: PanelContainer = null
var crisis_legend_box: VBoxContainer = null

var current_aid_icon: Sprite2D = null
var right_hud_panel: Panel = null

var briefing_layer: CanvasLayer = null
var briefing_overlay: ColorRect = null
var briefing_panel: PanelContainer = null
var briefing_title: Label = null
var briefing_body: Label = null
var briefing_button: Button = null
var briefing_active := false

var aid_selection_layer: CanvasLayer = null
var aid_selection_panel: PanelContainer = null
var aid_selection_title: Label = null
var aid_selection_buttons: Array[Button] = []

var event_card_layer: CanvasLayer = null
var event_card_panel: PanelContainer = null
var event_card_icon: TextureRect = null
var event_card_title: Label = null
var event_card_body: Label = null
var event_card_timer_id := 0

var legend_layer: CanvasLayer = null
var legend_overlay: ColorRect = null
var legend_panel: PanelContainer = null
var legend_button: Button = null
var legend_close_button: Button = null

var event_icon_paths = {
	"Storm Surge": "res://assets/icons/storm_surge.png",
	"Storm Surge Warning": "res://assets/icons/storm_surge.png",
	"Infrastructure Collapse": "res://assets/icons/crisis/infrastructure.png",
	"Supply Drop": "res://assets/icons/aid/food_aid.png",
	"Quantum": "res://assets/icons/dice.png"
}

var team_names = [
	"Blue Horizon Aid",
	"Solar Relief Corps",
	"Red Wing Response",
	"Green Cross Airlift"
]

var team_roles = [
	"Relief Coordination Unit",
	"Regional Response Unit",
	"Crisis Support Unit",
	"Logistics Operations Unit"
]

var team_mottos = [
	"Coordinates aid delivery across unstable zones.",
	"Responds to changing field conditions and local emergencies.",
	"Supports affected regions with adaptable relief resources.",
	"Maintains routes, supplies, and operational movement."
]

var crisis_flavour_text = {
	"Flood": [
		"Floodwater has blocked key routes and isolated nearby communities.",
		"Emergency teams report rising water levels across the region.",
		"Evacuation corridors are unstable. Water response is needed."
	],

	"Wildfire": [
		"Dry conditions have accelerated a fast-moving fire front.",
		"Smoke is reducing visibility and threatening nearby supply routes.",
		"Fire crews are requesting immediate aerial support."
	],

	"Medical": [
		"Local clinics are overwhelmed by a sudden surge in casualties.",
		"Medical supplies are running low in the affected zone.",
		"Field hospitals require urgent support."
	],

	"Infrastructure": [
		"Transport links and power systems are failing in this sector.",
		"Damaged infrastructure is slowing the relief operation.",
		"Repair teams are needed to restore access routes."
	],

	"Food Shortage": [
		"Supply chains have been disrupted and local reserves are running low.",
		"Food distribution points are reporting critical shortages.",
		"Relief teams must restore access to emergency supplies."
	]
}

var team_turn_flavour = [
	"awaits deployment orders.",
	"is reviewing the crisis map.",
	"is ready to coordinate the next response.",
	"is standing by for field instructions.",
	"is preparing the next aid operation."
]

func get_crisis_flavour(crisis_type: String) -> String:
	if not crisis_flavour_text.has(crisis_type):
		return "The crisis zone is unstable and requires immediate attention."

	var options = crisis_flavour_text[crisis_type]
	if options.is_empty():
		return "The crisis zone is unstable and requires immediate attention."

	return options[randi() % options.size()]

func get_team_turn_message(player_id: int) -> String:
	var team_name = get_team_name(player_id)
	var line = team_turn_flavour[randi() % team_turn_flavour.size()]
	return "%s %s" % [team_name, line]

var team_card_layer: CanvasLayer = null
var team_card_panel: PanelContainer = null
var team_card_icon: TextureRect = null
var team_card_name: Label = null
var team_card_role: Label = null
var team_card_motto: Label = null

var move_card_layer: CanvasLayer = null
var move_card_panel: PanelContainer = null
var move_card_title: Label = null
var move_card_body: Label = null
var move_card_timer_id := 0

func get_team_name(player_id: int) -> String:
	if player_id >= 0 and player_id < team_names.size():
		return team_names[player_id]

	return "Player %d" % (player_id + 1)

var board_tiles = []
var board_tile_labels = []
@export var map_width: float = 900.0
@export var map_height: float = 620.0
@export var map_jitter: float = 0.18
@export var board_zoom: float = 1.12
@export var tile_radius: float = 18.0
@export var airport_distance: float = 120.0

const LEFT_HUD_WIDTH := 300.0
const RIGHT_HUD_WIDTH := 380.0
const TOP_MARGIN := 70.0
const BOTTOM_BAR_HEIGHT := 92.0
const SCREEN_PADDING := 16.0

@export var map_node_count_2_players: int = 34
@export var map_node_count_3_players: int = 44
@export var map_node_count_4_players: int = 54

@export var max_active_crises_2_players: int = 4
@export var max_active_crises_3_players: int = 7
@export var max_active_crises_4_players: int = 9

@export var starting_crises_2_players: int = 4
@export var starting_crises_3_players: int = 5
@export var starting_crises_4_players: int = 7

var base_tile_positions: Array[Vector2] = []
var tile_positions: Array[Vector2] = []
var player_planes: Array[Node2D] = []
var board_background: Sprite2D = null
var board_backdrop_panel: Panel = null
var board_route_line: Line2D = null
var crisis_glow_nodes := {}
var player_plane_texture_paths = [
	"res://assets/planes/team_blue.png",
	"res://assets/planes/team_yellow.png",
	"res://assets/planes/team_red.png",
	"res://assets/planes/team_green.png"
]

var crisis_icon_nodes := {}
var crisis_icon_types := {}
var crisis_icon_paths = {
	"Flood": "res://assets/icons/crisis/flood.png",
	"FL": "res://assets/icons/crisis/flood.png",

	"Wildfire": "res://assets/icons/crisis/wildfire.png",
	"Fire": "res://assets/icons/crisis/wildfire.png",
	"WF": "res://assets/icons/crisis/wildfire.png",

	"Medical": "res://assets/icons/crisis/medical.png",
	"MD": "res://assets/icons/crisis/medical.png",
	"MED": "res://assets/icons/crisis/medical.png",

	"Infrastructure": "res://assets/icons/crisis/infrastructure.png",
	"IN": "res://assets/icons/crisis/infrastructure.png",

	"Food Shortage": "res://assets/icons/crisis/food_shortage.png",
	"Food": "res://assets/icons/crisis/food_shortage.png",
	"FD": "res://assets/icons/crisis/food_shortage.png"
}

# Sound effects
var sfx_paths = {
	"button_click": "res://assets/audio/sfx/button_click.ogg",
	"button_hover": "res://assets/audio/sfx/button_hover.ogg",
	"success": "res://assets/audio/sfx/success.ogg",
	"win": "res://assets/audio/sfx/success.ogg",
	"error": "res://assets/audio/sfx/error.ogg",
	"crisis": "res://assets/audio/sfx/crisis.ogg",
	"quantum": "res://assets/audio/sfx/quantum.ogg"
}

var sfx_cache = {}

var airport_entry_tiles: Array[int] = []
var airport_base_positions: Array[Vector2] = []
var airport_positions: Array[Vector2] = []

var airport_colors = [
	Color(0.25, 0.55, 1.0, 1.0),
	Color(1.0, 0.75, 0.15, 1.0),
	Color(1.0, 0.25, 0.2, 1.0),
	Color(0.25, 0.9, 0.35, 1.0)
]

var crisis_tiles: Array[int] = []
var crisis_severity: Dictionary = {}
var crisis_age: Dictionary = {}

var crisis_types: Dictionary = {}

@export var global_event_chance: float = 0.65

var player_next_match_bonus: Array[int] = []

var possible_crisis_types = [
	"Flood",
	"Wildfire",
	"Medical",
	"Infrastructure",
	"Food Shortage"
]

var crises_resolved_count: int = 0
var perfect_response_count: int = 0
var partial_response_count: int = 0
var total_aid_points_earned: int = 0
var crises_escalated_count: int = 0
var instability_events_count: int = 0
var quantum_tools_used_count: int = 0
var impact_report_shown: bool = false

var end_screen_layer: CanvasLayer = null
var end_screen_panel: PanelContainer = null
var end_screen_title: Label = null
var end_screen_rank: Label = null
var end_screen_stats: Label = null
var end_screen_outcome: Label = null

@export var max_crisis_severity: int = 3
@export var global_instability: int = 0
@export var max_global_instability: int = 12
@export var crisis_escalation_interval: int = 2
@export var crisis_spawn_after_aid_chance: float = 0.25
@export var crisis_spawn_per_round_chance: float = 0.35

var game_finished: bool = false

const QUBIT_COUNT := 3
const QUANTUM_STATE_COUNT := 8
const QUANTUM_SURGE_INSTABILITY_COST := 1

var quantum_active: bool = false
var quantum_options: Array[int] = []
var quantum_positions: Array[int] = []
var quantum_ghosts = []

# Complex amplitudes are stored as Vector2(real, imaginary)
var quantum_amplitudes: Array[Vector2] = []
var quantum_marked_states: Array[int] = []

var oracle_used: bool = false
var amplification_used: bool = false
var entangle_used: bool = false

var entanglement_active: bool = false
var entangled_positions: Array[int] = []
var entangled_ghosts = []

func get_map_node_count_for_players() -> int:
	if player_count <= 2:
		return map_node_count_2_players
	elif player_count == 3:
		return map_node_count_3_players
	else:
		return map_node_count_4_players


func get_starting_crisis_count_for_players() -> int:
	if player_count <= 2:
		return starting_crises_2_players
	elif player_count == 3:
		return starting_crises_3_players
	else:
		return starting_crises_4_players


func get_max_active_crises() -> int:
	if player_count <= 2:
		return max_active_crises_2_players
	elif player_count == 3:
		return max_active_crises_3_players
	else:
		return max_active_crises_4_players


func does_aid_match_crisis(aid_type: String, crisis_type: String) -> bool:
	if aid_type == "Water Rescue" and crisis_type == "Flood":
		return true

	if aid_type == "Fire Response" and crisis_type == "Wildfire":
		return true

	if aid_type == "Medical Supplies" and crisis_type == "Medical":
		return true

	if aid_type == "Repair Team" and crisis_type == "Infrastructure":
		return true

	if aid_type == "Food Aid" and crisis_type == "Food Shortage":
		return true

	return false


func get_crisis_short_name(crisis_type: String) -> String:
	match crisis_type:
		"Flood":
			return "FL"
		"Wildfire":
			return "WF"
		"Medical":
			return "MD"
		"Infrastructure":
			return "IN"
		"Food Shortage":
			return "FD"
		_:
			return "?"


func generate_new_map(reset_scores := true):
	base_tile_positions.clear()

	var count = max(get_map_node_count_for_players(), 12)
	var angle_offset = randf_range(0.0, TAU)

	for i in range(count):
		var angle = angle_offset + TAU * float(i) / float(count)
		var radius_noise = randf_range(1.0 - map_jitter, 1.0 + map_jitter)

		var x = cos(angle) * (map_width * 0.5) * radius_noise
		var y = sin(angle) * (map_height * 0.5) * radius_noise

		base_tile_positions.append(Vector2(x, y))

	# Move HQ/start tile to the upper-left-ish part of the map.
	var start_index = 0
	var best_score = 99999999.0

	for i in range(base_tile_positions.size()):
		var score_value = base_tile_positions[i].x + base_tile_positions[i].y
		if score_value < best_score:
			best_score = score_value
			start_index = i

	var rotated_positions: Array[Vector2] = []

	for i in range(base_tile_positions.size()):
		rotated_positions.append(base_tile_positions[(start_index + i) % base_tile_positions.size()])

	base_tile_positions = rotated_positions

	generate_airport_data()

	player_positions.clear()
	player_in_airport.clear()

	for i in range(player_count):
		player_positions.append(get_player_start_tile(i))
		player_in_airport.append(true)

	plane_position = player_positions[0]

	quantum_active = false
	entanglement_active = false
	oracle_used = false
	amplification_used = false
	entangle_used = false

	quantum_options.clear()
	quantum_amplitudes.clear()
	quantum_marked_states.clear()

	clear_quantum_ghosts()
	clear_entangled_ghosts()

	generate_starting_crises()

	if reset_scores:
		score = 0
		player_scores.clear()
		player_aid_loadouts.clear()

		for i in range(player_count):
			player_scores.append(0)
			player_aid_loadouts.append(possible_aid_loadouts[i % possible_aid_loadouts.size()])

			# Initialize per-player event bonuses
		player_next_match_bonus.clear()

		for i in range(player_count):
			player_next_match_bonus.append(0)

		current_player = 0
		game_finished = false
		global_instability = 0

		crises_resolved_count = 0
		perfect_response_count = 0
		partial_response_count = 0
		total_aid_points_earned = 0
		crises_escalated_count = 0
		instability_events_count = 0
		quantum_tools_used_count = 0
		impact_report_shown = false

		if end_game_popup != null:
			end_game_popup.visible = false

		if impact_report_panel != null:
			impact_report_panel.visible = false

		if end_screen_panel != null:
			end_screen_panel.visible = false
	else:
		while player_scores.size() < player_count:
			player_scores.append(0)
		while player_aid_loadouts.size() < player_count:
			player_aid_loadouts.append(possible_aid_loadouts[player_aid_loadouts.size() % possible_aid_loadouts.size()])

func generate_starting_crises():
	crisis_tiles.clear()
	crisis_severity.clear()
	crisis_age.clear()
	crisis_types.clear()

	var possible_tiles = []

	for i in range(base_tile_positions.size()):
		if i != 0 and i not in airport_entry_tiles and i not in player_positions:
			possible_tiles.append(i)

	possible_tiles.shuffle()

	var amount = min(get_starting_crisis_count_for_players(), possible_tiles.size())

	for i in range(amount):
		var tile_id = possible_tiles[i]
		crisis_tiles.append(tile_id)
		crisis_severity[tile_id] = 1
		crisis_age[tile_id] = 0
		crisis_types[tile_id] = possible_crisis_types[randi() % possible_crisis_types.size()]


@onready var board = $Board
@onready var plane = $Plane
@onready var plane2 = $Plane2

@onready var score_label = $UI/ScoreLabel
@onready var status_label = $UI/StatusLabel
@onready var quantum_button = $UI/ButtonBar/QuantumMoveButton
@onready var measure_button = $UI/ButtonBar/MeasureButton

@onready var move_button = get_node_or_null("UI/ButtonBar/MoveButton")
@onready var stabilize_button = get_node_or_null("UI/ButtonBar/StabilizeButton")
@onready var boost_button = get_node_or_null("UI/ButtonBar/BoostButton")
@onready var entangle_button = get_node_or_null("UI/ButtonBar/EntangleButton")

@onready var quantum_state_label = get_node_or_null("UI/QuantumStateLabel")
@onready var quantum_probability_label = get_node_or_null("UI/QuantumProbabilityLabel")
@onready var instability_label = get_node_or_null("UI/InstabilityLabel")
@onready var news_feed_label = get_node_or_null("UI/NewsFeedLabel")

@onready var save_game_button = get_node_or_null("UI/ButtonBar/SaveGameButton")
@onready var main_menu_button = get_node_or_null("UI/ButtonBar/MainMenuButton")

@onready var aid_loadout_label = get_node_or_null("UI/AidLoadoutLabel")
@onready var crisis_legend_label = get_node_or_null("UI/CrisisLegendLabel")
@onready var change_aid_button = get_node_or_null("UI/ButtonBar/ChangeAidButton")

@onready var impact_report_panel = get_node_or_null("UI/ImpactReportPanel")
@onready var impact_report_label = get_node_or_null("UI/ImpactReportPanel/ImpactReportLabel")

@onready var end_game_popup = get_node_or_null("UI/EndGamePopup")
@onready var end_game_title_label = get_node_or_null("UI/EndGamePopup/EndGameTitleLabel")
@onready var end_game_report_label = get_node_or_null("UI/EndGamePopup/EndGameReportLabel")
@onready var end_game_new_game_button = get_node_or_null("UI/EndGamePopup/EndGameNewGameButton")
@onready var end_game_main_menu_button = get_node_or_null("UI/EndGamePopup/EndGameMainMenuButton")


func setup_player_nodes():
	player_planes.clear()

	var possible_planes = [
		plane,
		plane2,
		get_node_or_null("Plane3"),
		get_node_or_null("Plane4")
	]

	for p in possible_planes:
		if p != null:
			player_planes.append(p)

	player_count = int(clamp(player_count, 2, min(4, player_planes.size())))

	for i in range(player_planes.size()):
		player_planes[i].visible = i < player_count
		player_planes[i].z_index = 20


func apply_player_plane_sprites():
	for i in range(player_planes.size()):
		var plane_node = player_planes[i]
		if plane_node == null:
			continue

		# Hide old simple token shapes if they exist
		for child in plane_node.get_children():
			if child is Polygon2D:
				child.visible = false

		var sprite = plane_node.get_node_or_null("PlaneSprite")
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = "PlaneSprite"
			plane_node.add_child(sprite)

		if i < player_plane_texture_paths.size():
			var path = player_plane_texture_paths[i]
			if ResourceLoader.exists(path):
				sprite.texture = load(path)

		sprite.centered = true
		sprite.z_index = 30

		if sprite.texture != null:
			var target_size = 60.0
			var texture_size = max(sprite.texture.get_width(), sprite.texture.get_height())
			sprite.scale = Vector2.ONE * (target_size / texture_size)


func _ready():
	randomize()

	# Load sound effects
	load_sfx()
	validate_asset_paths()
	# start_gameplay_music()

	if news_feed_label != null:
		news_feed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		news_feed_label.clip_text = false
		news_feed_label.custom_minimum_size = Vector2(650, 60)

	if status_label != null:
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_label.clip_text = true

	if not GameState.load_requested:
		player_count = GameState.selected_player_count

	setup_player_nodes()
	apply_player_plane_sprites()
	setup_layering()
	create_board_backdrop_panel()
	add_board_background()

	if board is Line2D:
		board.closed = true
		board.width = 10.0
		board.default_color = Color(1, 1, 1, 0.35)

	get_viewport().size_changed.connect(layout_board_to_screen)
	get_viewport().size_changed.connect(layout_ui)

	if GameState.load_requested:
		GameState.load_requested = false

		var loaded = load_game()

		if not loaded:
			generate_new_map(true)
			layout_board_to_screen()
			layout_ui()
			update_plane_position(true)
	else:
		generate_new_map(true)
		layout_board_to_screen()
		layout_ui()
		update_plane_position(true)

	update_score()
	update_instability_ui()

	# Initial news/message for players
	show_news("Satellite network online. Monitoring global crisis zones.")
	update_buttons()
	update_quantum_ui()
	create_aid_selection_ui()
	create_crisis_icon_legend()
	check_game_state()
	update_status()

	update_aid_loadout_ui()
	update_crisis_legend_ui()
	update_current_aid_icon()
	create_event_card_ui()
	create_team_card_ui()
	create_move_card_ui()
	create_legend_ui()
	create_legend_button()
	update_team_card()

	if not GameState.load_requested:
		show_opening_briefing()

	connect_game_ui_buttons()
	style_buttons()


func _exit_tree():
	stop_gameplay_music()


# -----------------------------
# Board setup
# -----------------------------
func make_tile_polygon(radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var sides = 8

	for i in range(sides):
		var angle = -PI / 2.0 + TAU * float(i) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	return points


func color_with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func get_player_airport_slot(player_id: int) -> int:
	if player_count == 2:
		var slots = [0, 2]
		return slots[player_id]
	elif player_count == 3:
		var slots = [0, 1, 2]
		return slots[player_id]
	else:
		return player_id


func get_player_start_tile(player_id: int) -> int:
	if airport_entry_tiles.is_empty():
		return 0

	var airport_slot = get_player_airport_slot(player_id)
	return airport_entry_tiles[airport_slot]


func get_airport_slot_offset(player_id: int) -> Vector2:
	var offsets = [
		Vector2(-18, -18),
		Vector2(18, -18),
		Vector2(18, 18),
		Vector2(-18, 18)
	]

	return offsets[player_id % offsets.size()]


func get_player_airport_position(player_id: int) -> Vector2:
	if airport_positions.is_empty():
		if not tile_positions.is_empty():
			return tile_positions[player_positions[player_id]]
		return Vector2.ZERO

	var airport_slot = get_player_airport_slot(player_id)

	if airport_slot >= airport_positions.size():
		return airport_positions[0]

	return airport_positions[airport_slot] + get_airport_slot_offset(player_id)


func get_player_display_position(player_id: int) -> Vector2:
	if player_id < player_in_airport.size() and player_in_airport[player_id]:
		return get_player_airport_position(player_id)

	return tile_positions[player_positions[player_id]] + get_player_offset(player_id)


func is_airport_active(airport_id: int) -> bool:
	for i in range(player_count):
		if get_player_airport_slot(i) == airport_id:
			return true

	return false


func generate_airport_data():
	airport_entry_tiles.clear()
	airport_base_positions.clear()

	var count = base_tile_positions.size()

	if count < 12:
		return

	airport_entry_tiles.append(0)
	airport_entry_tiles.append(int(round(count * 0.25)) % count)
	airport_entry_tiles.append(int(round(count * 0.50)) % count)
	airport_entry_tiles.append(int(round(count * 0.75)) % count)

	for entry_index in airport_entry_tiles:
		var entry_pos = base_tile_positions[entry_index]
		var direction = entry_pos.normalized()

		if direction.length() < 0.01:
			direction = Vector2.RIGHT

		var airport_pos = entry_pos + direction.normalized() * airport_distance
		airport_base_positions.append(airport_pos)


func get_track_color(index: int) -> Color:
	if index in crisis_tiles:
		var severity = crisis_severity.get(index, 1)
		return get_crisis_color(severity)

	var airport_id = airport_entry_tiles.find(index)

	if airport_id != -1:
		return airport_colors[airport_id]

	return Color(0.55, 0.65, 0.78)


func create_airport_markers():
	for i in range(airport_positions.size()):
		var base_color = airport_colors[i]
		var active = is_airport_active(i)

		var main_alpha = 0.28 if active else 0.12
		var slot_alpha = 0.50 if active else 0.20
		var label_alpha = 1.0 if active else 0.45

		var airport_position = clamp_position_to_screen(airport_positions[i], 75.0)
		airport_positions[i] = airport_position

		# Main airport body
		var airport = Polygon2D.new()
		airport.polygon = make_tile_polygon(tile_radius * 2.4)
		airport.position = airport_position
		airport.color = color_with_alpha(base_color, main_alpha)
		airport.z_index = 1
		board.add_child(airport)

		# Smaller slot markers inside airport
		var slot_offsets = [
			Vector2(-18, -18),
			Vector2(18, -18),
			Vector2(18, 18),
			Vector2(-18, 18)
		]

		for s in range(slot_offsets.size()):
			var slot = Polygon2D.new()
			slot.polygon = make_tile_polygon(tile_radius * 0.55)
			slot.position = airport_position + slot_offsets[s]
			slot.color = color_with_alpha(base_color, slot_alpha)
			slot.z_index = 2
			board.add_child(slot)

		# Shorter airport label
		var label = Label.new()
		label.text = "A%d" % (i + 1)
		label.position = airport_position + Vector2(-12, -10)
		label.modulate = Color(1, 1, 1, label_alpha)
		label.z_index = 4
		board.add_child(label)


func create_board_tiles():
	for child in board.get_children():
		child.queue_free()

	board_tiles.clear()
	board_tile_labels.clear()
	crisis_icon_nodes.clear()
	crisis_icon_types.clear()
	crisis_glow_nodes.clear()

	create_board_route_line()

	for i in range(tile_positions.size()):
		var tile = Polygon2D.new()
		tile.polygon = make_tile_polygon(tile_radius)
		tile.position = tile_positions[i]
		tile.z_index = 2

		tile.color = get_track_color(i)

		board.add_child(tile)
		board_tiles.append(tile)

		var tile_label = Label.new()
		tile_label.position = tile_positions[i] + Vector2(-10, -12)
		tile_label.z_index = 3
		tile_label.modulate = Color.WHITE

		if i in crisis_tiles:
			var label_severity = crisis_severity.get(i, 1)
			var crisis_type = crisis_types.get(i, "Unknown")

			if has_crisis_icon_asset(crisis_type):
				tile_label.text = "!" + str(label_severity)
				tile_label.position = tile_positions[i] + Vector2(-7, 7)
			else:
				tile_label.text = "!" + str(label_severity) + "\n" + get_crisis_short_name(crisis_type)
				tile_label.position = tile_positions[i] + Vector2(-13, -13)

			tile_label.add_theme_font_size_override("font_size", 12)
			tile_label.z_index = 25
		elif i in airport_entry_tiles:
			var airport_id = airport_entry_tiles.find(i)
			tile_label.text = "P" + str(airport_id + 1)
		else:
			tile_label.text = ""

		board.add_child(tile_label)
		board_tile_labels.append(tile_label)

	create_airport_markers()
	refresh_all_crisis_icons()
	refresh_all_crisis_glows()


func add_board_background():
	if board_background != null:
		return

	if not ResourceLoader.exists(BOARD_BACKGROUND_PATH):
		print("Missing board background: ", BOARD_BACKGROUND_PATH)
		return

	var screen_size = get_viewport_rect().size

	var play_area = Rect2(
		Vector2(LEFT_HUD_WIDTH, TOP_MARGIN),
		Vector2(
			screen_size.x - LEFT_HUD_WIDTH - RIGHT_HUD_WIDTH - SCREEN_PADDING,
			screen_size.y - TOP_MARGIN - BOTTOM_BAR_HEIGHT
		)
	)

	board_background = Sprite2D.new()
	board_background.name = "BoardBackground"
	board_background.texture = load(BOARD_BACKGROUND_PATH)
	board_background.centered = true
	board_background.position = play_area.position + play_area.size / 2.0
	board_background.z_index = -100

	add_child(board_background)
	move_child(board_background, 0)

	if board_background.texture != null:
		var texture_width = board_background.texture.get_width()
		var texture_height = board_background.texture.get_height()

		var scale_x = play_area.size.x / texture_width
		var scale_y = play_area.size.y / texture_height

		var final_scale = max(scale_x, scale_y)
		board_background.scale = Vector2(final_scale, final_scale)

	board_background.modulate = Color(0.55, 0.72, 0.9, 0.16)


func create_board_backdrop_panel():
	var screen_size = get_viewport_rect().size

	var play_area = Rect2(
		Vector2(LEFT_HUD_WIDTH, TOP_MARGIN),
		Vector2(
			screen_size.x - LEFT_HUD_WIDTH - RIGHT_HUD_WIDTH - SCREEN_PADDING,
			screen_size.y - TOP_MARGIN - BOTTOM_BAR_HEIGHT
		)
	)

	if board_backdrop_panel == null:
		board_backdrop_panel = Panel.new()
		board_backdrop_panel.name = "BoardBackdropPanel"
		add_child(board_backdrop_panel)
		move_child(board_backdrop_panel, 0)

	board_backdrop_panel.position = play_area.position - Vector2(10, 10)
	board_backdrop_panel.size = play_area.size + Vector2(20, 20)
	board_backdrop_panel.z_index = -90
	board_backdrop_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.04, 0.09, 0.58)
	style.border_color = Color(0.2, 0.65, 1.0, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)

	board_backdrop_panel.add_theme_stylebox_override("panel", style)


func create_board_route_line():
	if board == null:
		return

	if board_route_line != null:
		board_route_line.queue_free()

	board_route_line = Line2D.new()
	board_route_line.name = "BoardRouteLine"
	board_route_line.width = 5.0
	board_route_line.default_color = Color(0.2, 0.75, 1.0, 0.45)
	board_route_line.z_index = -5
	board_route_line.joint_mode = Line2D.LINE_JOINT_ROUND
	board_route_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	board_route_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	for i in range(tile_positions.size()):
		board_route_line.add_point(tile_positions[i])

	if tile_positions.size() > 0:
		board_route_line.add_point(tile_positions[0])

	board.add_child(board_route_line)
	board.move_child(board_route_line, 0)


func has_crisis_icon_asset(crisis_type: String) -> bool:
	if not crisis_icon_paths.has(crisis_type):
		return false

	var path = crisis_icon_paths[crisis_type]
	return ResourceLoader.exists(path)


func is_active_crisis_tile(tile_id: int) -> bool:
	if not crisis_tiles.has(tile_id):
		return false

	if crisis_severity.get(tile_id, 0) <= 0:
		return false

	if not crisis_types.has(tile_id):
		return false

	return true


func remove_crisis_icon(tile_id: int):
	if crisis_icon_nodes.has(tile_id):
		var old_icon = crisis_icon_nodes[tile_id]
		if is_instance_valid(old_icon):
			old_icon.queue_free()

	crisis_icon_nodes.erase(tile_id)
	crisis_icon_types.erase(tile_id)

	var old_named_icon = board.get_node_or_null("CrisisIcon_%d" % tile_id)
	if old_named_icon != null:
		old_named_icon.queue_free()


func add_crisis_icon(tile_id: int) -> bool:
	if not is_active_crisis_tile(tile_id):
		remove_crisis_icon(tile_id)
		return false

	var crisis_type = crisis_types.get(tile_id, "Unknown")

	if not crisis_icon_paths.has(crisis_type):
		print("No crisis icon mapping for: ", crisis_type)
		return false

	var path = crisis_icon_paths[crisis_type]

	if not ResourceLoader.exists(path):
		print("Missing crisis icon file: ", path)
		return false

	if crisis_icon_nodes.has(tile_id):
		var existing_icon = crisis_icon_nodes[tile_id]
		if is_instance_valid(existing_icon) and crisis_icon_types.get(tile_id, "") == crisis_type:
			return true

	remove_crisis_icon(tile_id)

	var icon = Sprite2D.new()
	icon.name = "CrisisIcon_%d" % tile_id
	icon.texture = load(path)
	icon.centered = true
	icon.position = tile_positions[tile_id] + Vector2(0, -8)
	icon.z_index = 20

	if icon.texture != null:
		var target_size = 22.0
		var texture_size = max(icon.texture.get_width(), icon.texture.get_height())
		icon.scale = Vector2.ONE * (target_size / texture_size)

	board.add_child(icon)

	crisis_icon_nodes[tile_id] = icon
	crisis_icon_types[tile_id] = crisis_type

	return true


func refresh_crisis_icon(tile_id: int):
	if is_active_crisis_tile(tile_id):
		add_crisis_icon(tile_id)
	else:
		remove_crisis_icon(tile_id)

	refresh_crisis_glow(tile_id)


func refresh_all_crisis_icons():
	for tile_id in crisis_icon_nodes.keys().duplicate():
		if not is_active_crisis_tile(tile_id):
			remove_crisis_icon(tile_id)

	for tile_id in crisis_tiles:
		refresh_crisis_icon(tile_id)

	refresh_all_crisis_glows()


func add_crisis_glow(tile_id: int):
	if tile_id < 0 or tile_id >= tile_positions.size():
		return

	if crisis_glow_nodes.has(tile_id):
		var existing_glow = crisis_glow_nodes[tile_id]
		if is_instance_valid(existing_glow):
			return

	var glow = Polygon2D.new()
	glow.name = "CrisisGlow_%d" % tile_id
	glow.position = tile_positions[tile_id]
	glow.z_index = 3
	glow.color = Color(1.0, 0.25, 0.1, 0.28)

	var points = []
	var radius = 28.0
	var sides = 32

	for i in range(sides):
		var angle = TAU * float(i) / float(sides)
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	glow.polygon = points
	board.add_child(glow)
	crisis_glow_nodes[tile_id] = glow

	var tween = create_tween()
	tween.tween_property(glow, "scale", Vector2(1.18, 1.18), 0.7)
	tween.tween_property(glow, "scale", Vector2.ONE, 0.7)


func remove_crisis_glow(tile_id: int):
	if crisis_glow_nodes.has(tile_id):
		var glow = crisis_glow_nodes[tile_id]
		if is_instance_valid(glow):
			glow.queue_free()

	crisis_glow_nodes.erase(tile_id)


func refresh_crisis_glow(tile_id: int):
	if is_active_crisis_tile(tile_id):
		add_crisis_glow(tile_id)
	else:
		remove_crisis_glow(tile_id)


func refresh_all_crisis_glows():
	for tile_id in crisis_glow_nodes.keys().duplicate():
		if not is_active_crisis_tile(tile_id):
			remove_crisis_glow(tile_id)

	for tile_id in crisis_tiles:
		refresh_crisis_glow(tile_id)


func update_current_aid_icon():
	if current_aid_icon == null:
		current_aid_icon = Sprite2D.new()
		current_aid_icon.name = "CurrentAidIcon"
		current_aid_icon.z_index = 50
		add_child(current_aid_icon)

	var screen_size = get_viewport_rect().size
	current_aid_icon.position = Vector2(screen_size.x - 45, 154)

	if current_player >= player_aid_loadouts.size():
		current_aid_icon.visible = false
		return

	var aid_name = player_aid_loadouts[current_player]

	if not aid_icon_paths.has(aid_name):
		current_aid_icon.visible = false
		return

	var path = aid_icon_paths[aid_name]

	if not ResourceLoader.exists(path):
		current_aid_icon.visible = false
		print("Missing aid icon: ", path)
		return

	current_aid_icon.texture = load(path)
	current_aid_icon.visible = true
	current_aid_icon.centered = true

	if current_aid_icon.texture != null:
		var target_size = 34.0
		var texture_size = max(
			current_aid_icon.texture.get_width(),
			current_aid_icon.texture.get_height()
		)
		current_aid_icon.scale = Vector2.ONE * (target_size / texture_size)


func validate_asset_paths():
	var missing_assets := []

	for path in player_plane_texture_paths:
		if not ResourceLoader.exists(path):
			missing_assets.append(path)

	for path in crisis_icon_paths.values():
		if not ResourceLoader.exists(path):
			missing_assets.append(path)

	for path in aid_icon_paths.values():
		if not ResourceLoader.exists(path):
			missing_assets.append(path)

	for path in sfx_paths.values():
		if not ResourceLoader.exists(path):
			missing_assets.append(path)

	if missing_assets.size() > 0:
		print("Missing assets:")
		for path in missing_assets:
			print("- ", path)
	else:
		print("All checked assets loaded successfully.")


func hide_temporary_ui_cards():
	if event_card_panel != null:
		event_card_panel.visible = false

	if move_card_panel != null:
		move_card_panel.visible = false

	if aid_selection_panel != null:
		aid_selection_panel.visible = false

	if briefing_layer != null:
		briefing_layer.visible = false


func update_ui():
	update_aid_loadout_ui()
	update_current_aid_icon()
	update_team_card()


func get_tile_keys() -> Array:
	var keys := []

	for i in range(tile_positions.size()):
		keys.append(i)

	return keys


func fit_board_to_safe_area():
	var screen_size = get_viewport_rect().size

	var play_area = Rect2(
		Vector2(LEFT_HUD_WIDTH, TOP_MARGIN),
		Vector2(
			screen_size.x - LEFT_HUD_WIDTH - RIGHT_HUD_WIDTH - SCREEN_PADDING,
			screen_size.y - TOP_MARGIN - BOTTOM_BAR_HEIGHT
		)
	)

	var keys = get_tile_keys()
	if keys.is_empty():
		return

	var min_pos = tile_positions[keys[0]]
	var max_pos = tile_positions[keys[0]]

	for key in keys:
		var p = tile_positions[key]
		min_pos.x = min(min_pos.x, p.x)
		min_pos.y = min(min_pos.y, p.y)
		max_pos.x = max(max_pos.x, p.x)
		max_pos.y = max(max_pos.y, p.y)

	var board_size = max_pos - min_pos
	if board_size.x <= 0 or board_size.y <= 0:
		return

	var board_center = min_pos + board_size / 2.0
	var safe_center = play_area.position + play_area.size / 2.0

	var scale_factor = min(
		play_area.size.x / board_size.x,
		play_area.size.y / board_size.y
	) * 0.98

	for key in keys:
		tile_positions[key] = safe_center + (tile_positions[key] - board_center) * scale_factor

	for i in range(airport_positions.size()):
		airport_positions[i] = safe_center + (airport_positions[i] - board_center) * scale_factor

	if board_background != null:
		board_background.position = safe_center


func clamp_position_to_screen(pos: Vector2, padding := 70.0) -> Vector2:
	var screen_size = get_viewport_rect().size

	return Vector2(
		clamp(pos.x, padding, screen_size.x - padding),
		clamp(pos.y, padding, screen_size.y - padding - BOTTOM_BAR_HEIGHT + 30.0)
	)


func clamp_all_airports_to_screen():
	for i in range(airport_positions.size()):
		airport_positions[i] = clamp_position_to_screen(airport_positions[i], 80.0)


func layout_board_to_screen():
	if base_tile_positions.is_empty():
		return

	var screen_size = get_viewport_rect().size
	var min_x = base_tile_positions[0].x
	var max_x = base_tile_positions[0].x
	var min_y = base_tile_positions[0].y
	var max_y = base_tile_positions[0].y

	for pos in base_tile_positions:
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)

	var board_size = Vector2(max_x - min_x, max_y - min_y)
	var map_scale = min(
		screen_size.x / board_size.x,
		screen_size.y / board_size.y
	) * board_zoom

	tile_positions.clear()

	var board_center = Vector2(
		(min_x + max_x) / 2.0,
		(min_y + max_y) / 2.0
	)

	var screen_center = Vector2(
		screen_size.x / 2.0,
		screen_size.y / 2.0
	)

	if board_background != null:
		board_background.position = screen_center

	for pos in base_tile_positions:
		var centered_pos = pos - board_center
		var scaled_pos = centered_pos * map_scale
		tile_positions.append(screen_center + scaled_pos)

	airport_positions.clear()

	for pos in airport_base_positions:
		var centered_pos = pos - board_center
		var scaled_pos = centered_pos * map_scale
		airport_positions.append(screen_center + scaled_pos)

	fit_board_to_safe_area()

	if board != null:
		board.points = tile_positions
		board.queue_redraw()

	clamp_all_airports_to_screen()
	create_board_tiles()
	update_plane_position(true)

	if quantum_active:
		create_quantum_ghosts()
		update_quantum_ghost_visuals()

	if entanglement_active:
		create_entangled_ghosts()
		update_entangled_ghost_visuals()

func layout_ui():
	var screen_size = get_viewport_rect().size
	create_board_backdrop_panel()
	create_right_hud_panel()

	var left_panel_x = 24.0
	var left_panel_width = 240.0
	var right_x = screen_size.x - RIGHT_HUD_WIDTH + 36

	# Title at top-left instead of top-center
	var title_label = get_node_or_null("UI/TitleLabel")
	if title_label != null:
		title_label.position = Vector2(24, 18)
		title_label.size = Vector2(480, 40)

	# Score block on the top-right
	if score_label != null:
		score_label.position = Vector2(right_x, 32)
		score_label.size = Vector2(360, 28)

	if instability_label != null:
		instability_label.position = Vector2(right_x, 82)
		instability_label.size = Vector2(360, 28)

	if aid_loadout_label != null:
		aid_loadout_label.position = Vector2(right_x, 132)
		aid_loadout_label.size = Vector2(330, 100)
		aid_loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if news_feed_label != null:
		news_feed_label.position = Vector2(24, 90)
		news_feed_label.size = Vector2(310, 42)
		news_feed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if quantum_probability_label != null:
		quantum_probability_label.position = Vector2(24, 155)
		quantum_probability_label.size = Vector2(310, 42)

	if quantum_state_label != null:
		quantum_state_label.position = Vector2(24, 365)
		quantum_state_label.size = Vector2(310, 42)

	if crisis_legend_label != null:
		crisis_legend_label.position = Vector2(left_panel_x, 390)
		crisis_legend_label.size = Vector2(left_panel_width, 220)

	if status_label != null:
		status_label.position = Vector2(360, screen_size.y - 30)
		status_label.size = Vector2(screen_size.x - 760, 24)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var button_bar = get_node_or_null("UI/ButtonBar")
	if button_bar != null:
		button_bar.position = Vector2(
			screen_size.x / 2.0 - button_bar.size.x / 2.0,
			screen_size.y - 58
		)

	if impact_report_panel != null:
		impact_report_panel.position = Vector2(
			screen_size.x / 2.0 - 250,
			screen_size.y / 2.0 - 210
		)
		impact_report_panel.size = Vector2(500, 420)

	if impact_report_label != null:
		impact_report_label.position = Vector2(20, 20)
		impact_report_label.size = Vector2(460, 380)

	if end_game_popup != null:
		end_game_popup.position = Vector2(
			screen_size.x / 2.0 - 280,
			screen_size.y / 2.0 - 230
		)
		end_game_popup.size = Vector2(560, 460)

	if end_game_title_label != null:
		end_game_title_label.position = Vector2(24, 20)
		end_game_title_label.size = Vector2(512, 40)

	if end_game_report_label != null:
		end_game_report_label.position = Vector2(24, 70)
		end_game_report_label.size = Vector2(512, 280)

	if end_game_new_game_button != null:
		end_game_new_game_button.position = Vector2(110, 380)
		end_game_new_game_button.size = Vector2(140, 44)

	if end_game_main_menu_button != null:
		end_game_main_menu_button.position = Vector2(310, 380)
		end_game_main_menu_button.size = Vector2(140, 44)

func setup_layering():
	if board != null:
		board.z_index = 0

	for player_plane in player_planes:
		if player_plane != null:
			player_plane.z_index = 20
# Player movement and UI

func get_player_offset(player_id: int) -> Vector2:
	var offsets = [
		Vector2(-16, -16),
		Vector2(16, -16),
		Vector2(16, 16),
		Vector2(-16, 16)
	]

	return offsets[player_id % offsets.size()]


func animate_player_to_tile(player_id: int, tile_id: int):
	if player_id < 0 or player_id >= player_planes.size():
		return

	if tile_id < 0 or tile_id >= tile_positions.size():
		return

	var plane_node = player_planes[player_id]
	if plane_node == null:
		return

	var target_pos = tile_positions[tile_id] + get_player_offset(player_id)
	var tween = create_tween()

	tween.set_parallel(false)
	tween.tween_property(
		plane_node,
		"position",
		target_pos,
		0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		plane_node,
		"scale",
		Vector2(1.18, 1.18),
		0.08
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		plane_node,
		"scale",
		Vector2.ONE,
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func pulse_node(node: CanvasItem, pulse_color := Color(1.0, 0.9, 0.3, 1.0)):
	if node == null:
		return

	var original_modulate = node.modulate
	var tween = create_tween()

	tween.tween_property(node, "modulate", pulse_color, 0.12)
	tween.tween_property(node, "modulate", original_modulate, 0.18)


func shake_node(node: Node2D, strength := 6.0, duration := 0.22):
	if node == null:
		return

	var original_pos = node.position
	var tween = create_tween()

	var steps = 6
	for i in range(steps):
		var offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		tween.tween_property(
			node,
			"position",
			original_pos + offset,
			duration / float(steps)
		)

	tween.tween_property(node, "position", original_pos, 0.05)


func update_plane_positions(instant := false):
	if tile_positions.is_empty():
		return

	if instant:
		for i in range(player_count):
			if i >= player_planes.size():
				continue

			player_planes[i].position = get_player_display_position(i)
	else:
		for i in range(player_count):
			if i >= player_planes.size():
				continue

			if i < player_in_airport.size() and player_in_airport[i]:
				player_planes[i].position = get_player_display_position(i)
			else:
				animate_player_to_tile(i, player_positions[i])


func update_plane_position(instant := false):
	update_plane_positions(instant)


func update_score():
	var text = "Aid"

	for i in range(player_count):
		text += " | P%d:%d" % [i + 1, player_scores[i]]

	text += " | Goal:%d" % target_score

	score_label.text = text


func update_instability_ui():
	if instability_label != null:
		instability_label.text = "Global Instability: %d / %d" % [
			global_instability,
			max_global_instability
		]


func update_buttons():
	quantum_button.disabled = quantum_active or game_finished
	measure_button.disabled = not quantum_active or game_finished

	if move_button != null:
		move_button.disabled = quantum_active or game_finished

	if stabilize_button != null:
		# StabilizeButton is now Amplify.
		stabilize_button.disabled = not quantum_active or game_finished or amplification_used

	if boost_button != null:
		# BoostButton is now Oracle.
		boost_button.disabled = not quantum_active or game_finished or oracle_used

	if entangle_button != null:
		entangle_button.disabled = not quantum_active or game_finished or entangle_used

	if save_game_button != null:
		save_game_button.disabled = quantum_active

	if change_aid_button != null:
		change_aid_button.disabled = quantum_active or game_finished


func set_gameplay_buttons_enabled(enabled: bool):
	if move_button != null:
		move_button.disabled = not enabled

	if quantum_button != null:
		quantum_button.disabled = not enabled

	if measure_button != null:
		measure_button.disabled = not enabled

	if stabilize_button != null:
		stabilize_button.disabled = not enabled

	if boost_button != null:
		boost_button.disabled = not enabled

	if entangle_button != null:
		entangle_button.disabled = not enabled

	if change_aid_button != null:
		change_aid_button.disabled = not enabled

	if save_game_button != null:
		save_game_button.disabled = not enabled


func create_right_hud_panel():
	var screen_size = get_viewport_rect().size

	if right_hud_panel == null:
		right_hud_panel = Panel.new()
		right_hud_panel.name = "RightHUDPanel"
		add_child(right_hud_panel)

	right_hud_panel.position = Vector2(screen_size.x - RIGHT_HUD_WIDTH + 16, 14)
	right_hud_panel.size = Vector2(RIGHT_HUD_WIDTH - 34, 260)
	right_hud_panel.z_index = 80

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.04, 0.09, 0.82)
	style.border_color = Color(0.2, 0.75, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	right_hud_panel.add_theme_stylebox_override("panel", style)


func update_status():
	if not game_finished and not quantum_active:
		status_label.text = get_team_turn_message(current_player)

	update_aid_loadout_ui()
	update_team_card()


func update_aid_loadout_ui():
	if aid_loadout_label == null:
		return

	var text = "Aid Loadouts:\n"

	for i in range(player_count):
		if i >= player_aid_loadouts.size():
			continue

		var marker = "▶ " if i == current_player else "   "
		text += "%sP%d: %s\n" % [
			marker,
			i + 1,
			player_aid_loadouts[i]
		]

	aid_loadout_label.text = text
	update_current_aid_icon()


func create_aid_selection_ui():
	if aid_selection_layer != null:
		return

	aid_selection_layer = CanvasLayer.new()
	aid_selection_layer.name = "AidSelectionLayer"
	add_child(aid_selection_layer)

	aid_selection_panel = PanelContainer.new()
	aid_selection_panel.name = "AidSelectionPanel"
	aid_selection_panel.position = Vector2(430, 150)
	aid_selection_panel.custom_minimum_size = Vector2(420, 390)
	aid_selection_panel.visible = false
	aid_selection_layer.add_child(aid_selection_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.07, 0.13, 0.96)
	panel_style.border_color = Color(0.4, 0.9, 1.0, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	aid_selection_panel.add_theme_stylebox_override("panel", panel_style)

	var box = VBoxContainer.new()
	box.name = "AidSelectionBox"
	box.add_theme_constant_override("separation", 10)
	aid_selection_panel.add_child(box)

	aid_selection_title = Label.new()
	aid_selection_title.text = "Choose Aid"
	aid_selection_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aid_selection_title.add_theme_font_size_override("font_size", 24)
	box.add_child(aid_selection_title)

	aid_selection_buttons.clear()

	for aid_name in possible_aid_loadouts:
		var button = Button.new()
		button.text = aid_name
		button.custom_minimum_size = Vector2(320, 42)
		button.add_theme_font_size_override("font_size", 18)

		button.pressed.connect(_on_aid_option_pressed.bind(aid_name))

		box.add_child(button)
		aid_selection_buttons.append(button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(320, 42)
	cancel_button.add_theme_font_size_override("font_size", 18)
	cancel_button.pressed.connect(close_aid_selection_ui)
	box.add_child(cancel_button)


func open_aid_selection_ui():
	if game_finished or quantum_active:
		return

	if current_player >= player_aid_loadouts.size():
		return

	create_aid_selection_ui()

	aid_selection_title.text = "Choose Aid for %s" % get_team_name(current_player)

	var current_aid = player_aid_loadouts[current_player]

	for button in aid_selection_buttons:
		var base_text = button.text.replace("✓ ", "")
		if base_text == current_aid:
			button.text = "✓ " + current_aid
		else:
			button.text = base_text

	aid_selection_panel.visible = true


func close_aid_selection_ui():
	if aid_selection_panel != null:
		aid_selection_panel.visible = false


func create_legend_ui():
	if legend_layer != null:
		return

	legend_layer = CanvasLayer.new()
	legend_layer.name = "LegendLayer"
	add_child(legend_layer)

	legend_overlay = ColorRect.new()
	legend_overlay.name = "LegendOverlay"
	legend_overlay.color = Color(0, 0, 0, 0.55)
	legend_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	legend_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	legend_overlay.visible = false
	legend_layer.add_child(legend_overlay)

	legend_panel = PanelContainer.new()
	legend_panel.name = "LegendPanel"
	legend_panel.position = Vector2(390, 115)
	legend_panel.custom_minimum_size = Vector2(500, 430)
	legend_overlay.add_child(legend_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.13, 0.97)
	style.border_color = Color(0.4, 0.9, 1.0, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	legend_panel.add_theme_stylebox_override("panel", style)

	var box = VBoxContainer.new()
	box.name = "LegendBox"
	box.add_theme_constant_override("separation", 14)
	legend_panel.add_child(box)

	var title = Label.new()
	title.text = "CRISIS RESPONSE LEGEND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var body = Label.new()
	body.text = (
		"Match each crisis with the correct aid type:\n\n" +
		"Flood  →  Water Rescue\n" +
		"Wildfire  →  Fire Response\n" +
		"Medical  →  Medical Supplies\n" +
		"Infrastructure  →  Repair Team\n" +
		"Food Shortage  →  Food Aid\n\n" +
		"Changing aid costs a turn.\n" +
		"Correct aid reduces or clears crisis severity.\n" +
		"Global instability rises when crises worsen."
	)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.custom_minimum_size = Vector2(440, 260)
	box.add_child(body)

	legend_close_button = Button.new()
	legend_close_button.text = "Close"
	legend_close_button.custom_minimum_size = Vector2(180, 44)
	legend_close_button.add_theme_font_size_override("font_size", 20)
	legend_close_button.pressed.connect(close_legend_ui)

	var button_holder = HBoxContainer.new()
	button_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	button_holder.add_child(legend_close_button)
	box.add_child(button_holder)


func open_legend_ui():
	create_legend_ui()

	if legend_overlay != null:
		legend_overlay.visible = true

	if has_method("play_sfx"):
		play_sfx("button_click")


func close_legend_ui():
	if legend_overlay != null:
		legend_overlay.visible = false

	if has_method("play_sfx"):
		play_sfx("button_click")


func create_legend_button():
	if legend_button != null:
		return

	legend_button = Button.new()
	legend_button.name = "LegendButton"
	legend_button.text = "Legend"
	legend_button.custom_minimum_size = Vector2(110, 34)
	legend_button.position = Vector2(24, 24)
	legend_button.add_theme_font_size_override("font_size", 16)
	legend_button.pressed.connect(open_legend_ui)

	add_child(legend_button)

	if has_method("connect_button_sound"):
		connect_button_sound(legend_button)

	if has_method("connect_button_hover_sound"):
		connect_button_hover_sound(legend_button)


func _on_aid_option_pressed(aid_name: String):
	if current_player >= player_aid_loadouts.size():
		return

	player_aid_loadouts[current_player] = aid_name

	status_label.text = "%s equipped %s." % [
		get_team_name(current_player),
		aid_name
	]

	close_aid_selection_ui()
	update_aid_loadout_ui()
	update_current_aid_icon()

	end_turn()


func create_opening_briefing_ui():
	if briefing_layer != null:
		return

	briefing_layer = CanvasLayer.new()
	briefing_layer.name = "OpeningBriefingLayer"
	add_child(briefing_layer)

	briefing_overlay = ColorRect.new()
	briefing_overlay.name = "OpeningBriefingOverlay"
	briefing_overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	briefing_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	briefing_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	briefing_layer.add_child(briefing_overlay)

	briefing_panel = PanelContainer.new()
	briefing_panel.name = "OpeningBriefingPanel"
	briefing_panel.position = Vector2(340, 135)
	briefing_panel.custom_minimum_size = Vector2(600, 360)
	briefing_overlay.add_child(briefing_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.07, 0.13, 0.96)
	panel_style.border_color = Color(0.4, 0.9, 1.0, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 26
	panel_style.content_margin_bottom = 26
	briefing_panel.add_theme_stylebox_override("panel", panel_style)

	var box = VBoxContainer.new()
	box.name = "BriefingBox"
	box.add_theme_constant_override("separation", 18)
	briefing_panel.add_child(box)

	briefing_title = Label.new()
	briefing_title.name = "BriefingTitle"
	briefing_title.text = "MISSION BRIEFING"
	briefing_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	briefing_title.add_theme_font_size_override("font_size", 34)
	box.add_child(briefing_title)

	briefing_body = Label.new()
	briefing_body.name = "BriefingBody"
	briefing_body.text = (
		"Operation Crisis Skies has been activated.\n\n" +
		"Climate disasters are spreading across the response map faster than normal relief systems can manage.\n\n" +
		"Your teams must move between crisis zones, equip the correct aid, and stabilize affected regions before global instability reaches critical levels.\n\n" +
		"Quantum planning tools can improve your odds, but they cannot remove risk completely.\n\n" +
		"Coordinate carefully. Every turn matters."
	)
	briefing_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	briefing_body.add_theme_font_size_override("font_size", 18)
	briefing_body.custom_minimum_size = Vector2(520, 190)
	box.add_child(briefing_body)

	briefing_button = Button.new()
	briefing_button.name = "BeginMissionButton"
	briefing_button.text = "Begin Mission"
	briefing_button.custom_minimum_size = Vector2(230, 50)
	briefing_button.add_theme_font_size_override("font_size", 22)
	briefing_button.pressed.connect(close_opening_briefing)

	var button_holder = HBoxContainer.new()
	button_holder.name = "BriefingButtonHolder"
	button_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	button_holder.add_child(briefing_button)
	box.add_child(button_holder)

	briefing_layer.visible = false


func show_opening_briefing():
	create_opening_briefing_ui()

	briefing_active = true
	briefing_layer.visible = true
	set_gameplay_buttons_enabled(false)

	if status_label != null:
		status_label.text = "Mission briefing active. Review the objective before deployment."


func close_opening_briefing():
	briefing_active = false

	if briefing_layer != null:
		briefing_layer.visible = false

	set_gameplay_buttons_enabled(true)

	if status_label != null:
		status_label.text = get_team_turn_message(current_player)
		return

	team_card_layer = CanvasLayer.new()
	team_card_layer.name = "TeamCardLayer"
	add_child(team_card_layer)

	team_card_panel = PanelContainer.new()
	team_card_panel.name = "TeamCardPanel"
	var screen_size = get_viewport_rect().size
	team_card_panel.position = Vector2(screen_size.x - RIGHT_HUD_WIDTH + 34, 300)
	team_card_panel.custom_minimum_size = Vector2(RIGHT_HUD_WIDTH - 70, 150)
	team_card_layer.add_child(team_card_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.06, 0.12, 0.88)
	panel_style.border_color = Color(0.35, 0.85, 1.0, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	team_card_panel.add_theme_stylebox_override("panel", panel_style)

	var row = HBoxContainer.new()
	row.name = "TeamCardRow"
	row.add_theme_constant_override("separation", 12)
	team_card_panel.add_child(row)

	team_card_icon = TextureRect.new()
	team_card_icon.name = "TeamIcon"
	team_card_icon.custom_minimum_size = Vector2(54, 54)
	team_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(team_card_icon)

	var text_box = VBoxContainer.new()
	text_box.name = "TeamTextBox"
	text_box.custom_minimum_size = Vector2(230, 90)
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)

	team_card_name = Label.new()
	team_card_name.name = "TeamName"
	team_card_name.add_theme_font_size_override("font_size", 22)
	team_card_name.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0, 1.0))
	text_box.add_child(team_card_name)

	team_card_role = Label.new()
	team_card_role.name = "TeamRole"
	team_card_role.add_theme_font_size_override("font_size", 15)
	text_box.add_child(team_card_role)

	team_card_motto = Label.new()
	team_card_motto.name = "TeamMotto"
	team_card_motto.add_theme_font_size_override("font_size", 13)
	team_card_motto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	team_card_motto.custom_minimum_size = Vector2(220, 45)
	text_box.add_child(team_card_motto)

func create_team_card_ui():
	if team_card_layer != null:
		return

	team_card_layer = CanvasLayer.new()
	team_card_layer.name = "TeamCardLayer"
	add_child(team_card_layer)

	team_card_panel = PanelContainer.new()
	team_card_panel.name = "TeamCardPanel"

	var screen_size = get_viewport_rect().size
	team_card_panel.position = Vector2(screen_size.x - 370, 300)
	team_card_panel.custom_minimum_size = Vector2(330, 145)

	team_card_layer.add_child(team_card_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.06, 0.12, 0.88)
	panel_style.border_color = Color(0.35, 0.85, 1.0, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	team_card_panel.add_theme_stylebox_override("panel", panel_style)

	var row = HBoxContainer.new()
	row.name = "TeamCardRow"
	row.add_theme_constant_override("separation", 12)
	team_card_panel.add_child(row)

	team_card_icon = TextureRect.new()
	team_card_icon.name = "TeamIcon"
	team_card_icon.custom_minimum_size = Vector2(54, 54)
	team_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(team_card_icon)

	var text_box = VBoxContainer.new()
	text_box.name = "TeamTextBox"
	text_box.custom_minimum_size = Vector2(230, 90)
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)

	team_card_name = Label.new()
	team_card_name.name = "TeamName"
	team_card_name.add_theme_font_size_override("font_size", 19)
	text_box.add_child(team_card_name)

	team_card_role = Label.new()
	team_card_role.name = "TeamRole"
	team_card_role.add_theme_font_size_override("font_size", 14)
	text_box.add_child(team_card_role)

	team_card_motto = Label.new()
	team_card_motto.name = "TeamMotto"
	team_card_motto.add_theme_font_size_override("font_size", 13)
	team_card_motto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	team_card_motto.custom_minimum_size = Vector2(220, 45)
	text_box.add_child(team_card_motto)

func update_team_card():
	create_team_card_ui()

	if current_player < 0 or current_player >= team_names.size():
		return

	team_card_name.text = team_names[current_player]
	team_card_role.text = team_roles[current_player]
	team_card_motto.text = team_mottos[current_player]

	if current_player < player_plane_texture_paths.size():
		var path = player_plane_texture_paths[current_player]
		if ResourceLoader.exists(path):
			team_card_icon.texture = load(path)
			team_card_icon.visible = true
		else:
			team_card_icon.visible = false

	var tween = create_tween()
	tween.tween_property(team_card_panel, "scale", Vector2(1.04, 1.04), 0.08)
	tween.tween_property(team_card_panel, "scale", Vector2.ONE, 0.12)


func create_move_card_ui():
	if move_card_layer != null:
		return

	move_card_layer = CanvasLayer.new()
	move_card_layer.name = "MoveCardLayer"
	add_child(move_card_layer)

	move_card_panel = PanelContainer.new()
	move_card_panel.name = "MoveCardPanel"

	var screen_size = get_viewport_rect().size
	move_card_panel.position = Vector2(screen_size.x - 370, screen_size.y - 210)
	move_card_panel.custom_minimum_size = Vector2(315, 105)
	move_card_panel.visible = false
	move_card_layer.add_child(move_card_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.13, 0.94)
	style.border_color = Color(0.45, 0.9, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	move_card_panel.add_theme_stylebox_override("panel", style)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	move_card_panel.add_child(box)

	move_card_title = Label.new()
	move_card_title.text = "DEPLOYMENT"
	move_card_title.add_theme_font_size_override("font_size", 20)
	move_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(move_card_title)

	move_card_body = Label.new()
	move_card_body.text = ""
	move_card_body.add_theme_font_size_override("font_size", 15)
	move_card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	move_card_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_card_body.custom_minimum_size = Vector2(270, 45)
	box.add_child(move_card_body)


func show_move_card(player_id: int, steps: int):
	create_move_card_ui()

	var team_name = get_team_name(player_id)

	move_card_body.text = "%s moves %d sector%s." % [
		team_name,
		steps,
		"" if steps == 1 else "s"
	]

	move_card_panel.visible = true
	move_card_panel.modulate = Color(1, 1, 1, 1)
	move_card_panel.scale = Vector2(0.92, 0.92)

	var tween = create_tween()
	tween.tween_property(move_card_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	move_card_timer_id += 1
	var my_id = move_card_timer_id

	await get_tree().create_timer(2.0).timeout

	if my_id != move_card_timer_id:
		return

	move_card_panel.visible = false


func update_crisis_legend_ui():
	if crisis_legend_label == null:
		return

	crisis_legend_label.text = "Crisis Types:\n"
	crisis_legend_label.text += "FL = Flood\n"
	crisis_legend_label.text += "WF = Wildfire\n"
	crisis_legend_label.text += "MD = Medical\n"
	crisis_legend_label.text += "IN = Infrastructure\n"
	crisis_legend_label.text += "FD = Food Shortage\n\n"
	crisis_legend_label.text += "Aid Match Bonus:\n"
	crisis_legend_label.text += "Correct aid gives +1 point\n"
	crisis_legend_label.text += "and reduces instability."


func show_impact_report(result_text: String):
	if impact_report_shown:
		return

	impact_report_shown = true

	var report = ""
	report += "Humanitarian Impact Report\n\n"
	report += "%s\n\n" % result_text

	report += "Aid Delivered: %d\n" % total_aid_points_earned
	report += "Crises Resolved: %d\n" % crises_resolved_count
	report += "Perfect Aid Matches: %d\n" % perfect_response_count
	report += "Partial Responses: %d\n" % partial_response_count
	report += "Crises Escalated: %d\n" % crises_escalated_count
	report += "Instability Events: %d\n" % instability_events_count
	report += "Final Global Instability: %d / %d\n\n" % [
		global_instability,
		max_global_instability
	]

	report += "Mission Rank: %s\n\n" % get_mission_rank()

	for i in range(player_count):
		report += "%s Impact Score: %d\n" % [
			get_team_name(i),
			player_scores[i]
		]

	if impact_report_panel != null and impact_report_label != null:
		impact_report_panel.visible = true
		impact_report_label.text = report
	else:
		status_label.text = result_text


func show_end_game_popup(title_text: String, result_text: String):
	if impact_report_shown:
		return

	impact_report_shown = true
	show_final_results_screen(title_text, result_text)


func create_end_screen_ui():
	if end_screen_layer != null:
		return

	end_screen_layer = CanvasLayer.new()
	end_screen_layer.name = "EndScreenLayer"
	add_child(end_screen_layer)

	end_screen_panel = PanelContainer.new()
	end_screen_panel.name = "EndScreenPanel"
	end_screen_panel.position = Vector2(360, 120)
	end_screen_panel.custom_minimum_size = Vector2(560, 390)
	end_screen_panel.visible = false
	end_screen_layer.add_child(end_screen_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.06, 0.12, 0.96)
	panel_style.border_color = Color(0.4, 0.85, 1.0, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	end_screen_panel.add_theme_stylebox_override("panel", panel_style)

	var box = VBoxContainer.new()
	box.name = "EndScreenBox"
	box.add_theme_constant_override("separation", 16)
	end_screen_panel.add_child(box)

	end_screen_title = Label.new()
	end_screen_title.text = "MISSION COMPLETE"
	end_screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_screen_title.add_theme_font_size_override("font_size", 34)
	box.add_child(end_screen_title)

	end_screen_rank = Label.new()
	end_screen_rank.text = "Global Response Rating"
	end_screen_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_screen_rank.add_theme_font_size_override("font_size", 24)
	box.add_child(end_screen_rank)

	end_screen_stats = Label.new()
	end_screen_stats.text = ""
	end_screen_stats.add_theme_font_size_override("font_size", 18)
	end_screen_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_screen_stats)

	end_screen_outcome = Label.new()
	end_screen_outcome.text = ""
	end_screen_outcome.add_theme_font_size_override("font_size", 18)
	end_screen_outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_screen_outcome)

	var button_row = HBoxContainer.new()
	button_row.name = "EndScreenButtons"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	box.add_child(button_row)

	if end_game_new_game_button != null:
		end_game_new_game_button.reparent(button_row)
		end_game_new_game_button.visible = true
		end_game_new_game_button.text = "New Game"

	if end_game_main_menu_button != null:
		end_game_main_menu_button.reparent(button_row)
		end_game_main_menu_button.visible = true
		end_game_main_menu_button.text = "Main Menu"

	if end_game_popup != null:
		end_game_popup.visible = false


func get_final_response_rating() -> String:
	var unresolved_crises = crisis_tiles.size()

	if global_instability <= 2 and unresolved_crises <= 2:
		return "Excellent Response"

	if global_instability <= 5 and unresolved_crises <= 4:
		return "Stable Recovery"

	if global_instability <= 8:
		return "Partial Success"

	return "Critical Outcome"


func show_final_results_screen(title_text := "", result_text := ""):
	hide_temporary_ui_cards()
	create_end_screen_ui()

	var rating = get_final_response_rating()
	var unresolved_crises = crisis_tiles.size()
	var top_player = get_team_name(current_player)
	var top_score = -1

	for i in range(player_count):
		if i < player_scores.size() and player_scores[i] > top_score:
			top_score = player_scores[i]
			top_player = get_team_name(i)

	if title_text == "Shared Loss" or rating == "Critical Outcome":
		end_screen_title.text = "MISSION FAILED"
	else:
		end_screen_title.text = "MISSION COMPLETE"

	end_screen_rank.text = "Global Response Rating: " + rating

	end_screen_stats.text = (
		"Crises Resolved: %d\n" % crises_resolved_count +
		"Remaining Crises: %d\n" % unresolved_crises +
		"Global Instability: %d / %d\n" % [global_instability, max_global_instability] +
		"Instability Events: %d\n" % instability_events_count +
		"Quantum Tools Used: %d\n" % quantum_tools_used_count +
		"Top Relief Team: %s (%d impact)" % [top_player, max(top_score, 0)]
	)

	match rating:
		"Excellent Response":
			end_screen_outcome.text = "Outcome: Operation Crisis Skies succeeded. Most affected zones were stabilized before instability could spread further."
		"Stable Recovery":
			end_screen_outcome.text = "Outcome: The response network held together. Several regions still need support, but the crisis is under control."
		"Partial Success":
			end_screen_outcome.text = "Outcome: Relief teams prevented total collapse, but instability remains high across the map."
		"Critical Outcome":
			end_screen_outcome.text = "Outcome: The crisis network was overwhelmed. Response teams must regroup before a second operation can begin."

	if result_text != "":
		status_label.text = result_text

	end_screen_panel.visible = true
	play_sfx("win", -5.0)


func update_quantum_ui():
	if quantum_state_label != null:
		if quantum_active:
			var text = "Quantum Circuit: 3-qubit movement register active"

			if oracle_used:
				text += " | Oracle used"

			if amplification_used:
				text += " | Amplified"

			if entanglement_active:
				text += " | P%d linked with P%d" % [
					current_player + 1,
					get_entangled_player() + 1
				]

			quantum_state_label.text = text
		else:
			quantum_state_label.text = "Quantum Circuit: inactive"

	if quantum_probability_label != null:
		quantum_probability_label.text = get_formatted_quantum_probability_text()


func get_formatted_quantum_probability_text() -> String:
	if not quantum_active:
		return "Quantum probabilities: --"

	var probabilities = get_quantum_probabilities()
	var lines = []
	var current_line = ""

	for i in range(quantum_options.size()):
		var state = quantum_options[i]
		var move = get_move_from_quantum_state(state)

		var marked = ""
		if state in quantum_marked_states:
			marked = "*"

		var part = "%s|%s⟩ +%d: %.1f%%" % [
			marked,
			state_to_bits(state),
			move,
			probabilities[i] * 100.0
		]

		if i % 2 == 0:
			current_line = part
		else:
			current_line += "\n" + part
			lines.append(current_line)

	if quantum_options.size() % 2 != 0:
		lines.append(current_line)

	return "\n\n".join(lines)

func pulse_plane(player_id: int):
	if player_id >= player_planes.size():
		return

	var target_plane = player_planes[player_id]

	var tween = create_tween()
	tween.tween_property(target_plane, "scale", Vector2(1.25, 1.25), 0.12)
	tween.tween_property(target_plane, "scale", Vector2(1.0, 1.0), 0.12)

# -----------------------------
# Crisis tile system
# -----------------------------

func get_crisis_color(severity: int) -> Color:
	if severity <= 1:
		return Color(1.0, 0.55, 0.1)
	elif severity == 2:
		return Color(1.0, 0.2, 0.1)
	else:
		return Color(0.6, 0.0, 0.0)


func color_crisis_tiles():
	for i in range(board_tiles.size()):
		var tile = board_tiles[i]
		var tile_label = board_tile_labels[i]

		tile.color = get_track_color(i)

		if i in crisis_tiles:
			var severity = crisis_severity.get(i, 1)
			var crisis_type = crisis_types.get(i, "Unknown")
			if has_crisis_icon_asset(crisis_type):
				tile_label.text = "!" + str(severity)
				tile_label.position = tile_positions[i] + Vector2(-7, 7)
			else:
				tile_label.text = "!" + str(severity) + "\n" + get_crisis_short_name(crisis_type)
				tile_label.position = tile_positions[i] + Vector2(-13, -13)
		elif i in airport_entry_tiles:
			var airport_id = airport_entry_tiles.find(i)
			tile_label.text = "P" + str(airport_id + 1)
			tile_label.position = tile_positions[i] + Vector2(-10, -12)
		else:
			tile_label.text = ""
			tile_label.position = tile_positions[i] + Vector2(-10, -12)

func spawn_new_crisis():
	var possible_tiles = []

	for i in range(tile_positions.size()):
		if i != 0 and i not in airport_entry_tiles and i not in crisis_tiles and i not in player_positions:
			possible_tiles.append(i)

	if possible_tiles.size() > 0 and crisis_tiles.size() < get_max_active_crises():
		var new_tile = possible_tiles[randi() % possible_tiles.size()]
		crisis_tiles.append(new_tile)
		crisis_severity[new_tile] = 1
		crisis_age[new_tile] = 0
		crisis_types[new_tile] = possible_crisis_types[randi() % possible_crisis_types.size()]
		refresh_crisis_icon(new_tile)


func check_crisis_tile_for_player(player_id: int) -> bool:
	if player_id < player_in_airport.size() and player_in_airport[player_id]:
		return false

	var pos = player_positions[player_id]

	if pos in crisis_tiles:
		var severity = crisis_severity.get(pos, 1)
		var crisis_type = crisis_types.get(pos, "Unknown")
		var aid_type = player_aid_loadouts[player_id]
		var aid_matches = does_aid_match_crisis(aid_type, crisis_type)

		show_event_card(
			crisis_type + " Alert",
			get_crisis_flavour(crisis_type),
			"crisis"
		)

		var points_earned = severity

		if aid_matches:
			points_earned = severity + 1
			global_instability = max(global_instability - 1, 0)
		else:
			points_earned = max(1, severity - 1)

		# Apply any supply drop bonus granted by global events
		if aid_matches and player_id < player_next_match_bonus.size():
			if player_next_match_bonus[player_id] > 0:
				points_earned += player_next_match_bonus[player_id]
				show_news("Supply Drop bonus applied for %s." % get_team_name(player_id))
				player_next_match_bonus[player_id] = 0

		crises_resolved_count += 1
		total_aid_points_earned += points_earned

		if aid_matches:
			perfect_response_count += 1
		else:
			partial_response_count += 1

		score += points_earned
		player_scores[player_id] += points_earned

		crisis_tiles.erase(pos)
		crisis_severity.erase(pos)
		crisis_age.erase(pos)
		crisis_types.erase(pos)
		refresh_crisis_icon(pos)

		if randf() < crisis_spawn_after_aid_chance:
			spawn_new_crisis()

		update_score()
		update_instability_ui()
		color_crisis_tiles()

		if aid_matches:
			status_label.text = "Perfect response! %s delivered %s to a %s crisis." % [
				get_team_name(player_id),
				aid_type,
				crisis_type
			]
			play_sfx("success", -5.0)
			if player_id < player_planes.size():
				pulse_node(player_planes[player_id], Color(0.4, 1.0, 0.5, 1.0))
		else:
			status_label.text = "Partial response: %s delivered %s to a %s crisis." % [
				get_team_name(player_id),
				aid_type,
				crisis_type
			]
			play_sfx("error", -6.0)
			if player_id < player_planes.size():
				shake_node(player_planes[player_id])

		show_popup_message(
			"+%d Aid" % points_earned,
			tile_positions[pos],
			Color(0.4, 1.0, 0.4, 1.0)
		)

		return true

	return false


func crisis_update_phase():
	if game_finished:
		return

	var instability_gained = 0

	for tile_id in crisis_tiles.duplicate():
		var age = crisis_age.get(tile_id, 0) + 1
		crisis_age[tile_id] = age

		if age % crisis_escalation_interval != 0:
			continue

		var severity = crisis_severity.get(tile_id, 1)

		if severity < max_crisis_severity:
			crisis_severity[tile_id] = severity + 1
			crises_escalated_count += 1
			refresh_crisis_icon(tile_id)
			if crisis_icon_nodes.has(tile_id):
				pulse_node(crisis_icon_nodes[tile_id], Color(1.0, 0.35, 0.25, 1.0))
			play_sfx("crisis", -4.0)
		else:
			instability_gained += 1
			instability_events_count += 1

	global_instability += instability_gained

	if randf() < crisis_spawn_per_round_chance:
		spawn_new_crisis()

	color_crisis_tiles()
	refresh_all_crisis_icons()
	update_instability_ui()

	if instability_gained > 0:
		status_label.text = "Crisis Update: instability increased by %d." % instability_gained
	else:
		status_label.text = "Crisis Update: unresolved crises are being monitored."

	if randf() < global_event_chance:
		trigger_global_event()

	check_game_state()


func check_game_state():
	if global_instability >= max_global_instability:
		status_label.text = "Global instability reached maximum. Shared loss!"
		game_finished = true

		show_end_game_popup(
			"Shared Loss",
			"Global instability exceeded safe limits. The crisis system went out of control."
		)
	else:
		for i in range(player_count):
			if player_scores[i] >= target_score:
				status_label.text = "%s Wins!" % get_team_name(i)
				game_finished = true

				show_end_game_popup(
					"%s Wins!" % get_team_name(i),
					"%s achieved the highest humanitarian impact." % get_team_name(i)
				)
				break

	update_buttons()
	update_quantum_ui()
	update_instability_ui()


func end_turn():
	if game_finished:
		return

	if current_player == player_count - 1:
		crisis_update_phase()

		if game_finished:
			return

	current_player = (current_player + 1) % player_count

	update_status()
	update_buttons()
	update_quantum_ui()
	update_ui()

func show_popup_message(text: String, world_pos: Vector2, color := Color.WHITE):
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = world_pos + Vector2(-40, -40)
	label.z_index = 100

	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -35), 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)


func show_news(text: String):
	if news_feed_label != null:
		news_feed_label.text = "Crisis News: " + text
	else:
		status_label.text = text


func create_event_card_ui():
	if event_card_layer != null:
		return

	event_card_layer = CanvasLayer.new()
	event_card_layer.name = "EventCardLayer"
	add_child(event_card_layer)

	event_card_panel = PanelContainer.new()
	event_card_panel.name = "EventCardPanel"
	event_card_panel.position = Vector2(24, 455)
	event_card_panel.custom_minimum_size = Vector2(315, 125)
	event_card_panel.visible = false
	event_card_layer.add_child(event_card_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.07, 0.13, 0.92)
	panel_style.border_color = Color(0.4, 0.8, 1.0, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	event_card_panel.add_theme_stylebox_override("panel", panel_style)

	var row = HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 12)
	event_card_panel.add_child(row)

	event_card_icon = TextureRect.new()
	event_card_icon.name = "EventIcon"
	event_card_icon.custom_minimum_size = Vector2(42, 42)
	event_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(event_card_icon)

	var text_box = VBoxContainer.new()
	text_box.name = "TextBox"
	text_box.custom_minimum_size = Vector2(225, 90)
	row.add_child(text_box)

	event_card_title = Label.new()
	event_card_title.name = "EventTitle"
	event_card_title.text = "Event"
	event_card_title.add_theme_font_size_override("font_size", 18)
	text_box.add_child(event_card_title)

	event_card_body = Label.new()
	event_card_body.name = "EventBody"
	event_card_body.text = ""
	event_card_body.add_theme_font_size_override("font_size", 14)
	event_card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_card_body.custom_minimum_size = Vector2(225, 55)
	text_box.add_child(event_card_body)


func show_event_card(title: String, description: String, sound_key := "crisis"):
	create_event_card_ui()

	# Keep the old news label short so it does not get cut off.
	show_news(title)

	if status_label != null:
		status_label.text = "%s - %s" % [title, description]

	play_sfx(sound_key, -5.0)

	event_card_title.text = title
	event_card_body.text = description

	if event_icon_paths.has(title):
		var path = event_icon_paths[title]
		if ResourceLoader.exists(path):
			event_card_icon.texture = load(path)
			event_card_icon.visible = true
		else:
			event_card_icon.visible = false
	else:
		event_card_icon.visible = false

	event_card_panel.modulate = Color(1, 1, 1, 1)
	event_card_panel.visible = true

	event_card_timer_id += 1
	var my_timer_id = event_card_timer_id

	await get_tree().create_timer(3.0).timeout

	if my_timer_id != event_card_timer_id:
		return

	event_card_panel.visible = false


func load_sfx():
	sfx_cache.clear()

	for key in sfx_paths.keys():
		var path = sfx_paths[key]
		if ResourceLoader.exists(path):
			sfx_cache[key] = load(path)


func start_gameplay_music():
	if DisplayServer.get_name() == "headless":
		return

	if gameplay_music_player == null:
		gameplay_music_player = AudioStreamPlayer.new()
		gameplay_music_player.name = "GameplayMusic"
		add_child(gameplay_music_player)

	if gameplay_music_player.stream == null:
		gameplay_music_player.stream = load_audio_stream(GAMEPLAY_MUSIC_PATH)

	if gameplay_music_player.stream == null:
		print("Missing gameplay music: ", GAMEPLAY_MUSIC_PATH)
		return

	gameplay_music_player.volume_db = -18.0

	if not gameplay_music_player.finished.is_connected(_on_gameplay_music_finished):
		gameplay_music_player.finished.connect(_on_gameplay_music_finished)

	if not gameplay_music_player.playing:
		gameplay_music_player.play()


func _on_gameplay_music_finished():
	if gameplay_music_player != null:
		gameplay_music_player.play()


func stop_gameplay_music():
	if gameplay_music_player != null:
		gameplay_music_player.stop()


func load_audio_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)

	if not FileAccess.file_exists(path):
		return null

	var extension = path.get_extension().to_lower()

	if extension == "ogg":
		var stream = AudioStreamOggVorbis.load_from_file(path)
		return stream

	return null


func play_sfx(key: String, volume_db := -6.0):
	if not sfx_cache.has(key):
		return

	if not is_inside_tree():
		return

	var audio = AudioStreamPlayer.new()
	audio.stream = sfx_cache[key]
	audio.volume_db = volume_db
	add_child(audio)

	if not audio.is_inside_tree():
		audio.queue_free()
		return

	audio.finished.connect(audio.queue_free)
	audio.play()


func connect_button_sound(button):
	if button == null:
		return

	if not button.pressed.is_connected(_on_any_button_pressed):
		button.pressed.connect(_on_any_button_pressed)


func connect_button_hover_sound(button):
	if button == null:
		return

	if not button.mouse_entered.is_connected(_on_any_button_hovered):
		button.mouse_entered.connect(_on_any_button_hovered)


func _on_any_button_pressed():
	play_sfx("button_click", -10.0)


func _on_any_button_hovered():
	play_sfx("button_hover", -12.0)


func get_random_crisis_of_type(crisis_type: String) -> int:
	var candidates = []

	for tile_id in crisis_tiles:
		if crisis_types.get(tile_id, "") == crisis_type:
			candidates.append(tile_id)

	if candidates.is_empty():
		return -1

	return candidates[randi() % candidates.size()]


func escalate_specific_crisis(tile_id: int) -> bool:
	if tile_id == -1:
		return false

	var severity = crisis_severity.get(tile_id, 1)

	if severity < max_crisis_severity:
		crisis_severity[tile_id] = severity + 1
		crises_escalated_count += 1
		refresh_crisis_icon(tile_id)
		if crisis_icon_nodes.has(tile_id):
			pulse_node(crisis_icon_nodes[tile_id], Color(1.0, 0.35, 0.25, 1.0))
		play_sfx("crisis", -4.0)
	else:
		global_instability += 1
		instability_events_count += 1

	color_crisis_tiles()
	update_instability_ui()
	return true


func trigger_global_event():
	if game_finished:
		return

	var event_id = randi() % 3

	match event_id:
		0:
			var tile_id = get_random_crisis_of_type("Flood")

			if escalate_specific_crisis(tile_id):
				show_event_card(
					"Storm Surge",
					"Heavy rainfall has worsened flooding in one active crisis zone.",
					"crisis"
				)
			else:
				show_event_card(
					"Storm Surge Warning",
					"Weather systems are unstable, but no active flood zone was affected.",
					"error"
				)

		1:
			global_instability += 1
			instability_events_count += 1
			update_instability_ui()
			show_event_card(
				"System Pressure Rising",
				"Multiple regions report delays. Global instability increased by 1.",
				"crisis"
			)

		2:
			var target_player = randi() % player_count

			if target_player >= player_next_match_bonus.size():
				return

			player_next_match_bonus[target_player] += 1

			show_event_card(
				"Emergency Supply Window",
				"%s receives priority access to relief supplies. Aid Bonus +1." % get_team_name(target_player),
				"success"
			)


func get_mission_rank() -> String:
	if global_instability <= 3:
		return "Excellent Humanitarian Response"
	elif global_instability <= 7:
		return "Stable Response"
	elif global_instability < max_global_instability:
		return "Critical Response"
	else:
		return "Global System Failure"



func vector2_to_data(v: Vector2) -> Dictionary:
	return {
		"x": v.x,
		"y": v.y
	}


func data_to_vector2(data: Dictionary) -> Vector2:
	return Vector2(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0))
	)


func vector_array_to_data(array: Array) -> Array:
	var result = []

	for v in array:
		result.append(vector2_to_data(v))

	return result


func data_to_vector_array(array: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []

	for item in array:
		if item is Dictionary:
			result.append(data_to_vector2(item))

	return result


func int_array_from_data(array: Array) -> Array[int]:
	var result: Array[int] = []

	for value in array:
		result.append(int(value))

	return result


func bool_array_from_data(array: Array) -> Array[bool]:
	var result: Array[bool] = []

	for value in array:
		result.append(bool(value))

	return result


func int_dictionary_from_data(dict_data: Dictionary) -> Dictionary:
	var result = {}

	for key in dict_data.keys():
		result[int(key)] = int(dict_data[key])

	return result


func string_array_from_data(array: Array) -> Array[String]:
	var result: Array[String] = []

	for value in array:
		result.append(str(value))

	return result


func string_dictionary_from_data(dict_data: Dictionary) -> Dictionary:
	var result = {}

	for key in dict_data.keys():
		result[int(key)] = str(dict_data[key])

	return result


func save_game():
	if quantum_active:
		status_label.text = "Measure the quantum state before saving."
		return

	var save_data = {
		"player_count": player_count,
		"player_positions": player_positions,
		"player_in_airport": player_in_airport,
		"player_scores": player_scores,
		"player_aid_loadouts": player_aid_loadouts,
		"current_player": current_player,
		"score": score,
		"game_finished": game_finished,

		"crises_resolved_count": crises_resolved_count,
		"perfect_response_count": perfect_response_count,
		"partial_response_count": partial_response_count,
		"total_aid_points_earned": total_aid_points_earned,
		"crises_escalated_count": crises_escalated_count,
		"instability_events_count": instability_events_count,
		"quantum_tools_used_count": quantum_tools_used_count,
		"impact_report_shown": impact_report_shown,

		"base_tile_positions": vector_array_to_data(base_tile_positions),
		"crisis_tiles": crisis_tiles,
		"crisis_severity": crisis_severity,
		"crisis_age": crisis_age,
		"crisis_types": crisis_types,

		"global_instability": global_instability,
		"target_score": target_score,
		"max_global_instability": max_global_instability
	}

	var file = FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)

	if file == null:
		status_label.text = "Save failed."
		return

	file.store_string(JSON.stringify(save_data))
	file.close()

	status_label.text = "Game saved."


func load_game() -> bool:
	if not FileAccess.file_exists(GameState.SAVE_PATH):
		status_label.text = "No save file found."
		return false

	var file = FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)

	if file == null:
		status_label.text = "Load failed."
		return false

	var text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(text)

	if not (data is Dictionary):
		status_label.text = "Save file is invalid."
		return false

	player_count = int(data.get("player_count", 2))
	setup_player_nodes()

	base_tile_positions = data_to_vector_array(data.get("base_tile_positions", []))

	if base_tile_positions.is_empty():
		status_label.text = "Save file has no map data."
		return false

	generate_airport_data()

	player_positions = int_array_from_data(data.get("player_positions", []))
	player_in_airport = bool_array_from_data(data.get("player_in_airport", []))
	player_scores = int_array_from_data(data.get("player_scores", []))
	player_aid_loadouts = string_array_from_data(data.get("player_aid_loadouts", []))

	while player_positions.size() < player_count:
		player_positions.append(get_player_start_tile(player_positions.size()))

	while player_in_airport.size() < player_count:
		player_in_airport.append(true)

	while player_scores.size() < player_count:
		player_scores.append(0)

	while player_aid_loadouts.size() < player_count:
		player_aid_loadouts.append(possible_aid_loadouts[player_aid_loadouts.size() % possible_aid_loadouts.size()])

	current_player = int(data.get("current_player", 0))
	current_player = int(clamp(current_player, 0, player_count - 1))

	score = int(data.get("score", 0))
	game_finished = bool(data.get("game_finished", false))

	crises_resolved_count = int(data.get("crises_resolved_count", 0))
	perfect_response_count = int(data.get("perfect_response_count", 0))
	partial_response_count = int(data.get("partial_response_count", 0))
	total_aid_points_earned = int(data.get("total_aid_points_earned", 0))
	crises_escalated_count = int(data.get("crises_escalated_count", 0))
	instability_events_count = int(data.get("instability_events_count", 0))
	quantum_tools_used_count = int(data.get("quantum_tools_used_count", 0))
	impact_report_shown = bool(data.get("impact_report_shown", false))

	crisis_tiles = int_array_from_data(data.get("crisis_tiles", []))
	crisis_severity = int_dictionary_from_data(data.get("crisis_severity", {}))
	crisis_age = int_dictionary_from_data(data.get("crisis_age", {}))
	crisis_types = string_dictionary_from_data(data.get("crisis_types", {}))

	global_instability = int(data.get("global_instability", 0))
	target_score = int(data.get("target_score", target_score))
	max_global_instability = int(data.get("max_global_instability", max_global_instability))

	quantum_active = false
	entanglement_active = false
	oracle_used = false
	amplification_used = false
	entangle_used = false

	quantum_options.clear()
	quantum_amplitudes.clear()
	quantum_marked_states.clear()

	clear_quantum_ghosts()
	clear_entangled_ghosts()

	get_tree().paused = false

	layout_board_to_screen()
	layout_ui()
	update_plane_position(true)

	update_score()
	update_instability_ui()
	update_buttons()
	update_quantum_ui()
	color_crisis_tiles()
	check_game_state()
	update_status()

	update_aid_loadout_ui()
	update_crisis_legend_ui()

	status_label.text = "Game loaded."
	return true
# -----------------------------
# Quantum computing movement system
# -----------------------------

func complex_probability(a: Vector2) -> float:
	return a.x * a.x + a.y * a.y


func get_quantum_probabilities() -> Array:
	var probabilities = []

	for amp in quantum_amplitudes:
		probabilities.append(complex_probability(amp))

	return probabilities


func normalize_quantum_amplitudes():
	var total_probability = 0.0

	for amp in quantum_amplitudes:
		total_probability += complex_probability(amp)

	if total_probability <= 0.0:
		create_circuit_superposition()
		return

	var normalizer = sqrt(total_probability)

	for i in range(quantum_amplitudes.size()):
		quantum_amplitudes[i] = quantum_amplitudes[i] / normalizer


func state_to_bits(state: int) -> String:
	var bits = ""

	for bit in range(QUBIT_COUNT - 1, -1, -1):
		bits += str((state >> bit) & 1)

	return bits


func get_move_from_quantum_state(state: int) -> int:
	# 3-qubit movement register:
	# |000> = move 0
	# |001> to |110> = move 1 to 6
	# |111> = quantum surge, move 7 with instability risk
	if state <= 0:
		return 0

	if state >= 7:
		return 7

	return state


func create_circuit_superposition():
	quantum_options.clear()
	quantum_amplitudes.clear()
	quantum_marked_states.clear()

	var uniform_amplitude = 1.0 / sqrt(float(QUANTUM_STATE_COUNT))

	for state in range(QUANTUM_STATE_COUNT):
		quantum_options.append(state)
		quantum_amplitudes.append(Vector2(uniform_amplitude, 0.0))


func get_branch_target_position(player_id: int, state: int) -> int:
	var move = get_move_from_quantum_state(state)
	return (player_positions[player_id] + move) % tile_positions.size()


func get_branch_value_for_state(player_id: int, state: int) -> int:
	var target_pos = get_branch_target_position(player_id, state)

	if target_pos in crisis_tiles:
		return int(crisis_severity.get(target_pos, 1))

	return 0


func find_oracle_marked_states() -> Array[int]:
	var marked: Array[int] = []

	for state in quantum_options:
		var value = get_branch_value_for_state(current_player, state)

		if value > 0:
			marked.append(state)

	return marked


func apply_crisis_oracle():
	if not quantum_active or oracle_used:
		return

	quantum_marked_states = find_oracle_marked_states()

	if quantum_marked_states.is_empty():
		oracle_used = true
		status_label.text = "Oracle found no crisis-reaching movement states."
		update_quantum_ui()
		return

	for state in quantum_marked_states:
		var index = quantum_options.find(state)

		if index != -1:
			# Oracle phase flip:
			# marked useful states get their phase inverted.
			quantum_amplitudes[index] = quantum_amplitudes[index] * -1.0

	oracle_used = true

	update_quantum_ghost_visuals()
	update_quantum_ui()

	var marked_text = PackedStringArray()

	for state in quantum_marked_states:
		marked_text.append("|%s⟩(+%d)" % [
			state_to_bits(state),
			get_move_from_quantum_state(state)
		])

	status_label.text = "Oracle marked %d crisis route(s): %s" % [
		quantum_marked_states.size(),
		" ".join(marked_text)
	]


func apply_amplification():
	if not quantum_active or amplification_used:
		return

	if quantum_amplitudes.is_empty():
		return

	if not oracle_used:
		status_label.text = "Use Oracle first. Amplify needs marked crisis routes."
		return

	if quantum_marked_states.is_empty():
		status_label.text = "No marked crisis routes to amplify."
		return

	var n = quantum_amplitudes.size()
	var average = Vector2.ZERO

	for amp in quantum_amplitudes:
		average += amp

	average /= float(n)

	for i in range(n):
		quantum_amplitudes[i] = average * 2.0 - quantum_amplitudes[i]

	normalize_quantum_amplitudes()

	amplification_used = true

	update_quantum_ghost_visuals()
	update_quantum_ui()

	status_label.text = "Amplification applied: marked crisis routes are now more likely."


func choose_quantum_index() -> int:
	var probabilities = get_quantum_probabilities()
	var r = randf()
	var cumulative = 0.0

	for i in range(probabilities.size()):
		cumulative += probabilities[i]

		if r <= cumulative:
			return i

	return max(probabilities.size() - 1, 0)


func create_quantum_ghosts():
	clear_quantum_ghosts()

	if current_player >= player_planes.size():
		return

	if tile_positions.is_empty():
		return

	for state in quantum_options:
		quantum_positions.append(get_branch_target_position(current_player, state))

	var source_plane = player_planes[current_player]
	var offset = get_player_offset(current_player)

	for i in range(quantum_positions.size()):
		var ghost = source_plane.duplicate()
		ghost.position = tile_positions[quantum_positions[i]] + offset
		ghost.modulate = Color(1.0, 1.0, 1.0, 0.25)
		ghost.scale = Vector2(0.72, 0.72)
		ghost.z_index = 12

		add_child(ghost)
		quantum_ghosts.append(ghost)

	update_quantum_crisis_preview()


func clear_quantum_ghosts():
	for ghost in quantum_ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()

	quantum_ghosts.clear()
	quantum_positions.clear()


func update_quantum_crisis_preview():
	if not quantum_active:
		return

	for i in range(quantum_positions.size()):
		if i >= quantum_ghosts.size():
			continue

		var qpos = quantum_positions[i]

		if qpos in crisis_tiles:
			quantum_ghosts[i].scale = Vector2(1.25, 1.25)
		else:
			quantum_ghosts[i].scale = Vector2(0.72, 0.72)


func create_crisis_icon_legend():
	if crisis_legend_panel != null:
		return

	crisis_legend_panel = PanelContainer.new()
	crisis_legend_panel.name = "CrisisIconLegendPanel"
	crisis_legend_panel.position = Vector2(310, 285)
	crisis_legend_panel.custom_minimum_size = Vector2(660, 260)
	crisis_legend_panel.visible = false
	add_child(crisis_legend_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.13, 0.92)
	style.border_color = Color(0.4, 0.9, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	crisis_legend_panel.add_theme_stylebox_override("panel", style)

	crisis_legend_box = VBoxContainer.new()
	crisis_legend_box.add_theme_constant_override("separation", 8)
	crisis_legend_panel.add_child(crisis_legend_box)

	add_crisis_legend_row("Flood", "Water Rescue")
	add_crisis_legend_row("Wildfire", "Fire Response")
	add_crisis_legend_row("Medical", "Medical Supplies")
	add_crisis_legend_row("Infrastructure", "Repair Team")
	add_crisis_legend_row("Food Shortage", "Food Aid")


func add_crisis_legend_row(crisis_name: String, aid_name: String):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	crisis_legend_box.add_child(row)

	var crisis_icon = TextureRect.new()
	crisis_icon.custom_minimum_size = Vector2(36, 36)
	crisis_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if crisis_icon_paths.has(crisis_name):
		var crisis_path = crisis_icon_paths[crisis_name]
		if ResourceLoader.exists(crisis_path):
			crisis_icon.texture = load(crisis_path)

	row.add_child(crisis_icon)

	var label = Label.new()
	label.text = "%s  →  %s" % [crisis_name, aid_name]
	label.custom_minimum_size = Vector2(360, 36)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)

	var aid_icon = TextureRect.new()
	aid_icon.custom_minimum_size = Vector2(36, 36)
	aid_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if aid_icon_paths.has(aid_name):
		var aid_path = aid_icon_paths[aid_name]
		if ResourceLoader.exists(aid_path):
			aid_icon.texture = load(aid_path)

	row.add_child(aid_icon)
func update_quantum_ghost_visuals():
	var probabilities = get_quantum_probabilities()

	for i in range(quantum_ghosts.size()):
		if i >= quantum_amplitudes.size():
			continue

		var probability = probabilities[i]
		var alpha = clamp(0.15 + probability * 2.2, 0.15, 0.95)

		var state = quantum_options[i]
		var amp = quantum_amplitudes[i]

		if state in quantum_marked_states:
			# Green/cyan = oracle-marked useful state.
			quantum_ghosts[i].modulate = Color(0.25, 1.0, 0.65, alpha)
		elif amp.x < 0.0 or abs(amp.y) > 0.01:
			# Pink/red = phase-shifted state.
			quantum_ghosts[i].modulate = Color(1.0, 0.35, 0.55, alpha)
		else:
			quantum_ghosts[i].modulate = Color(1.0, 1.0, 1.0, alpha)

	update_quantum_crisis_preview()


# -----------------------------
# Entanglement
# -----------------------------

func get_entangled_player() -> int:
	return (current_player + 1) % player_count


func get_entangled_state_for_state(state: int) -> int:
	# Anti-correlated 3-qubit state.
	# |000> links with |111>, |001> links with |110>, etc.
	return (QUANTUM_STATE_COUNT - 1) - state


func create_entangled_ghosts():
	clear_entangled_ghosts()

	var other_player = get_entangled_player()

	if other_player >= player_planes.size():
		return

	if tile_positions.is_empty():
		return

	entangled_positions.clear()

	for state in quantum_options:
		var linked_state = get_entangled_state_for_state(state)
		var linked_move = get_move_from_quantum_state(linked_state)
		var linked_pos = (player_positions[other_player] + linked_move) % tile_positions.size()

		entangled_positions.append(linked_pos)

	var source_plane = player_planes[other_player]
	var offset = get_player_offset(other_player)

	for i in range(entangled_positions.size()):
		var ghost = source_plane.duplicate()
		ghost.position = tile_positions[entangled_positions[i]] + offset
		ghost.modulate = Color(0.35, 0.75, 1.0, 0.25)
		ghost.scale = Vector2(0.65, 0.65)
		ghost.z_index = 11

		add_child(ghost)
		entangled_ghosts.append(ghost)


func clear_entangled_ghosts():
	for ghost in entangled_ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()

	entangled_ghosts.clear()
	entangled_positions.clear()


func update_entangled_ghost_visuals():
	for ghost in entangled_ghosts:
		if is_instance_valid(ghost):
			ghost.modulate = Color(0.35, 0.75, 1.0, 0.25)


# -----------------------------
# Button functions
# -----------------------------

func _on_quantum_move_button_pressed():
	if quantum_active or game_finished:
		return

	if current_player < player_in_airport.size() and player_in_airport[current_player]:
		status_label.text = "%s must take off before using the quantum circuit." % get_team_name(current_player)
		return

	create_circuit_superposition()

	quantum_active = true
	entanglement_active = false

	oracle_used = false
	amplification_used = false
	entangle_used = false

	create_quantum_ghosts()
	update_quantum_ghost_visuals()
	quantum_tools_used_count += 1
	play_sfx("quantum", -5.0)
	if current_player < player_planes.size():
		pulse_node(player_planes[current_player], Color(0.45, 0.85, 1.0, 1.0))

	status_label.text = "%s created a 3-qubit movement superposition." % get_team_name(current_player)

	update_buttons()
	update_quantum_ui()


func _on_stabilize_button_pressed():
	if not quantum_active or game_finished or amplification_used:
		return

	# StabilizeButton is now the Amplify button.
	apply_amplification()
	quantum_tools_used_count += 1
	play_sfx("quantum", -5.0)
	if current_player < player_planes.size():
		pulse_node(player_planes[current_player], Color(0.45, 0.85, 1.0, 1.0))

	update_buttons()
	update_quantum_ui()


func _on_boost_button_pressed():
	if not quantum_active or game_finished or oracle_used:
		return

	# BoostButton is now the Oracle button.
	apply_crisis_oracle()
	quantum_tools_used_count += 1
	play_sfx("quantum", -5.0)
	if current_player < player_planes.size():
		pulse_node(player_planes[current_player], Color(0.45, 0.85, 1.0, 1.0))

	update_buttons()
	update_quantum_ui()


func _on_entangle_button_pressed():
	if not quantum_active or game_finished or entangle_used:
		return

	entanglement_active = true
	entangle_used = true

	create_entangled_ghosts()
	update_entangled_ghost_visuals()
	quantum_tools_used_count += 1
	play_sfx("quantum", -5.0)
	if current_player < player_planes.size():
		pulse_node(player_planes[current_player], Color(0.45, 0.85, 1.0, 1.0))

	var linked_player = get_entangled_player()

	status_label.text = "Entanglement active: %s movement register is linked with %s." % [
		get_team_name(current_player),
		get_team_name(linked_player)
	]

	update_buttons()
	update_quantum_ui()


func _on_move_button_pressed():
	if game_finished or quantum_active:
		return

	if current_player < player_in_airport.size() and player_in_airport[current_player]:
		player_in_airport[current_player] = false
		player_positions[current_player] = get_player_start_tile(current_player)
		plane_position = player_positions[current_player]

		update_plane_position()

		status_label.text = "%s took off from Airport %d." % [
			get_team_name(current_player),
			get_player_airport_slot(current_player) + 1
		]

		end_turn()
		update_buttons()
		update_quantum_ui()
		return

	player_positions[current_player] = (player_positions[current_player] + 1) % tile_positions.size()
	plane_position = player_positions[current_player]

	show_move_card(current_player, 1)
	update_plane_position()

	var delivered_aid = check_crisis_tile_for_player(current_player)
	check_game_state()

	if not game_finished:
		if not delivered_aid:
			status_label.text = "%s moved 1 tile." % get_team_name(current_player)

		end_turn()

	update_buttons()
	update_quantum_ui()


func _on_measure_button_pressed():
	if not quantum_active or game_finished:
		return

	if quantum_options.is_empty() or quantum_positions.is_empty():
		return

	if current_player < player_in_airport.size():
		player_in_airport[current_player] = false

	var chosen_index = choose_quantum_index()
	var measured_state = quantum_options[chosen_index]
	var move = get_move_from_quantum_state(measured_state)

	player_positions[current_player] = quantum_positions[chosen_index]
	plane_position = player_positions[current_player]

	var surge_happened = measured_state == 7

	if surge_happened:
		global_instability += QUANTUM_SURGE_INSTABILITY_COST
		update_instability_ui()

	var other_player = get_entangled_player()
	var entangled_move_happened = false
	var linked_state = -1
	var linked_move = 0

	if entanglement_active and entangled_positions.size() > chosen_index:
		linked_state = get_entangled_state_for_state(measured_state)
		linked_move = get_move_from_quantum_state(linked_state)

		if other_player < player_in_airport.size():
			player_in_airport[other_player] = false

		player_positions[other_player] = entangled_positions[chosen_index]
		entangled_move_happened = true

	quantum_active = false
	entanglement_active = false

	oracle_used = false
	amplification_used = false
	entangle_used = false

	quantum_options.clear()
	quantum_amplitudes.clear()
	quantum_marked_states.clear()

	clear_quantum_ghosts()
	clear_entangled_ghosts()

	update_plane_position()
	quantum_tools_used_count += 1
	play_sfx("quantum", -5.0)
	if current_player < player_planes.size():
		pulse_node(player_planes[current_player], Color(0.45, 0.85, 1.0, 1.0))
	pulse_plane(current_player)

	if entangled_move_happened:
		if other_player < player_planes.size():
			pulse_node(player_planes[other_player], Color(0.45, 0.85, 1.0, 1.0))
		pulse_plane(other_player)

	var delivered_aid = check_crisis_tile_for_player(current_player)
	var other_delivered_aid = false

	if entangled_move_happened:
		other_delivered_aid = check_crisis_tile_for_player(other_player)

	check_game_state()

	if not game_finished:
		if not delivered_aid and not other_delivered_aid:
			if entangled_move_happened:
				status_label.text = "Measured |%s⟩: %s moved +%d. Linked %s collapsed to |%s⟩, moving +%d." % [
					state_to_bits(measured_state),
					get_team_name(current_player),
					move,
					get_team_name(other_player),
					state_to_bits(linked_state),
					linked_move
				]
			else:
				status_label.text = "Measured |%s⟩: %s moved +%d." % [
					state_to_bits(measured_state),
					get_team_name(current_player),
					move
				]

			if surge_happened:
				status_label.text += " Quantum surge increased global instability."

		end_turn()

	update_buttons()
	update_quantum_ui()
	update_instability_ui()

func connect_game_ui_buttons():
	if save_game_button != null and not save_game_button.pressed.is_connected(_on_save_game_button_pressed):
		save_game_button.pressed.connect(_on_save_game_button_pressed)

	if main_menu_button != null and not main_menu_button.pressed.is_connected(_on_main_menu_button_pressed):
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)

	if change_aid_button != null and not change_aid_button.pressed.is_connected(_on_change_aid_button_pressed):
		change_aid_button.pressed.connect(_on_change_aid_button_pressed)

	if end_game_new_game_button != null and not end_game_new_game_button.pressed.is_connected(_on_end_game_new_game_pressed):
		end_game_new_game_button.pressed.connect(_on_end_game_new_game_pressed)

	if end_game_main_menu_button != null and not end_game_main_menu_button.pressed.is_connected(_on_end_game_main_menu_pressed):
		end_game_main_menu_button.pressed.connect(_on_end_game_main_menu_pressed)

	# Connect click sounds for common buttons
	connect_button_sound(move_button)
	connect_button_sound(quantum_button)
	connect_button_sound(measure_button)
	connect_button_sound(stabilize_button)
	connect_button_sound(boost_button)
	connect_button_sound(entangle_button)
	connect_button_sound(change_aid_button)
	connect_button_sound(save_game_button)
	connect_button_sound(main_menu_button)
	connect_button_sound(end_game_new_game_button)
	connect_button_sound(end_game_main_menu_button)
	connect_button_hover_sound(move_button)
	connect_button_hover_sound(quantum_button)
	connect_button_hover_sound(measure_button)
	connect_button_hover_sound(stabilize_button)
	connect_button_hover_sound(boost_button)
	connect_button_hover_sound(entangle_button)
	connect_button_hover_sound(change_aid_button)
	connect_button_hover_sound(save_game_button)
	connect_button_hover_sound(main_menu_button)
	connect_button_hover_sound(end_game_new_game_button)
	connect_button_hover_sound(end_game_main_menu_button)


func style_buttons():
	if move_button != null:
		move_button.text = "Deploy: 1"
		move_button.modulate = Color(0.75, 0.85, 1.0)
		move_button.custom_minimum_size = Vector2(92, 34)
		move_button.add_theme_font_size_override("font_size", 16)

	if quantum_button != null:
		quantum_button.text = "Create Superposition"
		quantum_button.modulate = Color(0.75, 0.55, 1.0)
		quantum_button.custom_minimum_size = Vector2(165, 34)
		quantum_button.add_theme_font_size_override("font_size", 16)

	if boost_button != null:
		boost_button.text = "Oracle"
		boost_button.modulate = Color(1.0, 0.55, 0.75)
		boost_button.custom_minimum_size = Vector2(92, 34)
		boost_button.add_theme_font_size_override("font_size", 16)

	if stabilize_button != null:
		stabilize_button.text = "Amplify"
		stabilize_button.modulate = Color(0.55, 1.0, 0.9)
		stabilize_button.custom_minimum_size = Vector2(92, 34)
		stabilize_button.add_theme_font_size_override("font_size", 16)

	if entangle_button != null:
		entangle_button.text = "Entangle"
		entangle_button.modulate = Color(0.45, 0.8, 1.0)
		entangle_button.custom_minimum_size = Vector2(115, 34)
		entangle_button.add_theme_font_size_override("font_size", 16)

	if measure_button != null:
		measure_button.text = "Measure"
		measure_button.modulate = Color(1.0, 0.85, 0.35)
		measure_button.custom_minimum_size = Vector2(92, 34)
		measure_button.add_theme_font_size_override("font_size", 16)

	if change_aid_button != null:
		change_aid_button.text = "Change Aid"
		change_aid_button.modulate = Color(0.65, 1.0, 0.65)
		change_aid_button.custom_minimum_size = Vector2(115, 34)
		change_aid_button.add_theme_font_size_override("font_size", 16)

	if main_menu_button != null:
		main_menu_button.custom_minimum_size = Vector2(115, 34)
		main_menu_button.add_theme_font_size_override("font_size", 16)

func _on_save_game_button_pressed():
	save_game()


func _on_main_menu_button_pressed():
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _on_change_aid_button_pressed():
	open_aid_selection_ui()


func _on_create_new_game_pressed():
	setup_player_nodes()
	generate_new_map(true)
	layout_board_to_screen()
	layout_ui()
	update_plane_position(true)

	update_score()
	update_instability_ui()
	update_buttons()
	update_quantum_ui()
	update_aid_loadout_ui()
	check_game_state()
	update_status()

func _on_end_game_new_game_pressed():
	generate_new_map(true)

	layout_board_to_screen()
	layout_ui()
	update_plane_position(true)

	update_score()
	update_instability_ui()
	update_buttons()
	update_quantum_ui()
	update_aid_loadout_ui()
	update_status()

	if end_game_popup != null:
		end_game_popup.visible = false


func _on_end_game_main_menu_pressed():
	get_tree().change_scene_to_file("res://MainMenu.tscn")
