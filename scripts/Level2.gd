extends Node2D

@onready var player1 = $Player1
@onready var player2 = $Player2
@onready var chain = $Chain
@onready var spawn_point = $SpawnPoint
@onready var moving_platform = $MovingPlatform
@onready var button_area = $Button/Area2D
@onready var warning_label = $WarningLabel
@onready var box = $Box

@onready var trigger_spike = $TriggerSpike
@onready var massive_spike = $MassiveSpike
@onready var trigger_text = $TriggerText
@onready var text_killer = $TextKiller # The "Congrats" text that falls and kills

# Text Trap state
var trigger_text_start_pos: Vector2
var text_killer_start_pos: Vector2
var is_text_falling: bool = false
var text_fall_tween: Tween

# Store spawn positions
var player1_spawn: Vector2
var player2_spawn: Vector2
var massive_spike_start_pos: Vector2
var box_start_pos: Vector2
var is_launching_spike: bool = false
var trigger_spike_activated: bool = false

# Store original platform positions/rotations
var original_platform_transforms: Array = []

# Button state
# Button state
var is_button_pressed: bool = false
# is_bridge_mode REMOVED

# Bodies currently on button
var bodies_on_button: Array = []

# Massive spike settings
@export var massive_spike_launch_duration: float = 2.0

# Active tween
var platform_tween: Tween
var spike_tween: Tween

@onready var spike_scene = preload("res://scenes/spike.tscn")
# bridge_spike_instance REMOVED

# Removed _process manual checks. 
# Fall checks now handled by KillZone node.
# Trap checks now handled by signal toggling.

func _ready():
	# Store initial spawn positions
	player1_spawn = player1.global_position
	player2_spawn = player2.global_position
	if box:
		box_start_pos = box.global_position
		# TUE BOX PHYSICS: Heavier, no bounce
		# User requested "harus didorong/dibody 2 player" -> Very heavy
		box.mass = 100.0
		# If physics material exists, modify it
		if box.physics_material_override:
			box.physics_material_override.friction = 1.0 # High friction
			box.physics_material_override.bounce = 0.0   # No bounce
		else:
			# Create new material if none
			var mat = PhysicsMaterial.new()
			mat.friction = 1.0
			mat.bounce = 0.0
			box.physics_material_override = mat

		# Also ensure it cannot rotate too fast? (AngularDamp)
		box.angular_damp = 5.0
	
	if text_killer:
		text_killer.z_index = 100 # Ensure on top of everything
		text_killer.visible = false  # Hidden until triggered

	# Restore platform setup which was deleted
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
	
	# Setup TextKiller (the falling "Congrats" text)
	if text_killer:
		text_killer.visible = false  # Hidden until triggered
		text_killer_start_pos = text_killer.position
		if not text_killer.body_entered.is_connected(_on_text_killer_hit):
			text_killer.body_entered.connect(_on_text_killer_hit)
		# Ensure it can detect players (layer 2)
		text_killer.collision_layer = 0  # Doesn't block anything
		text_killer.collision_mask = 2   # Detects players
	
	# Connect button signals
	button_area.body_entered.connect(_on_button_body_entered)
	button_area.body_exited.connect(_on_button_body_exited)
	
	if massive_spike:
		massive_spike_start_pos = massive_spike.position
	
	# BUG FIX: Force TriggerSpike to have its OWN unique shape
	# This is required because TriggerSpike and TriggerText share the same resource in the editor.
	# When you resized TriggerText's shape, TriggerSpike's shape also grew massive and covers the spawn point!
	if trigger_spike:
		if not trigger_spike.body_entered.is_connected(_on_trigger_spike_entered):
			trigger_spike.body_entered.connect(_on_trigger_spike_entered)
		var s_shape = trigger_spike.get_node_or_null("CollisionShape2D")
		if s_shape and s_shape.shape:
			var unique_shape = s_shape.shape.duplicate()
			# Reset size to correct value (206.5, 246.5) so it doesn't cover spawn
			if unique_shape is RectangleShape2D:
				unique_shape.size = Vector2(206.5, 246.5) 
			s_shape.shape = unique_shape

	# Setup Info Sign (Dynamic Creation if not found)
	_setup_info_sign()

	# Setup Drop Text Trap (Already in scene)
	if trigger_text:
		trigger_text_start_pos = trigger_text.position
		if not trigger_text.body_entered.is_connected(_on_trigger_text_entered):
			trigger_text.body_entered.connect(_on_trigger_text_entered)

