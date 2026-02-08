extends Area2D

## Simple bullet for bullet hell

@export var speed: float = 200.0
@export var lifetime: float = 8.0
@export var damage: int = 1

var direction: Vector2 = Vector2.RIGHT
var time_alive: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var visual: Node2D = $Visual if has_node("Visual") else null

var _base_radius: float = 8.0
var _base_radius_initialized: bool = false

# Homing options (used by SunBoss homing skill)
var homing_enabled: bool = false
var homing_strength: float = 4.0  # Higher = turns faster
var _homing_target: Node2D = null
var _homing_retarget_timer: float = 0.0
var _hit_someone: bool = false  # Prevent hitting multiple players with one bullet

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# CRITICAL: Make collision shape unique per instance to prevent shared resource bug
	# Without this, modifying radius affects ALL bullets!
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
	
	if collision_shape and collision_shape.shape is CircleShape2D:
		_base_radius = (collision_shape.shape as CircleShape2D).radius
		_base_radius_initialized = true

func _process(delta: float) -> void:
	if homing_enabled:
		_update_homing(delta)

	position += direction * speed * delta
	
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()

func setup(dir: Vector2, spd: float = -1.0, size_mult: float = 1.0, homing: bool = false, homing_turn: float = 4.0) -> void:
	# NOTE: Boss spawns may call setup() before this node enters the scene tree,
	# so @onready vars can still be null. Resolve them lazily here.
	if collision_shape == null and has_node("CollisionShape2D"):
		collision_shape = get_node("CollisionShape2D") as CollisionShape2D
	if visual == null and has_node("Visual"):
		visual = get_node("Visual") as Node2D
	
	# CRITICAL: Make shape unique to prevent shared resource bug
	if collision_shape and collision_shape.shape and not _base_radius_initialized:
		collision_shape.shape = collision_shape.shape.duplicate()
	
	if (not _base_radius_initialized) and collision_shape and collision_shape.shape is CircleShape2D:
		_base_radius = (collision_shape.shape as CircleShape2D).radius
		_base_radius_initialized = true

	direction = dir.normalized()
	if spd > 0:
		speed = spd
	homing_enabled = homing
	homing_strength = homing_turn
	# Apply size multiplier to visual + hitbox (without scaling the Area2D parent)
	size_mult = max(0.2, size_mult)
	if visual:
		visual.scale = Vector2.ONE * size_mult
	if collision_shape and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = _base_radius * size_mult
	if homing_enabled:
		_homing_retarget_timer = 0.0
		_homing_target = null

func _update_homing(delta: float) -> void:
	_homing_retarget_timer -= delta
	if _homing_retarget_timer <= 0.0 or not is_instance_valid(_homing_target):
		_homing_target = _find_nearest_player()
		_homing_retarget_timer = 0.25

	if not is_instance_valid(_homing_target):
		return

	var desired_dir = (_homing_target.global_position - global_position).normalized()
	if desired_dir == Vector2.ZERO:
		return

	# Smooth turn towards target
	var t = clamp(homing_strength * delta, 0.0, 1.0)
	direction = direction.lerp(desired_dir, t).normalized()

func _find_nearest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	var best: Node2D = null
	var best_dist := INF
	for p in players:
		if p is Node2D and is_instance_valid(p):
			var d = (p as Node2D).global_position.distance_squared_to(global_position)
			if d < best_dist:
				best_dist = d
				best = p as Node2D
	return best

func _on_body_entered(body: Node2D) -> void:
	if _hit_someone:
		return  # Already hit someone, don't double-hit
	if body.is_in_group("player"):
		_hit_someone = true
		# Notify level about hit
		var level = get_tree().current_scene
		if level and level.has_method("on_player_hit"):
			level.call("on_player_hit", body)
		queue_free()
