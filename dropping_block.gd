extends StaticBody2D

## DroppingBlock - Block jatuh setelah player trigger, dengan delay dan shake effect

@export var drop_delay: float = 0.5  # Waktu tunggu sebelum jatuh
@export var drop_speed: float = 800.0  # Kecepatan jatuh
@export var shake_amount: float = 3.0  # Intensitas shake
@export var respawn_time: float = 3.0  # Waktu respawn (0 = tidak respawn)

var original_position: Vector2
var is_triggered: bool = false
var is_falling: bool = false
var is_gone: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trigger_area: Area2D = $Area2D

func _ready() -> void:
	original_position = global_position

func _physics_process(delta: float) -> void:
	if is_falling and not is_gone:
		# Jatuh dengan kecepatan tinggi
		global_position.y += drop_speed * delta
		
		# Cek kalau sudah jatuh terlalu jauh
		if global_position.y > original_position.y + 1000:
			_on_fallen()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if is_triggered or is_gone:
		return
	
	if body.is_in_group("player") or body.name.begins_with("Player"):
		is_triggered = true
		_start_drop_sequence()

func _start_drop_sequence() -> void:
	# Shake effect sebelum jatuh
	var tween = create_tween()
	var shake_duration = drop_delay
	var shake_interval = 0.05
	var num_shakes = int(shake_duration / shake_interval)
	
	for i in range(num_shakes):
		var offset = Vector2(randf_range(-shake_amount, shake_amount), 0)
		tween.tween_property(self, "position", original_position + offset, shake_interval / 2)
		tween.tween_property(self, "position", original_position, shake_interval / 2)
	
	tween.tween_callback(_start_falling)

func _start_falling() -> void:
	is_falling = true
	# Disable trigger supaya tidak trigger lagi
	trigger_area.set_deferred("monitoring", false)

func _on_fallen() -> void:
	is_gone = true
	is_falling = false
	visible = false
	collision_shape.set_deferred("disabled", true)
	
	if respawn_time > 0:
		await get_tree().create_timer(respawn_time).timeout
		_respawn()
	else:
		queue_free()

func _respawn() -> void:
	global_position = original_position
	is_triggered = false
	is_falling = false
	is_gone = false
	visible = true
	collision_shape.set_deferred("disabled", false)
	trigger_area.set_deferred("monitoring", true)
