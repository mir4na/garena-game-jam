extends CharacterBody2D

## Top-down player for bullet hell level (Level 5)
## 8-directional movement, no gravity

@export var player_id: int = 1
@export var move_speed: float = 300.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

var last_input_dir: Vector2 = Vector2.ZERO
var is_hit: bool = false
var invincible_timer: float = 0.0
var invincible_duration: float = 1.5

func _ready() -> void:
	add_to_group("player")
	if sprite:
		sprite.play("run")

func _physics_process(delta: float) -> void:
	# Invincibility after hit
	if invincible_timer > 0:
		invincible_timer -= delta
		# Flash effect
		if sprite:
			sprite.visible = int(invincible_timer * 10) % 2 == 0
		if invincible_timer <= 0:
			is_hit = false
			if sprite:
				sprite.visible = true
	
	var input_dir := _get_input_direction()
	last_input_dir = input_dir
	
	if input_dir != Vector2.ZERO:
		velocity = input_dir * move_speed
		_update_sprite_direction(input_dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 0.2)
	
	move_and_slide()

func _get_input_direction() -> Vector2:
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

func _update_sprite_direction(dir: Vector2) -> void:
	if not sprite:
		return
	
	# Flip based on horizontal direction
	if dir.x < 0:
		sprite.flip_h = true
	elif dir.x > 0:
		sprite.flip_h = false

func take_hit() -> void:
	if is_hit or invincible_timer > 0:
		return
	
	is_hit = true
	invincible_timer = invincible_duration

func get_move_input_dir() -> Vector2:
	return last_input_dir
