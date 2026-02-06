extends RigidBody2D

@export var player_id: int = 1
@export var move_force: float = 666.0
@export var jump_impulse: float = 800.0

func _ready():
	lock_rotation = true
	can_sleep = false
	# Adjust physics material if not set in editor
	if not physics_material_override:
		physics_material_override = PhysicsMaterial.new()
		physics_material_override.friction = 0.5

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var input_dir := 0.0
	var jump_requested := false

	if player_id == 1:
		if Input.is_key_pressed(KEY_A): input_dir -= 1
		if Input.is_key_pressed(KEY_D): input_dir += 1
		if Input.is_key_pressed(KEY_W): jump_requested = true
	else:
		if Input.is_key_pressed(KEY_LEFT): input_dir -= 1
		if Input.is_key_pressed(KEY_RIGHT): input_dir += 1
		if Input.is_key_pressed(KEY_UP): jump_requested = true

	if input_dir != 0:
		apply_central_force(Vector2(input_dir * move_force, 0))
	
	if jump_requested and state.get_contact_count() > 0:
		# Check if we are roughly on floor (contact normal points up)
		var on_floor = false
		for i in range(state.get_contact_count()):
			if state.get_contact_local_normal(i).dot(Vector2.UP) > 0.5:
				on_floor = true
				break
		
		if on_floor:
			apply_central_impulse(Vector2.UP * jump_impulse)

func apply_external_force(force: Vector2):
	apply_central_force(force)

func launch(impulse: Vector2):
	apply_central_impulse(impulse)
