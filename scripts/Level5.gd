extends Node2D

## Level 5 - Sun Boss Bullet Hell
## Theme: "Nothing works as expected"
## 
## Flow:
## 1. PLATFORMER: Normal platformer gameplay
## 2. Touch flag → flag terbang ke matahari
## 3. TRANSITION: Matahari ke tengah, map terbakar
## 4. BULLET_HELL: Top-down survival game
## 5. FAKE_DEATH: Boss "dies", flag falls...
## 6. GOTCHA: Boss revives with surprise attack!
## 7. VICTORY: Survive phase 2

@export_group("Transition")
@export var burn_duration: float = 3.5
@export var sun_move_duration: float = 2.0
@export var flag_fly_duration: float = 1.5

@export_group("Bullet Hell")
@export var phase1_duration: float = 15.0
@export var fake_death_duration: float = 3.0
@export var phase2_duration: float = 12.0
@export var player_lives: int = 5
var level_completed = false
# Node references - will be set depending on scene structure
var sun_boss: Node2D
var sun_sprite: Node2D  # Sun visual in sky during platformer (AnimatedSprite2D parent)
var sun_anim: AnimatedSprite2D  # The actual animated sprite
var player1: CharacterBody2D
var player2: CharacterBody2D
var flag_trigger: Area2D
var platform_chain: Node2D  # Regular platformer chain
var topdown_chain: Node2D   # Top-down chain
var map_container: Node2D   # Container for map elements

var timer_label: Label
var lives_label: Label
var message_label: Label

enum GamePhase { 
	PLATFORMER,      # Normal platformer gameplay
	FLAG_FLY,        # Flag flying to sun
	TRANSITION,      # Sun moving + map burning
	BULLET_HELL,     # Phase 1 bullet hell
	FAKE_DEATH,      # Boss "dies"
	PHASE_2,         # Boss revives
	VICTORY,         # Player won
	DEFEAT           # Player lost
}

var current_phase: GamePhase = GamePhase.PLATFORMER
var phase_timer: float = 0.0
var current_lives: int = 5
var burn_progress: float = 0.0

# Sun positions
var sun_sky_position: Vector2 = Vector2(1700, 150)
var sun_center_position: Vector2 = Vector2(960, 400)

# Flag reference
var flag: Node2D
var flag_area: Area2D  # Reference to the Flag Area2D for collision control
var flag_orbit_distance: float = 200.0

# Camera reference for shake
var camera: Camera2D

# Sound effects
var hurt_sound: AudioStreamPlayer
var crunch_sound: AudioStreamPlayer
var hurt_audio = preload("res://assets/sfx/Hurt.wav")
var crunch_audio = preload("res://assets/sfx/Crunch.wav")

# Burn effect materials
var burn_materials: Array[ShaderMaterial] = []

# Nodes for burn effect
var objects_node: Node2D
var tilemap_layer: TileMapLayer
var cloud_background: Node2D

# Spawn positions for soft reset
var player1_spawn: Vector2
var player2_spawn: Vector2

# Checkpoint positions
var checkpoint_p1: Vector2
var checkpoint_p2: Vector2

func _ready() -> void:
	current_lives = player_lives
	
	# Get node references - flexible to handle different scene structures
	_setup_node_references()
	
	# Store initial positions
	if sun_boss:
		# Position sun at sky position (like background in levels 1-4)
		sun_boss.global_position = sun_sky_position
		sun_boss.visible = true
		sun_boss.set_process(false)  # Don't attack yet
		if sun_sprite:
			sun_sky_position = sun_boss.global_position
	if flag_trigger:
		flag = flag_trigger
		# Get the actual Flag Area2D inside FlagTrigger and disable collision until victory
		flag_area = flag_trigger.get_node_or_null("Flag")
		if flag_area:
			flag_area.set_deferred("monitoring", false)
			flag_area.set_deferred("monitorable", false)
	
	# Store player spawn positions for soft reset
	if player1:
		player1_spawn = player1.global_position
		checkpoint_p1 = player1_spawn
	if player2:
		player2_spawn = player2.global_position
		checkpoint_p2 = player2_spawn
	
	# Setup burn materials for map elements
	_setup_burn_materials()
	# Defer cloud burn setup to ensure CloudBackground._ready() has completed
	call_deferred("_setup_cloud_burn_materials")
	
	# Setup sound effects
	hurt_sound = AudioStreamPlayer.new()
	hurt_sound.stream = hurt_audio
	add_child(hurt_sound)
	
	crunch_sound = AudioStreamPlayer.new()
	crunch_sound.stream = crunch_audio
	add_child(crunch_sound)
	
	_update_ui()

