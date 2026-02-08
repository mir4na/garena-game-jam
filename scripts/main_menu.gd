extends Node2D

## Parallax effect for main menu
@onready var background: Sprite2D = $Background
@onready var title: Sprite2D = $Title

# Base positions (from scene)
var bg_base_pos: Vector2 = Vector2(960, 540)
var title_base_pos: Vector2 = Vector2(600, 406)

# Parallax settings
var parallax_bg_strength: float = 25.0  # Background moves more (further away)
var parallax_title_strength: float = 40.0  # Title moves more (closer to camera)
var parallax_smooth: float = 6.0
var screen_center: Vector2 = Vector2(960, 540)
var current_parallax_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	$AudioStreamPlayer.play()

func _process(delta: float) -> void:
	# Calculate parallax offset based on mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	var offset_from_center = (mouse_pos - screen_center) / screen_center  # Normalized -1 to 1
	
	# Smooth the parallax movement
	current_parallax_offset = current_parallax_offset.lerp(offset_from_center, delta * parallax_smooth)
	
	# Apply parallax - background moves opposite direction (depth effect)
	if background:
		background.position = bg_base_pos - current_parallax_offset * parallax_bg_strength
	
	# Title moves more and in same direction as cursor (closer to camera)
	if title:
		title.position = title_base_pos + current_parallax_offset * parallax_title_strength

func _on_play_button_pressed() -> void:
	SceneTransition.change_scene("res://scenes/level_1.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()
