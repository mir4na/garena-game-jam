extends Node2D

@onready var platform = $Platform
@onready var player1 = $Player1
@onready var player2 = $Player2
@onready var chain = $Chain
@onready var trigger_end = $TriggerEnd
@onready var trigger_start = $TriggerStart

var trigger_tripped = false

func _ready():
    # Setup chain
    chain.player1 = player1
    chain.player2 = player2

func _on_trigger_end_body_entered(body):
    if not trigger_tripped and (body == player1 or body == player2):
        trigger_tripped = true
        # TROLL: Pull platform back
        var tween = create_tween()
        tween.tween_property(platform, "position:x", -2000, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
        print("Troll triggered! Returning to start...")

func _on_trigger_start_body_entered(body):
    if trigger_tripped and (body == player1 or body == player2):
        # Force forward
        var tween = create_tween()
        tween.tween_property(platform, "position:x", 0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        # Launch players right
        if player1.has_method("launch"):
            player1.launch(Vector2(2000, -500))
        if player2.has_method("launch"):
            player2.launch(Vector2(2000, -500))
        print("Launcher triggered! Go to Level 2!")
