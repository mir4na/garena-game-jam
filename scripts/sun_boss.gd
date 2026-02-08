extends Node2D

## Sun Boss - Bullet Hell Boss untuk Level 5
## Skills: Radial Burst, Spiral Shot, Rain, Sweep, Big Bullets, Homing
## Troll: Fake Death lalu bangkit lagi

signal boss_defeated
signal boss_fake_death
signal boss_revived
signal skill_started(skill_name: String)

@export var bullet_scene: PackedScene
@export var attack_cooldown: float = 3.0
@export var bullet_speed: float = 130.0
@export var radial_bullet_count: int = 8
@export var spiral_arms: int = 2
@export var aimed_warning_time: float = 1.0

@export_group("Big Bullets")
@export var big_bullet_size: float = 4.0
@export var big_bullet_speed: float = 80.0
@export var big_bullet_count: int = 4

@export_group("Homing")
@export var homing_bullet_size: float = 1.4
@export var homing_bullet_speed: float = 140.0
@export var homing_bullet_count: int = 8
@export var homing_turn_strength: float = 5.5

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var flag: Node2D = $Flag if has_node("Flag") else null

# Animated sun sprite (from SunSprite child)
var anim_sprite: AnimatedSprite2D = null

enum Phase { PHASE_1, FAKE_DEATH, PHASE_2, DEFEATED }
var current_phase: Phase = Phase.PHASE_1
var attack_timer: float = 0.0
var spiral_angle: float = 0.0
var is_attacking: bool = false

# Attack pattern rotation (removed: aimed/wave/shotgun/rain/homing)
var attack_patterns: Array = ["radial", "spiral", "sweep", "big"]
var current_pattern_index: int = 0

# Flag rotation
var flag_angle: float = 0.0
var flag_distance: float = 200.0
var flag_speed: float = 1.5

# Players reference (set by Level5)
var player1: Node2D = null
var player2: Node2D = null

func _ready() -> void:
	attack_timer = attack_cooldown
	if not bullet_scene:
		bullet_scene = load("res://scenes/bullet.tscn")
	
	# Hide the old Sprite2D (we use SunSprite's AnimatedSprite2D now)
	if sprite:
		sprite.visible = false
	
	# Find AnimatedSprite2D from SunSprite child
	var sun_sprite = get_node_or_null("SunSprite")
	if sun_sprite:
		anim_sprite = sun_sprite.get_node_or_null("AnimatedSprite2D")
	if anim_sprite:
		anim_sprite.play("default")

func _process(delta: float) -> void:
	if current_phase == Phase.DEFEATED or current_phase == Phase.FAKE_DEATH:
		return
	
	# Rotate flag around sun
	_update_flag_orbit(delta)
	
	# Attack timer
	attack_timer -= delta
	if attack_timer <= 0 and not is_attacking:
		_perform_attack()
		attack_timer = attack_cooldown
		if current_phase == Phase.PHASE_2:
			attack_timer *= 0.7  # Faster in phase 2

## Play angry animation (called when boss fight starts)
func play_angry() -> void:
	if anim_sprite:
		anim_sprite.play("angry")

## Play default/idle animation
func play_idle() -> void:
	if anim_sprite:
		anim_sprite.play("default")

func _update_flag_orbit(delta: float) -> void:
	if not flag:
		return
	
	flag_angle += flag_speed * delta
	var orbit_pos = Vector2(
		cos(flag_angle) * flag_distance,
		sin(flag_angle) * flag_distance
	)
	flag.position = orbit_pos

func _perform_attack() -> void:
	var pattern = attack_patterns[current_pattern_index]
	current_pattern_index = (current_pattern_index + 1) % attack_patterns.size()
	_emit_skill_label(pattern)
	
	match pattern:
		"radial":
			_attack_radial_burst()
		"spiral":
			_attack_spiral()
		"rain":
			_attack_rain()
		"sweep":
			_attack_sweep()
		"big":
			_attack_big_bullets()
		"homing":
			_attack_homing()

func _emit_skill_label(pattern: String) -> void:
	var label := pattern
	match pattern:
		"radial":
			label = "RADIAL BURST"
		"spiral":
			label = "SPIRAL"
		"sweep":
			label = "SWEEP"
		"big":
			label = "BIG BULLETS"
	emit_signal("skill_started", label)

func _attack_radial_burst() -> void:
	# Shoot bullets in all directions
	var count = radial_bullet_count
	if current_phase == Phase.PHASE_2:
		count = int(count * 1.5)
	
	for i in range(count):
		var angle = (TAU / count) * i
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_bullet(global_position, dir, bullet_speed)