func _setup_node_references() -> void:
	# Try to find nodes - flexible naming
	sun_boss = get_node_or_null("SunBoss")
	
	# SunSprite is a child of SunBoss
	if sun_boss:
		sun_sprite = sun_boss.get_node_or_null("SunSprite")
		if sun_sprite:
			sun_anim = sun_sprite.get_node_or_null("AnimatedSprite2D")
	
	player1 = get_node_or_null("Player1")
	player2 = get_node_or_null("Player2")
	flag_trigger = get_node_or_null("FlagTrigger")
	platform_chain = get_node_or_null("Chain")
	topdown_chain = get_node_or_null("TopdownChain")
	map_container = get_node_or_null("MapContainer")
	objects_node = get_node_or_null("Objects")
	# TileMapLayer is under Objects
	if objects_node:
		tilemap_layer = objects_node.get_node_or_null("TileMapLayer")
	else:
		tilemap_layer = get_node_or_null("TileMapLayer")
	camera = get_node_or_null("Camera2D")
	
	# UI
	if has_node("UI"):
		timer_label = get_node_or_null("UI/TimerLabel")
		lives_label = get_node_or_null("UI/LivesLabel")
		message_label = get_node_or_null("UI/MessageLabel")
		# Create missing UI elements
		_create_ui_elements()
	
	# CloudBackground
	cloud_background = get_node_or_null("CloudBackground")

func _create_ui_elements() -> void:
	var ui_node = get_node_or_null("UI")
	if not ui_node:
		return
	
	# Create Timer Label (top center)
	if not timer_label:
		timer_label = Label.new()
		timer_label.name = "TimerLabel"
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Position at top center (screen center X - half label width)
		timer_label.position = Vector2(760, 30)  # 960 - 200
		timer_label.custom_minimum_size = Vector2(400, 60)
		timer_label.pivot_offset = Vector2(200, 30)
		timer_label.add_theme_font_size_override("font_size", 52)
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
		timer_label.add_theme_constant_override("outline_size", 6)
		ui_node.add_child(timer_label)
	
	# Create Lives Label (top left)
	if not lives_label:
		lives_label = Label.new()
		lives_label.name = "LivesLabel"
		lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lives_label.position = Vector2(30, 30)
		lives_label.add_theme_font_size_override("font_size", 32)
		lives_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		lives_label.add_theme_color_override("font_outline_color", Color.BLACK)
		lives_label.add_theme_constant_override("outline_size", 3)
		ui_node.add_child(lives_label)
	


