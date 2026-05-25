extends Node2D

var plane_position: int = 0
var score: int = 0

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

var board_tiles = []
var board_tile_labels = []
@export var map_width: float = 900.0
@export var map_height: float = 620.0
@export var map_jitter: float = 0.18
@export var board_zoom: float = 1.12
@export var tile_radius: float = 18.0
@export var airport_distance: float = 120.0

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
var impact_report_shown: bool = false

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

		current_player = 0
		game_finished = false
		global_instability = 0

		crises_resolved_count = 0
		perfect_response_count = 0
		partial_response_count = 0
		total_aid_points_earned = 0
		crises_escalated_count = 0
		instability_events_count = 0
		impact_report_shown = false

		if end_game_popup != null:
			end_game_popup.visible = false

		if impact_report_panel != null:
			impact_report_panel.visible = false
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


func _ready():
	randomize()

	if not GameState.load_requested:
		player_count = GameState.selected_player_count

	setup_player_nodes()
	setup_layering()

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
	update_buttons()
	update_quantum_ui()
	check_game_state()
	update_status()

	update_aid_loadout_ui()
	update_crisis_legend_ui()

	connect_game_ui_buttons()
	style_buttons()


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

		# Main airport body
		var airport = Polygon2D.new()
		airport.polygon = make_tile_polygon(tile_radius * 2.4)
		airport.position = airport_positions[i]
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
			slot.position = airport_positions[i] + slot_offsets[s]
			slot.color = color_with_alpha(base_color, slot_alpha)
			slot.z_index = 2
			board.add_child(slot)

		# Shorter airport label
		var label = Label.new()
		label.text = "A%d" % (i + 1)
		label.position = airport_positions[i] + Vector2(-12, -10)
		label.modulate = Color(1, 1, 1, label_alpha)
		label.z_index = 4
		board.add_child(label)


func create_board_tiles():
	for child in board.get_children():
		child.queue_free()

	board_tiles.clear()
	board_tile_labels.clear()

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
			tile_label.text = "!" + str(label_severity) + "\n" + get_crisis_short_name(crisis_type)
		elif i in airport_entry_tiles:
			var airport_id = airport_entry_tiles.find(i)
			tile_label.text = "P" + str(airport_id + 1)
		else:
			tile_label.text = ""

		board.add_child(tile_label)
		board_tile_labels.append(tile_label)

	create_airport_markers()


