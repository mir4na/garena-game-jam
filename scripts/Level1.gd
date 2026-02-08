extends Node2D

## Level 1 - Introduction level with shrinking platform puzzle
## Polished with visual feedback and smooth transitions

@onready var player1 = $Player1
@onready var player2 = $Player2
@onready var spawn_point = $SpawnPoint
@onready var chain = $Chain
@onready var trigger1 = $Trigger1
@onready var trigger2 = $Trigger2
@onready var trigger3 = $Trigger3

@onready var platform_body = $Platform/PlatformBergerak
@onready var platform_sprite = $Platform/PlatformBergerak/Sprite2D
@onready var platform_collision = $Platform/PlatformBergerak/CollisionShape2D

# Death overlay for visual feedback
var death_overlay: ColorRect

# Checkpoint system
var checkpoint_p1: Vector2
var checkpoint_p2: Vector2

var original_sprite_scale: Vector2
var original_sprite_pos: Vector2
var original_collision_pos: Vector2
var original_collision_size: Vector2

var trigger1_activated = false
var trigger2_activated = false
var trigger3_activated = false

const SHRINK_SPEED = 250.0

func _ready():
	# Create death overlay for visual feedback
	_create_death_overlay()
	
	original_sprite_scale = platform_sprite.scale
	original_sprite_pos = platform_sprite.position
	original_collision_pos = platform_collision.position
	original_collision_size = platform_collision.shape.size
	
	# Initialize checkpoint to spawn position
	var spawn_pos = spawn_point.global_position if spawn_point else player1.global_position
	checkpoint_p1 = spawn_pos + Vector2(-50, 0)
	checkpoint_p2 = spawn_pos + Vector2(50, 0)

