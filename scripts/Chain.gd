extends Node2D

## Verlet Rope - Smooth rope simulation between two players
## Uses Verlet integration for stable, natural-looking rope physics

@export var player1: CharacterBody2D
@export var player2: CharacterBody2D

## Number of rope segments (more = smoother, but heavier computation)
@export var segment_count: int = 15

## Total rope length
@export var rope_length: float = 150.0

## How strongly the rope pulls players when taut
@export var constraint_strength: float = 0.5

## Gravity for rope segments
@export var rope_gravity: float = 500.0

## Number of constraint iterations (more = stiffer rope)
@export var constraint_iterations: int = 8

## Visual settings
@export_group("Visuals")
@export var rope_width: float = 4.0
@export var rope_color: Color = Color(0.55, 0.35, 0.2)  # Brown rope
@export var tension_color: Color = Color.ORANGE_RED

# Rope point data structure
class RopePoint:
	var position: Vector2
	var old_position: Vector2
	var is_locked: bool = false
	
	func _init(pos: Vector2, locked: bool = false) -> void:
		position = pos
		old_position = pos
		is_locked = locked

# Array of rope points
var points: Array[RopePoint] = []

# Segment rest length
var segment_length: float = 0.0

# Initialization flag
var is_initialized: bool = false

func _ready() -> void:
	# Wait a frame for players to be ready
	await get_tree().process_frame
	_initialize_rope()

func _initialize_rope() -> void:
	if not player1 or not player2:
		push_warning("Rope: player1 or player2 not assigned!")
		return
	
	if is_initialized:
		return
	
	# Calculate segment length based on rope_length
	segment_length = rope_length / segment_count
	
	# Create rope points starting from actual player positions
	points.clear()
	var start_pos = player1.global_position
	var end_pos = player2.global_position
	
	# Create points along a line between players, but with a slight sag for natural look
	for i in range(segment_count + 1):
		var t = float(i) / segment_count
		var pos = start_pos.lerp(end_pos, t)
		
		# Add slight sag in the middle (catenary-like curve)
		var sag_amount = sin(t * PI) * 20.0  # 20 pixels of sag at center
		pos.y += sag_amount
		
		# First and last points are locked to players
		var is_endpoint = (i == 0 or i == segment_count)
		var point = RopePoint.new(pos, is_endpoint)
		points.append(point)
	
	is_initialized = true
	print("Rope initialized with ", segment_count, " segments, length: ", rope_length)

func _physics_process(delta: float) -> void:
	if not is_initialized or not player1 or not player2:
		return
	
	# Lock first and last points to players
	points[0].position = player1.global_position
	points[0].old_position = player1.global_position
	points[segment_count].position = player2.global_position
	points[segment_count].old_position = player2.global_position
	
	# Verlet integration for middle points
	_simulate_rope(delta)
	
	# Apply distance constraints
	_apply_constraints()
	
	# Calculate and apply forces to players if rope is taut
	_apply_player_forces()

func _simulate_rope(delta: float) -> void:
	# Apply verlet integration to non-locked points
	for i in range(1, segment_count):
		var point = points[i]
		
		# Calculate velocity from position difference
		var velocity = point.position - point.old_position
		
		# Apply damping
		velocity *= 0.98
		
		# Store old position
		point.old_position = point.position
		
		# Apply gravity and update position
		point.position += velocity
		point.position.y += rope_gravity * delta * delta

func _apply_constraints() -> void:
	# Iterate multiple times for stability
	for _iteration in range(constraint_iterations):
		for i in range(segment_count):
			var point_a = points[i]
			var point_b = points[i + 1]
			
			var delta_pos = point_b.position - point_a.position
			var distance = delta_pos.length()
			
			if distance < 0.0001:
				continue
			
			var difference = segment_length - distance
			var direction = delta_pos.normalized()
			var correction = direction * difference * 0.5
			
			# Apply correction based on lock status
			if not point_a.is_locked and not point_b.is_locked:
				point_a.position -= correction
				point_b.position += correction
			elif point_a.is_locked and not point_b.is_locked:
				point_b.position += correction * 2.0
			elif not point_a.is_locked and point_b.is_locked:
				point_a.position -= correction * 2.0

func _apply_player_forces() -> void:
	# Hard constraint - if players are too far apart, pull them back immediately
	var player_distance = player1.global_position.distance_to(player2.global_position)
	
	# If players are within rope length, no constraint needed
	if player_distance <= rope_length:
		return
	
	# Calculate how much the rope is overstretched
	var overstretch = player_distance - rope_length
	
	# Direction from player1 to player2
	var direction = (player2.global_position - player1.global_position).normalized()
	
	# Hard constraint: directly adjust velocities to prevent further separation
	# Split the correction between both players (each moves half)
	var correction = direction * overstretch * 0.5
	
	# Move players toward each other to maintain rope length
	player1.global_position += correction
	player2.global_position -= correction
	
	# Also adjust velocities to prevent fighting the constraint
	# Project velocity onto constraint direction and limit outward movement
	var p1_vel_along_rope = player1.velocity.dot(direction)
	var p2_vel_along_rope = player2.velocity.dot(-direction)
	
	# If player1 is moving away from player2, reduce that velocity component
	if p1_vel_along_rope < 0:
		player1.velocity -= direction * p1_vel_along_rope * 0.8
	
	# If player2 is moving away from player1, reduce that velocity component  
	if p2_vel_along_rope < 0:
		player2.velocity -= (-direction) * p2_vel_along_rope * 0.8
	
	# Transfer some momentum when one player pulls the other
	# This makes it feel like they're connected
	var avg_vel_along_rope = (player1.velocity.dot(direction) + player2.velocity.dot(direction)) * 0.5
	player1.velocity = player1.velocity - direction * (player1.velocity.dot(direction) - avg_vel_along_rope) * 0.3
	player2.velocity = player2.velocity - direction * (player2.velocity.dot(direction) - avg_vel_along_rope) * 0.3

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return
	
	# Build points array for drawing
	var draw_points: PackedVector2Array = PackedVector2Array()
	for point in points:
		draw_points.append(to_local(point.position))
	
	# Calculate tension for color
	var total_distance = 0.0
	for i in range(segment_count):
		total_distance += points[i].position.distance_to(points[i + 1].position)
	
	var stretch_ratio = total_distance / rope_length
	var tension = clamp((stretch_ratio - 0.9) / 0.2, 0.0, 1.0)
	var current_color = rope_color.lerp(tension_color, tension)
	
	# Draw the rope
	draw_polyline(draw_points, current_color, rope_width, true)
	
	# Optional: Draw small circles at each point for visual detail
	for i in range(draw_points.size()):
		var size = rope_width * 0.6
		if i == 0 or i == draw_points.size() - 1:
			size = rope_width * 0.8  # Larger at endpoints
		draw_circle(draw_points[i], size, current_color.darkened(0.15))

## Reset rope to initial state
func reset_rope() -> void:
	is_initialized = false
	points.clear()
	await get_tree().process_frame
	_initialize_rope()

## Get current stretched length
func get_current_length() -> float:
	var total = 0.0
	for i in range(segment_count):
		total += points[i].position.distance_to(points[i + 1].position)
	return total

## Check if rope is taut
func is_taut() -> float:
	return get_current_length() / rope_length
