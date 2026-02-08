extends Control

## Main Menu with Start button and Character Selection
## Polished with smooth transitions and subtle animations

@onready var start_panel = $StartPanel
@onready var selection_panel = $SelectionPanel
@onready var start_button = $StartPanel/StartButton
@onready var title_label = $StartPanel/Title
@onready var background = $Background

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

# Animation state
var title_base_scale: Vector2 = Vector2.ONE
var title_breath_time: float = 0.0

# Parallax settings
var parallax_bg_strength: float = 30.0  # How much background moves
var parallax_title_strength: float = 20.0  # Title moves less (closer to camera feel)
var parallax_smooth: float = 8.0  # Smoothing factor
var screen_center: Vector2 = Vector2(960, 540)
var current_parallax_offset: Vector2 = Vector2.ZERO

# Preload preview textures
var style_previews = {
	1: preload("res://assets/player1/idle1.png"),
	2: preload("res://assets/player2/idle1.png"),
	3: preload("res://assets/player3/idle1.png")
}

func _ready():
	# Start with only start panel visible
	start_panel.visible = true
	start_panel.modulate.a = 1.0
	selection_panel.visible = false
	selection_panel.modulate.a = 0.0
	
	# Setup button hover effects
	_setup_button_hover(start_button)
	_setup_button_hover(play_button)
	_setup_button_hover(p1_style1)
	_setup_button_hover(p1_style2)
	_setup_button_hover(p1_style3)
	_setup_button_hover(p2_style1)
	_setup_button_hover(p2_style2)
	_setup_button_hover(p2_style3)
	
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
	
	# Store title base scale for breathing animation
	if title_label:
		title_label.pivot_offset = title_label.size / 2
	
	# Set pivot for parallax
	if start_panel:
		start_panel.pivot_offset = start_panel.size / 2
	if selection_panel:
		selection_panel.pivot_offset = selection_panel.size / 2

func _process(delta: float) -> void:
	# Calculate parallax offset based on mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	var offset_from_center = (mouse_pos - screen_center) / screen_center  # Normalized -1 to 1
	
	# Smooth the parallax movement
	var target_offset = offset_from_center
	current_parallax_offset = current_parallax_offset.lerp(target_offset, delta * parallax_smooth)
	
	# Apply parallax to background using offset (works with anchored controls)
	if background:
		background.offset_left = -current_parallax_offset.x * parallax_bg_strength - 50
		background.offset_right = -current_parallax_offset.x * parallax_bg_strength + 50
		background.offset_top = -current_parallax_offset.y * parallax_bg_strength - 50
		background.offset_bottom = -current_parallax_offset.y * parallax_bg_strength + 50
	
	# Apply parallax to start panel using offset
	if start_panel and start_panel.visible:
		var offset_x = -current_parallax_offset.x * parallax_title_strength
		var offset_y = -current_parallax_offset.y * parallax_title_strength
		start_panel.offset_left = -150 + offset_x
		start_panel.offset_right = 150 + offset_x
		start_panel.offset_top = -100 + offset_y
		start_panel.offset_bottom = 100 + offset_y
	
	# Apply to selection panel too when visible
	if selection_panel and selection_panel.visible:
		var offset_x = -current_parallax_offset.x * parallax_title_strength
		var offset_y = -current_parallax_offset.y * parallax_title_strength
		selection_panel.offset_left = -400 + offset_x
		selection_panel.offset_right = 400 + offset_x
		selection_panel.offset_top = -250 + offset_y
		selection_panel.offset_bottom = 250 + offset_y
	
	# Subtle title breathing animation
	if title_label and start_panel.visible:
		title_breath_time += delta
		var breath = 1.0 + sin(title_breath_time * 1.5) * 0.03
		title_label.scale = Vector2(breath, breath)

func _setup_button_hover(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2
	btn.mouse_entered.connect(func(): _on_button_hover(btn, true))
	btn.mouse_exited.connect(func(): _on_button_hover(btn, false))

func _on_button_hover(btn: Button, hovered: bool) -> void:
	var target_scale = Vector2(1.05, 1.05) if hovered else Vector2.ONE
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "scale", target_scale, 0.15)

func _on_start_pressed():
	# Smooth transition between panels
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# Fade out start panel
	tween.tween_property(start_panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): 
		start_panel.visible = false
		selection_panel.visible = true
	)
	# Fade in selection panel
	tween.tween_property(selection_panel, "modulate:a", 1.0, 0.3)
	
	# Pop in the previews
	tween.tween_callback(_animate_previews_in)

func _animate_previews_in() -> void:
	# Subtle bounce-in for previews
	if p1_preview:
		p1_preview.scale = Vector2(0.8, 0.8)
		var t1 = create_tween()
		t1.set_ease(Tween.EASE_OUT)
		t1.set_trans(Tween.TRANS_BACK)
		t1.tween_property(p1_preview, "scale", Vector2.ONE, 0.3)
	if p2_preview:
		p2_preview.scale = Vector2(0.8, 0.8)
		var t2 = create_tween()
		t2.set_ease(Tween.EASE_OUT)
		t2.set_trans(Tween.TRANS_BACK)
		t2.tween_property(p2_preview, "scale", Vector2.ONE, 0.35)

func _select_p1_style(style: int):
	player1_selected = style
	_update_previews()
	_update_button_states()
	# Quick bounce on selection
	_bounce_preview(p1_preview)

func _select_p2_style(style: int):
	player2_selected = style
	_update_previews()
	_update_button_states()
	# Quick bounce on selection
	_bounce_preview(p2_preview)

func _bounce_preview(preview: TextureRect) -> void:
	if not preview:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(preview, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(preview, "scale", Vector2.ONE, 0.15)

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
	
	# Smooth fade out before level transition
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/Level1.tscn")
	)
