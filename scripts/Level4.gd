extends Node2D

## Level 4 - Flappy Bird Co-op Mode
## Full Intro Animation + Flappy Bird Gameplay

# === State Machine ===
enum GameState {
	INTRO_APPROACH,     # Players + Rock walk toward flag
	INTRO_FLAG_SHAKE,   # Flag shakes when players are close
	INTRO_FLAG_ESCAPE,  # Flag escapes off-camera
	INTRO_GO_TO_ROCK,   # Players walk toward rock
	INTRO_DETACH,       # Players detach chain from rock
	INTRO_JUMP,         # Players jump off platform
	INTRO_TUTORIAL,     # 5 seconds - flying with control hints
	INTRO_BUFFER,       # 2 seconds buffer before gameplay
	PLAYING,            # Flappy Bird gameplay
	GAME_OVER,          # Death
	COMPLETE            # Win
}

# Start State
var current_state: GameState = GameState.INTRO_TUTORIAL # Modified from INTRO_APPROACH

# === Node References ===
@onready var player1: CharacterBody2D = $Player1
@onready var player2: CharacterBody2D = $Player2
@onready var chain: Node2D = $Chain
@onready var rock_chain: Node2D = $RockChain if has_node("RockChain") else null
@onready var rock: RigidBody2D = $Rock if has_node("Rock") else null
@onready var flag: Node2D = $Flag
@onready var camera: Camera2D = $Camera2D
@onready var platform: Node2D = $Platform if has_node("Platform") else null
@onready var obstacle_container: Node2D = $ObstacleContainer if has_node("ObstacleContainer") else null
@onready var ui_label: Label = $UI/Label if has_node("UI/Label") else null
@onready var bg_sprite: Sprite2D = $Bg if has_node("Bg") else null
@onready var spawn_point: Node2D = $SpawnPoint
@onready var background_node: ParallaxBackground = $Background if has_node("Background") else null
@onready var flag_point = $FlagPoint

# === Intro Settings ===
@export_group("Intro Animation")
@export var approach_speed: float = 100.0
@export var flag_shake_duration: float = 1.5
@export var flag_escape_duration: float = 1.5
@export var go_to_rock_duration: float = 2.0
@export var detach_duration: float = 1.5
@export var jump_duration: float = 1.0
@export var tutorial_duration: float = 5.0
@export var buffer_duration: float = 2.0

# === Flappy Bird Settings ===
@export_group("Flappy Gameplay")
@export var flap_impulse: float = -350.0
@export var gravity: float = 800.0
@export var scroll_speed: float = 200.0
@export var parallax_speed: float = 100.0
@export var total_obstacles: int = 10
@export var obstacle_spacing: float = 400.0
@export var obstacle_gap_size: float = 180.0
@export var min_gap_y: float = 150.0
@export var max_gap_y: float = 550.0
@export var screen_width: float = 1920.0
@export var screen_height: float = 1080.0

# === Internal State ===
var state_timer: float = 0.0
var is_flappy_mode: bool = false
var obstacles_passed: int = 0
var finish_flag: Node2D = null

# Animation positions
var flag_start_pos: Vector2
var platform_edge_pos: Vector2
var rock_original_pos: Vector2

# Parallax
var parallax_layers: Array[Node2D] = []

# Kill zones
var kill_zone_top: Area2D = null
var kill_zone_bottom: Area2D = null

# Obstacles
var obstacles: Array[Node2D] = []

@onready var note_sprite: Sprite2D = $Note

@onready var trigger_win: Area2D = $TriggerWin
@onready var win_platform: StaticBody2D = $WinPlatform

# Surprise Trigger Variables
var trigger1: Area2D
var trigger2: Area2D
var trigger3: Area2D

# Surprise Target Variables
var target_it2_area2d2: Area2D
var target_it3_area2d2: Area2D
var target_it5_area2d: Area2D
var target_it5_area2d2: Area2D

var surprise_target_initial_pos: Dictionary = {}

var trigger_win_start_x: float = 0.0
var win_platform_start_x: float = 0.0

