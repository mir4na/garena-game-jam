extends Node2D

## Random walking character for main menu decoration

@export var move_speed: float = 120.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 800.0
@export var min_walk_time: float = 1.0
@export var max_walk_time: float = 3.0
@export var jump_chance: float = 0.15  # Chance to jump per second
@export var floor_y: float = 650.0  # Y position of floor
@export var min_x: float = 100.0
@export var max_x: float = 1820.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var velocity: Vector2 = Vector2.ZERO
var direction: int = 1  # 1 = right, -1 = left
var walk_timer: float = 0.0
var is_on_floor: bool = true

func _ready() -> void:
	_pick_new_direction()
	sprite.play("run")

func _process(delta: float) -> void:
	# Gravity
	if not is_on_floor:
		velocity.y += gravity * delta
	
	# Check floor
	if position.y >= floor_y:
		position.y = floor_y
		velocity.y = 0
		is_on_floor = true
	else:
		is_on_floor = false
	
	# Random jump
	if is_on_floor and randf() < jump_chance * delta:
		_jump()
	
	# Walk timer
	walk_timer -= delta
	if walk_timer <= 0:
		_pick_new_direction()
	
	# Movement
	velocity.x = direction * move_speed
	position += velocity * delta
	
	# Flip at boundaries
	if position.x < min_x:
		position.x = min_x
		direction = 1
		walk_timer = randf_range(min_walk_time, max_walk_time)
	elif position.x > max_x:
		position.x = max_x
		direction = -1
		walk_timer = randf_range(min_walk_time, max_walk_time)
	
	# Flip sprite
	sprite.flip_h = (direction < 0)
	
	# Animation
	_update_animation()

func _pick_new_direction() -> void:
	direction = 1 if randf() > 0.5 else -1
	walk_timer = randf_range(min_walk_time, max_walk_time)

func _jump() -> void:
	velocity.y = jump_velocity
	is_on_floor = false

func _update_animation() -> void:
	if not is_on_floor:
		if sprite.animation != "jump":
			sprite.play("jump")
	else:
		if sprite.animation != "run":
			sprite.play("run")
