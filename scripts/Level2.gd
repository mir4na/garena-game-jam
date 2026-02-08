extends Node2D

## Level 2 - Trap filled level with Box puzzle
## Polished with visual feedback and smooth transitions

# Sound effects
var hurt_sound: AudioStreamPlayer
var hurt_audio = preload("res://assets/sfx/Hurt.wav")

@onready var player1 = $Player1
@onready var player2 = $Player2
@onready var chain = $Chain
@onready var spawn_point = $SpawnPoint
@onready var player_platform = $PlayerPlatform
@onready var box_platform = $BoxPlatform
@onready var button_area = $Button/Area2D
@onready var warning_label = $WarningLabel
@onready var box = $Box

@onready var trigger_spike = $TriggerSpike
@onready var massive_spike = $MassiveSpike
@onready var trigger_text = $TriggerText
@onready var text_killer = $TextKiller # The "Congrats" text that falls and kills
@onready var spike_point = $SpikePoint # Optional: User defined spawn point for spike
@onready var platform_part_2 = $Platform/StaticBody2D2 # The part that moves with box button
@onready var flag = $Flag # Flag moves with box button

# New Spikes
@onready var trigger_one_spike = $TriggerOneSpike
@onready var trigger_many_spike = $TriggerManySpike
@onready var spike_alone = $SpikeAlone
# Include Spike6 in case user adds it, logic handles nulls
@onready var spikes_many = [$Spike1, $Spike2, $Spike3, $Spike4, $Spike5, get_node_or_null("Spike6")]

var one_spike_triggered: bool = false
var many_spikes_triggered: bool = false
var spike_alone_target_pos: Vector2
var spikes_many_target_pos: Array[Vector2] = []

# Death overlay for visual feedback
var death_overlay: ColorRect

# Text Trap state
var trigger_text_start_pos: Vector2
var text_killer_start_pos: Vector2
var is_text_falling: bool = false
var text_fall_tween: Tween

# Store spawn positions
var player1_spawn: Vector2
var player2_spawn: Vector2

# Checkpoint system
var checkpoint_p1: Vector2
var checkpoint_p2: Vector2

var massive_spike_start_pos: Vector2
var box_start_pos: Vector2
var is_launching_spike: bool = false
var trigger_spike_activated: bool = false

# Store original platform positions/rotations
var original_platform_transforms: Array = []
var original_box_platform_transforms: Array = []

# Button state
var is_player_pressed: bool = false
var is_box_pressed: bool = false
# is_bridge_mode REMOVED

# Bodies currently on button
var bodies_on_button: Array = []

# Massive spike settings
@export var massive_spike_launch_duration: float = 2.0

# Active tween
var platform_tween: Tween
var box_platform_tween: Tween
var spike_tween: Tween

@onready var spike_scene = preload("res://scenes/spike.tscn")
# bridge_spike_instance REMOVED

# Removed _process manual checks. 
# Fall checks now handled by KillZone node.
# Trap checks now handled by signal toggling.

