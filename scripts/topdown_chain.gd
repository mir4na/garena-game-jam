extends Node2D

## Top-down chain for bullet hell level
## Hard constraint - players can't exceed rope length

@export var player1_path: NodePath
@export var player2_path: NodePath
@export var rope_length: float = 200.0

## Visual settings
@export_group("Visuals")
@export var segment_count: int = 12
@export var rope_width: float = 4.0
@export var rope_color: Color = Color(0.55, 0.35, 0.2)
@export var tension_color: Color = Color.ORANGE_RED

var player1: CharacterBody2D
var player2: CharacterBody2D
var rope_points: Array[Vector2] = []

func _ready() -> void:
	await get_tree().process_frame
	if player1_path:
		player1 = get_node_or_null(player1_path)
	if player2_path:
		player2 = get_node_or_null(player2_path)

func _physics_process(_delta: float) -> void:
	if not player1 or not player2:
		return
	
	_enforce_rope_constraint()
	_update_rope_visual()

func _enforce_rope_constraint() -> void:
	var p1_pos = player1.global_position
	var p2_pos = player2.global_position
	var distance = p1_pos.distance_to(p2_pos)
	
	if distance <= rope_length:
		return
	
	# Calculate excess distance
	var excess = distance - rope_length
	var direction = (p2_pos - p1_pos).normalized()
	
	# Move both players toward center (equal split)
	var correction = direction * (excess / 2.0)
	player1.global_position += correction
	player2.global_position -= correction
	
	# Stop outward velocity
	var p1_outward = player1.velocity.dot(-direction)
	if p1_outward > 0:
		player1.velocity -= (-direction) * p1_outward
	
	var p2_outward = player2.velocity.dot(direction)
	if p2_outward > 0:
		player2.velocity -= direction * p2_outward

func _update_rope_visual() -> void:
	rope_points.clear()
	
	var start_pos = player1.global_position
	var end_pos = player2.global_position
	var distance = start_pos.distance_to(end_pos)
	
	# Calculate sag
	var slack_ratio = clamp(1.0 - (distance / rope_length), 0.0, 1.0)
	var max_sag = 30.0 * slack_ratio * slack_ratio
	
	for i in range(segment_count + 1):
		var t = float(i) / segment_count
		var pos = start_pos.lerp(end_pos, t)
		
		# Sag perpendicular to rope direction
		var sag = sin(t * PI) * max_sag
		var perp = (end_pos - start_pos).normalized().orthogonal()
		pos += perp * sag
		
		rope_points.append(pos)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if rope_points.size() < 2:
		return
	
	if not player1 or not player2:
		return
	
	# Calculate tension for color
	var distance = player1.global_position.distance_to(player2.global_position)
	var tension = clamp((distance - rope_length * 0.7) / (rope_length * 0.3), 0.0, 1.0)
	var current_color = rope_color.lerp(tension_color, tension)
	
	# Convert to local coordinates
	var local_points: PackedVector2Array = PackedVector2Array()
	for p in rope_points:
		local_points.append(to_local(p))
	
	draw_polyline(local_points, current_color, rope_width, true)
	
	# Draw knots
	if local_points.size() > 0:
		draw_circle(local_points[0], rope_width * 1.2, current_color.darkened(0.2))
		draw_circle(local_points[local_points.size() - 1], rope_width * 1.2, current_color.darkened(0.2))
