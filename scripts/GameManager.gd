extends Node

## GameManager - Stores global game state like character selections

# Character style selection (1, 2, or 3)
var player1_style: int = 1
var player2_style: int = 3

func set_player_style(player_id: int, style: int) -> void:
	if player_id == 1:
		player1_style = style
	else:
		player2_style = style
	print("Player ", player_id, " selected style ", style)

func get_player_style(player_id: int) -> int:
	if player_id == 1:
		return player1_style
	return player2_style
