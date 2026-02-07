extends Node2D

## Level 3 - Trolling flag level
## Flag di ujung kanan, ketika player mendekat platform membawa flag naik ke kiri atas
## Dunia miring kanan. Lalu ketika miring kiri, flag pindah ke kanan (troll)

@export var tilt_right_time: float = 12.0  # Durasi miring kanan
@export var tilt_left_time: float = 12.0  # Durasi miring kiri
@export var tilt_angle_deg: float = 10.0
@export var tilt_speed: float = 3.0  # Kecepatan rotasi ground
@export var flag_move_duration: float = 1.5  # Durasi animasi flag bergerak

@onready var player1: CharacterBody2D = $Player1
@onready var player2: CharacterBody2D = $Player2
@onready var rock: RigidBody2D = $Rock
@onready var ground: Node2D = $Ground
@onready var spike_spawner: Node2D = $Ground/SpikeSpawner
@onready var spike_spawner_2: Node2D = $Ground/SpikeSpawner2

# Flag platform
@onready var flag_platform: Node2D = $FlagPlatform if has_node("FlagPlatform") else null

@onready var timer_label: Label = $UI/TimerLabel if has_node("UI/TimerLabel") else null
@onready var instruction_label: Label = $UI/InstructionLabel if has_node("UI/InstructionLabel") else null

enum Phase { WAITING, TILT_RIGHT, TILT_LEFT, COMPLETE }
var current_phase: Phase = Phase.WAITING
var phase_timer: float = 0.0
var target_rotation: float = 0.0

# Flag positions
var flag_start_pos: Vector2  # Posisi awal (kanan bawah)
var flag_left_pos: Vector2   # Posisi kiri atas saat tilt right
var flag_right_pos: Vector2  # Posisi kanan atas saat tilt left (troll)

# Spawn positions for reset
var player1_spawn: Vector2
var player2_spawn: Vector2
var rock_spawn: Vector2

func _ready() -> void:
	current_phase = Phase.WAITING
	target_rotation = 0.0
	
	# Store spawn positions
	player1_spawn = player1.global_position
	player2_spawn = player2.global_position
	rock_spawn = rock.global_position
	
	# Setup flag positions
	if flag_platform:
		flag_start_pos = flag_platform.global_position
		flag_left_pos = Vector2(200, 300)   # Kiri atas
		flag_right_pos = Vector2(1700, 300)  # Kanan atas (troll)
	
	# Ground mulai datar
	if ground:
		ground.rotation = 0.0
	
	if instruction_label:
		instruction_label.text = "Ambil flag di ujung kanan!"
	if timer_label:
		timer_label.text = ""

func _process(delta: float) -> void:
	phase_timer -= delta
	
	match current_phase:
		Phase.WAITING:
			# Menunggu player mendekati flag
			if timer_label:
				timer_label.text = ""
		
		Phase.TILT_RIGHT:
			if timer_label:
				timer_label.text = "SURVIVE: %.1f" % max(0, phase_timer)
			if phase_timer <= 0:
				_start_tilt_left()
		
		Phase.TILT_LEFT:
			if timer_label:
				timer_label.text = "SURVIVE: %.1f" % max(0, phase_timer)
			if phase_timer <= 0:
				_complete_level()
		
		Phase.COMPLETE:
			pass
	
	# Smooth rotate ground ke target
	if ground:
		ground.rotation = lerp(ground.rotation, target_rotation, tilt_speed * delta)

## Dipanggil ketika player mendekati flag (dari FlagTrigger area)
func on_player_near_flag() -> void:
	if current_phase != Phase.WAITING:
		return
	_start_tilt_right()

func _start_tilt_right() -> void:
	current_phase = Phase.TILT_RIGHT
	phase_timer = tilt_right_time
	target_rotation = deg_to_rad(tilt_angle_deg)  # Miring kanan (positif)
	
	# Animasi flag naik ke kiri atas
	_move_flag_to_left()
	
	if instruction_label:
		instruction_label.text = "HAH?! Flag kabur!\nDunia MIRING KANAN!\nLARI KE KIRI!"
	_spawn_spikes_from_left()
func _start_tilt_left() -> void:
	current_phase = Phase.TILT_LEFT
	phase_timer = tilt_left_time
	target_rotation = deg_to_rad(-tilt_angle_deg)  # Miring kiri (negatif)
	
	# Animasi flag pindah ke kanan (TROLL!)
	_move_flag_to_right()
	
	_spawn_spikes_from_right()
		
	if instruction_label:
		instruction_label.text = "LAGI?! Flag ke KANAN!\nDunia MIRING KIRI!\nLARI KE KANAN!"

## Animasi flag bergerak ke kiri atas
func _move_flag_to_left() -> void:
	if not flag_platform:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(flag_platform, "global_position", flag_left_pos, flag_move_duration)

## Animasi flag bergerak ke kanan (troll)
func _move_flag_to_right() -> void:
	if not flag_platform:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(flag_platform, "global_position", flag_right_pos, flag_move_duration)

## Spawn spikes dari kiri yang slide ke kanan
func _spawn_spikes_from_left() -> void:
	for i in range(5):
		await get_tree().create_timer(2.0).timeout
		if current_phase == Phase.TILT_RIGHT and spike_spawner:
			spike_spawner.spawn_spike(1.0)  # Slide ke kanan

## Spawn spikes dari kanan yang slide ke kiri
func _spawn_spikes_from_right() -> void:
	for i in range(5):
		await get_tree().create_timer(2.0).timeout
		if current_phase == Phase.TILT_LEFT and spike_spawner_2:
			spike_spawner_2.spawn_spike(-1.0)  # Slide ke kiri

func _complete_level() -> void:
	current_phase = Phase.COMPLETE
	target_rotation = 0.0
	
	if instruction_label:
		instruction_label.text = "SELAMAT!\nKamu bertahan hidup!"
	if timer_label:
		timer_label.text = "COMPLETE!"
	
	# Stop rock
	if rock:
		rock.linear_velocity = Vector2.ZERO
		rock.angular_velocity = 0.0


func _reset_level() -> void:
	# Reset positions
	player1.global_position = player1_spawn
	player2.global_position = player2_spawn
	player1.velocity = Vector2.ZERO
	player2.velocity = Vector2.ZERO
	
	rock.global_position = rock_spawn
	rock.linear_velocity = Vector2.ZERO
	rock.angular_velocity = 0.0
	
	# Reset flag
	if flag_platform:
		flag_platform.global_position = flag_start_pos
	
	# Reset phase
	current_phase = Phase.WAITING
	phase_timer = 0.0
	target_rotation = 0.0
	if ground:
		ground.rotation = 0.0
	
	if instruction_label:
		instruction_label.text = "Ambil flag di ujung kanan!"

func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_reset_level()
