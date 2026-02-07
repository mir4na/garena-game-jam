extends Node2D

## Level 2 - Box Puzzle with Button and Moving Platform Bridge

@onready var player1 = $Player1
@onready var player2 = $Player2
@onready var chain = $Chain
@onready var spawn_point = $SpawnPoint
@onready var moving_platform = $MovingPlatform
@onready var button_area = $Button/Area2D
@onready var warning_label = $WarningLabel
@onready var box = $Box

# Store spawn positions
var player1_spawn: Vector2
var player2_spawn: Vector2

# Store original platform positions/rotations
var original_platform_transforms: Array = []

# Button state
var is_button_pressed: bool = false
var is_bridge_mode: bool = false

# Bodies currently on button
var bodies_on_button: Array = []

# Active tween
var platform_tween: Tween

func _ready():
	# Store initial spawn positions
	player1_spawn = player1.global_position
	player2_spawn = player2.global_position
	
	# Store original transforms of moving platform children
	for child in moving_platform.get_children():
		if child is StaticBody2D:
			original_platform_transforms.append({
				"node": child,
				"position": child.position,
				"rotation": child.rotation
			})
	
	# Initially hide moving platform and warning
	moving_platform.visible = false
	_disable_platform_collision(moving_platform)
	
	if warning_label:
		warning_label.visible = false
	
	# Connect button signals
	button_area.body_entered.connect(_on_button_body_entered)
	button_area.body_exited.connect(_on_button_body_exited)

func _disable_platform_collision(platform_node: Node2D):
	for child in platform_node.get_children():
		if child is StaticBody2D:
			child.set_collision_layer_value(1, false)
			child.set_collision_mask_value(1, false)

func _enable_platform_collision(platform_node: Node2D):
	for child in platform_node.get_children():
		if child is StaticBody2D:
			child.set_collision_layer_value(1, true)
			child.set_collision_mask_value(1, true)

func _on_button_body_entered(body):
	if body not in bodies_on_button:
		bodies_on_button.append(body)
	
	_update_button_state()

func _on_button_body_exited(body):
	bodies_on_button.erase(body)
	_update_button_state()

func _update_button_state():
	var player_on_button = false
	var box_on_button = false
	
	for body in bodies_on_button:
		if body == player1 or body == player2:
			player_on_button = true
		if body == box:
			box_on_button = true
	
	var something_on_button = player_on_button or box_on_button
	
	# Button pressed -> reveal platform
	if something_on_button and not is_button_pressed:
		is_button_pressed = true
		_reveal_moving_platform()
	
	# Button released -> hide platform
	if not something_on_button and is_button_pressed:
		is_button_pressed = false
		is_bridge_mode = false
		_hide_moving_platform()
	
	# Box on button -> transform to bridge (60 degree angle)
	if box_on_button and not is_bridge_mode:
		is_bridge_mode = true
		_transform_to_bridge()

func _reveal_moving_platform():
	print("Button pressed! Revealing moving platform...")
	
	# Kill any existing tween
	if platform_tween and platform_tween.is_valid():
		platform_tween.kill()
	
	moving_platform.visible = true
	_enable_platform_collision(moving_platform)
	
	# Reset to original positions if not in bridge mode
	if not is_bridge_mode:
		_reset_platform_transforms()
	
	# Animate fade in
	platform_tween = create_tween()
	moving_platform.modulate.a = 0.0
	platform_tween.tween_property(moving_platform, "modulate:a", 1.0, 0.5)

func _hide_moving_platform():
	print("Button released! Hiding moving platform...")
	
	# Kill any existing tween
	if platform_tween and platform_tween.is_valid():
		platform_tween.kill()
	
	# Animate fade out then disable
	platform_tween = create_tween()
	platform_tween.tween_property(moving_platform, "modulate:a", 0.0, 0.3)
	platform_tween.tween_callback(func():
		moving_platform.visible = false
		_disable_platform_collision(moving_platform)
		_reset_platform_transforms()
	)

func _reset_platform_transforms():
	for data in original_platform_transforms:
		data.node.position = data.position
		data.node.rotation = data.rotation

func _transform_to_bridge():
	print("Box holding button! Forming 60-degree straight bridge...")
	
	# Kill any existing tween
	if platform_tween and platform_tween.is_valid():
		platform_tween.kill()
	
	moving_platform.visible = true
	_enable_platform_collision(moving_platform)
	
	platform_tween = create_tween()
	platform_tween.set_parallel(true)
	
	# Ensure platform fades in (just in case it wasn't fully visible)
	if moving_platform.modulate.a < 1.0:
		platform_tween.tween_property(moving_platform, "modulate:a", 1.0, 0.5)
	
	# Target: Straight line angled at 40 degrees towards the right sky
	# Adjusted per user request: x - 300, y - 100
	var start_pos = Vector2(152, 1796)
	var angle_rad = deg_to_rad(-40) # Up-Right angle (40 degrees)
	var spacing = 180.0 # Distance between platforms
	var direction = Vector2.RIGHT.rotated(angle_rad)
	
	# Internal offset of the sprites/collision shapes relative to their StaticBody2D parent
	# Found in level_2.tscn: Sprite pos is (706, 811)
	var internal_offset = Vector2(706, 811)
	
	var index = 0
	for child in moving_platform.get_children():
		if child is StaticBody2D:
			# Calculate where the visual center should be
			var target_visual_pos = start_pos + (direction * spacing * index)
			
			# Compensate for the internal offset to set the StaticBody position correctly
			var final_target_pos = target_visual_pos - internal_offset
			
			# Move to corrected position
			platform_tween.tween_property(child, "position", final_target_pos, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# Rotate to match angle
			platform_tween.tween_property(child, "rotation", angle_rad, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
			index += 1
			
	# Show warning after animation
	platform_tween.set_parallel(false)
	platform_tween.tween_callback(func():
		_show_warning()
	)

func _show_warning():
	if warning_label:
		warning_label.visible = true
		warning_label.text = "Hati-hati dengan spike!\nJangan sampai terinjak!"
		
		var tween = create_tween()
		warning_label.modulate.a = 0.0
		tween.tween_property(warning_label, "modulate:a", 1.0, 0.5)
		tween.tween_interval(3.0)
		tween.tween_property(warning_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func():
			warning_label.visible = false
		)

func _on_death_area_body_entered(body):
	if body == player1 or body == player2:
		print("Player died! Resetting...")
		_reset_level()

func _reset_level():
	# Reset players to spawn positions
	player1.global_position = player1_spawn
	player2.global_position = player2_spawn
	
	# Reset player velocities
	player1.velocity = Vector2.ZERO
	player2.velocity = Vector2.ZERO
	
	# Reset button state
	is_button_pressed = false
	is_bridge_mode = false
	bodies_on_button.clear()
	
	# Hide and reset platform
	moving_platform.visible = false
	_disable_platform_collision(moving_platform)
	_reset_platform_transforms()
	
	# Reset chain if exists
	if chain and chain.has_method("reset_rope"):
		chain.reset_rope()