func _on_trigger_1_body_entered(body):
	if not trigger1_activated and (body == player1 or body == player2 ):
		trigger1_activated = true
		print("Trigger1 activated! Shrinking right side...")
		
		# Shrink until width is 325
		var target_width = 325.0
		var shrink_distance = original_collision_size.x - target_width
		var duration = shrink_distance / SHRINK_SPEED
		
		var tween = create_tween().set_parallel(true)
		
		tween.tween_property(platform_collision.shape, "size:x", target_width, duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(platform_collision, "position:x", original_collision_pos.x - shrink_distance * 0.5, duration).set_trans(Tween.TRANS_LINEAR)
		
		# Shrink sprite (visual)
		var scale_ratio = target_width / original_collision_size.x
		tween.tween_property(platform_sprite, "scale:x", original_sprite_scale.x * scale_ratio, duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(platform_sprite, "position:x", original_sprite_pos.x - shrink_distance * 0.5, duration).set_trans(Tween.TRANS_LINEAR)

func _on_trigger_2_body_entered(body):
	if trigger1_activated and not trigger2_activated and (body == player1 or body == player2):
		trigger2_activated = true
		print("Trigger2 activated! Extending right, shrinking left...")
		
		var extend_distance = original_collision_size.x - 325.0 # Restore from previous shrink
		
		# FASTER speed for Trigger 2 (2x normal speed)
		var fast_speed = SHRINK_SPEED * 2.0
		var extend_duration = extend_distance / fast_speed
		
		var tween = create_tween().set_parallel(true)
		
		# Restore RIGHT side (collision + sprite)
		tween.tween_property(platform_collision.shape, "size:x", original_collision_size.x, extend_duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(platform_collision, "position:x", original_collision_pos.x, extend_duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(platform_sprite, "scale:x", original_sprite_scale.x, extend_duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(platform_sprite, "position:x", original_sprite_pos.x, extend_duration).set_trans(Tween.TRANS_LINEAR)
		
		await tween.finished
		
		# Shrink LEFT side
		var shrink_distance = original_collision_size.x * 0.7
		var shrink_duration = shrink_distance / SHRINK_SPEED
		
		var tween2 = create_tween().set_parallel(true)
		
		tween2.tween_property(platform_collision.shape, "size:x", original_collision_size.x * 0.3, shrink_duration).set_trans(Tween.TRANS_LINEAR)
		tween2.tween_property(platform_collision, "position:x", original_collision_pos.x + shrink_distance * 0.5, shrink_duration).set_trans(Tween.TRANS_LINEAR)
		tween2.tween_property(platform_sprite, "scale:x", original_sprite_scale.x * 0.3, shrink_duration).set_trans(Tween.TRANS_LINEAR)
		tween2.tween_property(platform_sprite, "position:x", original_sprite_pos.x + shrink_distance * 0.5, shrink_duration).set_trans(Tween.TRANS_LINEAR)

func _on_door_body_entered(body):
	if body == player1 or body == player2:
		print("Level Complete!")
		_level_complete()

func _level_complete() -> void:
	# Smooth fade to next level
	if death_overlay:
		death_overlay.color = Color(0, 0, 0, 0)
		var tween = create_tween()
		tween.tween_property(death_overlay, "color:a", 1.0, 0.5)
		tween.tween_callback(func():
			get_tree().change_scene_to_file("res://scenes/Level2.tscn")
		)

func _on_death_area_body_entered(body):
	if body == player1 or body == player2:
		print("Player died! Resetting...")
		_show_death_flash()

func _show_death_flash() -> void:
	if death_overlay:
		death_overlay.color = Color(1, 0.2, 0.2, 0)
		var tween = create_tween()
		tween.tween_property(death_overlay, "color:a", 0.5, 0.1)
		tween.tween_property(death_overlay, "color:a", 0.0, 0.2)
		tween.tween_callback(_reset_level)
	else:
		_reset_level()

func _create_death_overlay() -> void:
	death_overlay = ColorRect.new()
	death_overlay.color = Color(0, 0, 0, 0)
	death_overlay.anchor_left = 0
	death_overlay.anchor_top = 0
	death_overlay.anchor_right = 1
	death_overlay.anchor_bottom = 1
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create a CanvasLayer so overlay is always on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.add_child(death_overlay)
	add_child(canvas_layer)

func _reset_level():
	# Reset players to checkpoint
	player1.global_position = checkpoint_p1
	player2.global_position = checkpoint_p2
	
	# Reset player velocities
	player1.velocity = Vector2.ZERO
	player2.velocity = Vector2.ZERO
	
	# Reset trigger states
	trigger1_activated = false
	trigger2_activated = false
	trigger3_activated = false
	
	# Reset platform to original size/position
	platform_collision.shape.size.x = original_collision_size.x
	platform_collision.position = original_collision_pos
	platform_sprite.scale = original_sprite_scale
	platform_sprite.position = original_sprite_pos
	
	# Reset chain if exists
	if chain and chain.has_method("reset_rope"):
		chain.reset_rope()

## Update checkpoint to current player positions
func update_checkpoint() -> void:
	checkpoint_p1 = player1.global_position
	checkpoint_p2 = player2.global_position
	print("Checkpoint updated!")

func _on_trigger_3_body_entered(body):
	if trigger2_activated and not trigger3_activated and (body == player1 or body == player2):
		trigger3_activated = true
		print("Trigger3 activated! Shrinking right side slightly...")
		
		# Calculate current right edge and target
		var current_left_edge = platform_collision.global_position.x - platform_collision.shape.size.x * 0.5
		var target_right_edge = 1350.0
		var target_size = target_right_edge - current_left_edge
		
		var shrink_distance = platform_collision.shape.size.x - target_size
		var duration = shrink_distance / SHRINK_SPEED
		
		var tween = create_tween().set_parallel(true)
		
		# Shrink from right (reduce size, shift position left)
		var new_center_x = current_left_edge + target_size * 0.5
		var local_new_center = new_center_x - platform_body.global_position.x
		
		tween.tween_property(platform_collision.shape, "size:x", target_size, duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(platform_collision, "position:x", local_new_center, duration).set_trans(Tween.TRANS_LINEAR)
		
		# Sprite - approximate using scale ratio
		var scale_ratio = target_size / original_collision_size.x
		tween.tween_property(platform_sprite, "scale:x", original_sprite_scale.x * scale_ratio, duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(platform_sprite, "position:x", local_new_center, duration).set_trans(Tween.TRANS_LINEAR)
