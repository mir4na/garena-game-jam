extends Node2D

## Pico Park Style Rope - Hard constraint connecting two players
## Rope has max length, players cannot go beyond it

@export var player1_path: NodePath
@export var player2_path: NodePath

var player1: CharacterBody2D
var player2: CharacterBody2D

## Total rope length (max distance between players)
@export var rope_length: float = 200.0

## Number of visual segments for rope drawing
@export var segment_count: int = 12

## Visual settings
@export_group("Visuals")
@export var rope_width: float = 4.0
@export var rope_color: Color = Color(0.55, 0.35, 0.2)  # Brown rope
@export var tension_color: Color = Color.ORANGE_RED

# Visual rope points
var rope_points: Array[Vector2] = []
var is_initialized: bool = false

func _ready() -> void:
	await get_tree().process_frame
	_initialize()

func _initialize() -> void:
	if player1_path: player1 = get_node_or_null(player1_path)
	if player2_path: player2 = get_node_or_null(player2_path)

	if not player1 or not player2:
		push_warning("Rope: player1 or player2 not assigned!")
		return
	
	# Set partner references
	if player1.has_method("set_partner"):
		player1.call("set_partner", player2)
	if player2.has_method("set_partner"):
		player2.call("set_partner", player1)
	
	is_initialized = true

func _physics_process(delta: float) -> void:
	if not is_initialized or not player1 or not player2:
		return
	
	_apply_pico_park_constraint(delta)
	_update_rope_visual()

func _apply_pico_park_constraint(_delta: float) -> void:
	var p1_pos = player1.global_position
	var p2_pos = player2.global_position
	var distance = p1_pos.distance_to(p2_pos)
	
	# Tidak ada constraint jika dalam rope length
	if distance <= rope_length:
		return
	
	# Hitung seberapa jauh over-stretched
	var excess = distance - rope_length
	var direction = (p2_pos - p1_pos).normalized()  # p1 -> p2
	
	var p1_grounded = player1.is_on_floor()
	var p2_grounded = player2.is_on_floor()
	
	# Cari siapa yang menyebabkan stretch (moving away)
	var p1_moving_away = player1.velocity.dot(-direction) > 10  # p1 moving away from p2
	var p2_moving_away = player2.velocity.dot(direction) > 10   # p2 moving away from p1
	
	# PICO PARK CONSTRAINT:
	# 1. Hard limit - tidak boleh lebih jauh dari rope_length
	# 2. Koreksi posisi langsung
	# 3. Transfer momentum
	
	if p1_grounded and not p2_grounded:
		# P1 di tanah, P2 di udara -> P2 ditarik
		_pull_player(player2, -direction, excess, 1.0)
		_stop_outward_velocity(player2, direction)
		
	elif p2_grounded and not p1_grounded:
		# P2 di tanah, P1 di udara -> P1 ditarik
		_pull_player(player1, direction, excess, 1.0)
		_stop_outward_velocity(player1, -direction)
		
	elif p1_grounded and p2_grounded:
		# Keduanya di tanah
		if p1_moving_away and not p2_moving_away:
			# P1 yang bergerak menjauh -> P1 ditarik lebih, atau bawa P2
			_pull_player(player1, direction, excess * 0.7, 1.0)
			_pull_player(player2, -direction, excess * 0.3, 1.0)
			_stop_outward_velocity(player1, -direction)
		elif p2_moving_away and not p1_moving_away:
			# P2 yang bergerak menjauh -> P2 ditarik lebih, atau bawa P1
			_pull_player(player2, -direction, excess * 0.7, 1.0)
			_pull_player(player1, direction, excess * 0.3, 1.0)
			_stop_outward_velocity(player2, direction)
		else:
			# Keduanya diam atau keduanya bergerak -> split equal
			_pull_player(player1, direction, excess * 0.5, 1.0)
			_pull_player(player2, -direction, excess * 0.5, 1.0)
			
	else:
		# Keduanya di udara -> split based on velocity
		var p1_speed = abs(player1.velocity.dot(-direction))
		var p2_speed = abs(player2.velocity.dot(direction))
		var total_speed = p1_speed + p2_speed + 0.001
		
		var p1_ratio = p1_speed / total_speed
		var p2_ratio = p2_speed / total_speed
		
		_pull_player(player1, direction, excess * p2_ratio, 1.0)
		_pull_player(player2, -direction, excess * p1_ratio, 1.0)

func _pull_player(player: CharacterBody2D, direction: Vector2, amount: float, strength: float) -> void:
	# Koreksi posisi langsung (hard constraint)
	player.global_position += direction * amount * strength
	
	# Juga beri velocity ke arah tarikan untuk feel yang smooth
	var pull_vel = direction * amount * 5.0
	player.velocity += pull_vel

func _stop_outward_velocity(player: CharacterBody2D, outward_dir: Vector2) -> void:
	# Stop velocity component yang bergerak menjauh
	var outward_speed = player.velocity.dot(outward_dir)
	if outward_speed > 0:
		player.velocity -= outward_dir * outward_speed * 0.95

func _update_rope_visual() -> void:
	rope_points.clear()
	
	if not player1 or not player2:
		return
	
	var start_pos = player1.global_position
	var end_pos = player2.global_position
	var distance = start_pos.distance_to(end_pos)
	
	# Calculate sag - lebih sag kalau kendur, tidak ada sag kalau tegang
	var slack_ratio = clamp(1.0 - (distance / rope_length), 0.0, 1.0)
	var max_sag = 40.0 * slack_ratio * slack_ratio  # Quadratic for more natural sag
	
	for i in range(segment_count + 1):
		var t = float(i) / segment_count
		var pos = start_pos.lerp(end_pos, t)
		
		# Parabolic sag
		var sag = sin(t * PI) * max_sag
		pos.y += sag
		
		rope_points.append(pos)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if rope_points.size() < 2:
		return
	
	if not player1 or not player2:
		return
	
	# Hitung tension untuk warna
	var distance = player1.global_position.distance_to(player2.global_position)
	var tension = clamp((distance - rope_length * 0.7) / (rope_length * 0.3), 0.0, 1.0)
	var current_color = rope_color.lerp(tension_color, tension)
	
	# Convert to local coordinates
	var local_points: PackedVector2Array = PackedVector2Array()
	for p in rope_points:
		local_points.append(to_local(p))
	
	# Draw rope
	draw_polyline(local_points, current_color, rope_width, true)
	
	# Draw end points (knots)
	if local_points.size() > 0:
		draw_circle(local_points[0], rope_width * 1.2, current_color.darkened(0.2))
		draw_circle(local_points[local_points.size() - 1], rope_width * 1.2, current_color.darkened(0.2))