func _ready() -> void:
	# FREEZE PLAYERS - They don't control themselves during intro
	player1.set_physics_process(false)
	player2.set_physics_process(false)
	
	# Store original positions
	flag_start_pos = flag.global_position
	if rock:
		rock_original_pos = rock.global_position
		rock.freeze = true  # Freeze rigid body during intro
	
	# Platform edge is to the right
	platform_edge_pos = Vector2(700, 500)  # Adjust based on your scene
	
	# Hide player-to-player chain initially (only rock chain visible)
	if chain:
		chain.visible = false
	
	# Setup camera for intro (zoomed in)
	if camera:
		camera.zoom = Vector2(2.0, 2.0)
		camera.global_position = flag_start_pos
	
	# === BUG FIXES ===
	# 1. Enable Chain Physics (Pico Park Style Constraint)
	if chain and "physics_enabled" in chain:
		chain.physics_enabled = true
		chain.rope_length = 150.0 # Ensure tight constraint
		
	# 2. Fix Invisibility (Remove Shader if it's causing issues)
	player1.material = null
	player2.material = null
	
	# 3. Ensure visual sprites are visible and reset
	player1.modulate.a = 1.0
	player2.modulate.a = 1.0
	player1.visible = true
	player2.visible = true
	
	# NOTE: ObstacleContainer is already in the scene - do NOT create new one
	# Hide obstacle container during intro (show when gameplay starts)
	if obstacle_container:
		obstacle_container.visible = false
	
	# Setup parallax background
	_setup_parallax_background()
	
	# Setup kill zones (for gameplay)
	_setup_kill_zones()
	
	# Collect obstacles ONCE at startup to get correct initial positions
	_collect_scene_obstacles()
	
	# Connect MANUAL Win Nodes
	trigger_win = get_node_or_null("TriggerWin")
	win_platform = get_node_or_null("WinPlatform") 
	
	if trigger_win: trigger_win_start_x = trigger_win.position.x
	if win_platform: win_platform_start_x = win_platform.position.x 
	
	# Setup Surprise Triggers
	_setup_surprise_triggers() 
	
	# Start intro with idle animation
	_play_player_animation(player1, "idle")
	_play_player_animation(player2, "idle")
	
	# Start intro
	current_state = GameState.INTRO_APPROACH
	
	# Start directly at TUTORIAL (Skip Intro)
	current_state = GameState.INTRO_TUTORIAL
	state_timer = tutorial_duration
	
	# Force positions to SPAWN POINT immediately
	var spawn_pos = Vector2(300, screen_height / 2)
	if spawn_point:
		spawn_pos = spawn_point.global_position
	
	player1.global_position = spawn_pos + Vector2(0, -60)
	player2.global_position = spawn_pos + Vector2(0, 60)
	
	# Force Camera
	if camera:
		camera.global_position = Vector2(screen_width / 2, screen_height / 2)
		camera.zoom = Vector2(1.0, 1.0)
	
	# Hide Intro Elements
	if platform: platform.visible = false
	if rock: rock.visible = false
	if rock_chain: rock_chain.visible = false
	
	# Show Player Chain
	if chain:
		chain.visible = true
		chain.modulate.a = 1.0
	
	# DEBUG PLAYER VISIBILITY
	print("DEBUG LEVEL4: P1 GlobalPos: ", player1.global_position, " Vis: ", player1.visible, " Mod: ", player1.modulate)
	if "current_sprite" in player1:
		var s = player1.current_sprite
		if s:
			print("DEBUG LEVEL4: P1 ActiveSprite: ", s.name, " Vis: ", s.visible, " Frame: ", s.frame)
	
	# Show Control Hints
	_show_control_hints()
	
	if ui_label:
		ui_label.text = "Get Ready..."
		
	# COMMENTED OUT ANIMATION CALLS (User Request)
	# _play_player_animation(player1, "idle")
	# _play_player_animation(player2, "idle")

# === PLAYER ANIMATION HELPER ===
func _play_player_animation(player: CharacterBody2D, anim_name: String) -> void:
	# Access player's current_sprite and play animation
	if player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
	# Also try the current_sprite variable if it exists
	if "current_sprite" in player and player.current_sprite:
		player.current_sprite.play(anim_name)

func _setup_parallax_background() -> void:
	# Parallax configured in scene using ParallaxBackground and ParallaxLayer nodes
	# Force settings to ensure it works
	if background_node:
		background_node.scroll_ignore_camera_zoom = true
		background_node.scroll_base_scale = Vector2(1, 1) # Ensure scale is 1
		background_node.scale = Vector2(1, 1) # Ensure Node scale is 1
		print("DEBUG: Parallax Configured. Node: ", background_node)

# Removed _create_cloud_layer as we use scene nodes now

