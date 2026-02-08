extends Area2D

@onready var dialog_label: Label = $DialogSprite/DialogLabel
@export var dialog_text: String
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var mark: Sprite2D = $Mark
var dont_show_text := false
var never_seen = true
var showed := false
func _ready() -> void:
	dialog_label.text = dialog_text
func _on_body_entered(body: Node2D) -> void:
	if not showed and not dont_show_text:
		showed = true
		animation_player.play("show_dialog")
		if never_seen:
			mark.hide()

func _on_body_exited(body: Node2D) -> void:
	if showed:
		animation_player.play_backwards("show_dialog")
		showed = false