func _setup_burn_materials() -> void:
	var burn_shader = load("res://shaders/pixelated_burn.gdshader")
	var noise_tex = load("res://shaders/burn_noise.tres")
	
	if not burn_shader:
		print("[Level5] Burn shader not found")
		return
	
	# Apply burn material to Objects children (Sprites)
	if objects_node:
		for child in objects_node.get_children():
			if child is CanvasItem:
				var mat = ShaderMaterial.new()
				mat.shader = burn_shader
				if noise_tex:
					mat.set_shader_parameter("noise_texture", noise_tex)
				mat.set_shader_parameter("burn_radius", 0.0)
				mat.set_shader_parameter("burn_center_screen", sun_sky_position)
				mat.set_shader_parameter("screen_size", Vector2(1920, 1080))
				child.material = mat
				burn_materials.append(mat)
	
	# Apply burn material to TileMapLayer
	if tilemap_layer:
		var mat = ShaderMaterial.new()
		mat.shader = burn_shader
		if noise_tex:
			mat.set_shader_parameter("noise_texture", noise_tex)
		mat.set_shader_parameter("burn_radius", 0.0)
		mat.set_shader_parameter("burn_center_screen", sun_sky_position)
		mat.set_shader_parameter("screen_size", Vector2(1920, 1080))
		tilemap_layer.material = mat
		burn_materials.append(mat)
	
	# Also apply to MapContainer children if any
	if map_container:
		for child in map_container.get_children():
			var visual = child.get_node_or_null("Visual")
			if visual and visual is CanvasItem:
				var mat = ShaderMaterial.new()
				mat.shader = burn_shader
				if noise_tex:
					mat.set_shader_parameter("noise_texture", noise_tex)
				mat.set_shader_parameter("burn_radius", 0.0)
				mat.set_shader_parameter("burn_center_screen", sun_sky_position)
				mat.set_shader_parameter("screen_size", Vector2(1920, 1080))
				visual.material = mat
				burn_materials.append(mat)

func _setup_cloud_burn_materials() -> void:
	var burn_shader = load("res://shaders/pixelated_burn.gdshader")
	var noise_tex = load("res://shaders/burn_noise.tres")
	
	if not burn_shader or not cloud_background:
		return
	
	# Apply burn material to CloudBackground children (clouds)
	for child in cloud_background.get_children():
		if child is Sprite2D:
			var mat = ShaderMaterial.new()
			mat.shader = burn_shader
			if noise_tex:
				mat.set_shader_parameter("noise_texture", noise_tex)
			mat.set_shader_parameter("burn_radius", 0.0)
			mat.set_shader_parameter("burn_center_screen", sun_sky_position)
			mat.set_shader_parameter("screen_size", Vector2(1920, 1080))
			child.material = mat
			burn_materials.append(mat)
	print("[Level5] Cloud burn materials applied: %d clouds" % cloud_background.get_child_count())

func _process(delta: float) -> void:
	match current_phase:
		GamePhase.PLATFORMER:
			pass
		
		GamePhase.FLAG_FLY:
			pass  # Handled by tween
		
		GamePhase.TRANSITION:
			burn_progress += delta / burn_duration
			burn_progress = clamp(burn_progress, 0.0, 1.0)
			_update_burn_effect(burn_progress)
			
			if burn_progress >= 1.0:
				_start_bullet_hell()
		
		GamePhase.BULLET_HELL:
			var old_timer = phase_timer
			phase_timer -= delta
			_update_timer_display(old_timer, phase_timer, phase1_duration)
			if phase_timer <= 0:
				_trigger_fake_death()
		
		GamePhase.FAKE_DEATH:
			phase_timer -= delta
			if timer_label:
				timer_label.text = ""
			if phase_timer <= 0:
				_trigger_revive()
		
		GamePhase.PHASE_2:
			var old_timer = phase_timer
			phase_timer -= delta
			_update_timer_display(old_timer, phase_timer, phase2_duration)
			if phase_timer <= 0:
				_trigger_real_victory()
		
		GamePhase.VICTORY:
			level_completed = true
			_check_flag_collision()

## ========== FLAG TRIGGER - STARTS TRANSITION ==========

func _on_flag_touched(body: Node2D) -> void:
	if current_phase != GamePhase.PLATFORMER:
		return
	if not body.is_in_group("player"):
		return
	
	print("Flag touched! Starting transition...")
	current_phase = GamePhase.FLAG_FLY
	_animate_flag_to_sun()