func _setup_kill_zones() -> void:
	# Top kill zone
	kill_zone_top = Area2D.new()
	kill_zone_top.name = "KillZoneTop"
	kill_zone_top.collision_layer = 0
	kill_zone_top.collision_mask = 2
	var shape_top = CollisionShape2D.new()
	var rect_top = RectangleShape2D.new()
	rect_top.size = Vector2(screen_width * 10, 100)
	shape_top.shape = rect_top
	shape_top.position = Vector2(screen_width * 2, -50)
	kill_zone_top.add_child(shape_top)
	add_child(kill_zone_top)
	kill_zone_top.body_entered.connect(_on_kill_zone_entered)
	
	# Bottom kill zone
	kill_zone_bottom = Area2D.new()
	kill_zone_bottom.name = "KillZoneBottom"
	kill_zone_bottom.collision_layer = 0
	kill_zone_bottom.collision_mask = 2
	var shape_bottom = CollisionShape2D.new()
	var rect_bottom = RectangleShape2D.new()
	rect_bottom.size = Vector2(screen_width * 10, 100)
	shape_bottom.shape = rect_bottom
	shape_bottom.position = Vector2(screen_width * 2, screen_height + 50)
	kill_zone_bottom.add_child(shape_bottom)
	add_child(kill_zone_bottom)
	kill_zone_bottom.body_entered.connect(_on_kill_zone_entered)

func _physics_process(delta: float) -> void:
	match current_state:
		GameState.INTRO_APPROACH:
			_process_approach(delta)
		GameState.INTRO_FLAG_SHAKE:
			_process_flag_shake(delta)
		GameState.INTRO_FLAG_ESCAPE:
			_process_flag_escape(delta)
		GameState.INTRO_GO_TO_ROCK:
			_process_go_to_rock(delta)
		GameState.INTRO_DETACH:
			_process_detach(delta)
		GameState.INTRO_JUMP:
			_process_jump(delta)
		GameState.INTRO_TUTORIAL:
			_process_tutorial(delta)
		GameState.INTRO_BUFFER:
			_process_buffer(delta)
		GameState.PLAYING:
			_process_playing(delta)
		GameState.GAME_OVER:
			pass
		GameState.COMPLETE:
			pass

# =====================
# INTRO STATE 1: APPROACH
# =====================
func _process_approach(delta: float) -> void:
	# Move players + rock toward flag
	var target_x = flag_start_pos.x - 150  # Stop before flag
	
	# Move players and play RUN animation
	if player1.global_position.x < target_x:
		player1.global_position.x += approach_speed * delta
		player2.global_position.x += approach_speed * delta
		if rock:
			rock.global_position.x += approach_speed * delta
		
		# Play run animation
		_play_player_animation(player1, "run")
		_play_player_animation(player2, "run")
	else:
		# Reached flag area - start shake
		_start_flag_shake()
	
	# Camera follows players
	if camera:
		var center = (player1.global_position + player2.global_position) / 2
		camera.global_position = camera.global_position.lerp(center, 3 * delta)

func _start_flag_shake() -> void:
	current_state = GameState.INTRO_FLAG_SHAKE
	state_timer = flag_shake_duration
	
	# Players stop and look at flag (idle)
	_play_player_animation(player1, "idle")
	_play_player_animation(player2, "idle")
	
	if ui_label:
		ui_label.text = "...?!"

# =====================
# INTRO STATE 2: FLAG SHAKE
# =====================
func _process_flag_shake(delta: float) -> void:
	state_timer -= delta
	
	# Shake the flag
	var shake_offset = Vector2(
		sin(Time.get_ticks_msec() * 0.05) * 5,
		cos(Time.get_ticks_msec() * 0.07) * 3
	)
	flag.global_position = flag_start_pos + shake_offset
	
	if state_timer <= 0:
		_start_flag_escape()

func _start_flag_escape() -> void:
	current_state = GameState.INTRO_FLAG_ESCAPE
	state_timer = flag_escape_duration
	
	if ui_label:
		ui_label.text = "The flag is escaping!"
	
	# Flag flies away to the right
	var tween = create_tween()
	tween.tween_property(flag, "global_position:x", flag_start_pos.x + 3000, 1.2)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_IN)

# =====================
# INTRO STATE 3: FLAG ESCAPE
# =====================
func _process_flag_escape(delta: float) -> void:
	state_timer -= delta
	
	# Camera stays on players
	if camera:
		var center = (player1.global_position + player2.global_position) / 2
		camera.global_position = camera.global_position.lerp(center, 3 * delta)
	
	if state_timer <= 0:
		_start_go_to_rock()

