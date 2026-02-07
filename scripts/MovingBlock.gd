extends StaticBody2D

## MovingBlock - Block that moves when player triggers it

@export var move_direction: Vector2 = Vector2.RIGHT  # Direction to move
@export var move_distance: float = 100.0  # How far to move
@export var move_speed: float = 200.0  # Movement speed
@export var trigger_once: bool = true  # Only trigger once, or can be re-triggered
@export var return_after: float = 0.0  # Seconds before returning (0 = don't return)

var original_position: Vector2
var target_position: Vector2
var is_triggered: bool = false
var is_moving: bool = false
var is_at_target: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trigger_area: Area2D = $TriggerArea

func _ready() -> void:
	original_position = global_position
	target_position = original_position + move_direction.normalized() * move_distance
	trigger_area.body_entered.connect(_on_trigger_body_entered)

func _physics_process(delta: float) -> void:
	if not is_moving:
		return
	
	var current_target = target_position if not is_at_target else original_position
	var direction = (current_target - global_position).normalized()
	var distance_to_target = global_position.distance_to(current_target)
	
	if distance_to_target < move_speed * delta:
		# Reached target
		global_position = current_target
		is_moving = false
		
		if not is_at_target:
			is_at_target = true
			if return_after > 0:
				_schedule_return()
		else:
			is_at_target = false
			if not trigger_once:
				is_triggered = false  # Can be triggered again
	else:
		# Move toward target
		global_position += direction * move_speed * delta

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

## Force the block to move to target (for external triggers)
func activate() -> void:
	if not is_moving and not is_at_target:
		is_triggered = true
		_start_moving()

## Force the block to return to original position
func reset() -> void:
	if is_at_target and not is_moving:
		is_moving = true