func _animate_flag_to_sun() -> void:
	if not flag or not sun_boss:
		_start_transition()
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# Flag flies to sun position
	var sun_pos = sun_boss.global_position
	tween.tween_property(flag, "global_position", sun_pos, flag_fly_duration)
	tween.tween_callback(_start_transition)

func _start_transition() -> void:
	current_phase = GamePhase.TRANSITION
	burn_progress = 0.0
	
	# Sun becomes ANGRY - turn red and play angry animation!
	if sun_anim:
		sun_anim.play("angry")
	
	# Tint sun red
	if sun_sprite:
		var color_tween = create_tween()
		color_tween.tween_property(sun_sprite, "modulate", Color(1.0, 0.4, 0.3, 1.0), 0.5)
	
	# Animate sun_boss moving to center and growing
	if sun_boss:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(sun_boss, "global_position", sun_center_position, sun_move_duration)
		tween.parallel().tween_property(sun_boss, "scale", Vector2(1.5, 1.5), sun_move_duration)

func _update_burn_effect(progress: float) -> void:
	var max_radius = 2500.0
	var current_radius = progress * max_radius
	var current_sun_pos = sun_boss.global_position if sun_boss else sun_center_position
	
	for mat in burn_materials:
		mat.set_shader_parameter("burn_radius", current_radius)
		mat.set_shader_parameter("burn_center_screen", current_sun_pos)

## ========== BULLET HELL PHASE ==========

func _start_bullet_hell() -> void:
	current_phase = GamePhase.BULLET_HELL
	phase_timer = phase1_duration
	
	# Camera shake for dramatic transition
	_shake_camera(0.5)
	
	# Queue_free all burned elements - they're gone forever!
	
	# Remove CloudBackground
	if cloud_background:
		cloud_background.queue_free()
		cloud_background = null
	
	# Remove MapContainer
	if map_container:
		map_container.queue_free()
		map_container = null
	
	# Remove Objects (includes TileMapLayer)
	if objects_node:
		objects_node.queue_free()
		objects_node = null
		tilemap_layer = null  # It was a child of objects_node
	
	# Clear burn materials references (nodes are freed)
	burn_materials.clear()
	
	# Activate sun boss (it's already visible and positioned)
	if sun_boss:
		sun_boss.set_process(true)
		
		# Play angry animation
		if sun_boss.has_method("play_angry"):
			sun_boss.play_angry()
		
		# Connect boss signals
		if sun_boss.has_method("set_players"):
			sun_boss.set_players(player1, player2)
		if sun_boss.has_signal("boss_fake_death"):
			if not sun_boss.is_connected("boss_fake_death", _on_boss_fake_death):
				sun_boss.boss_fake_death.connect(_on_boss_fake_death)
		if sun_boss.has_signal("boss_revived"):
			if not sun_boss.is_connected("boss_revived", _on_boss_revived):
				sun_boss.boss_revived.connect(_on_boss_revived)
		if sun_boss.has_signal("boss_defeated"):
			if not sun_boss.is_connected("boss_defeated", _on_boss_defeated):
				sun_boss.boss_defeated.connect(_on_boss_defeated)
	
	# Transfer flag to boss for orbiting - SMOOTH transition
	if flag and sun_boss:
		# Store current global position before reparenting
		var flag_global_pos = flag.global_position
		if flag.get_parent() != sun_boss:
			flag.get_parent().remove_child(flag)
			sun_boss.add_child(flag)
		# Restore global position first (so it doesn't snap)
		flag.global_position = flag_global_pos
		# Then tween to orbit position
		var target_local_pos = Vector2(flag_orbit_distance, 0)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(flag, "position", target_local_pos, 1.0)
	
	# Switch player movement to top-down
	_enable_topdown_movement()
	
	# Switch chains
	if platform_chain:
		platform_chain.set_process(false)
		platform_chain.visible = false
	if topdown_chain:
		topdown_chain.set_process(true)
		topdown_chain.visible = true
	
	# Show message
	if message_label:
		message_label.text = "SURVIVE THE SUN!"
		await get_tree().create_timer(2.0).timeout
		if current_phase == GamePhase.BULLET_HELL:
			message_label.text = ""

