extends Node2D

## Level 4 - Simple platform level with chain mechanics
## Polished with visual feedback and smooth transitions

@onready var player1: CharacterBody2D = $Player1
@onready var player2: CharacterBody2D = $Player2
@onready var chain: Node2D = $Chain if has_node("Chain") else null

# Death overlay for visual feedback
var death_overlay: ColorRect

# Spawn positions
var player1_spawn: Vector2
var player2_spawn: Vector2

# Checkpoint positions (for soft reset)
var checkpoint_p1: Vector2
var checkpoint_p2: Vector2

func _ready() -> void:
	# Create death overlay for visual feedback
	_create_death_overlay()
	
	# Store spawn positions
	player1_spawn = player1.global_position
	player2_spawn = player2.global_position
	
	# Initialize checkpoints to spawn positions
	checkpoint_p1 = player1_spawn
	checkpoint_p2 = player2_spawn

## Visual polish helper functions
func _create_death_overlay() -> void:
	death_overlay = ColorRect.new()
	death_overlay.color = Color(0, 0, 0, 0)
	death_overlay.anchor_left = 0
	death_overlay.anchor_top = 0
	death_overlay.anchor_right = 1
	death_overlay.anchor_bottom = 1
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.add_child(death_overlay)
	add_child(canvas_layer)

func _show_death_flash() -> void:
	if death_overlay:
		death_overlay.color = Color(1, 0.2, 0.2, 0)
		var tween = create_tween()
		tween.tween_property(death_overlay, "color:a", 0.5, 0.1)
		tween.tween_property(death_overlay, "color:a", 0.0, 0.2)
		tween.tween_callback(_reset_level)
	else:
		_reset_level()

func _reset_level() -> void:
	# Reset players to checkpoint (not spawn)
	player1.global_position = checkpoint_p1
	player2.global_position = checkpoint_p2
	player1.velocity = Vector2.ZERO
	player2.velocity = Vector2.ZERO
	
	# Reset chain if exists
	if chain and chain.has_method("reset_rope"):
		chain.reset_rope()

func _level_complete() -> void:
	# Smooth fade to next level
	if death_overlay:
		death_overlay.color = Color(0, 0, 0, 0)
		var tween = create_tween()
		tween.tween_property(death_overlay, "color:a", 1.0, 0.5)
		tween.tween_callback(func():
			get_tree().change_scene_to_file("res://scenes/level_5.tscn")
		)

## Called by Flag when touched
func _on_flag_body_entered(body: Node2D) -> void:
	if body == player1 or body == player2:
		_level_complete()

## Update checkpoint - simpan posisi aktual kedua player
func update_checkpoint() -> void:
	checkpoint_p1 = player1.global_position
	checkpoint_p2 = player2.global_position
