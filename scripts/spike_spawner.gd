extends Node2D

var sliding_spike_scene = preload("res://scenes/sliding_spike.tscn")

@export var slide_speed: float = 350.0
@export var spawn_y_offset: float = 15.0  # Offset dari posisi spawner

## Spawn spike yang meluncur ke arah tertentu
## direction: 1 = kanan, -1 = kiri
func spawn_spike(direction: float = 1.0) -> void:
	var spike = sliding_spike_scene.instantiate()
	spike.position = Vector2(0, spawn_y_offset)
	spike.slide_speed = slide_speed
	spike.set_direction(direction)
	add_child(spike)

## Legacy function untuk kompatibilitas
func spawn_spike_force(force: Vector2) -> void:
	# Gunakan arah X dari force untuk menentukan arah slide
	var dir = sign(force.x) if force.x != 0 else 1.0
	spawn_spike(dir)