func _attack_spiral() -> void:
	# Spawn spiral bullets over time
	is_attacking = true
	var arms = spiral_arms
	var bullets_per_arm = 8
	var delay = 0.1
	
	for b in range(bullets_per_arm):
		await get_tree().create_timer(delay).timeout
		if current_phase == Phase.DEFEATED:
			is_attacking = false
			return
		
		for arm in range(arms):
			var base_angle = (TAU / arms) * arm
			var angle = base_angle + spiral_angle
			var dir = Vector2(cos(angle), sin(angle))
			_spawn_bullet(global_position, dir, bullet_speed * 0.8)
		
		spiral_angle += 0.2
	
	is_attacking = false

func _attack_aimed() -> void:
	# Warning indicator then shoot at players
	is_attacking = true
	
	# Collect player positions
	var targets: Array[Vector2] = []
	if player1 and is_instance_valid(player1):
		targets.append(player1.global_position)
	if player2 and is_instance_valid(player2):
		targets.append(player2.global_position)
	
	# Visual warning (flash)
	if anim_sprite:
		var original_modulate = anim_sprite.modulate
		anim_sprite.modulate = Color.RED
		await get_tree().create_timer(aimed_warning_time).timeout
		anim_sprite.modulate = original_modulate
	else:
		await get_tree().create_timer(aimed_warning_time).timeout
	
	if current_phase == Phase.DEFEATED:
		is_attacking = false
		return
	
	# Shoot at where players WERE (gives them time to dodge)
	for target in targets:
		var dir = (target - global_position).normalized()
		# Shoot 3 bullets in a spread
		for spread in [-0.15, 0, 0.15]:
			var spread_dir = dir.rotated(spread)
			_spawn_bullet(global_position, spread_dir, bullet_speed * 1.3)
	
	is_attacking = false

## NEW: Wave attack - bullets in sine wave pattern
func _attack_wave() -> void:
	is_attacking = true
	var num_waves = 3
	var bullets_per_wave = 8
	var wave_delay = 0.4
	
	for w in range(num_waves):
		await get_tree().create_timer(wave_delay).timeout
		if current_phase == Phase.DEFEATED:
			is_attacking = false
			return
		
		# Spawn bullets going left and right with wave motion
		for i in range(bullets_per_wave):
			var y_offset = (i - bullets_per_wave / 2.0) * 60
			var spawn_pos = global_position + Vector2(0, y_offset)
			
			# Left wave
			_spawn_bullet(spawn_pos, Vector2(-1, sin(i * 0.5) * 0.3).normalized(), bullet_speed * 0.9)
			# Right wave  
			_spawn_bullet(spawn_pos, Vector2(1, sin(i * 0.5) * 0.3).normalized(), bullet_speed * 0.9)
	
	is_attacking = false

## NEW: Rain attack - bullets falling from top
func _attack_rain() -> void:
	is_attacking = true
	var drops = 15
	var drop_delay = 0.08
	
	for d in range(drops):
		await get_tree().create_timer(drop_delay).timeout
		if current_phase == Phase.DEFEATED:
			is_attacking = false
			return
		
		# Random x position across arena
		var spawn_x = randf_range(100, 1820)
		var spawn_pos = Vector2(spawn_x, 50)
		var dir = Vector2(randf_range(-0.1, 0.1), 1).normalized()
		_spawn_bullet(spawn_pos, dir, bullet_speed * 1.2)
	
	is_attacking = false

## NEW: Shotgun burst - concentrated spread at one player
func _attack_shotgun() -> void:
	is_attacking = true
	
	# Pick random target player
	var target: Node2D = null
	if player1 and player2:
		target = player1 if randf() > 0.5 else player2
	elif player1:
		target = player1
	elif player2:
		target = player2
	
	if not target or not is_instance_valid(target):
		is_attacking = false
		return
	
	# Warning flash
	if anim_sprite:
		anim_sprite.modulate = Color.YELLOW
		await get_tree().create_timer(0.5).timeout
		anim_sprite.modulate = Color.WHITE
	
	if current_phase == Phase.DEFEATED:
		is_attacking = false
		return
	
	# Shotgun spread - many bullets in tight cone
	var base_dir = (target.global_position - global_position).normalized()
	var num_pellets = 12
	var spread_angle = 0.5  # About 30 degrees total
	
	for i in range(num_pellets):
		var angle_offset = (i / float(num_pellets - 1) - 0.5) * spread_angle
		var dir = base_dir.rotated(angle_offset)
		var speed_variance = randf_range(0.9, 1.1)
		_spawn_bullet(global_position, dir, bullet_speed * 1.4 * speed_variance)
	
	is_attacking = false

