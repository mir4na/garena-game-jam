extends Node

#@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var music_current_position : float
#var _current_bgm_clip: String = "MainMenu"
var _bgm_change_cooldown: float = 0.0

#func _ready() -> void:
	#background_music.play()

func _process(delta: float) -> void:
	if _bgm_change_cooldown > 0:
		_bgm_change_cooldown -= delta

func _can_change_bgm() -> bool:
	return _bgm_change_cooldown <= 0

#func change_bgm_to_combat() -> void:
	#if not _can_change_bgm() or _current_bgm_clip == "Combat":
		#return
	#_current_bgm_clip = "Combat"
	#_bgm_change_cooldown = 0.5
	#background_music["parameters/switch_to_clip"] = "Combat"
#
#
#func change_bgm_to_main_menu():
	#if not _can_change_bgm() or _current_bgm_clip == "MainMenu":
		#return
	#_current_bgm_clip = "MainMenu"
	#_bgm_change_cooldown = 0.5
	#background_music["parameters/switch_to_clip"] = "MainMenu"
#
		#
#func stop_bgm():
	#background_music.stop()
	#_current_bgm_clip = ""
func start_sfx(sfx_position:Node, sfx_path:String, pitch_randomizer:Array = [1,1], volume:float = 0, start_at:float = 0) -> void :
	var audio_resource := load(sfx_path)
	var speaker = AudioStreamPlayer2D.new()
	sfx_position.add_child(speaker)
	speaker.stream = audio_resource
	speaker.bus = "SFX"
	speaker.pitch_scale = randf_range(pitch_randomizer[0], pitch_randomizer[1])
	speaker.volume_db = volume
	speaker.play(start_at)
	await speaker.finished
	speaker.queue_free()

func start_ui_sfx(sfx_path:String, pitch_randomizer:Array = [1, 1], volume:float = 0, start_at:float=0) -> void:
	var audio_resource := load(sfx_path)
	var speaker = AudioStreamPlayer.new()
	add_child(speaker)
	speaker.stream = audio_resource
	speaker.bus = "SFX"
	speaker.pitch_scale = randf_range(pitch_randomizer[0], pitch_randomizer[1])
	speaker.volume_db = volume
	speaker.play(start_at)
	
	await speaker.finished
	speaker.queue_free()

func start_card_sfx(sfx: AudioStream, pitch_randomizer:Array = [1, 1], volume:float = 0, start_at:float=0) -> void:
	var speaker = AudioStreamPlayer.new()
	add_child(speaker)
	speaker.stream = sfx
	speaker.bus = "SFX"
	speaker.pitch_scale = randf_range(pitch_randomizer[0], pitch_randomizer[1])
	speaker.volume_db = volume
	speaker.play(start_at)
	
	await speaker.finished
	speaker.queue_free()
func start_loop_sfx(sfx_path:String, pitch_randomizer:Array = [1, 1], volume:float = 0, start_at:float=0) -> AudioStreamPlayer:
	var audio_resource := load(sfx_path)
	var speaker = AudioStreamPlayer.new()
	add_child(speaker)
	speaker.stream = audio_resource
	speaker.bus = "SFX"
	speaker.pitch_scale = randf_range(pitch_randomizer[0], pitch_randomizer[1])
	speaker.volume_db = volume
	speaker.play(start_at)
	return speaker

func reset():
	for child in get_children():
		child.queue_free()
	
