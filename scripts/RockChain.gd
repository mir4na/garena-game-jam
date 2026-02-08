extends Node2D

## RockChain - Dua player terikat ke batu.
## Batu hanya bisa ditarik kalau kedua player menarik searah.

@export var player1_path: NodePath
@export var player2_path: NodePath
@export var rock_path: NodePath

@export var rope_length_1: float = 220.0  # Rope length for player1
@export var rope_length_2: float = 220.0  # Rope length for player2
@export var taut_threshold_ratio: float = 0.92

@export var pull_force: float = 1800.0
@export var pull_requires_grounded: bool = true

@export var player_snap_strength: float = 1.0  # 1.0 = hard clamp ke rope length
@export var max_position_correction_per_frame: float = 60.0  # Batasi snap biar ga terlihat teleport
@export var player_pull_velocity: float = 900.0

## Visual settings
@export_group("Visuals")
@export var segment_count: int = 10
@export var rope_width: float = 4.0
@export var rope_color: Color = Color(0.55, 0.35, 0.2)  # Brown rope
@export var tension_color: Color = Color.ORANGE_RED

var player1: CharacterBody2D
var player2: CharacterBody2D
var rock: RigidBody2D

# Visual rope points
var rope_points_1: Array[Vector2] = []  # player1 to rock
var rope_points_2: Array[Vector2] = []  # player2 to rock

func _ready() -> void:
	if player1_path:
		player1 = get_node_or_null(player1_path)
	if player2_path:
		player2 = get_node_or_null(player2_path)
	if rock_path:
		rock = get_node_or_null(rock_path)

func _physics_process(delta: float) -> void:
	if not player1 or not player2 or not rock:
		return

	# 1) Enforce rope constraint (batu menarik player)
	_enforce_player_rope(player1, rope_length_1, delta)
	_enforce_player_rope(player2, rope_length_2, delta)

	# 2) Cooperative pull (player menarik batu kalau dua-duanya searah)
	_apply_team_pull(delta)
	
	# 3) Update visual
	_update_rope_visual()

func _enforce_player_rope(player: CharacterBody2D, rope_len: float, delta: float) -> void:
	var to_player = player.global_position - rock.global_position
	var dist = to_player.length()
	if dist <= rope_len:
		return

	var dir = to_player / dist
	var excess = dist - rope_len

	# Position correction (dibatasi supaya ga terlihat "teleport")
	var correction = excess * player_snap_strength
	if max_position_correction_per_frame > 0.0:
		correction = min(correction, max_position_correction_per_frame)
	player.global_position -= dir * correction
	player.reset_physics_interpolation()

	# Beri velocity ke arah batu biar terasa ketarik
	var toward_rock = -dir
	player.velocity += toward_rock * player_pull_velocity * delta

func _apply_team_pull(_delta: float) -> void:
	var p1_dir = 0.0
	var p2_dir = 0.0
	if player1.has_method("get_move_input_dir"):
		p1_dir = float(player1.call("get_move_input_dir"))
	if player2.has_method("get_move_input_dir"):
		p2_dir = float(player2.call("get_move_input_dir"))

	# Must both be pressing and same direction
	if abs(p1_dir) < 0.1 or abs(p2_dir) < 0.1:
		return
	if sign(p1_dir) != sign(p2_dir):
		return

	if pull_requires_grounded:
		if not player1.is_on_floor() or not player2.is_on_floor():
			return

	# Must be taut-ish (at least one rope tight helps the feeling)
	var taut_len_1 = rope_length_1 * taut_threshold_ratio
	var taut_len_2 = rope_length_2 * taut_threshold_ratio
	var d1 = player1.global_position.distance_to(rock.global_position)
	var d2 = player2.global_position.distance_to(rock.global_position)
	if d1 < taut_len_1 and d2 < taut_len_2:
		return

	# Apply force to rock: direction based on players input
	# Input left (-1) => pull rock left
	var pull_dir = Vector2(sign(p1_dir), 0)
	rock.apply_central_force(pull_dir * pull_force)

func _update_rope_visual() -> void:
	rope_points_1.clear()
	rope_points_2.clear()
	
	var rock_pos = rock.global_position
	
	# Build rope from player1 to rock
	_build_rope_points(player1.global_position, rock_pos, rope_points_1, rope_length_1)
	# Build rope from player2 to rock
	_build_rope_points(player2.global_position, rock_pos, rope_points_2, rope_length_2)

func _build_rope_points(start_pos: Vector2, end_pos: Vector2, points: Array[Vector2], rope_len: float) -> void:
	var distance = start_pos.distance_to(end_pos)
	
	# Calculate sag - more sag when slack, no sag when taut
	var slack_ratio = clamp(1.0 - (distance / rope_len), 0.0, 1.0)
	var max_sag = 35.0 * slack_ratio * slack_ratio
	
	for i in range(segment_count + 1):
		var t = float(i) / segment_count
		var pos = start_pos.lerp(end_pos, t)
		
		# Parabolic sag
		var sag = sin(t * PI) * max_sag
		pos.y += sag
		
		points.append(pos)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not player1 or not player2 or not rock:
		return
	
	# Draw rope from player1 to rock
	_draw_single_rope(rope_points_1, player1.global_position, rope_length_1)
	# Draw rope from player2 to rock
	_draw_single_rope(rope_points_2, player2.global_position, rope_length_2)

func _draw_single_rope(points: Array[Vector2], player_pos: Vector2, rope_len: float) -> void:
	if points.size() < 2:
		return
	
	# Calculate tension for color
	var distance = player_pos.distance_to(rock.global_position)
	var tension = clamp((distance - rope_len * 0.7) / (rope_len * 0.3), 0.0, 1.0)
	var current_color = rope_color.lerp(tension_color, tension)
	
	# Convert to local coordinates
	var local_points: PackedVector2Array = PackedVector2Array()
	for p in points:
		local_points.append(to_local(p))
	
	# Draw rope
	draw_polyline(local_points, current_color, rope_width, true)
	
	# Draw knots at ends
	if local_points.size() > 0:
		draw_circle(local_points[0], rope_width * 1.2, current_color.darkened(0.2))
		draw_circle(local_points[local_points.size() - 1], rope_width * 1.2, current_color.darkened(0.2))
