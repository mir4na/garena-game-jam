extends Camera2D
class_name ShakeableCamera

## Camera with shake functionality for impactful moments

@export var decay: float = 5.0  # How quickly the shake diminishes
@export var max_offset: Vector2 = Vector2(20, 15)  # Maximum shake offset

var _trauma: float = 0.0  # Current shake intensity (0-1)
var _noise_offset: float = 0.0

func _process(delta: float) -> void:
	if _trauma > 0:
		_trauma = max(_trauma - decay * delta, 0)
		_apply_shake()
	else:
		offset = Vector2.ZERO

func _apply_shake() -> void:
	var shake_amount = _trauma * _trauma  # Quadratic falloff feels better
	_noise_offset += 1
	
	# Use randomness for simple shake
	offset = Vector2(
		randf_range(-1, 1) * max_offset.x * shake_amount,
		randf_range(-1, 1) * max_offset.y * shake_amount
	)

## Call this to add shake. Amount should be 0.0 to 1.0
func add_trauma(amount: float) -> void:
	_trauma = min(_trauma + amount, 1.0)

## Convenience: shake presets
func shake_light() -> void:
	add_trauma(0.2)

func shake_medium() -> void:
	add_trauma(0.4)

func shake_heavy() -> void:
	add_trauma(0.7)

## Static helper to find and shake the current scene's camera
static func shake_current_camera(amount: float) -> void:
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		var camera = tree.current_scene.get_node_or_null("Camera2D")
		if camera and camera.has_method("add_trauma"):
			camera.add_trauma(amount)
