extends CharacterBody2D

## Player untuk platformer Pico Park style
## - Players bisa saling menginjak
## - Ketika player bawah loncat, player atas ikut terangkat

@export var player_id: int = 1

# Movement parameters
@export_group("Movement")
@export var move_speed: float = 280.0
@export var air_control: float = 0.5

# Jump parameters
@export_group("Jump")
@export var jump_velocity: float = -500.0
@export var min_jump_velocity: float = -200.0  # Minimum jump saat tap cepat
@export var gravity_scale: float = 1.0
@export var fall_gravity_multiplier: float = 1.5
@export var jump_cut_multiplier: float = 0.4  # Potong velocity saat release tombol (0.3-0.6 enak)
@export var jump_hold_time: float = 0.14  # Durasi (detik) untuk hold-jump lebih tinggi
@export var jump_hold_gravity_multiplier: float = 0.55  # Gravity saat tombol ditahan (lebih kecil = lebih tinggi)
@export var coyote_time: float = 0.12
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
var is_jumping: bool = false  # Track apakah sedang dalam lompatan
var jump_hold_timer: float = 0.0
var jump_held_prev: bool = false

# Stacking state - Pico Park style
var player_on_top: CharacterBody2D = null  # Player yang berdiri di atas kita
var player_below: CharacterBody2D = null   # Player yang kita injak
var last_y_position: float = 0.0           # Untuk track pergerakan vertikal

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
	
	# Add to player group for stacking detection
	add_to_group("player")
	
	last_y_position = global_position.y

func _physics_process(delta: float) -> void:
	# Simpan posisi Y sebelum movement untuk stacking
	var prev_y = global_position.y

	var jump_held := _is_jump_held()
	var jump_just_released := (not jump_held) and jump_held_prev
	jump_held_prev = jump_held

	# Get input based on player_id
	var input_dir := _get_input_direction()
	has_movement_input = (input_dir != 0)
	
	var grounded = is_on_floor()
	
	# Coyote time logic
	if grounded:
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
		is_jumping = true
		jump_hold_timer = jump_hold_time

	# Variable jump height (Pico Park-ish):
	# - Hold: gravity lebih kecil sebentar saat masih naik
	# - Release: jump-cut sekali
	if not grounded:
		var current_gravity = base_gravity * gravity_scale
		if velocity.y < 0 and jump_held and jump_hold_timer > 0.0:
			current_gravity *= jump_hold_gravity_multiplier
			jump_hold_timer = max(0.0, jump_hold_timer - delta)
		elif velocity.y > 0:
			current_gravity *= fall_gravity_multiplier
		velocity.y += current_gravity * delta
	else:
		# Reset vertical velocity when grounded
		if velocity.y > 0:
			velocity.y = 0
		is_jumping = false
		jump_hold_timer = 0.0

	# Jump cut saat tombol dilepas (sekali)
	if jump_just_released and velocity.y < 0:
		velocity.y *= jump_cut_multiplier
		# Pastikan minimal jump height (velocity negatif, jadi > berarti lebih lemah)
		if velocity.y > min_jump_velocity:
			velocity.y = min_jump_velocity
	
	# Horizontal movement
	if input_dir != 0:
		if grounded:
			velocity.x = input_dir * move_speed
		else:
			var target_vel = input_dir * move_speed
			velocity.x = lerp(velocity.x, target_vel, air_control)
		current_sprite.flip_h = (input_dir < 0)
	else:
		if grounded:
			velocity.x = move_toward(velocity.x, 0, move_speed * 0.3)
	
	# Apply rope force
	velocity += rope_force
	rope_force = Vector2.ZERO
	
	# Move
	move_and_slide()
	
	# PICO PARK STACKING: Jika kita bergerak ke atas dan ada player di atas, angkat dia juga
	var y_delta = global_position.y - prev_y  # Negatif = naik
	if y_delta < 0 and player_on_top and is_instance_valid(player_on_top):
		# Kita naik, angkat player di atas
		player_on_top.global_position.y += y_delta
		# Beri dia velocity yang sama supaya smooth
		if player_on_top.velocity.y > velocity.y:
			player_on_top.velocity.y = velocity.y
	
	# Animation
	_update_animation(input_dir, did_jump)
	
	was_on_floor = grounded
	last_y_position = global_position.y




func _update_animation(input_dir: float, did_jump: bool) -> void:
	var grounded = is_on_floor()
	if did_jump:
		current_sprite.play("jump")
	elif grounded:
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
	var is_pressed: bool = _is_jump_held()
	var just_pressed = is_pressed and not jump_key_was_pressed
	jump_key_was_pressed = is_pressed
	return just_pressed

func _is_jump_held() -> bool:
	if player_id == 1:
		return Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE)
	else:
		return Input.is_key_pressed(KEY_UP)

## Apply external force (called by rope system)
func apply_rope_force(force: Vector2) -> void:
	rope_force += force

## Set partner reference (called by Chain)
func set_partner(p: CharacterBody2D) -> void:
	partner = p

## Launch player with impulse
func launch(impulse: Vector2) -> void:
	velocity += impulse
