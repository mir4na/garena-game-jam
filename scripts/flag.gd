extends Area2D

@export var level := 1

func advance_to_next_level():
	var scene_file_name = "res://scenes/level_" + str(level + 1) + ".tscn"
	if level >= 5:
		SceneTransition.change_scene("res://scenes/main_menu.tscn")
	else:
		SceneTransition.change_scene(scene_file_name)


func _on_body_entered(body: Node2D) -> void:
	advance_to_next_level()