func _start_go_to_rock() -> void:
	current_state = GameState.INTRO_GO_TO_ROCK
	state_timer = go_to_rock_duration
	
	# Players run back (flip direction)
	_play_player_animation(player1, "run")
	_play_player_animation(player2, "run")
	
	if ui_label:
		ui_label.text = "We need to chase it!\nRelease the rock!"

# =====================
# INTRO STATE 4: GO TO ROCK
# =====================
func _process_go_to_rock(delta: float) -> void:
	state_timer -= delta
	
	# Players walk backward toward rock (run animation already playing)
	if rock:
		var rock_x = rock.global_position.x
		if player1.global_position.x > rock_x + 80:
			player1.global_position.x -= approach_speed * 0.8 * delta
			player2.global_position.x -= approach_speed * 0.8 * delta
		else:
			# Reached rock - stop running
			_play_player_animation(player1, "idle")
			_play_player_animation(player2, "idle")
	
	# Camera follows
	if camera:
		var center = (player1.global_position + player2.global_position) / 2
		camera.global_position = camera.global_position.lerp(center, 3 * delta)
	
	if state_timer <= 0:
		_start_detach()

func _start_detach() -> void:
	current_state = GameState.INTRO_DETACH
	state_timer = detach_duration
	
	if ui_label:
		ui_label.text = "Releasing chain..."
	
	# Hide rock chain with fade
	if rock_chain:
		var tween = create_tween()
		tween.tween_property(rock_chain, "modulate:a", 0.0, 0.8)
		tween.tween_callback(func(): rock_chain.visible = false)
	
	# Rock falls away
	if rock:
		rock.freeze = false
		rock.gravity_scale = 3.0
		var tween = create_tween()
		tween.tween_property(rock, "modulate:a", 0.0, 1.0)

# =====================
# INTRO STATE 5: DETACH
# =====================
func _process_detach(delta: float) -> void:
	state_timer -= delta
	
	# Camera follows players
	if camera:
		var center = (player1.global_position + player2.global_position) / 2
		camera.global_position = camera.global_position.lerp(center, 3 * delta)
	
	if state_timer <= 0:
		_start_jump()

func _start_jump() -> void:
	current_state = GameState.INTRO_JUMP
	state_timer = jump_duration
	
	# Show player-to-player chain
	if chain:
		chain.visible = true
		chain.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(chain, "modulate:a", 1.0, 0.5)
	
	if ui_label:
		ui_label.text = "JUMP!"
	
	# Play JUMP animation
	_play_player_animation(player1, "jump")
	_play_player_animation(player2, "jump")
	
	# Animate players jumping off platform
	var jump_target_y = screen_height / 2
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Players jump forward and up
	tween.tween_property(player1, "global_position", Vector2(300, jump_target_y - 50), jump_duration)
	tween.tween_property(player2, "global_position", Vector2(300, jump_target_y + 50), jump_duration)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

# =====================
# INTRO STATE 6: JUMP
# =====================
func _process_jump(delta: float) -> void:
	state_timer -= delta
	
	# Zoom out camera during jump
	if camera:
		camera.zoom = camera.zoom.lerp(Vector2(1.0, 1.0), 2 * delta)
		camera.global_position = camera.global_position.lerp(Vector2(screen_width / 2, screen_height / 2), 2 * delta)
	
	if state_timer <= 0:
		_start_tutorial()

func _start_tutorial() -> void:
	current_state = GameState.INTRO_TUTORIAL
	state_timer = tutorial_duration
	
	# Ensure camera is positioned correctly
	if camera:
		camera.zoom = Vector2(1.0, 1.0)
		camera.global_position = Vector2(screen_width / 2, screen_height / 2)
	
	# HIDE PLATFORM - We're in the sky now (Flappy Bird mode)
	if platform:
		var tween = create_tween()
		tween.tween_property(platform, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): platform.visible = false)
	
	# Keep jump animation (players are flying)
	_play_player_animation(player1, "jump")
	_play_player_animation(player2, "jump")
	
	# Position players at SPAWN POINT
	var spawn_pos = Vector2(300, screen_height / 2)
	if spawn_point:
		spawn_pos = spawn_point.global_position
		
	player1.global_position = spawn_pos + Vector2(0, -60)
	player2.global_position = spawn_pos + Vector2(0, 60)
	
	# Show control hints
	_show_control_hints()
	
	if ui_label:
		ui_label.text = "Learn to FLY!"

