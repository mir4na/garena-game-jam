extends Node2D

@export var player1: RigidBody2D
@export var player2: RigidBody2D
@export var max_length: float = 300.0
@export var stiffness: float = 20.0
@export var damping: float = 0.5

func _process(delta: float) -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not player1 or not player2:
		return
		
	var pointer = player2.global_position - player1.global_position
	var distance = pointer.length()
	
	# Elastic spring force (Hooke's Law)
	# F = k * x (where x is stretch beyond natural max_length, or just distance in general if we want rubber band)
	# The user asked for "elastically" so let's make it act like a rubber band that is loose until max_length.
	# Actually, a chain usually is loose until max length, then rigid. 
	# But user said "like elastically", so maybe it's a bungee cord?
	# Let's interpret: Slack until `max_length`, then spring force pulls them back.
	
	if distance > max_length:
		var stretch = distance - max_length
		var force_magnitude = stiffness * stretch
		var force_dir = pointer.normalized()
		
		# Calculate relative velocity for damping
		var rel_vel = player2.linear_velocity - player1.linear_velocity
		var damp_force = rel_vel.dot(force_dir) * damping
		
		var total_force = (force_magnitude + damp_force) * force_dir
		
		# Apply forces
		# Pull P1 towards P2
		player1.apply_central_force(total_force)
		# Pull P2 towards P1 (Newton's 3rd Law)
		player2.apply_central_force(-total_force)

func _draw() -> void:
	if player1 and player2:
		var pointer = player2.global_position - player1.global_position
		var color = Color.WEB_GRAY
		# Visual feedback for tension
		if pointer.length() > max_length:
			color = Color.ORANGE_RED
			
		draw_line(to_local(player1.global_position), to_local(player2.global_position), color, 5.0)