func _ready():
	$AudioStreamPlayer.play()

	# Create death overlay for visual feedback
	_create_death_overlay()
	
	# Setup hurt sound
	hurt_sound = AudioStreamPlayer.new()
	hurt_sound.stream = hurt_audio
	add_child(hurt_sound)
	
	# Store initial spawn positions
	player1_spawn = player1.global_position
	player2_spawn = player2.global_position
	
	# Initialize checkpoint to spawn position
	checkpoint_p1 = player1_spawn
	checkpoint_p2 = player2_spawn
	
	if box:
		box_start_pos = box.global_position
		# TUE BOX PHYSICS: Heavier, no bounce
		# Initially set to IMMOVABLE (Wait for 2 players to push)
		box.mass = 10000.0
		box.angular_damp = 50.0 # Prevent rotation
		
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

		# Enable contact monitoring for "2-player push" logic
		box.contact_monitor = true
		box.max_contacts_reported = 4

		# STRICT PHYSICS: No rotation, heavy gravity to stick to ground
		box.lock_rotation = true
		box.gravity_scale = 3.0 # Heavy falling
		box.linear_damp = 1.0   # Stop sliding quickly when not pushed
	
	if text_killer:
		text_killer.z_index = 100 # Ensure on top of everything
		text_killer.visible = false  # Hidden until triggered

	# Restore platform setup which was deleted
	for child in player_platform.get_children():
		if child is StaticBody2D:
			original_platform_transforms.append({
				"node": child,
				"position": child.position,
				"rotation": child.rotation
			})
	
	# Initially hide moving platform and warning
	player_platform.visible = false
	_disable_platform_collision(player_platform)
	
	# SETUP BOX PLATFORM
	if box_platform:
		for child in box_platform.get_children():
			if child is StaticBody2D:
				original_box_platform_transforms.append({
					"node": child,
					"position": child.position,
					"rotation": child.rotation
				})
		box_platform.visible = false
		_disable_platform_collision(box_platform)
	
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
		if spike_point:
			massive_spike_start_pos = spike_point.position
			massive_spike.position = spike_point.position
		else:
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

	# SETUP NEW SPIKES
	# Store target positions and hide them below ground AND make invisible
	if spike_alone:
		spike_alone_target_pos = spike_alone.position
		spike_alone.position.y += 200 # Move below
		spike_alone.visible = false   # Hide until triggered
		
	for s in spikes_many:
		if s:
			spikes_many_target_pos.append(s.position)
			s.position.y += 200 # Move below
			s.visible = false   # Hide until triggered
	
	if trigger_one_spike:
		trigger_one_spike.body_entered.connect(_on_trigger_one_spike_entered)
	if trigger_many_spike:
		trigger_many_spike.body_entered.connect(_on_trigger_many_spike_entered)

	# Setup Drop Text Trap (Already in scene)
	# Setup Drop Text Trap (Already in scene)
	if trigger_text:
		trigger_text_start_pos = trigger_text.position
		# FORCE COLLISION MASK: Detect Layer 2 (Players)
		trigger_text.collision_mask = 2
		trigger_text.collision_layer = 0
		if not trigger_text.body_entered.is_connected(_on_trigger_text_entered):
			trigger_text.body_entered.connect(_on_trigger_text_entered)
		print("TriggerText Setup: Mask: ", trigger_text.collision_mask, " Pos: ", trigger_text.global_position)

	if text_killer:
		# Force maximum visibility
		text_killer.z_index = 4096
		text_killer.modulate = Color(1, 0, 0, 1) # Red for visibility
		print("TextKiller Setup: Z: ", text_killer.z_index, " Pos: ", text_killer.global_position)

func _physics_process(_delta):
	# LOGIC: Box requires 2 Players to push
	if box:
		var bodies = box.get_colliding_bodies()
		var p1_touching = false
		var p2_touching = false
		
		for b in bodies:
			if b == player1: p1_touching = true
			if b == player2: p2_touching = true
		
		if p1_touching and p2_touching:
			# Both pushing -> Make it heavy but movable
			box.mass = 60.0 # Heavy but manageable by 2 players (force 100)
			box.physics_material_override.friction = 0.5 # Allow slide
		else:
			# Just one or none -> IMMOVABLE
			box.mass = 10000.0 # Extremely heavy
			box.physics_material_override.friction = 1.0 # Sticky
			# Kill residual velocity if one player stops pushing
			if not (p1_touching and p2_touching) and box.linear_velocity.length() > 10:
				box.linear_velocity = box.linear_velocity.lerp(Vector2.ZERO, 0.1)

func _setup_info_sign():
	# Look for existing SignInfo node (scene uses "SignInfo" not "InfoSign")
	var info_sign = get_node_or_null("SignInfo")
	if not info_sign:
		info_sign = get_node_or_null("InfoSign")
	if not info_sign:
		info_sign = get_node_or_null("Background/InfoSign")
	
	# If still not found, create dynamically on Sign sprite
	if not info_sign:
		var sign_sprite = get_node_or_null("Background/Sign")
		if not sign_sprite:
			sign_sprite = get_node_or_null("SignInfo/Sign")
		if sign_sprite:
			print("Creating dynamic SignInfo trigger...")
			info_sign = Area2D.new()
			info_sign.name = "SignInfo_Dynamic"
			add_child(info_sign)
			info_sign.global_position = sign_sprite.global_position
			
			var col = CollisionShape2D.new()
			var rect = RectangleShape2D.new()
			rect.size = Vector2(120, 120)
			col.shape = rect
			info_sign.add_child(col)
			
			info_sign.collision_layer = 0
			info_sign.collision_mask = 2
	
	if info_sign:
		# Connect signals for SignInfo
		if not info_sign.body_entered.is_connected(_on_info_sign_entered):
			info_sign.body_entered.connect(_on_info_sign_entered)
		if not info_sign.body_exited.is_connected(_on_info_sign_exited):
			info_sign.body_exited.connect(_on_info_sign_exited)
		# Ensure collision mask is set
		info_sign.collision_layer = 0
		info_sign.collision_mask = 2
		print("SignInfo connected at: ", info_sign.global_position)

