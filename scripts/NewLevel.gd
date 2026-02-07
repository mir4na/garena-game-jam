extends Node2D

## NewLevel - Level logic with death/spike reset

@onready var player1 = $Player
@onready var player2 = $Player2
@onready var chain = $Chain

# Store spawn positions
var player1_spawn: Vector2
var player2_spawn: Vector2

@onready var spike1 = $Spike1

var trigger1_activated = false
var original_spike_position: Vector2

func _ready():
	# DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	# Store initial spawn positions
	player1_spawn = player1.global_position
	player2_spawn = player2.global_position
	
	# Store original spike position
	if spike1:
		original_spike_position = spike1.position

func _on_death_area_body_entered(body):
	if body == player1 or body == player2:
		print("Player died! Resetting...")
		_reset_level()

func _on_spike_body_entered(body):
	if body == player1 or body == player2:
		print("Player hit spike! Resetting...")
		_reset_level()

var spike_tween: Tween

func _reset_level():
	# Kill active tween if exists
	if spike_tween and spike_tween.is_valid():
		spike_tween.kill()

	# Reset players to spawn positions
	player1.global_position = player1_spawn
	player2.global_position = player2_spawn
	
	# Reset player velocities
	player1.velocity = Vector2.ZERO
	player2.velocity = Vector2.ZERO
	
	# Reset trigger states
	trigger1_activated = false
	
	# Reset spike
	if spike1:
		spike1.position = original_spike_position
		if spike1.has_method("reset_spike"):
			spike1.reset_spike()
	
	if chain and chain.has_method("reset_rope"):
		chain.reset_rope()

func _on_trigger_1_body_entered(body: Node2D) -> void:
	if not trigger1_activated and (body == player1 or body == player2):
		trigger1_activated = true
		print("SURPRISE! Spike extends!")
		
		# Extend spike tip upward very fast (-900 = 900 pixels up)
		if spike1 and spike1.has_method("extend_tip"):
			spike1.extend_tip(-900.0, 0.1)
		
		# After 3 seconds, move spike left by -350
		await get_tree().create_timer(3.0).timeout
		
		# If reset happened during the wait, trigger1_activated will be false. STOP here.
		if not trigger1_activated:
			return
			
		spike_tween = create_tween()
		spike_tween.tween_property(spike1, "position:x", spike1.position.x - 350.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		
		# After ANOTHER 3 seconds (total 6s from start), shoot UP fast (-1500)
		await get_tree().create_timer(3.0).timeout
		
		if not trigger1_activated:
			return
			
		# Shoot up very fast
		spike_tween = create_tween()
		spike_tween.tween_property(spike1, "position:y", spike1.position.y - 1500.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
