extends Node2D

@onready var player1 = $Player1
#@onready var player2 = $Player2
@onready var trigger1 = $Trigger1
@onready var trigger2 = $Trigger2
@onready var trigger3 = $Trigger3

@onready var platform_body = $Platform/PlatformBergerak
@onready var platform_sprite = $Platform/PlatformBergerak/Sprite2D
@onready var platform_collision = $Platform/PlatformBergerak/CollisionShape2D

var original_sprite_scale: Vector2
var original_sprite_pos: Vector2
var original_collision_pos: Vector2
var original_collision_size: Vector2

var trigger1_activated = false
var trigger2_activated = false
var trigger3_activated = false

const SHRINK_SPEED = 300.0

func _ready():
	original_sprite_scale = platform_sprite.scale
	original_sprite_pos = platform_sprite.position
	original_collision_pos = platform_collision.position
	original_collision_size = platform_collision.shape.size

func _on_trigger_1_body_entered(body):
	if not trigger1_activated and (body == player1):
		trigger1_activated = true
		print("Trigger1 activated! Shrinking right side...")
		
		var shrink_distance = original_collision_size.x * 0.5
		var duration = shrink_distance / SHRINK_SPEED
		
		var tween = create_tween().set_parallel(true)
		
		tween.tween_property(platform_collision.shape, "size:x", original_collision_size.x * 0.5, duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(platform_collision, "position:x", original_collision_pos.x - shrink_distance * 0.5, duration).set_trans(Tween.TRANS_LINEAR)
		
		# Shrink sprite (visual)
		tween.tween_property(platform_sprite, "scale:x", original_sprite_scale.x * 0.5, duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(platform_sprite, "position:x", original_sprite_pos.x - shrink_distance * 0.5, duration).set_trans(Tween.TRANS_LINEAR)

func _on_trigger_2_body_entered(body):
	if trigger1_activated and not trigger2_activated and (body == player1):
		trigger2_activated = true
		print("Trigger2 activated! Extending right, shrinking left...")
		
		var extend_distance = original_collision_size.x * 0.5
		var extend_duration = extend_distance / SHRINK_SPEED
		
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
	if body == player1:
		print("Level Complete!")
		for child in get_children():
			child.queue_free()
		RenderingServer.set_default_clear_color(Color.BLACK)


func _on_trigger_3_body_entered(body):
	if trigger2_activated and not trigger3_activated and (body == player1):
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