func _show_control_hints() -> void:
	if note_sprite:
		note_sprite.visible = true
		note_sprite.scale = Vector2.ZERO # Start small
		
		# Entrance Animation (Pop up)
		var tween = create_tween()
		tween.tween_property(note_sprite, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# =====================
# INTRO STATE 7: TUTORIAL (5 seconds)
# =====================
func _process_tutorial(delta: float) -> void:
	state_timer -= delta
	
	# Players bob/float gently
	var bob = sin(Time.get_ticks_msec() * 0.003) * 15
	player1.global_position.y = screen_height / 2 - 60 + bob
	player2.global_position.y = screen_height / 2 + 60 + bob
	
	# Update UI with countdown
	if ui_label:
		var seconds_left = int(state_timer) + 1
		ui_label.text = "Get ready... %d" % seconds_left
	
	# Scroll parallax background slightly
	_update_parallax(delta * 0.5)
	
	if state_timer <= 0:
		_start_buffer()

func _start_buffer() -> void:
	current_state = GameState.INTRO_BUFFER
	# Buffer after OUT animation (0.5s anim + 2.0s buffer)
	state_timer = 0.5 + 2.0
	
	if ui_label:
		ui_label.text = "HERE WE GO!"
		
	# Exit Animation for Note
	if note_sprite:
		var tween = create_tween()
		tween.tween_property(note_sprite, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): note_sprite.visible = false)

# =====================
# INTRO STATE 8: BUFFER (2 seconds)
# =====================
func _process_buffer(delta: float) -> void:
	state_timer -= delta
	
	# Players still float
	var bob = sin(Time.get_ticks_msec() * 0.003) * 10
	player1.global_position.y = screen_height / 2 - 50 + bob
	player2.global_position.y = screen_height / 2 + 50 + bob
	
	# Slow parallax
	_update_parallax(delta * 0.3)
	
	if state_timer <= 0:
		_start_playing()

func _start_playing() -> void:
	current_state = GameState.PLAYING
	is_flappy_mode = true
	obstacles_passed = 0
	
	# Force visibility (Z-Index handled by ParallaxBackground layer -100)
	player1.visible = true
	player2.visible = true
	
	# Hide control hints
	# Hide control hints
	if note_sprite:
		note_sprite.visible = false
	
	if ui_label:
		ui_label.text = "FLY!"
	
	# Keep jump animation - players are flying!
	_play_player_animation(player1, "jump")
	_play_player_animation(player2, "jump")
	
	# Position players (same X, different Y)
	var start_x = 300.0
	if spawn_point:
		start_x = spawn_point.global_position.x
		
	player1.global_position = Vector2(start_x, screen_height / 2 - 50)
	player2.global_position = Vector2(start_x, screen_height / 2 + 50)
	
	# Force Camera Position (in case tutorial was skipped/bugged)
	if camera:
		camera.global_position = Vector2(screen_width / 2, screen_height / 2)
		camera.zoom = Vector2(1.0, 1.0)
	
	print("DEBUG: Force Set Position: P1 ", player1.global_position)
	
	# Reset manual velocity tracking for tap-to-fly
	p1_velocity_y = 0.0
	p2_velocity_y = 0.0
	
	# SHOW OBSTACLE CONTAINER (already exists in scene)
	if obstacle_container:
		obstacle_container.visible = true
		obstacle_container.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(obstacle_container, "modulate:a", 1.0, 0.5)
	
	# Ensure finish flag is set up
	_ensure_finish_flag()

# =====================
# GAMEPLAY
# =====================

# =====================
# GAMEPLAY
# =====================

# Store initial positions of obstacles for resetting
var obstacle_initial_positions: Dictionary = {}

func _collect_scene_obstacles() -> void:
	obstacles.clear()
	obstacle_initial_positions.clear()
	
	if obstacle_container:
		for child in obstacle_container.get_children():
			if child is Node2D:
				obstacles.append(child)
				obstacle_initial_positions[child] = child.position
				
				# Ensure Area2D children can detect players (Layer 2)
				for subchild in child.get_children():
					if subchild is Area2D:
						# Add Layer 2 to mask so it detects Players
						subchild.collision_mask |= 2
						subchild.monitoring = true


# Remove dynamic spawning functions since we use scene obstacles
# func _spawn_all_obstacles() ... DELETED
# func _spawn_finish_flag() ... DELETED (assuming finish flag is also in scene or we keep it simple)

