extends StaticBody2D

@export var drop_time = 2.0

func _on_area_2d_body_entered(body: Node2D) -> void:
	get_tree().create_timer(drop_time).timeout.connect(drop_block)
	
func drop_block():
	pass
