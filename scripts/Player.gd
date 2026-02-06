extends CharacterBody2D

## Player untuk platformer dengan rope/chain constraint

@export var player_id: int = 1

# Movement parameters
@export_group("Movement")
@export var move_speed: float = 200.0

# Jump parameters
@export_group("Jump")
@export var jump_velocity: float = -400.0
@export var gravity_scale: float = 1.0
@export var fall_gravity_multiplier: float = 1.5
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

# Internal state
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var jump_key_was_pressed: bool = false  # Track jump key state for "just pressed" detection

# External force from rope constraint
var rope_force: Vector2 = Vector2.ZERO

# Get gravity from project settings
var base_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
	# Get input based on player_id
	var input_dir := _get_input_direction()
	
	# Apply gravity
	if not is_on_floor():
		var current_gravity = base_gravity * gravity_scale
		# Heavier gravity when falling for better game feel
		if velocity.y > 0:
			current_gravity *= fall_gravity_multiplier
		velocity.y += current_gravity * delta
	
	# Coyote time logic
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	
	# Jump buffer logic
	if _is_jump_just_pressed():
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	
	# Handle jump
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
	
	# Horizontal movement (instant, no acceleration)
	if input_dir != 0:
		velocity.x = input_dir * move_speed
	else:
		velocity.x = 0
	
	# Apply rope force (from VerletRope constraint)
	velocity += rope_force
	rope_force = Vector2.ZERO  # Reset after applying
	
	# Move the character
	move_and_slide()
	
	was_on_floor = is_on_floor()

func _get_input_direction() -> float:
	if player_id == 1:
		# Player 1: WASD only (tidak pakai ui_left/ui_right karena itu juga arrow keys)
		var left = Input.is_key_pressed(KEY_A)
		var right = Input.is_key_pressed(KEY_D)
		return float(right) - float(left)
	else:
		# Player 2: Arrow keys only
		var left = Input.is_key_pressed(KEY_LEFT)
		var right = Input.is_key_pressed(KEY_RIGHT)
		return float(right) - float(left)

func _is_jump_just_pressed() -> bool:
	var is_pressed: bool
	if player_id == 1:
		# Player 1: W or Space
		is_pressed = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE)
	else:
		# Player 2: Up arrow
		is_pressed = Input.is_key_pressed(KEY_UP)
	
	# Only return true on the first frame the key is pressed
	var just_pressed = is_pressed and not jump_key_was_pressed
	jump_key_was_pressed = is_pressed
	return just_pressed

## Apply external force (called by rope system)
func apply_rope_force(force: Vector2) -> void:
	rope_force += force

## Get the attachment point for the rope (center of player)
func get_rope_attachment_point() -> Vector2:
	return global_position

## Launch player with impulse (for special mechanics)
func launch(impulse: Vector2) -> void:
	velocity += impulse