# Check if finish flag exists in scene, if not create it
# Check if finish flag exists in scene, if not create it
func _ensure_finish_flag() -> void:
	# Use the existing Flag node from intro if available
	if flag and obstacle_container:
		finish_flag = flag
		
		# Reparent to ObstacleContainer so it scrolls with them
		if flag.get_parent() != obstacle_container:
			flag.get_parent().remove_child(flag)
			obstacle_container.add_child(flag)
		
		# Find FlagPoint marker
		if flag_point:
			flag.position = flag_point.position
			print("DEBUG: Flag placed at FlagPoint: ", flag.position)
		# Reset scale/rotation if needed
		flag.scale = Vector2(1, 1)
		flag.rotation = 0
		flag.visible = true
		flag.modulate.a = 1.0
		
		# Add trigger if not present
		if not finish_flag.has_node("WinTrigger"):
			var trigger = Area2D.new()
			trigger.name = "WinTrigger"
			trigger.collision_layer = 0
			trigger.collision_mask = 2
			var shape = CollisionShape2D.new()
			var rect = RectangleShape2D.new()
			rect.size = Vector2(200, 800) # Big trigger area
			shape.shape = rect
			trigger.add_child(shape)
			finish_flag.add_child(trigger)
			trigger.body_entered.connect(_on_finish_reached)
		return

	# Fallback (should not happen if Flag exists in scene)
	if has_node("FinishFlag"):
		finish_flag = $FinishFlag
		return



# Removed _create_obstacle_pair and _add_pipe_segment as requested

# Removed _add_pipe_segment as requested

func _process_playing(delta: float) -> void:
	# TAP-TO-FLY PHYSICS (manual position-based, not using move_and_slide)
	_apply_tap_to_fly_physics(delta)
	
	# Handle flap input
	_handle_flap_input()
	
	# Lock X position (both players stay at same X)
	player1.global_position.x = 300
	player2.global_position.x = 300
	
	# Clamp Y - Allow hitting top ceiling (bounce?), but ALLOW falling off bottom (death)
	# Only clamp top
	if player1.global_position.y < 50: player1.global_position.y = 50
	if player2.global_position.y < 50: player2.global_position.y = 50
	
	# Scroll obstacles
	_update_obstacles(delta)
	
	# Parallax
	_update_parallax(delta)
	
	# Collision check
	_check_obstacle_collisions_area()
	
	# UI
	_update_progress_ui()

# Store vertical velocity for each player (manual tracking)
var p1_velocity_y: float = 0.0
var p2_velocity_y: float = 0.0

func _apply_tap_to_fly_physics(delta: float) -> void:
	# FORCE X POSITION (Prevent Drift)
	var target_x = 300.0
	if spawn_point: target_x = spawn_point.global_position.x
	player1.global_position.x = target_x
	player2.global_position.x = target_x

	# Apply gravity to internal velocity variables
	p1_velocity_y += gravity * delta
	p2_velocity_y += gravity * delta
	
	# Clamp max fall speed
	p1_velocity_y = min(p1_velocity_y, 600)
	p2_velocity_y = min(p2_velocity_y, 600)
	
	# Transfer to Player Velocity for Physics Engine
	player1.velocity = Vector2(0, p1_velocity_y)
	player2.velocity = Vector2(0, p2_velocity_y)
	
	# Move using Engine (Allows Chain to affect them)
	player1.move_and_slide()
	player2.move_and_slide()
	
	# Read back velocity (in case collision/chain affected it)
	if is_instance_valid(player1): p1_velocity_y = player1.velocity.y
	if is_instance_valid(player2): p2_velocity_y = player2.velocity.y
	
	# DEBUG: Check P2 Velocity
	if abs(p2_velocity_y) > 10.0 and Engine.get_physics_frames() % 60 == 0:
		print("DEBUG P2 VEL: ", p2_velocity_y)

var _p1_flap_held: bool = false
var _p2_flap_held: bool = false

func _handle_flap_input() -> void:
	# Player 1: W key = FLY UP
	if _is_flap_just_pressed_p1():
		p1_velocity_y = flap_impulse  # Negative = go UP
		print("P1 FLAP!")
	
	# Player 2: UP Arrow = FLY UP
	if _is_flap_just_pressed_p2():
		p2_velocity_y = flap_impulse
		print("P2 FLAP!")

func _is_flap_just_pressed_p1() -> bool:
	var pressed = Input.is_key_pressed(KEY_W)
	if pressed and not _p1_flap_held:
		_p1_flap_held = true
		return true
	elif not pressed:
		_p1_flap_held = false
	return false

