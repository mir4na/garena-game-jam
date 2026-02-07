extends Area2D


func _on_body_entered(body: Node2D) -> void:
	var reset_target = _find_reset_target()
	if not reset_target:
		get_tree().call_deferred("reload_current_scene")
		return
		
	# Special case for Box: Try to reset only the box
	if (body.name == "Box" or body is RigidBody2D) and reset_target.has_method("_reset_box"):
		print("[KillZone] Resetting Box Only")
		reset_target.call_deferred("_reset_box")
		return
	reset_target.call_deferred("_reset_level")

func _find_reset_target() -> Node:
	var root = get_tree().current_scene
	print("[KillZone] Searching for reset target... Root: ", root.name)
	if not root:
		return null
	if root.has_method("_reset_level"):
		print("[KillZone] Found reset method on root: ", root.name)
		return root
	var stack: Array = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			if child.has_method("_reset_level"):
				return child
			stack.append(child)
	return null