func _enable_topdown_movement() -> void:
	# Switch players to top-down mode
	# This could enable a flag on the player or swap scripts
	if player1 and player1.has_method("set_topdown_mode"):
		player1.set_topdown_mode(true)
	if player2 and player2.has_method("set_topdown_mode"):
		player2.set_topdown_mode(true)

## ========== FAKE DEATH SEQUENCE ==========

func _trigger_fake_death() -> void:
	current_phase = GamePhase.FAKE_DEATH
	phase_timer = fake_death_duration
	last_timer_second = -1  # Reset timer animation
	
	# Big camera shake - sun "dies"!
	_shake_camera(0.7)
	
	if message_label:
		message_label.text = "You... you did it?!"
		message_label.modulate = Color.GREEN
		# Pop animation
		var msg_tween = create_tween()
		msg_tween.tween_property(message_label, "scale", Vector2(1.4, 1.4), 0.15)
		msg_tween.tween_property(message_label, "scale", Vector2.ONE, 0.1)
	
	if timer_label:
		timer_label.text = ""
		timer_label.modulate = Color.WHITE
	
	if sun_boss and sun_boss.has_method("trigger_fake_death"):
		sun_boss.trigger_fake_death()
	
	# Flag starts falling with dramatic effect
	if flag and sun_boss:
		var flag_global_pos = flag.global_position
		if flag.get_parent() == sun_boss:
			sun_boss.remove_child(flag)
			add_child(flag)
		flag.global_position = flag_global_pos
		
		# Dramatic flag drop - pause, then fall
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_BOUNCE)
		# Rotate and wobble while falling
		tween.tween_property(flag, "rotation_degrees", 15.0, 0.3)
		tween.parallel().tween_property(flag, "global_position:y", flag_global_pos.y + 50, 0.3)
		tween.tween_property(flag, "rotation_degrees", -15.0, 0.3)
		tween.parallel().tween_property(flag, "global_position:y", 700.0, 0.9)
		tween.tween_property(flag, "rotation_degrees", 0.0, 0.2)

func _on_boss_fake_death() -> void:
	pass  # Visual handled by boss

func _trigger_revive() -> void:
	current_phase = GamePhase.PHASE_2
	phase_timer = phase2_duration
	last_timer_second = -1  # Reset timer animation
	
	# Triple shake - SURPRISE!
	_shake_camera(0.8)
	await get_tree().create_timer(0.2).timeout
	_shake_camera(0.6)
	
	if message_label:
		message_label.text = "JUST KIDDING!"
		message_label.modulate = Color.RED
		# Scary pop animation
		var msg_tween = create_tween()
		msg_tween.tween_property(message_label, "scale", Vector2(1.6, 1.6), 0.1)
		msg_tween.tween_property(message_label, "scale", Vector2.ONE, 0.2)
		await get_tree().create_timer(1.5).timeout
		if current_phase == GamePhase.PHASE_2:
			message_label.text = ""
			message_label.modulate = Color.WHITE
	
	# Flag yanked back up!
	if flag:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(flag, "global_position:y", sun_center_position.y, 0.3)
		tween.tween_callback(_reparent_flag_to_boss)
	
	if sun_boss and sun_boss.has_method("trigger_revive"):
		sun_boss.trigger_revive()

func _reparent_flag_to_boss() -> void:
	if flag and sun_boss:
		if flag.get_parent() != sun_boss:
			var flag_local_pos = Vector2(flag_orbit_distance, 0)
			flag.get_parent().remove_child(flag)
			sun_boss.add_child(flag)
			flag.position = flag_local_pos

func _on_boss_revived() -> void:
	pass  # Visual handled by boss

## ========== REAL VICTORY ==========

