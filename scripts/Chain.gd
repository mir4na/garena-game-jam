extends Node2D

## Pico Park Style Rope - Simple elastic rope connecting two players
## When one player moves too far, both get pulled

@export var player1_path: NodePath
@export var player2_path: NodePath

var player1: CharacterBody2D
var player2: CharacterBody2D

## Total rope length (max distance between players)
@export var rope_length: float = 150.0

## Number of visual segments for rope drawing
@export var segment_count: int = 10

## How strongly the rope pulls when stretched
@export var pull_strength: float = 15.0

## Visual settings
@export_group("Visuals")
@export var rope_width: float = 4.0
@export var rope_color: Color = Color(0.55, 0.35, 0.2)  # Brown rope
@export var tension_color: Color = Color.ORANGE_RED

## Rope gravity for visual sag
@export var rope_gravity: float = 400.0

# Visual rope points (for drawing)
var rope_points: Array[Vector2] = []

# Initialization flag
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
	print("Pico Park rope initialized, length: ", rope_length)

func _physics_process(_delta: float) -> void:
	if not is_initialized or not player1 or not player2:
		return
	
	# Calculate distance between players
	var distance = player1.global_position.distance_to(player2.global_position)
	var direction = (player2.global_position - player1.global_position).normalized()
	
	# Only apply constraint if rope is stretched beyond max length
	if distance > rope_length:
		_apply_rope_constraint(distance, direction)
	
	# Update visual rope points
	_update_rope_visual()

func _apply_rope_constraint(distance: float, direction: Vector2) -> void:
	var overstretch = distance - rope_length
	
	# Calculate pull force
	var pull_force = overstretch * pull_strength
	
	# Check which player is moving away (causing the stretch)
	var p1_vel_away = player1.velocity.dot(-direction)  # Moving away from p2
	var p2_vel_away = player2.velocity.dot(direction)   # Moving away from p1
	
	var p1_on_floor = player1.is_on_floor()
	var p2_on_floor = player2.is_on_floor()
	
	# Pico Park logic: 
	# - If one is grounded and other is in air, pull the air one
	# - If both in air or both grounded, pull both equally
	# - Player moving away gets stopped
	
	if p1_on_floor and not p2_on_floor:
		# P1 grounded, P2 in air - P2 gets pulled back
		if player2.has_method("apply_rope_force"):
			player2.call("apply_rope_force", -direction * pull_force)
		# Stop P2's outward velocity
		if p2_vel_away > 0:
			player2.velocity -= direction * p2_vel_away * 0.9
			
	elif p2_on_floor and not p1_on_floor:
		# P2 grounded, P1 in air - P1 gets pulled back
		if player1.has_method("apply_rope_force"):
			player1.call("apply_rope_force", direction * pull_force)
		# Stop P1's outward velocity
		if p1_vel_away > 0:
			player1.velocity -= (-direction) * p1_vel_away * 0.9
			
	else:
		# Both grounded or both in air - split force
		# Player causing stretch gets more force
		var p1_factor = 0.5
		var p2_factor = 0.5
		
		if p1_vel_away > 50 and p2_vel_away <= 50:
			p1_factor = 0.8
			p2_factor = 0.2
		elif p2_vel_away > 50 and p1_vel_away <= 50:
			p1_factor = 0.2
			p2_factor = 0.8
		
		if player1.has_method("apply_rope_force"):
			player1.call("apply_rope_force", direction * pull_force * p1_factor)
		if player2.has_method("apply_rope_force"):
			player2.call("apply_rope_force", -direction * pull_force * p2_factor)
		
		# Dampen outward velocities
		if p1_vel_away > 0:
			player1.velocity -= (-direction) * p1_vel_away * 0.5
		if p2_vel_away > 0:
			player2.velocity -= direction * p2_vel_away * 0.5

func _update_rope_visual() -> void:
	rope_points.clear()
	
	var start_pos = player1.global_position
	var end_pos = player2.global_position
	var distance = start_pos.distance_to(end_pos)
	
	# Calculate sag based on slack (less sag when stretched)
	var slack_ratio = clamp(1.0 - (distance / rope_length), 0.0, 1.0)
	var max_sag = 30.0 * slack_ratio
	
	for i in range(segment_count + 1):
		var t = float(i) / segment_count
		var pos = start_pos.lerp(end_pos, t)
		
		# Add sag (parabolic curve)
		var sag = sin(t * PI) * max_sag
		pos.y += sag
		
		rope_points.append(pos)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if rope_points.size() < 2:
		return
	
	# Calculate tension for color
	var distance = player1.global_position.distance_to(player2.global_position)
	var tension = clamp((distance - rope_length * 0.8) / (rope_length * 0.3), 0.0, 1.0)
	var current_color = rope_color.lerp(tension_color, tension)
	
	# Convert to local coordinates
	var local_points: PackedVector2Array = PackedVector2Array()
	for p in rope_points:
		local_points.append(to_local(p))
	
	# Draw rope
	draw_polyline(local_points, current_color, rope_width, true)
	
	# Draw end points
	if local_points.size() > 0:
		draw_circle(local_points[0], rope_width * 0.8, current_color.darkened(0.2))
		draw_circle(local_points[local_points.size() - 1], rope_width * 0.8, current_color.darkened(0.2))
