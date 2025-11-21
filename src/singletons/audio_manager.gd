extends Node

# --- Configuration ---
const NUM_SFX_PLAYERS = 8
const BUS_MUSIC = "Music"
const BUS_SFX = "SFX"

# --- Music Library ---
# Preloading here means they are always ready in memory.
# For an RPG of this size, this is totally fine and prevents stutter.
var track_library = {
	#"main_menu": preload("res://assets/music/main_menu.mp3"),
	"battle": preload("res://assets/music/battle.mp3"),
	#"boss": preload("res://assets/music/boss_theme.mp3"),
	#"exploration": preload("res://assets/music/mars_ruins.mp3"),
	#"victory": preload("res://assets/music/victory_fanfare.mp3")
}

var sfx_library = {
	"pistol": preload("res://assets/sfx/pistol.wav"),
	"terminal": preload("res://assets/sfx/terminal.wav"),
	"press": preload("res://assets/sfx/press.wav"),
	"radiate": preload("res://assets/sfx/radiate.wav"),
}

# --- Internal Nodes ---
var _music_player_1: AudioStreamPlayer
var _music_player_2: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_idx: int = 0
var _current_music_player: AudioStreamPlayer = null
var _current_track_key: String = ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player_1 = AudioStreamPlayer.new()
	_music_player_1.bus = BUS_MUSIC
	add_child(_music_player_1)

	_music_player_2 = AudioStreamPlayer.new()
	_music_player_2.bus = BUS_MUSIC
	add_child(_music_player_2)

	for i in range(NUM_SFX_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.bus = BUS_SFX
		p.finished.connect(_on_sfx_finished.bind(p))
		add_child(p)
		_sfx_players.append(p)

# --- MUSIC API ---

func play_music(track_name: String, fade_duration: float = 1.0):
	# 1. Validate track exists
	if not track_library.has(track_name):
		push_warning("AudioManager: Track not found in library: " + track_name)
		return

	var stream = track_library[track_name]

	# 2. Check if already playing (by key or stream)
	if _current_music_player and _current_music_player.playing and _current_track_key == track_name:
		return

	var new_player = _music_player_2 if _current_music_player == _music_player_1 else _music_player_1
	var old_player = _current_music_player

	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()

	_current_music_player = new_player
	_current_track_key = track_name

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_player, "volume_db", 0.0, fade_duration)

	if old_player and old_player.playing:
		tween.tween_property(old_player, "volume_db", -80.0, fade_duration)
		tween.chain().tween_callback(old_player.stop)

# --- SFX API (Unchanged) ---
func play_sfx(sfx_name: String, pitch_variance: float = 0.0, volume_db: float = 0.0):
	if not sfx_library.has(sfx_name):
		push_warning("AudioManager: SFX not found in library: " + sfx_name)
		return

	var stream = sfx_library[sfx_name]
	var player = _get_available_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	if pitch_variance > 0:
		player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	else:
		player.pitch_scale = 1.0
	player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	var player = _sfx_players[_next_sfx_idx]
	_next_sfx_idx = (_next_sfx_idx + 1) % NUM_SFX_PLAYERS
	return player

func _on_sfx_finished(_player: AudioStreamPlayer):
	pass
