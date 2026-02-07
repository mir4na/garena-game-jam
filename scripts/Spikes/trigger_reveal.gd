extends Area2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var revealed := false

# Reference to parent spike's collision
@onready var spike_collision: CollisionShape2D = get_parent().get_node("CollisionShape2D")

func _ready() -> void:
	# Disable spike collision until revealed
	if spike_collision:
		spike_collision.set_deferred("disabled", true)

func _on_body_entered(body: Node2D) -> void:
	if not revealed:
		revealed = true
		
		# Enable collision AFTER a tiny delay so animation is visible
		animation_player.play("reveal_spike")
		
		# Enable collision after animation starts (so player sees the spike)
		await get_tree().create_timer(0.05).timeout
		if spike_collision:
			spike_collision.set_deferred("disabled", false)