func _trigger_real_victory() -> void:
	current_phase = GamePhase.VICTORY
	
	# MASSIVE camera shake - sun REALLY dies!
	_shake_camera(1.0)
	await get_tree().create_timer(0.3).timeout
	_shake_camera(0.6)
	
	if message_label:
		message_label.text = "Okay... for real this time..."
		message_label.modulate = Color(1.0, 0.9, 0.3, 1.0)  # Golden
	
	if timer_label:
		timer_label.text = ""
		timer_label.modulate = Color.WHITE
	
	if sun_boss and sun_boss.has_method("trigger_real_death"):
		sun_boss.trigger_real_death()
	
	# Flag falls for real with EPIC drop
	if flag and sun_boss:
		if flag.get_parent() == sun_boss:
			var flag_global_pos = flag.global_position
			sun_boss.remove_child(flag)
			add_child(flag)
			flag.global_position = flag_global_pos
		
		# Epic slow-mo feel flag drop
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		# Hang in air for a beat
		tween.tween_interval(0.5)
		# Then drop with style
		tween.tween_property(flag, "global_position:y", 600.0, 0.4)
		tween.parallel().tween_property(flag, "rotation_degrees", 360.0, 0.8)
		tween.tween_property(flag, "global_position:y", 750.0, 0.4)
		tween.tween_property(flag, "rotation_degrees", 0.0, 0.2)
		tween.tween_callback(_flag_landed)

func _on_boss_defeated() -> void:
	if timer_label:
		timer_label.text = "GET THE FLAG!"
		# Pulse animation
		var tween = create_tween().set_loops(0)
		tween.tween_property(timer_label, "scale", Vector2(1.15, 1.15), 0.4)
		tween.tween_property(timer_label, "scale", Vector2.ONE, 0.4)

func _flag_landed() -> void:
	# Small shake when flag lands
	_shake_camera(0.3)
	if timer_label:
		timer_label.modulate = Color.GREEN

func _check_flag_collision() -> void:
	if not flag or not player1 or not player2:
		return
	
	var flag_pos = flag.global_position
	var p1_dist = player1.global_position.distance_to(flag_pos)
	var p2_dist = player2.global_position.distance_to(flag_pos)
	
	if p1_dist < 60 or p2_dist < 60:
		_win_level()

func _win_level() -> void:
	current_phase = GamePhase.DEFEAT  # Stop processing
	
	# Enable flag collision for proper scene transition
	if flag_area:
		flag_area.monitoring = true
		flag_area.monitorable = true
		# Set level_5_completed so flag.gd allows advancement
		if flag_area.has_method("get") or "level_5_completed" in flag_area:
			flag_area.level_5_completed = true
	
	if message_label:
		message_label.text = "YOU WIN!"
		message_label.modulate = Color(1, 0.9, 0.2, 1)  # Golden color
		# Victory pop-in animation
		message_label.scale = Vector2(0.5, 0.5)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(message_label, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(message_label, "scale", Vector2.ONE, 0.15)
	if timer_label:
		timer_label.text = ""
	
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

## ========== DAMAGE HANDLING ==========

## Called by bullets when they hit player
func on_player_hit(player: Node2D) -> void:
	if current_phase == GamePhase.FAKE_DEATH or current_phase == GamePhase.VICTORY:
		return  # Invincible during these phases
	if current_phase == GamePhase.PLATFORMER:
		return  # No bullets during platformer
	
	if player.has_method("take_hit"):
		var was_hit = player.is_hit if "is_hit" in player else false
		if was_hit:
			return
		player.take_hit()
	
	# Play hurt sound
	if hurt_sound:
		hurt_sound.play()
	
	# Camera shake on hit
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.35)
	
	current_lives -= 1
	_update_ui()
	
	if current_lives <= 0:
		_game_over()