func _is_flap_just_pressed_p2() -> bool:
	var pressed = Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_UP)
	if pressed and not _p2_flap_held:
		_p2_flap_held = true
		print("DEBUG: P2 Input DETECTED!") 
		return true
	elif not pressed:
		_p2_flap_held = false
	return false

func _update_obstacles(delta: float) -> void:
	for obstacle in obstacles:
		obstacle.global_position.x -= scroll_speed * delta
	
	if finish_flag:
		finish_flag.global_position.x -= scroll_speed * delta
	
	# Manual Scroll for Win Nodes
	if trigger_win: trigger_win.global_position.x -= scroll_speed * delta
	if win_platform: win_platform.global_position.x -= scroll_speed * delta
	
	# Manual Scroll for Surprise Triggers
	if trigger1: trigger1.global_position.x -= scroll_speed * delta
	if trigger2: trigger2.global_position.x -= scroll_speed * delta
	if trigger3: trigger3.global_position.x -= scroll_speed * delta
	
	var passed = 0
	for obstacle in obstacles:
		if obstacle.global_position.x < 200:
			passed += 1
	obstacles_passed = passed

func _update_parallax(delta: float) -> void:
	# Update scroll_base_offset of ParallaxBackground (scroll_offset is overridden by Camera)
	if background_node:
		background_node.scroll_base_offset.x -= parallax_speed * delta * 2.0
		# DEBUG PARALLAX (Once per sec)
		if Engine.get_physics_frames() % 60 == 0:
			print("DEBUG PARALLAX: Base Offset X: ", background_node.scroll_base_offset.x)

func _update_progress_ui() -> void:
	if ui_label:
		ui_label.text = "Obstacles: %d / %d" % [obstacles_passed, total_obstacles]

# Area-based collision detection (since we're not using move_and_slide)
func _check_obstacle_collisions_area() -> void:
	# Check if players are overlapping any obstacle areas
	for obstacle in obstacles:
		# Check all children (Area2D)
		for child in obstacle.get_children():
			if child is Area2D:
				if child.overlaps_body(player1):
					_on_kill_zone_entered(player1)
					return
				if child.overlaps_body(player2):
					_on_kill_zone_entered(player2)
					return



# Keep old function for compatibility (unused now)
func _check_obstacle_collisions() -> void:
	pass

func _on_trigger_win_body_entered(body: Node2D) -> void:
	if current_state == GameState.COMPLETE: return
	
	if body == player1 or body == player2:
		print()
		current_state = GameState.COMPLETE
		is_flappy_mode = false
		
		p1_velocity_y = 0
		p2_velocity_y = 0
		player1.velocity = Vector2.ZERO
		player2.velocity = Vector2.ZERO
		
		player1.set_physics_process(true)
		player2.set_physics_process(true)
		
		var jump_force = Vector2(800, -1000)
		player1.velocity = jump_force
		player2.velocity = jump_force

func _on_finish_reached(body: Node2D) -> void:
	if body == player1 or body == player2:
		_on_trigger_win_body_entered(body)

func _complete_level() -> void:
	current_state = GameState.COMPLETE
	is_flappy_mode = false
	if ui_label:
		ui_label.text = "CONGRATULATIONS!\nYou completed Level 4!"

# === SURPRISE MECHANICS ===

func _setup_surprise_triggers() -> void:
	# Get Triggers (Root)
	trigger1 = get_node_or_null("Trigger1")
	trigger2 = get_node_or_null("Trigger2")
	trigger3 = get_node_or_null("Trigger3")
	
	if trigger1: 
		trigger1.body_entered.connect(_on_trigger_1_entered)
		trigger1.collision_mask = 15 # Detect Layers 1-4
		trigger1.monitoring = true
	if trigger2: 
		trigger2.body_entered.connect(_on_trigger_2_entered)
		trigger2.collision_mask = 15
		trigger2.monitoring = true
	if trigger3: 
		trigger3.body_entered.connect(_on_trigger_3_entered)
		trigger3.collision_mask = 15
		trigger3.monitoring = true
	
	# Get Targets (In ObstacleContainer)
	if obstacle_container:
		target_it2_area2d2 = obstacle_container.get_node_or_null("Iteration2/Area2D")
		target_it3_area2d2 = obstacle_container.get_node_or_null("Iteration3/Area2D2")
		target_it5_area2d = obstacle_container.get_node_or_null("Iteration5/Area2D")
		target_it5_area2d2 = obstacle_container.get_node_or_null("Iteration5/Area2D2")
		
		if target_it2_area2d2: surprise_target_initial_pos[target_it2_area2d2] = target_it2_area2d2.position
		if target_it3_area2d2: surprise_target_initial_pos[target_it3_area2d2] = target_it3_area2d2.position
		if target_it5_area2d: surprise_target_initial_pos[target_it5_area2d] = target_it5_area2d.position
		if target_it5_area2d2: surprise_target_initial_pos[target_it5_area2d2] = target_it5_area2d2.position

