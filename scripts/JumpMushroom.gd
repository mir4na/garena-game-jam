extends Area2D

## JumpMushroom - Gives jump boost when player lands on it

@export var bounce_force: float = -700.0  # Negative = upward

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Cooldown to prevent multiple bounces
var bounce_cooldown: Dictionary = {}
const BOUNCE_COOLDOWN_TIME: float = 0.1


func _physics_process(delta: float) -> void:
	# Reduce cooldowns
	for player in bounce_cooldown.keys():
		bounce_cooldown[player] -= delta
		if bounce_cooldown[player] <= 0:
			bounce_cooldown.erase(player)
	
	# Check all overlapping bodies
	for body in get_overlapping_bodies():
		if not (body.is_in_group("player") or body.name.begins_with("Player")):
			continue
		
		# Skip if on cooldown
		if body in bounce_cooldown:
			continue
		
		# Bounce if player is falling and touching ground
		if body.velocity.y >= 0 and body.is_on_floor():
			_bounce_player(body)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player"):
		# Skip if on cooldown
		if body in bounce_cooldown:
			return
		
		# Bounce if falling onto mushroom
		if body.velocity.y > 0:
			_bounce_player(body)

func _bounce_player(player: Node2D) -> void:
	# Set cooldown
	bounce_cooldown[player] = BOUNCE_COOLDOWN_TIME
	
	# Set velocity directly for reliable bounce
	player.velocity.y = bounce_force
	
	# Play bounce animation
	_play_bounce_effect()
	
	print("Player bounced! Force: ", bounce_force)

func _play_bounce_effect() -> void:
	if not sprite:
		return
	
	var original_scale = sprite.scale
	var tween = create_tween()
	
	# Squash
	tween.tween_property(sprite, "scale", Vector2(original_scale.x * 1.3, original_scale.y * 0.6), 0.05)
	# Stretch back
	tween.tween_property(sprite, "scale", Vector2(original_scale.x * 0.9, original_scale.y * 1.2), 0.1)
	# Return to normal
	tween.tween_property(sprite, "scale", original_scale, 0.1)
