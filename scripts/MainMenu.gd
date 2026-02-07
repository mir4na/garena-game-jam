extends Control

## Main Menu with Start button and Character Selection

@onready var start_panel = $StartPanel
@onready var selection_panel = $SelectionPanel
@onready var start_button = $StartPanel/StartButton

# Player 1 selection
@onready var p1_style1 = $SelectionPanel/PlayersContainer/Player1Selection/ButtonsContainer/Style1
@onready var p1_style2 = $SelectionPanel/PlayersContainer/Player1Selection/ButtonsContainer/Style2
@onready var p1_style3 = $SelectionPanel/PlayersContainer/Player1Selection/ButtonsContainer/Style3
@onready var p1_preview = $SelectionPanel/PlayersContainer/Player1Selection/Preview

# Player 2 selection
@onready var p2_style1 = $SelectionPanel/PlayersContainer/Player2Selection/ButtonsContainer/Style1
@onready var p2_style2 = $SelectionPanel/PlayersContainer/Player2Selection/ButtonsContainer/Style2
@onready var p2_style3 = $SelectionPanel/PlayersContainer/Player2Selection/ButtonsContainer/Style3
@onready var p2_preview = $SelectionPanel/PlayersContainer/Player2Selection/Preview

@onready var play_button = $SelectionPanel/PlayButton

var player1_selected: int = 1
var player2_selected: int = 1

# Preload preview textures
var style_previews = {
	1: preload("res://assets/player1/idle1.png"),
	2: preload("res://assets/player2/idle1.png"),
	3: preload("res://assets/player3/idle1.png")
}

func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	# Start with only start panel visible
	start_panel.visible = true
	selection_panel.visible = false
	
	# Connect buttons
	start_button.pressed.connect(_on_start_pressed)
	
	p1_style1.pressed.connect(func(): _select_p1_style(1))
	p1_style2.pressed.connect(func(): _select_p1_style(2))
	p1_style3.pressed.connect(func(): _select_p1_style(3))
	
	p2_style1.pressed.connect(func(): _select_p2_style(1))
	p2_style2.pressed.connect(func(): _select_p2_style(2))
	p2_style3.pressed.connect(func(): _select_p2_style(3))
	
	play_button.pressed.connect(_on_play_pressed)
	
	# Set initial previews
	_update_previews()

func _on_start_pressed():
	start_panel.visible = false
	selection_panel.visible = true

func _select_p1_style(style: int):
	player1_selected = style
	_update_previews()
	_update_button_states()

func _select_p2_style(style: int):
	player2_selected = style
	_update_previews()
	_update_button_states()

func _update_previews():
	p1_preview.texture = style_previews[player1_selected]
	p2_preview.texture = style_previews[player2_selected]

func _update_button_states():
	# Visual feedback for selected buttons (toggle button_pressed property)
	p1_style1.button_pressed = (player1_selected == 1)
	p1_style2.button_pressed = (player1_selected == 2)
	p1_style3.button_pressed = (player1_selected == 3)
	
	p2_style1.button_pressed = (player2_selected == 1)
	p2_style2.button_pressed = (player2_selected == 2)
	p2_style3.button_pressed = (player2_selected == 3)

func _on_play_pressed():
	# Store selections in GameManager
	GameManager.set_player_style(1, player1_selected)
	GameManager.set_player_style(2, player2_selected)
	
	# Go to Level 1
	get_tree().change_scene_to_file("res://scenes/Level1.tscn")
