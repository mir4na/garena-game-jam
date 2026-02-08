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
@export var gravity_right := false
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

# Animation smoothing (prevents jump anim on 1-2 frame floor jitter)
var anim_airborne_time: float = 0.0

# Stacking state - Pico Park style
var player_on_top: CharacterBody2D = null  # Player yang berdiri di atas kita
var player_below: CharacterBody2D = null   # Player yang kita injak
var last_y_position: float = 0.0           # Untuk track pergerakan vertikal

# External force from rope constraint
var rope_force: Vector2 = Vector2.ZERO

# Track if player has active input this frame
var has_movement_input: bool = false
var last_input_dir: float = 0.0

# Partner reference (set by Chain)
var partner: CharacterBody2D = null

# Get gravity from project settings
var base_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Top-down mode for bullet hell
var topdown_mode: bool = false
var topdown_speed: float = 300.0
var is_hit: bool = false
var invincible_timer: float = 0.0
var invincible_duration: float = 1.5

func _ready() -> void:
	if gravity_right:
		rotation = rad_to_deg(3.14159)
		
	
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
	
	if current_sprite:
		current_sprite.visible = true
		current_sprite.play("idle")
		print("DEBUG PLAYER: Player ", name, " Style: ", style, " Sprite: ", current_sprite.name, " Vis: ", current_sprite.visible, " Mod: ", current_sprite.modulate)
	else:
		print("ERROR PLAYER: No current_sprite selected for ", name)
	
	# Add to player group for stacking detection
	add_to_group("player")
	
	last_y_position = global_position.y

func _physics_process(delta: float) -> void:
	# TOP-DOWN MODE - untuk bullet hell
	if topdown_mode:
		_physics_process_topdown(delta)
		return
	
	# PLATFORMER MODE - normal gameplay
	if gravity_right:
		gravity_scale = 0
		velocity.x += delta * base_gravity
		
	# Simpan posisi Y sebelum movement untuk stacking
	var _prev_y = global_position.y

	var jump_held := _is_jump_held()
	var jump_just_released := (not jump_held) and jump_held_prev
	jump_held_prev = jump_held

	# Get input based on player_id
	var input_dir := _get_input_direction()
	has_movement_input = (input_dir != 0)
	last_input_dir = input_dir
	
	var grounded = is_on_floor()
	# Track how long we've been off the floor for animation purposes
	if grounded:
		anim_airborne_time = 0.0
	else:
		anim_airborne_time += delta
	
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
	
	was_on_floor = grounded
	last_y_position = global_position.y

	# Handle slope rotation - align player to floor surface
	var target_rotation = 0.0
	if grounded:
		var normal = get_floor_normal()
		# Only rotate if we have a valid floor normal (not zero)
		if normal != Vector2.ZERO:
			# Calculate angle: normal points UP from surface, so we rotate perpendicular
			target_rotation = normal.angle() + PI / 2.0
			# Clamp to reasonable range to prevent crazy spinning
			target_rotation = clamp(target_rotation, deg_to_rad(-60), deg_to_rad(60))
	
	# Smoothly rotate towards target (faster when on ground, slower in air)
	var rotation_speed = 12.0 if grounded else 8.0
	rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)




func _update_animation(input_dir: float, did_jump: bool) -> void:
	# Catatan: is_on_floor() bisa false 1 frame (jitter/rotating ground/stacking)
	# Jadi untuk anim, kita treat airborne hanya kalau gerak vertikalnya signifikan.
	var grounded := is_on_floor()
	var vertical_speed := absf(velocity.y)
	# Require being off-floor for a short time to avoid rope/tilt jitter triggering jump anim
	var considered_airborne := (not grounded) and (anim_airborne_time > 0.08) and (vertical_speed > 30.0)

	var target_anim: StringName
	if did_jump or considered_airborne:
		target_anim = &"jump"
	else:
		# Ground (atau "nyaris ground"), gunakan gerak horizontal utk idle/run
		if absf(velocity.x) > 5.0 and input_dir != 0:
			target_anim = &"run"
		else:
			target_anim = &"idle"

	# Jangan restart anim yang sama tiap frame
	if current_sprite.animation != target_anim:
		current_sprite.play(target_anim)

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

func get_move_input_dir() -> float:
	return last_input_dir

## Apply external force (called by rope system)
func apply_rope_force(force: Vector2) -> void:
	rope_force += force

## Set partner reference (called by Chain)
func set_partner(p: CharacterBody2D) -> void:
	partner = p

## Launch player with impulse
func launch(impulse: Vector2) -> void:
	velocity += impulse

## ========== TOP-DOWN MODE FOR BULLET HELL ==========

func set_topdown_mode(enabled: bool) -> void:
	topdown_mode = enabled
	if enabled:
		# Reset velocity when switching modes
		velocity = Vector2.ZERO
		rotation = 0
		# Reset animation
		if current_sprite:
			current_sprite.play("run")

func _physics_process_topdown(delta: float) -> void:
	# Invincibility after hit
	if invincible_timer > 0:
		invincible_timer -= delta
		# Flash effect
		if current_sprite:
			current_sprite.visible = int(invincible_timer * 10) % 2 == 0
		if invincible_timer <= 0:
			is_hit = false
			if current_sprite:
				current_sprite.visible = true
	
	# Get 8-directional input
	var input_dir := _get_topdown_input()
	last_input_dir = input_dir.x
	has_movement_input = (input_dir != Vector2.ZERO)
	
	# Movement - no gravity
	if input_dir != Vector2.ZERO:
		velocity = input_dir * topdown_speed
		# Flip sprite based on horizontal direction
		if current_sprite:
			if input_dir.x < 0:
				current_sprite.flip_h = true
			elif input_dir.x > 0:
				current_sprite.flip_h = false
			current_sprite.play("run")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, topdown_speed * 0.2)
		if current_sprite and current_sprite.animation != "idle":
			current_sprite.play("idle")
	
	# Apply rope force
	velocity += rope_force
	rope_force = Vector2.ZERO
	
	move_and_slide()

func _get_topdown_input() -> Vector2:
	var dir := Vector2.ZERO
	
	if player_id == 1:
		if Input.is_key_pressed(KEY_W):
			dir.y -= 1
		if Input.is_key_pressed(KEY_S):
			dir.y += 1
		if Input.is_key_pressed(KEY_A):
			dir.x -= 1
		if Input.is_key_pressed(KEY_D):
			dir.x += 1
	else:
		if Input.is_key_pressed(KEY_UP):
			dir.y -= 1
		if Input.is_key_pressed(KEY_DOWN):
			dir.y += 1
		if Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1
		if Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1
	
	return dir.normalized()

func take_hit() -> void:
	if is_hit or invincible_timer > 0:
		return
	
	is_hit = true
	invincible_timer = invincible_duration
	
	# Red flash effect on hit
	if current_sprite:
		var tween = create_tween()
		tween.tween_property(current_sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.05)
		tween.tween_property(current_sprite, "modulate", Color.WHITE, 0.15)
