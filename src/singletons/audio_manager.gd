extends Node

signal sfx_finished

# --- Configuration ---
const NUM_SFX_PLAYERS = 8
const BUS_MUSIC = "Music"
const BUS_SFX = "SFX"

# --- Music Library ---
var track_library = {
	"battle": preload("res://assets/music/battle.ogg"),
	"map_1": preload("res://assets/music/map_1.ogg"),
	"hub": preload("res://assets/music/hub.ogg"),
	"title": preload("res://assets/music/title.ogg"),
	# Add your other tracks here
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

# --- State Tracking ---
var _current_music_player: AudioStreamPlayer = null
var _current_track_key: String = ""
# NEW: Dictionary to store the float position (seconds) of paused tracks
var _saved_track_positions: Dictionary = {}

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

func play_music(track_name: String, fade_duration: float = 1.0, save_current_pos: bool = false, resume_stored_pos: bool = false):
	# 1. Validate track exists
	if not track_library.has(track_name):
		push_warning("AudioManager: Track not found in library: " + track_name)
		return

	var stream = track_library[track_name]

	# 2. Check if already playing
	if _current_music_player and _current_music_player.playing and _current_track_key == track_name:
		return

	# 3. Identify Players
	var new_player = _music_player_2 if _current_music_player == _music_player_1 else _music_player_1
	var old_player = _current_music_player

	# 4. Handle Old Player (Save Position Logic)
	if old_player and old_player.playing:
		if save_current_pos and _current_track_key != "":
			# Save the exact timestamp where we left off
			_saved_track_positions[_current_track_key] = old_player.get_playback_position()
			print("Saved position for ", _current_track_key, ": ", _saved_track_positions[_current_track_key])

		# Fade out old player
		var tween_out = create_tween()
		tween_out.tween_property(old_player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween_out.tween_callback(old_player.stop)

	# 5. Handle New Player (Resume Logic)
	var start_time: float = 0.0
	if resume_stored_pos and _saved_track_positions.has(track_name):
		start_time = _saved_track_positions[track_name]
		print("Resuming ", track_name, " from: ", start_time)

	new_player.stream = stream
	new_player.volume_db = -80.0
	# Play from the calculated start time
	new_player.play(start_time)

	# Update State
	_current_music_player = new_player
	_current_track_key = track_name

	# Fade in new player
	var tween_in = create_tween()
	tween_in.tween_property(new_player, "volume_db", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# UPDATED: Added logic to save position on manual stop if desired
func stop_music(fade_duration: float = 1.0, save_pos: bool = false):
	if not _current_music_player or not _current_music_player.playing:
		return

	# Save position if requested
	if save_pos and _current_track_key != "":
		_saved_track_positions[_current_track_key] = _current_music_player.get_playback_position()

	var player_to_stop = _current_music_player

	var tween = create_tween()
	tween.tween_property(player_to_stop, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(player_to_stop.stop)

	_current_music_player = null
	_current_track_key = ""

# --- SFX API (Unchanged) ---
func play_sfx(sfx_name: String, pitch_variance: float = 0.0, volume_db: float = 0.0):
	if not sfx_library.has(sfx_name):
		# push_warning("AudioManager: SFX not found: " + sfx_name) # Optional: comment out to reduce spam
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
	sfx_finished.emit()