func _on_info_sign_entered(body):
	if body == player1 or body == player2:
		if warning_label:
			warning_label.visible = true
			warning_label.text = "In this world,\nthere is no one you can trust."
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
	var bodies = button_area.get_overlapping_bodies()
	var player_on_button = false
	var box_on_button = false
	
	for body in bodies:
		if body == player1 or body == player2:
			player_on_button = true
		if body == box:
			box_on_button = true
	
	# Player on button -> reveal Moving Platform (Trap)
	if player_on_button and not is_player_pressed:
		is_player_pressed = true
		_reveal_player_platform()
	elif not player_on_button and is_player_pressed:
		is_player_pressed = false
		_hide_player_platform()
		
	# Box on button -> reveal Box Platform (Safe)
	if box_on_button and not is_box_pressed:
		is_box_pressed = true
		_reveal_box_platform()
	elif not box_on_button and is_box_pressed:
		is_box_pressed = false
		_hide_box_platform()

func _reveal_player_platform():
	print("Button pressed! Revealing moving platform...")
	
	# Kill any existing tween
	if platform_tween and platform_tween.is_valid():
		platform_tween.kill()
	
	player_platform.visible = true
	player_platform.modulate.a = 1.0  # Ensure fully visible
	_enable_platform_collision(player_platform)
	
	# Reset to original positions (always, no more bridge mode)
	_reset_platform_transforms()
	
	# Animate slide up (from below)
	platform_tween = create_tween()
	platform_tween.set_parallel(true)
	for child in player_platform.get_children():
		if child is StaticBody2D:
			var target_pos = child.position
			child.position.y += 200  # Start 200px below
			platform_tween.tween_property(child, "position:y", target_pos.y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_player_platform():
	print("Button released! Hiding moving platform...")
	
	# Kill any existing tween
	if platform_tween and platform_tween.is_valid():
		platform_tween.kill()
	
	# Animate slide down (disappear below)
	platform_tween = create_tween()
	platform_tween.set_parallel(true)
	for child in player_platform.get_children():
		if child is StaticBody2D:
			var target_y = child.position.y + 200  # Go 200px down
			platform_tween.tween_property(child, "position:y", target_y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	platform_tween.set_parallel(false)
	platform_tween.tween_callback(func():
		player_platform.visible = false
		_disable_platform_collision(player_platform)
		_reset_platform_transforms()
	)

func _reset_platform_transforms():
	for data in original_platform_transforms:
		data.node.position = data.position
		data.node.rotation = data.rotation

func _reset_box_platform_transforms():
	for data in original_box_platform_transforms:
		data.node.position = data.position
		data.node.rotation = data.rotation

func _reveal_box_platform():
	print("Box on button! Revealing safe platform...")
	if box_platform:
		if box_platform_tween and box_platform_tween.is_valid():
			box_platform_tween.kill()
		
		box_platform.visible = true
		box_platform.modulate.a = 1.0
		_enable_platform_collision(box_platform)
		_reset_box_platform_transforms()
		
		box_platform_tween = create_tween()
		box_platform_tween.set_parallel(true)
		for child in box_platform.get_children():
			if child is StaticBody2D:
				var target_pos = child.position
				child.position.y += 200
				box_platform_tween.tween_property(child, "position:y", target_pos.y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Animate the extra platform part
		if platform_part_2:
			# Target 2839, 810 specified by user
			var target = Vector2(2839, 810)
			box_platform_tween.tween_property(platform_part_2, "position", target, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Animate Flag
		if flag:
			var target = Vector2(1824, 565)
			box_platform_tween.tween_property(flag, "position", target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_box_platform():
	print("Box left button! Hiding safe platform...")
	if box_platform:
		if box_platform_tween and box_platform_tween.is_valid():
			box_platform_tween.kill()
			
		box_platform_tween = create_tween()
		box_platform_tween.set_parallel(true)
		for child in box_platform.get_children():
			if child is StaticBody2D:
				var target_y = child.position.y + 200
				box_platform_tween.tween_property(child, "position:y", target_y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		# Animate extra platform part back to original (assumed 1100Y from scene)
		if platform_part_2:
			var target = Vector2(2839, 1100)
			box_platform_tween.tween_property(platform_part_2, "position", target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		# Animate Flag back
		if flag:
			var target = Vector2(1824, 832)
			box_platform_tween.tween_property(flag, "position", target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		box_platform_tween.set_parallel(false)
		box_platform_tween.tween_callback(func():
			box_platform.visible = false
			_disable_platform_collision(box_platform)
			_reset_box_platform_transforms()
			# Reset platform part 2 pos strictly (though tween should have done it)
			if platform_part_2:
				platform_part_2.position = Vector2(2839, 1100)
			if flag:
				flag.position = Vector2(1824, 832)
		)

func _show_warning():
	if warning_label:
		warning_label.visible = true
		warning_label.text = "In this world,\nthere is no one you can trust."
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
		_show_death_flash()

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
	# Play hurt sound
	if hurt_sound:
		hurt_sound.play()
	
	if death_overlay:
		death_overlay.color = Color(1, 0.2, 0.2, 0)
		var tween = create_tween()
		tween.tween_property(death_overlay, "color:a", 0.5, 0.1)
		tween.tween_property(death_overlay, "color:a", 0.0, 0.2)
		tween.tween_callback(_reset_level)
	else:
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

	# Reset players to checkpoint
	player1.global_position = checkpoint_p1
	player2.global_position = checkpoint_p2
	
	# Reset player velocities
	player1.velocity = Vector2.ZERO
	player2.velocity = Vector2.ZERO
	
	# Reset button state
	is_player_pressed = false
	is_box_pressed = false
	bodies_on_button.clear()
	if button_area:
		button_area.set_deferred("monitoring", false)
		button_area.set_deferred("monitoring", true)
	
	# Hide and reset platforms
	player_platform.visible = false
	_disable_platform_collision(player_platform)
	_reset_platform_transforms()
	
	if box_platform:
		box_platform.visible = false
		_disable_platform_collision(box_platform)
		_reset_box_platform_transforms()
		if platform_part_2:
			platform_part_2.position = Vector2(2839, 1100)
		if flag:
			flag.position = Vector2(1824, 832)
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
		if spike_tween and spike_tween.is_valid():
			spike_tween.kill()
		
		# Reset position to SpikePoint if exists, else start pos
		if spike_point:
			massive_spike.position = spike_point.position
			# Update start pos too so next reset is consistent
			massive_spike_start_pos = spike_point.position
		else:
			massive_spike.position = massive_spike_start_pos
			
		massive_spike.rotation = -0.28 # Approx -16 deg as seen in scene
		
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

	# Reset New Spikes
	one_spike_triggered = false
	many_spikes_triggered = false
	
	if spike_alone:
		spike_alone.position.y = spike_alone_target_pos.y + 200
		spike_alone.visible = false
		
	for i in range(spikes_many.size()):
		var s = spikes_many[i]
		if s and i < spikes_many_target_pos.size():
			s.position.y = spikes_many_target_pos[i].y + 200
			s.visible = false

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


func _on_trigger_one_spike_entered(body):
	print("test")
	if one_spike_triggered: return
	if body == player1 or body == player2:
		one_spike_triggered = true
		print("Trigger One Spike!")
		if spike_alone:
			spike_alone.visible = true # Reveal
			var tween = create_tween()
			tween.tween_property(spike_alone, "position", spike_alone_target_pos, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_trigger_many_spike_entered(body):
	if many_spikes_triggered: return
	if body == player1 or body == player2:
		many_spikes_triggered = true
		print("Trigger Many Spikes!")
		
		var tween = create_tween()
		for i in range(spikes_many.size()):
			var s = spikes_many[i]
			if s:
				s.visible = true # Reveal
				var target = spikes_many_target_pos[i]
				# Parallel or sequence? Let's do parallel with delay
				tween.parallel().tween_property(s, "position", target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.1)

func _on_trigger_text_entered(body: Node2D) -> void:
	if body == player1 or body == player2:
		# If not falling -> Trigger fall sequence
		if not is_text_falling and (text_fall_tween == null or not text_fall_tween.is_valid()):
			print("Text Trap Triggered! Waiting...")
			
			if text_fall_tween: text_fall_tween.kill()
			text_fall_tween = create_tween()
			
			if text_killer:
				text_killer.visible = true
			
			# User requested 1.5 seconds delay
			var delay = 1.5 
			text_fall_tween.tween_interval(delay)
			text_fall_tween.tween_callback(_execute_text_drop)

## Update checkpoint to current player positions
func update_checkpoint() -> void:
	checkpoint_p1 = player1.global_position
	checkpoint_p2 = player2.global_position
	print("Checkpoint updated!")
