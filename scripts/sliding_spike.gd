extends Area2D

## Spike yang meluncur smooth di lantai

@export var slide_speed: float = 300.0
@export var slide_direction: float = 1.0  # 1 = kanan, -1 = kiri
@export var lifetime: float = 10.0

var time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Slide horizontally
	position.x += slide_direction * slide_speed * delta
	
	# Lifetime check
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()

func set_direction(dir: float) -> void:
	slide_direction = sign(dir)
	# Flip sprite if going left
	if dir < 0:
		scale.x = -abs(scale.x)
	else:
		scale.x = abs(scale.x)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		# Kill player - reload scene
		get_tree().reload_current_scene()
