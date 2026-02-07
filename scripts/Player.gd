extends CharacterBody2D

## Player untuk platformer dengan rope/chain constraint (Pico Park style)
## Simple: can move, jump, connected by rope

@export var player_id: int = 1

# Movement parameters
@export_group("Movement")
@export var move_speed: float = 280.0
@export var air_control: float = 0.5  # Control in air

# Jump parameters
@export_group("Jump")
@export var jump_velocity: float = -420.0
@export var gravity_scale: float = 1.0
@export var fall_gravity_multiplier: float = 1.4
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

# Animation references
@onready var animated = $Player1Animated
@onready var animated2 = $Player2Animated
@onready var animated3 = $Player3Animated
var current_sprite: AnimatedSprite2D

# Internal state
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var jump_key_was_pressed: bool = false

# External force from rope constraint
var rope_force: Vector2 = Vector2.ZERO

# Track if player has active input this frame
var has_movement_input: bool = false

# Partner reference (set by Chain)
var partner: CharacterBody2D = null

# Get gravity from project settings
var base_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	# Get selected style from GameManager
	var style = 1
	if GameManager:
		style = GameManager.get_player_style(player_id)
	
	# Hide all sprites first
	animated.visible = false
	animated2.visible = false
	if animated3:
		animated3.visible = false
	
	# Select sprite based on style
	match style:
		1:
			current_sprite = animated
		2:
			current_sprite = animated2
		3:
			if animated3:
				current_sprite = animated3
			else:
				current_sprite = animated
		_:
			current_sprite = animated
	
	current_sprite.visible = true
	current_sprite.play("idle")

func _physics_process(delta: float) -> void:
	# Get input based on player_id
	var input_dir := _get_input_direction()
	
	# Track if player has movement input
	has_movement_input = (input_dir != 0)
	
	# Apply gravity
	if not is_on_floor():
		var current_gravity = base_gravity * gravity_scale
		# Heavier gravity when falling
		if velocity.y > 0:
			current_gravity *= fall_gravity_multiplier
		velocity.y += current_gravity * delta
	
	# Coyote time logic
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	
	# Jump buffer logic
	var jump_just_pressed = _is_jump_just_pressed()
	if jump_just_pressed:
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	
	# Handle jump
	var did_jump = false
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
		did_jump = true
	
	# Horizontal movement
	if input_dir != 0:
		if is_on_floor():
			velocity.x = input_dir * move_speed
		else:
			# Air control - lerp toward target
			var target_vel = input_dir * move_speed
			velocity.x = lerp(velocity.x, target_vel, air_control)
		# Flip sprite
		current_sprite.flip_h = (input_dir < 0)
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, move_speed * 0.3)
		# In air, preserve momentum
	
	# Apply rope force (from Chain constraint)
	velocity += rope_force
	rope_force = Vector2.ZERO
	
	# Move the character
	move_and_slide()
	
	# Push RigidBody2D objects by body collision
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody2D and not collider.freeze:
			var push_direction = collision.get_normal() * -1
			var push_force = 50.0  # Gentle push force
			collider.apply_central_impulse(push_direction * push_force)
	
	# Animation
	_update_animation(input_dir, did_jump)
	
	was_on_floor = is_on_floor()

func _update_animation(input_dir: float, did_jump: bool) -> void:
	if did_jump:
		current_sprite.play("jump")
	elif is_on_floor():
		if input_dir != 0:
			current_sprite.play("run")
		else:
			current_sprite.play("idle")
	else:
		if current_sprite.animation != "jump":
			current_sprite.play("jump")

func _get_input_direction() -> float:
	if player_id == 1:
		var left = Input.is_key_pressed(KEY_A)
		var right = Input.is_key_pressed(KEY_D)
		return float(right) - float(left)
	else:
		var left = Input.is_key_pressed(KEY_LEFT)
		var right = Input.is_key_pressed(KEY_RIGHT)
		return float(right) - float(left)

func _is_jump_just_pressed() -> bool:
	var is_pressed: bool
	if player_id == 1:
		is_pressed = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE)
	else:
		is_pressed = Input.is_key_pressed(KEY_UP)
	
	var just_pressed = is_pressed and not jump_key_was_pressed
	jump_key_was_pressed = is_pressed
	return just_pressed

## Apply external force (called by rope system)
func apply_rope_force(force: Vector2) -> void:
	rope_force += force

## Set partner reference (called by Chain)
func set_partner(p: CharacterBody2D) -> void:
	partner = p

## Launch player with impulse
func launch(impulse: Vector2) -> void:
	velocity += impulse
