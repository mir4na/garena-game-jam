extends Area2D

@export var level := 1

func advance_to_next_level():
	var scene_file_name = "res://scenes/level_" + str(level) + ".tscn"
	get_tree().change_scene_to_file(scene_file_name)


func _on_body_entered(body: Node2D) -> void:
	advance_to_next_level()