func _setup_info_sign():
	# Look for existing InfoSign node
	var info_sign = get_node_or_null("InfoSign")
	if not info_sign:
		# Search recursively or check common locations
		info_sign = get_node_or_null("Background/InfoSign")
	
	# If not found, try to attach to the visual Sign sprite
	if not info_sign:
		var sign_sprite = get_node_or_null("Background/Sign")
		if sign_sprite:
			print("InfoSign node not found, creating dynamic trigger on 'Sign' sprite...")
			info_sign = Area2D.new()
			info_sign.name = "InfoSign_Dynamic"
			# Convert sprite global position to local? Or just add as child of Level2
			# Adding as child of Level2 is safest for coordinate space
			add_child(info_sign)
			info_sign.global_position = sign_sprite.global_position
			
			var col = CollisionShape2D.new()
			var rect = RectangleShape2D.new()
			rect.size = Vector2(100, 100) # Reasonable trigger size
			col.shape = rect
			info_sign.add_child(col)
			
			# Setup collision mask to detect players
			info_sign.collision_layer = 0
			info_sign.collision_mask = 2 # Players
	
	if info_sign:
		if not info_sign.body_entered.is_connected(_on_info_sign_entered):
			info_sign.body_entered.connect(_on_info_sign_entered)
		if not info_sign.body_exited.is_connected(_on_info_sign_exited):
			info_sign.body_exited.connect(_on_info_sign_exited)

func _on_info_sign_entered(body):
	if body == player1 or body == player2:
		if warning_label:
			warning_label.visible = true
			warning_label.text = "Caution: Spike!\nDo not touch!"
			warning_label.modulate.a = 1.0

func _on_info_sign_exited(body):
	if body == player1 or body == player2:
		# Only hide if BOTH players are away? 
		# Or if ANY player leaves? Simple logic: if exit, hide.
		# Ideally check overlapping bodies, but simple for now.
		if warning_label:
			warning_label.visible = false

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
		# As requested: "warning label langsung muncul saja" when button is pressed
		_show_warning()
	
	# Button released -> hide platform
	if not something_on_button and is_button_pressed:
		is_button_pressed = false
		_hide_moving_platform()
		if warning_label:
			warning_label.visible = false

	# Box on button -> transform to bridge (REMOVED as requested)
	# Now just standard reveal (above)

