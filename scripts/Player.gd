extends RigidBody2D

@export var player_id: int = 1
@export var move_force: float = 666.0
@export var jump_impulse: float = 400.0

@onready var animated = $Player1Animated
@onready var animated2 = $Player2Animated
var current_sprite: AnimatedSprite2D

func _ready():
	lock_rotation = true
	can_sleep = false
	
	if player_id == 1:
		current_sprite = animated
		animated2.visible = false
		animated.visible = true
	else:
		current_sprite = animated2
		animated.visible = false
		animated2.visible = true
		
	if not physics_material_override:
		physics_material_override = PhysicsMaterial.new()
		physics_material_override.friction = 0.5

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var input_dir := 0.0
	var jump_requested := false

	# Check floor state first
	var on_floor = false
	if state.get_contact_count() > 0:
		for i in range(state.get_contact_count()):
			if state.get_contact_local_normal(i).dot(Vector2.UP) > 0.5:
				on_floor = true
				break

	if player_id == 1:
		if Input.is_key_pressed(KEY_A): 
			input_dir -= 1
			if on_floor: current_sprite.play("run")
			current_sprite.flip_h = true
		if Input.is_key_pressed(KEY_D): 
			input_dir += 1
			if on_floor: current_sprite.play("run")
			current_sprite.flip_h = false
		if Input.is_key_pressed(KEY_W): 
			jump_requested = true
	else:
		if Input.is_key_pressed(KEY_LEFT): 
			input_dir -= 1
			if on_floor: current_sprite.play("run")
			current_sprite.flip_h = true
		if Input.is_key_pressed(KEY_RIGHT): 
			input_dir += 1
			if on_floor: current_sprite.play("run")
			current_sprite.flip_h = false
		if Input.is_key_pressed(KEY_UP): 
			jump_requested = true

	# Animation Logic
	if jump_requested and on_floor:
		current_sprite.play("jump")
	elif on_floor and input_dir == 0:
		current_sprite.play("idle")
	elif not on_floor:
		# Keep playing jump loop or frame if airborne
		if current_sprite.animation != "jump":
			current_sprite.play("jump")

	# Physics Application
	if input_dir != 0:
		apply_central_force(Vector2(input_dir * move_force, 0))
	
	if jump_requested and on_floor:
		apply_central_impulse(Vector2.UP * jump_impulse)

func apply_external_force(force: Vector2):
	apply_central_force(force)

func launch(impulse: Vector2):
	apply_central_impulse(impulse)
