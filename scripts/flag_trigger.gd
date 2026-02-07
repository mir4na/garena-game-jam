extends Area2D

## Trigger area yang mendeteksi player mendekati flag
## Saat player masuk, panggil on_player_near_flag() di Level3

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		# Cari Level3 node
		var level3 = get_tree().current_scene
		if level3 and level3.has_method("on_player_near_flag"):
			level3.call("on_player_near_flag")
			# Disable trigger setelah sekali pakai
			set_deferred("monitoring", false)