func layout_board_to_screen():
	if base_tile_positions.is_empty():
		return

	var screen_size = get_viewport_rect().size

	# Reserve screen zones:
	# left for quantum info
	# top for title/score
	# bottom for buttons/status
	# right for score + airport margin
	var margin_left = 260.0
	var margin_right = 170.0
	var margin_top = 100.0
	var margin_bottom = 130.0

	var available_size = Vector2(
		screen_size.x - margin_left - margin_right,
		screen_size.y - margin_top - margin_bottom
	)

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

	var scale_factor = min(
		available_size.x / board_size.x,
		available_size.y / board_size.y
	) * board_zoom

	tile_positions.clear()

	var board_center = Vector2(
		(min_x + max_x) / 2.0,
		(min_y + max_y) / 2.0
	)

	# Put board in the actual center of the free play area,
	# not just the screen center.
	var screen_center = Vector2(
		margin_left + available_size.x / 2.0,
		margin_top + available_size.y / 2.0
	)

	for pos in base_tile_positions:
		var centered_pos = pos - board_center
		var scaled_pos = centered_pos * scale_factor
		tile_positions.append(screen_center + scaled_pos)

	airport_positions.clear()

	for pos in airport_base_positions:
		var centered_pos = pos - board_center
		var scaled_pos = centered_pos * scale_factor
		airport_positions.append(screen_center + scaled_pos)

	if board != null:
		board.points = tile_positions
		board.queue_redraw()

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

	var left_panel_x = 24.0
	var left_panel_width = 240.0

	# Title at top-left instead of top-center
	var title_label = get_node_or_null("UI/TitleLabel")
	if title_label != null:
		title_label.position = Vector2(24, 18)
		title_label.size = Vector2(480, 40)

	# Score block on the top-right
	if score_label != null:
		score_label.position = Vector2(screen_size.x - 430, 18)
		score_label.size = Vector2(410, 32)

	if instability_label != null:
		instability_label.position = Vector2(screen_size.x - 430, 52)
		instability_label.size = Vector2(410, 32)

	if aid_loadout_label != null:
		aid_loadout_label.position = Vector2(screen_size.x - 430, 86)
		aid_loadout_label.size = Vector2(410, 32)

	if quantum_probability_label != null:
		quantum_probability_label.position = Vector2(left_panel_x, 100)
		quantum_probability_label.size = Vector2(left_panel_width, 150)

	if quantum_state_label != null:
		quantum_state_label.position = Vector2(left_panel_x, 260)
		quantum_state_label.size = Vector2(left_panel_width, 110)

	if crisis_legend_label != null:
		crisis_legend_label.position = Vector2(left_panel_x, 390)
		crisis_legend_label.size = Vector2(left_panel_width, 220)

	if status_label != null:
		status_label.position = Vector2(screen_size.x / 2.0 - 300, screen_size.y - 42)
		status_label.size = Vector2(600, 36)

	var button_bar = get_node_or_null("UI/ButtonBar")
	if button_bar != null:
		button_bar.position = Vector2(
			screen_size.x / 2.0 - button_bar.size.x / 2.0,
			screen_size.y - 78
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


func update_plane_positions(instant := false):
	if tile_positions.is_empty():
		return

	if instant:
		for i in range(player_count):
			if i >= player_planes.size():
				continue

			player_planes[i].position = get_player_display_position(i)
	else:
		var tween = create_tween()

		for i in range(player_count):
			if i >= player_planes.size():
				continue

			var target_pos = get_player_display_position(i)

			if i == 0:
				tween.tween_property(player_planes[i], "position", target_pos, 0.35)
			else:
				tween.parallel().tween_property(player_planes[i], "position", target_pos, 0.35)


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


func update_status():
	if not game_finished and not quantum_active:
		status_label.text = "Mission Control: Player %d ready" % (current_player + 1)

	update_aid_loadout_ui()


func update_aid_loadout_ui():
	if aid_loadout_label == null:
		return

	if current_player >= player_aid_loadouts.size():
		aid_loadout_label.text = "Current Aid: --"
		return

	aid_loadout_label.text = "Current Aid: P%d carrying %s" % [
		current_player + 1,
		player_aid_loadouts[current_player]
	]


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

	for i in range(player_count):
		report += "Player %d Impact Score: %d\n" % [
			i + 1,
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

	if end_game_popup == null:
		status_label.text = result_text
		return

	var report = ""
	report += result_text + "\n\n"

	report += "Humanitarian Impact Summary\n"
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

	report += "Player Scores\n"

	for i in range(player_count):
		report += "Player %d: %d impact points\n" % [
			i + 1,
			player_scores[i]
		]

	if end_game_title_label != null:
		end_game_title_label.text = title_text

	if end_game_report_label != null:
		end_game_report_label.text = report

	end_game_popup.visible = true


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
			tile_label.text = "!" + str(severity) + "\n" + get_crisis_short_name(crisis_type)
		elif i in airport_entry_tiles:
			var airport_id = airport_entry_tiles.find(i)
			tile_label.text = "P" + str(airport_id + 1)
		else:
			tile_label.text = ""

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


func check_crisis_tile_for_player(player_id: int) -> bool:
	if player_id < player_in_airport.size() and player_in_airport[player_id]:
		return false

	var pos = player_positions[player_id]

	if pos in crisis_tiles:
		var severity = crisis_severity.get(pos, 1)
		var crisis_type = crisis_types.get(pos, "Unknown")
		var aid_type = player_aid_loadouts[player_id]
		var aid_matches = does_aid_match_crisis(aid_type, crisis_type)

		var points_earned = severity

		if aid_matches:
			points_earned = severity + 1
			global_instability = max(global_instability - 1, 0)
		else:
			points_earned = max(1, severity - 1)

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

		if randf() < crisis_spawn_after_aid_chance:
			spawn_new_crisis()

		update_score()
		update_instability_ui()
		color_crisis_tiles()

		if aid_matches:
			status_label.text = "Perfect response! Player %d delivered %s to a %s crisis." % [
				player_id + 1,
				aid_type,
				crisis_type
			]
		else:
			status_label.text = "Partial response: Player %d delivered %s to a %s crisis." % [
				player_id + 1,
				aid_type,
				crisis_type
			]

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
		else:
			instability_gained += 1
			instability_events_count += 1

	global_instability += instability_gained

	if randf() < crisis_spawn_per_round_chance:
		spawn_new_crisis()

	color_crisis_tiles()
	update_instability_ui()

	if instability_gained > 0:
		status_label.text = "Crisis Update: instability increased by %d." % instability_gained
	else:
		status_label.text = "Crisis Update: unresolved crises are being monitored."

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
				status_label.text = "Player %d Wins!" % (i + 1)
				game_finished = true

				show_end_game_popup(
					"Player %d Wins!" % (i + 1),
					"Player %d achieved the highest humanitarian impact." % (i + 1)
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
		status_label.text = "Player %d must take off before using the quantum circuit." % (current_player + 1)
		return

	create_circuit_superposition()

	quantum_active = true
	entanglement_active = false

	oracle_used = false
	amplification_used = false
	entangle_used = false

	create_quantum_ghosts()
	update_quantum_ghost_visuals()

	status_label.text = "Player %d created a 3-qubit movement superposition." % (current_player + 1)

	update_buttons()
	update_quantum_ui()


func _on_stabilize_button_pressed():
	if not quantum_active or game_finished or amplification_used:
		return

	# StabilizeButton is now the Amplify button.
	apply_amplification()

	update_buttons()
	update_quantum_ui()


func _on_boost_button_pressed():
	if not quantum_active or game_finished or oracle_used:
		return

	# BoostButton is now the Oracle button.
	apply_crisis_oracle()

	update_buttons()
	update_quantum_ui()


func _on_entangle_button_pressed():
	if not quantum_active or game_finished or entangle_used:
		return

	entanglement_active = true
	entangle_used = true

	create_entangled_ghosts()
	update_entangled_ghost_visuals()

	var linked_player = get_entangled_player()

	status_label.text = "Entanglement active: Player %d movement register is linked with Player %d." % [
		current_player + 1,
		linked_player + 1
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

		status_label.text = "Player %d took off from Airport %d." % [
			current_player + 1,
			get_player_airport_slot(current_player) + 1
		]

		end_turn()
		update_buttons()
		update_quantum_ui()
		return

	player_positions[current_player] = (player_positions[current_player] + 1) % tile_positions.size()
	plane_position = player_positions[current_player]

	update_plane_position()

	var delivered_aid = check_crisis_tile_for_player(current_player)
	check_game_state()

	if not game_finished:
		if not delivered_aid:
			status_label.text = "Player %d moved 1 tile." % (current_player + 1)

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
	pulse_plane(current_player)

	if entangled_move_happened:
		pulse_plane(other_player)

	var delivered_aid = check_crisis_tile_for_player(current_player)
	var other_delivered_aid = false

	if entangled_move_happened:
		other_delivered_aid = check_crisis_tile_for_player(other_player)

	check_game_state()

	if not game_finished:
		if not delivered_aid and not other_delivered_aid:
			if entangled_move_happened:
				status_label.text = "Measured |%s⟩: Player %d moved +%d. Linked Player %d collapsed to |%s⟩, moving +%d." % [
					state_to_bits(measured_state),
					current_player + 1,
					move,
					other_player + 1,
					state_to_bits(linked_state),
					linked_move
				]
			else:
				status_label.text = "Measured |%s⟩: Player %d moved +%d." % [
					state_to_bits(measured_state),
					current_player + 1,
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


func style_buttons():
	if move_button != null:
		move_button.text = "Move 1"
		move_button.modulate = Color(0.75, 0.85, 1.0)

	if quantum_button != null:
		quantum_button.text = "Create Superposition"
		quantum_button.modulate = Color(0.75, 0.55, 1.0)

	if boost_button != null:
		boost_button.text = "Oracle"
		boost_button.modulate = Color(1.0, 0.55, 0.75)

	if stabilize_button != null:
		stabilize_button.text = "Amplify"
		stabilize_button.modulate = Color(0.55, 1.0, 0.9)

	if entangle_button != null:
		entangle_button.text = "Entangle"
		entangle_button.modulate = Color(0.45, 0.8, 1.0)

	if measure_button != null:
		measure_button.text = "Measure"
		measure_button.modulate = Color(1.0, 0.85, 0.35)

	if change_aid_button != null:
		change_aid_button.text = "Change Aid"
		change_aid_button.modulate = Color(0.65, 1.0, 0.65)

func _on_save_game_button_pressed():
	save_game()


func _on_main_menu_button_pressed():
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _on_change_aid_button_pressed():
	if game_finished or quantum_active:
		return

	if current_player >= player_aid_loadouts.size():
		return

	var current_aid = player_aid_loadouts[current_player]
	var index = possible_aid_loadouts.find(current_aid)

	if index == -1:
		index = 0
	else:
		index = (index + 1) % possible_aid_loadouts.size()

	player_aid_loadouts[current_player] = possible_aid_loadouts[index]

	status_label.text = "Player %d changed aid loadout to %s." % [
		current_player + 1,
		player_aid_loadouts[current_player]
	]

	update_aid_loadout_ui()

	# Changing aid costs the player's turn.
	end_turn()


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