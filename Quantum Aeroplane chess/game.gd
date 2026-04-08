extends Node2D

var plane_position: int = 0
var score: int = 0
var player_positions = [0, 0]
var player_scores = [0, 0]
var current_player: int = 0

var target_score: int = 5

var crisis_tiles = [3, 8, 14, 19]
var max_active_crises: int = 4

var quantum_options = []
var quantum_active = false
var game_finished: bool = false
var quantum_weights = [0.5, 0.5]

var tile_positions: Array[Vector2] = [
	Vector2(120, 120),
	Vector2(220, 120),
	Vector2(320, 120),
	Vector2(420, 120),
	Vector2(520, 120),
	Vector2(620, 120),
	Vector2(720, 120),

	Vector2(820, 200),
	Vector2(820, 300),
	Vector2(820, 400),
	Vector2(820, 500),
	Vector2(820, 600),

	Vector2(720, 680),
	Vector2(620, 680),
	Vector2(520, 680),
	Vector2(420, 680),
	Vector2(320, 680),
	Vector2(220, 680),
	Vector2(120, 680),

	Vector2(40, 600),
	Vector2(40, 500),
	Vector2(40, 400),
	Vector2(40, 300),
	Vector2(40, 200)
]

@onready var board = $Board
@onready var plane = $Plane
@onready var plane2 = $Plane2
@onready var score_label = $UI/ScoreLabel
@onready var status_label = $UI/StatusLabel
@onready var quantum_button = $UI/QuantumMoveButton
@onready var measure_button = $UI/MeasureButton

func _ready():
	randomize()
	center_map()

	board.points = tile_positions
	board.queue_redraw()

	create_board_tiles()
	update_plane_position(true)
	update_score()
	update_buttons()
	check_game_state()
	update_status()

func create_board_tiles():
	for child in board.get_children():
		child.queue_free()

	for i in range(tile_positions.size()):
		var tile = Polygon2D.new()
		tile.polygon = PackedVector2Array([
			Vector2(-22, -22),
			Vector2(22, -22),
			Vector2(22, 22),
			Vector2(-22, 22)
		])

		tile.position = tile_positions[i]

		if i == 0:
			tile.color = Color(0.25, 0.85, 0.35)
		elif i in crisis_tiles:
			tile.color = Color(0.95, 0.25, 0.25)
		else:
			tile.color = Color(0.72, 0.74, 0.80)

		board.add_child(tile)

func center_map():
	var min_x = tile_positions[0].x
	var max_x = tile_positions[0].x
	var min_y = tile_positions[0].y
	var max_y = tile_positions[0].y

	for pos in tile_positions:
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)

	var map_center = Vector2(
		(min_x + max_x) / 2.0,
		(min_y + max_y) / 2.0
	)

	var screen_center = get_viewport_rect().size / 2.0
	var offset = screen_center - map_center

	for i in range(tile_positions.size()):
		tile_positions[i] += offset

func update_plane_positions(instant := false):
	var pos1 = tile_positions[player_positions[0]] + Vector2(-14, -14)
	var pos2 = tile_positions[player_positions[1]] + Vector2(14, 14)

	if instant:
		plane.position = pos1
		plane2.position = pos2
	else:
		var tween = create_tween()
		tween.tween_property(plane, "position", pos1, 0.35)
		tween.parallel().tween_property(plane2, "position", pos2, 0.35)

func update_plane_position(instant := false):
	update_plane_positions(instant)

func update_score():
	score_label.text = "P1: %d   P2: %d   Goal: %d" % [player_scores[0], player_scores[1], target_score]

func update_buttons():
	quantum_button.disabled = quantum_active or game_finished
	measure_button.disabled = not quantum_active or game_finished

func update_status():
	if not game_finished and not quantum_active:
		status_label.text = "Player %d turn" % (current_player + 1)

func color_crisis_tiles():
	var tiles = board.get_children()

	for i in range(tiles.size()):
		if tiles[i] is Polygon2D:
			if i == 0:
				tiles[i].color = Color(0.25, 0.85, 0.35)
			elif i in crisis_tiles:
				tiles[i].color = Color(0.95, 0.25, 0.25)
			else:
				tiles[i].color = Color(0.72, 0.74, 0.80)

func spawn_new_crisis():
	var possible_tiles = []

	for i in range(tile_positions.size()):
		if i != 0 and i not in crisis_tiles and i not in player_positions:
			possible_tiles.append(i)

	if possible_tiles.size() > 0 and crisis_tiles.size() < max_active_crises:
		var new_tile = possible_tiles[randi() % possible_tiles.size()]
		crisis_tiles.append(new_tile)

func check_crisis_tile():
	plane_position = player_positions[current_player]

	if plane_position in crisis_tiles:
		score += 1
		player_scores[current_player] += 1
		crisis_tiles.erase(plane_position)
		spawn_new_crisis()
		update_score()
		color_crisis_tiles()
		status_label.text = "Player %d delivered aid!" % (current_player + 1)

func check_game_state():
	if player_scores[0] >= target_score:
		status_label.text = "Player 1 Wins!"
		game_finished = true
	elif player_scores[1] >= target_score:
		status_label.text = "Player 2 Wins!"
		game_finished = true

	update_buttons()

func end_turn():
	if game_finished:
		return

	current_player = 1 - current_player
	update_status()

func _on_quantum_move_button_pressed():
	if quantum_active or game_finished:
		return

	quantum_options = [2, 4]
	quantum_weights = [0.5, 0.5]
	quantum_active = true
	status_label.text = "Player %d superposition: %s" % [current_player + 1, str(quantum_options)]
	update_buttons()

func _on_stabilize_button_pressed():
	if not quantum_active or game_finished:
		return

	quantum_weights = [0.75, 0.25]
	status_label.text = "State stabilized: 2 is more likely"

func _on_boost_button_pressed():
	if not quantum_active or game_finished:
		return

	quantum_weights = [0.25, 0.75]
	status_label.text = "State boosted: 4 is more likely"

func _on_move_button_pressed():
	if game_finished:
		return

	player_positions[current_player] = (player_positions[current_player] + 1) % tile_positions.size()
	plane_position = player_positions[current_player]

	update_plane_position()
	check_crisis_tile()
	check_game_state()

	if not game_finished:
		status_label.text = "Player %d moved 1 tile." % (current_player + 1)
		end_turn()

func _on_measure_button_pressed():
	if not quantum_active or game_finished:
		return

	var r = randf()
	var move = quantum_options[0] if r < quantum_weights[0] else quantum_options[1]

	player_positions[current_player] = (player_positions[current_player] + move) % tile_positions.size()
	plane_position = player_positions[current_player]

	quantum_active = false
	quantum_options.clear()

	update_plane_position()
	check_crisis_tile()
	check_game_state()

	if not game_finished and plane_position not in crisis_tiles:
		status_label.text = "Player %d collapsed move: %d" % [current_player + 1, move]

	update_buttons()

	if not game_finished:
		end_turn()
