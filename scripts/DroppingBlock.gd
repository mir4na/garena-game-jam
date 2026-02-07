extends StaticBody2D

## DroppingBlock - Block that falls after player triggers it

@export var drop_delay: float = 0.5  # Time before falling
@export var drop_speed: float = 800.0  # Fall speed
@export var shake_amount: float = 3.0  # Shake before falling
@export var respawn_time: float = 3.0  # Time before respawning (0 = no respawn)

var original_position: Vector2
var is_triggered: bool = false
var is_falling: bool = false
var is_gone: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var trigger_area: Area2D = $TriggerArea

func _ready() -> void:
	original_position = global_position

func _physics_process(delta: float) -> void:
	if is_falling and not is_gone:
		# Move down at high speed
		global_position.y += drop_speed * delta
		
		# Check if fallen too far (off screen) - then respawn or destroy
		if global_position.y > original_position.y + 1000:
			_on_fallen()

func _on_trigger_body_entered(body: Node2D) -> void:
	if is_triggered or is_gone:
		return
	
	if body.is_in_group("player") or body.name.begins_with("Player"):
		is_triggered = true
		_start_drop_sequence()

func _start_drop_sequence() -> void:
	# Shake effect before dropping
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
	# Disable trigger so it doesn't keep triggering
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
