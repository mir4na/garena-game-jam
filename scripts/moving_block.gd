extends StaticBody2D

## MovingBlock - Block yang bergerak saat player trigger

@export var move_direction: Vector2 = Vector2.RIGHT  # Arah gerakan
@export var move_distance: float = 100.0  # Jarak gerakan
@export var move_speed: float = 200.0  # Kecepatan gerakan
@export var trigger_once: bool = true  # Trigger sekali atau bisa berkali-kali
@export var return_after: float = 0.0  # Detik sebelum balik (0 = tidak balik)

var original_position: Vector2
var target_position: Vector2
var is_triggered: bool = false
var is_moving: bool = false
var is_at_target: bool = false
var players_on_block: Array = []  # Track players standing on this block

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trigger_area: Area2D = $MoveTrigger if has_node("MoveTrigger") else null

func _ready() -> void:
	original_position = global_position
	target_position = original_position + move_direction.normalized() * move_distance
	
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)

func _physics_process(delta: float) -> void:
	if not is_moving:
		return
	
	var current_target = target_position if not is_at_target else original_position
	var direction = (current_target - global_position).normalized()
	var distance_to_target = global_position.distance_to(current_target)
	
	var move_step = move_speed * delta
	
	if distance_to_target < move_step:
		# Sampai di target
		var final_move = current_target - global_position
		global_position = current_target
		is_moving = false
		
		# Move players yang berdiri di atas block ini
		_move_players_on_block(final_move)
		
		if not is_at_target:
			is_at_target = true
			if return_after > 0:
				_schedule_return()
		else:
			is_at_target = false
			if not trigger_once:
				is_triggered = false
	else:
		# Bergerak ke target
		var move_delta = direction * move_step
		global_position += move_delta
		
		# Move players yang berdiri di atas block ini
		_move_players_on_block(move_delta)

func _move_players_on_block(move_delta: Vector2) -> void:
	# Cari players yang berdiri di atas block ini
	for player in get_tree().get_nodes_in_group("player"):
		if player is CharacterBody2D and player.is_on_floor():
			# Cek apakah player berdiri di atas block ini
			if _is_player_on_this_block(player):
				player.global_position += move_delta

func _is_player_on_this_block(player: CharacterBody2D) -> bool:
	# Raycast dari player ke bawah untuk cek apakah dia berdiri di block ini
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		player.global_position,
		player.global_position + Vector2(0, 20),
		1  # Collision layer 1
	)
	query.exclude = [player.get_rid()]
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == self:
		return true
	return false

func _on_trigger_body_entered(body: Node2D) -> void:
	if is_triggered and trigger_once:
		return
	
	if is_moving:
		return
	
	if body.is_in_group("player") or body.name.begins_with("Player"):
		is_triggered = true
		_start_moving()

func _start_moving() -> void:
	is_moving = true

func _schedule_return() -> void:
	await get_tree().create_timer(return_after).timeout
	if is_at_target and not is_moving:
		is_moving = true

## Force block untuk bergerak ke target (untuk external triggers)
func activate() -> void:
	if not is_moving and not is_at_target:
		is_triggered = true
		_start_moving()

## Force block untuk kembali ke posisi awal
func reset() -> void:
	if is_at_target and not is_moving:
		is_moving = true


func _on_kill_zone_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
