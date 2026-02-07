extends Area2D

## Spike that can extend its tip upward

@onready var visual: Polygon2D = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

var original_polygon: PackedVector2Array
var original_collision_size: Vector2
var is_extended: bool = false

func _ready():
	original_polygon = visual.polygon.duplicate()
	original_collision_size = collision.shape.size

## Extend the spike tip upward very fast (for jumpscare effect)
func extend_tip(target_height: float = -300.0, duration: float = 0.1):
	if is_extended:
		return
	is_extended = true
	
	# Animate the top vertex (index 1) moving up
	var tween = create_tween()
	tween.tween_method(_set_tip_height, original_polygon[1].y, target_height, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _set_tip_height(y: float):
	var new_polygon = original_polygon.duplicate()
	new_polygon[1].y = y
	visual.polygon = new_polygon
	
	# Also extend collision to match
	var height = abs(y) + 16  # 16 is the base offset
	collision.shape.size.y = height
	collision.position.y = y / 2

## Reset spike to original state
func reset_spike():
	visual.polygon = original_polygon
	collision.shape.size = original_collision_size
	collision.position = Vector2.ZERO
	is_extended = false
