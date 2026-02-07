extends Area2D

## Spike that can extend its tip upward

@onready var visual: Sprite2D = $SpikeSprite
@onready var collision: CollisionShape2D = $CollisionShape2D

var original_collision_size: Vector2
var is_extended: bool = false

func _ready():
	original_collision_size = collision.shape.size


func _on_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()