func _game_over() -> void:
	current_phase = GamePhase.DEFEAT
	
	# Heavy camera shake on game over
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.8)
	
	if message_label:
		message_label.text = "GAME OVER"
		# Pulse effect on game over text
		var tween = create_tween().set_loops(3)
		tween.tween_property(message_label, "scale", Vector2(1.1, 1.1), 0.15)
		tween.tween_property(message_label, "scale", Vector2.ONE, 0.15)
	if timer_label:
		timer_label.text = ""
	
	await get_tree().create_timer(2.0).timeout
	_reset_level()

func _reset_level() -> void:
	# During platformer phase, do soft reset (no reload)
	if current_phase == GamePhase.PLATFORMER:
		if player1:
			player1.global_position = checkpoint_p1
			player1.velocity = Vector2.ZERO
		if player2:
			player2.global_position = checkpoint_p2
			player2.velocity = Vector2.ZERO
		return
	
	# For boss phases, full reload is needed to reset all state
	get_tree().reload_current_scene()

## Update checkpoint - simpan posisi aktual kedua player
func update_checkpoint() -> void:
	checkpoint_p1 = player1.global_position
	checkpoint_p2 = player2.global_position

func _update_ui() -> void:
	if lives_label:
		lives_label.text = "LIVES: %d" % current_lives

## ========== POLISHED TIMER ==========

var last_timer_second: int = -1

func _update_timer_display(old_time: float, new_time: float, max_time: float) -> void:
	if not timer_label:
		return
	
	var display_time = max(0, new_time)
	var current_second = int(ceil(display_time))
	var old_second = int(ceil(old_time))
	
	# Update text - just the number
	timer_label.text = "%d" % current_second
	
	# Animate on each second tick
	if current_second != last_timer_second and last_timer_second != -1:
		last_timer_second = current_second
		_animate_timer_tick(current_second, max_time)
	elif last_timer_second == -1:
		last_timer_second = current_second

func _animate_timer_tick(seconds_left: int, max_time: float) -> void:
	if not timer_label:
		return
	
	# Pop animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Scale up and back
	tween.tween_property(timer_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(timer_label, "scale", Vector2.ONE, 0.15)
	
	# Color changes based on time remaining
	var ratio = float(seconds_left) / max_time
	var target_color: Color
	if ratio > 0.5:
		target_color = Color.WHITE
	elif ratio > 0.25:
		target_color = Color.YELLOW
	else:
		target_color = Color(1.0, 0.4, 0.2, 1.0)  # Orange-red
		# Extra shake when low
		_shake_camera(0.15)
	
	timer_label.modulate = target_color
	
	# Pulse glow effect on last 5 seconds
	if seconds_left <= 5:
		var glow_tween = create_tween()
		glow_tween.tween_property(timer_label, "modulate:a", 0.6, 0.2)
		glow_tween.tween_property(timer_label, "modulate:a", 1.0, 0.2)

## ========== CAMERA SHAKE ==========

func _shake_camera(intensity: float) -> void:
	# Play crunch sound for dramatic effect
	if crunch_sound and intensity >= 0.3:
		crunch_sound.play()
	
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(intensity)
	elif camera:
		# Fallback shake if no trauma system
		_simple_camera_shake(intensity)

func _simple_camera_shake(intensity: float) -> void:
	if not camera:
		return
	
	var original_offset = camera.offset
	var tween = create_tween()
	var shake_count = 5
	var shake_duration = 0.05
	
	for i in range(shake_count):
		var offset = Vector2(
			randf_range(-20, 20) * intensity,
			randf_range(-20, 20) * intensity
		)
		tween.tween_property(camera, "offset", original_offset + offset, shake_duration)
	
	tween.tween_property(camera, "offset", original_offset, shake_duration)

## ========== COLLISION HELPER ==========

func _disable_all_collisions(node: Node) -> void:
	# Disable collision on this node if applicable
	if node is TileMapLayer:
		node.collision_enabled = false
	elif node is CollisionObject2D:
		node.set_collision_layer_value(1, false)
		node.set_collision_mask_value(1, false)
	
	# Recursively check children
	for child in node.get_children():
		_disable_all_collisions(child)
