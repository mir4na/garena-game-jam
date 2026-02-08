extends Node2D
class_name CloudBackground

## Background awan bergerak pelan ke kanan
## Spawn beberapa awan secara random, gerak ke kanan, wrap ketika keluar layar

@export var cloud_textures: Array[Texture2D] = []
@export var cloud_count: int = 6
@export var min_speed: float = 15.0
@export var max_speed: float = 35.0
@export var screen_width: float = 1920.0
@export var screen_height: float = 1080.0
@export var spawn_margin: float = 200.0  # Extra space for spawning off-screen

# Internal cloud data
var clouds: Array[Dictionary] = []

func _ready() -> void:
	# Auto-load cloud textures if not set
	if cloud_textures.is_empty():
		_load_default_textures()
	
	print("CloudBackground: Found %d textures" % cloud_textures.size())
	
	# Spawn initial clouds
	_spawn_clouds()

func _load_default_textures() -> void:
	var paths = [
		"res://assets/awan1.png",
		"res://assets/awan2.png",
	]
	for path in paths:
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex:
				cloud_textures.append(tex)

func _spawn_clouds() -> void:
	if cloud_textures.is_empty():
		push_warning("CloudBackground: No cloud textures found!")
		return
	
	print("CloudBackground: Spawning %d clouds" % cloud_count)
	for i in range(cloud_count):
		_spawn_single_cloud(true)

func _spawn_single_cloud(initial: bool = false) -> void:
	var sprite = Sprite2D.new()
	sprite.texture = cloud_textures[randi() % cloud_textures.size()]
	
	# Random scale for variety
	var scale_factor = randf_range(0.3, 0.8)
	sprite.scale = Vector2(scale_factor, scale_factor)
	
	# Random vertical position
	var y_pos = randf_range(50, screen_height * 0.4)  # Upper portion of screen
	
	# Horizontal position
	var x_pos: float
	if initial:
		# Spread across entire screen on init
		x_pos = randf_range(-spawn_margin, screen_width + spawn_margin)
	else:
		# Spawn off-screen left
		x_pos = -spawn_margin - sprite.texture.get_width() * scale_factor
	
	sprite.position = Vector2(x_pos, y_pos)
	sprite.z_index = 1  # In front of background, behind gameplay
	sprite.modulate.a = randf_range(0.5, 0.9)  # Slight transparency variation
	
	add_child(sprite)
	
	# Store cloud data
	var cloud_data = {
		"sprite": sprite,
		"speed": randf_range(min_speed, max_speed)
	}
	clouds.append(cloud_data)

func _process(delta: float) -> void:
	var to_remove: Array[int] = []
	
	for i in range(clouds.size()):
		var cloud = clouds[i]
		var sprite = cloud["sprite"] as Sprite2D
		var speed = cloud["speed"] as float
		
		# Move right
		sprite.position.x += speed * delta
		
		# Check if off-screen right
		var cloud_width = sprite.texture.get_width() * sprite.scale.x
		if sprite.position.x > screen_width + spawn_margin + cloud_width:
			to_remove.append(i)
	
	# Remove off-screen clouds and spawn new ones
	# Process in reverse to maintain indices
	for i in range(to_remove.size() - 1, -1, -1):
		var idx = to_remove[i]
		var sprite = clouds[idx]["sprite"] as Sprite2D
		sprite.queue_free()
		clouds.remove_at(idx)
		_spawn_single_cloud(false)
