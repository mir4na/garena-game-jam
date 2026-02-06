extends RigidBody2D

## ChainLink - Individual link in a physics-based chain
## Used for visual chain segments

# Reference to previous and next links
var prev_link: RigidBody2D = null
var next_link: RigidBody2D = null

func _ready() -> void:
	# Disable sleeping so physics is always active
	can_sleep = false

func _physics_process(_delta: float) -> void:
	pass