## NEW: Sweep attack - line of bullets sweeping across arena, aimed at player
func _attack_sweep() -> void:
	is_attacking = true
	var sweep_steps = 16
	var sweep_delay = 0.08
	
	# Get direction toward player
	var target: Node2D = _get_random_player()
	var base_dir := Vector2.DOWN
	if target and is_instance_valid(target):
		base_dir = (target.global_position - global_position).normalized()
	
	for s in range(sweep_steps):
		await get_tree().create_timer(sweep_delay).timeout
		if current_phase == Phase.DEFEATED:
			is_attacking = false
			return
		
		# Calculate angle sweeping from one side to the other of base_dir
		var start_angle = -PI / 3  # Sweep 60 degrees left
		var end_angle = PI / 3     # Sweep 60 degrees right
		var progress = s / float(sweep_steps - 1)
		
		var angle = lerp(start_angle, end_angle, progress)
		var dir = base_dir.rotated(angle)
		
		# Shoot 3 parallel bullets
		for offset in [-30, 0, 30]:
			var offset_vec = dir.orthogonal() * offset
			_spawn_bullet(global_position + offset_vec, dir, bullet_speed)
	
	is_attacking = false

## NEW: Big bullets - slow, large hitbox projectiles aimed at player
func _attack_big_bullets() -> void:
	# Big bullets feel like "oh no" moment; fewer but harder to dodge
	var count := big_bullet_count
	if current_phase == Phase.PHASE_2:
		count = int(count * 1.3)
	
	# Get target player
	var target: Node2D = _get_random_player()
	var base_angle := 0.0
	if target and is_instance_valid(target):
		base_angle = (target.global_position - global_position).angle()
	
	for i in range(count):
		# Spread bullets in a cone toward player
		var angle_offset = (i - count / 2.0) * (PI / 8) / count
		var angle = base_angle + angle_offset
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_bullet(global_position, dir, big_bullet_speed, big_bullet_size)

## Get random valid player target
func _get_random_player() -> Node2D:
	var valid_targets: Array = []
	if player1 and is_instance_valid(player1):
		valid_targets.append(player1)
	if player2 and is_instance_valid(player2):
		valid_targets.append(player2)
	if valid_targets.is_empty():
		return null
	return valid_targets[randi() % valid_targets.size()]

## NEW: Homing bullets - chase the nearest player
func _attack_homing() -> void:
	is_attacking = true
	var count := homing_bullet_count
	if current_phase == Phase.PHASE_2:
		count = int(count * 1.25)
	
	for i in range(count):
		var angle = (TAU / count) * i
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_bullet(global_position, dir, homing_bullet_speed, homing_bullet_size, true)
	
	is_attacking = false

func _spawn_bullet(pos: Vector2, dir: Vector2, spd: float, size_mult: float = 1.0, homing: bool = false) -> void:
	if not bullet_scene:
		return
	var bullet = bullet_scene.instantiate()
	bullet.global_position = pos
	if homing:
		bullet.setup(dir, spd, size_mult, true, homing_turn_strength)
	else:
		bullet.setup(dir, spd, size_mult)
	get_parent().add_child(bullet)

## Called by Level5 when survival time for phase 1 ends
func trigger_fake_death() -> void:
	current_phase = Phase.FAKE_DEATH
	is_attacking = false
	
	# Play death animation
	if anim_sprite:
		anim_sprite.play("death")
		# Fade out effect
		var tween = create_tween()
		tween.tween_property(anim_sprite, "modulate:a", 0.3, 1.0)
		tween.tween_callback(_on_fake_death_visual_done)
	else:
		_on_fake_death_visual_done()
	
	emit_signal("boss_fake_death")

func _on_fake_death_visual_done() -> void:
	# Flag starts falling... (handled by Level5)
	pass

## Called by Level5 after fake death delay
func trigger_revive() -> void:
	current_phase = Phase.PHASE_2
	
	# Play laugh animation (troll!)
	if anim_sprite:
		anim_sprite.play("laugh")
		# Fade back in and scale effect
		var tween = create_tween()
		tween.tween_property(anim_sprite, "modulate:a", 1.0, 0.3)
		tween.tween_property(anim_sprite, "scale", Vector2(1.3, 1.3), 0.2)
		tween.tween_property(anim_sprite, "scale", Vector2(1.0, 1.0), 0.2)
	
	# After laugh, switch to angry
	await get_tree().create_timer(2.0).timeout
	if anim_sprite and current_phase == Phase.PHASE_2:
		anim_sprite.play("angry")
	
	# Burst attack on revive!
	_attack_radial_burst()
	_attack_radial_burst()  # Double burst for surprise
	
	emit_signal("boss_revived")

## Called by Level5 when truly defeated
func trigger_real_death() -> void:
	current_phase = Phase.DEFEATED
	is_attacking = false
	
	# Stop flag orbit
	flag_speed = 0
	
	# Play death animation
	if anim_sprite:
		anim_sprite.play("death")
		var tween = create_tween()
		tween.tween_property(anim_sprite, "modulate", Color(0.5, 0.5, 0.5, 0.5), 1.5)
	
	emit_signal("boss_defeated")

func set_players(p1: Node2D, p2: Node2D) -> void:
	player1 = p1
	player2 = p2