func _reveal_moving_platform():
	print("Button pressed! Revealing moving platform...")
	
	# Kill any existing tween
	if platform_tween and platform_tween.is_valid():
		platform_tween.kill()
	
	moving_platform.visible = true
	moving_platform.modulate.a = 1.0  # Ensure fully visible
	_enable_platform_collision(moving_platform)
	
	# Reset to original positions (always, no more bridge mode)
	_reset_platform_transforms()
	
	# Animate slide up (from below)
	platform_tween = create_tween()
	platform_tween.set_parallel(true)
	for child in moving_platform.get_children():
		if child is StaticBody2D:
			var target_pos = child.position
			child.position.y += 200  # Start 200px below
			platform_tween.tween_property(child, "position:y", target_pos.y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_moving_platform():
	print("Button released! Hiding moving platform...")
	
	# Kill any existing tween
	if platform_tween and platform_tween.is_valid():
		platform_tween.kill()
	
	# Animate slide down (disappear below)
	platform_tween = create_tween()
	platform_tween.set_parallel(true)
	for child in moving_platform.get_children():
		if child is StaticBody2D:
			var target_y = child.position.y + 200  # Go 200px down
			platform_tween.tween_property(child, "position:y", target_y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	platform_tween.set_parallel(false)
	platform_tween.tween_callback(func():
		moving_platform.visible = false
		_disable_platform_collision(moving_platform)
		_reset_platform_transforms()
	)

func _reset_platform_transforms():
	for data in original_platform_transforms:
		data.node.position = data.position
		data.node.rotation = data.rotation

# _transform_to_bridge REMOVED

func _show_warning():
	if warning_label:
		warning_label.visible = true
		warning_label.text = "Hati-hati dengan spike!\nJangan pernah menyentuhnya!"
		# "Langsung muncul saja" = No animation required, just show it
		warning_label.modulate.a = 1.0

func _execute_text_drop():
	print("Text DROPPING!")
	is_text_falling = true
	
	var drop_tween = create_tween()
	var target_y = 2000.0 # Fall way down
	
	# Drop the TextKiller (it will kill player on collision via its own Area2D logic)
	if text_killer:
		drop_tween.tween_property(text_killer, "position:y", text_killer.position.y + target_y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_text_killer_hit(body):
	# TextKiller collided with something - kill player if it's them
	if body == player1 or body == player2:
		print("Player killed by falling text!")
		call_deferred("_reset_level")



func _launch_massive_spike():
	if is_launching_spike: return
	
	print("TRIGGERED! Launching massive spike!")
	is_launching_spike = true
	
	if massive_spike:
		if spike_tween and spike_tween.is_valid():
			spike_tween.kill()
		spike_tween = create_tween()
		var direction = Vector2.UP.rotated(massive_spike.rotation)
		var target_pos = massive_spike_start_pos + (direction * 3000) # Move 3000px (enough to clear screen)
		
		# Use exported duration variable (overridable, but default to snappy)
		# Use EASE_OUT for immediate fast speed (trap-like)
		# Use TRANS_QUINT for strong snap
		spike_tween.tween_property(massive_spike, "position", target_pos, 1.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)  # 1.2s (3x slower)
		# Optional: Add scale effect or shake here if desired

func _reset_level():
	print("Resetting Level 2...")
	# Stop any in-flight tweens so nothing keeps moving after reset
	if platform_tween and platform_tween.is_valid():
		platform_tween.kill()
	if spike_tween and spike_tween.is_valid():
		spike_tween.kill()
	if text_fall_tween and text_fall_tween.is_valid():
		text_fall_tween.kill()

	# Reset players to spawn positions
	player1.global_position = player1_spawn
	player2.global_position = player2_spawn
	
	# Reset player velocities
	player1.velocity = Vector2.ZERO
	player2.velocity = Vector2.ZERO
	
	# Reset button state
	is_button_pressed = false
	# is_bridge_mode removed
	bodies_on_button.clear()
	if button_area:
		button_area.set_deferred("monitoring", false)
		button_area.set_deferred("monitoring", true)
	
	# Hide and reset platform
	moving_platform.visible = false
	_disable_platform_collision(moving_platform)
	_reset_platform_transforms()
	if warning_label:
		warning_label.visible = false
	
	# Clean up bridge spike (REMOVED)
	# if bridge_spike_instance:
	# 	bridge_spike_instance.queue_free()
	# 	bridge_spike_instance = null
	
	# Reset chain if exists
	if chain and chain.has_method("reset_rope"):
		chain.reset_rope()
	
	# Reset massive spike
	if massive_spike:
		massive_spike.position = massive_spike_start_pos
	is_launching_spike = false
	
	# FIX: Reset flag deferredly so it happens AFTER monitoring toggle check
	# This prevents the "immediate re-trigger on spawn" bug
	call_deferred("set", "trigger_spike_activated", false)
	
	if trigger_spike:
		trigger_spike.set_deferred("monitoring", false)
		trigger_spike.set_deferred("monitoring", true)
		
	# Reset Drop Text Trap
	is_text_falling = false
	if trigger_text:
		trigger_text.position = trigger_text_start_pos
	if text_killer:
		text_killer.position = text_killer_start_pos
		text_killer.visible = false

	# Reset Box
	_reset_box()

func _reset_box():
	if box:
		print("Resetting box to start position...")
		# Force physics update using PhysicsServer2D
		PhysicsServer2D.body_set_state(
			box.get_rid(),
			PhysicsServer2D.BODY_STATE_TRANSFORM,
			Transform2D(0.0, box_start_pos)
		)
		PhysicsServer2D.body_set_state(
			box.get_rid(),
			PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
			Vector2.ZERO
		)
		PhysicsServer2D.body_set_state(
			box.get_rid(),
			PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,
			0.0
		)
		
		if box.freeze: 
			box.freeze = false


func _on_trigger_spike_entered(body: Node2D) -> void:
	if trigger_spike_activated:
		return
	
	if trigger_text and trigger_text.overlaps_body(body):
		return

	if body == player1 or body == player2:
		trigger_spike_activated = true
		trigger_spike.set_deferred("monitoring", false)
		_launch_massive_spike()


func _on_trigger_text_entered(body: Node2D) -> void:
	if body == player1 or body == player2:
		# If not falling -> Trigger fall sequence
		if not is_text_falling and (text_fall_tween == null or not text_fall_tween.is_valid()):
			print("Text Trap Triggered! Waiting...")
		
			if text_killer:
				text_killer.visible = true
			
			# User requested 2 minutes (120 seconds) delay
			var delay = 120.0 
			text_fall_tween.tween_interval(delay)
			text_fall_tween.tween_callback(_execute_text_drop)