func _on_trigger_1_entered(body: Node) -> void:
	if (body == player1 or body == player2) and target_it2_area2d2:
		print("trigger1")
		trigger1.set_deferred("monitoring", false)
		var tween = create_tween()
		tween.tween_property(target_it2_area2d2, "global_position:y", target_it2_area2d2.global_position.y + 400, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_trigger_2_entered(body: Node) -> void:
	if (body == player1 or body == player2) and target_it3_area2d2:
		print("trigger2")
		trigger2.set_deferred("monitoring", false)
		var tween = create_tween()
		tween.tween_property(target_it3_area2d2, "global_position:y", target_it3_area2d2.global_position.y - 400, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_trigger_3_entered(body: Node) -> void:
	if (body == player1 or body == player2):
		print("trigger3")
		trigger3.set_deferred("monitoring", false)
		if target_it5_area2d:
			var tween = create_tween()
			tween.tween_property(target_it5_area2d, "global_position:y", target_it5_area2d.global_position.y - 300, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if target_it5_area2d2:
			var tween = create_tween()
			tween.tween_property(target_it5_area2d2, "global_position:y", target_it5_area2d2.global_position.y + 300, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _reset_surprise_obstacles() -> void:
	for target in surprise_target_initial_pos:
		if is_instance_valid(target):
			target.position = surprise_target_initial_pos[target]
			
	_reset_trigger_positions()

func _reset_trigger_positions() -> void:
	if trigger1: 
		trigger1.position.x = 0
		trigger1.monitoring = true
	if trigger2: 
		trigger2.position.x = 0
		trigger2.monitoring = true
	if trigger3: 
		trigger3.position.x = 0
		trigger3.monitoring = true

func _on_kill_zone_entered(body: Node2D) -> void:
	if not is_flappy_mode:
		return
	if body == player1 or body == player2:
		_game_over()

func _game_over() -> void:
	current_state = GameState.GAME_OVER
	is_flappy_mode = false
	
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(_reset_to_buffer)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_reset_to_buffer()

# Respawn starting at the 2-second buffer (skipping tutorial)
func _reset_to_buffer() -> void:
	# Restore obstacles to initial positions
	for obstacle in obstacles:
		if obstacle in obstacle_initial_positions:
			obstacle.position = obstacle_initial_positions[obstacle]
		# Ensure they are visible
		obstacle.visible = true
	
	# Reset finish flag
	_ensure_finish_flag()
	
	# Reset Surprise Obstacles
	_reset_surprise_obstacles()
	
	# Reset Win Nodes
	if trigger_win: trigger_win.position.x = trigger_win_start_x
	if win_platform: win_platform.position.x = win_platform_start_x
	
	# Hide control hints
	if note_sprite:
		note_sprite.visible = false
	
	# Position players for start at SPAWN POINT
	var spawn_pos = Vector2(300, screen_height / 2)
	if spawn_point:
		spawn_pos = spawn_point.global_position
		
	player1.global_position = spawn_pos + Vector2(0, -60)
	player2.global_position = spawn_pos + Vector2(0, 60)
	
	# Force visibility
	player1.visible = true
	player2.visible = true
	
	# Force Chain visibility
	if chain:
		chain.visible = true
		chain.modulate.a = 1.0
	
	# Reset manual velocity tracking
	p1_velocity_y = 0.0
	p2_velocity_y = 0.0
	
	obstacles_passed = 0
	
	# HIDE PLATFORM (ensure it's gone if we reset from start)
	if platform:
		platform.visible = false
	
	# Ensure obstacle container is visible
	if obstacle_container:
		obstacle_container.visible = true
		obstacle_container.modulate.a = 1.0
	
	# Go to BUFFER state (2 seconds before start)
	current_state = GameState.INTRO_BUFFER
	state_timer = buffer_duration
	is_flappy_mode = false 
	
	if ui_label:
		ui_label.text = "TRY AGAIN!"
		
	_play_player_animation(player1, "jump")
	_play_player_animation(player2, "jump")

func _reset_level() -> void:
	_reset_to_buffer()
