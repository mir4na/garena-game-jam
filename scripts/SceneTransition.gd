extends CanvasLayer

## SceneTransition - Handles fade transitions between scenes
## Usage: SceneTransition.change_scene("res://scenes/level_1.tscn")

var transition_rect: ColorRect
var is_transitioning: bool = false

# Transition settings
@export var fade_duration: float = 0.4
@export var fade_color: Color = Color.BLACK

func _ready() -> void:
	layer = 100  # Above everything
	
	# Create the transition overlay
	transition_rect = ColorRect.new()
	transition_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(transition_rect)

## Main transition function - call this to change scenes with fade
func change_scene(scene_path: String, duration: float = -1.0) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	var fade_time = duration if duration > 0 else fade_duration
	
	# Fade to black
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, fade_time)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	
	await tween.finished
	
	# Change scene
	get_tree().change_scene_to_file(scene_path)
	
	# Wait a frame for scene to load
	await get_tree().process_frame
	
	# Fade from black
	var tween_out = create_tween()
	tween_out.tween_property(transition_rect, "color:a", 0.0, fade_time)
	tween_out.set_ease(Tween.EASE_OUT)
	tween_out.set_trans(Tween.TRANS_QUAD)
	
	await tween_out.finished
	is_transitioning = false

## Quick fade out only (for special cases)
func fade_out(duration: float = -1.0) -> void:
	var fade_time = duration if duration > 0 else fade_duration
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, fade_time)
	await tween.finished

## Quick fade in only (for special cases)
func fade_in(duration: float = -1.0) -> void:
	var fade_time = duration if duration > 0 else fade_duration
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.0, fade_time)
	await tween.finished
