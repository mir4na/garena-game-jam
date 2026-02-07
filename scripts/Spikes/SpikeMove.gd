extends RigidBody2D
## SpikeMove - Spike that starts moving when triggered

@export var move_speed: float = 200.0
@export var move_direction: Vector2 = Vector2.RIGHT  # LEFT or RIGHT

var is_moving: bool = false


func _physics_process(delta: float) -> void:
	if is_moving:
		global_position += move_direction.normalized() * move_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not is_moving:
		# Start moving when touched
		is_moving = true
		print("SpikeMove activated!")
## Called by external trigger to start movement
func activate() -> void:
	is_moving = true
	print("SpikeMove activated by trigger!")

## Stop movement
func stop() -> void:
	is_moving = false
