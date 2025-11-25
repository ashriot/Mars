extends Control
class_name BattleScene

signal battle_ended(won)

@export var manager: BattleManager

func _ready():
	get_tree().root.size_changed.connect(_on_viewport_resized)
	manager.battle_ended.connect(_on_battle_ended)
	_on_viewport_resized()

func setup_battle(enemy_roster: Array[EnemyData]):
	manager.spawn_encounter(enemy_roster)

func _on_viewport_resized():
	var base_size = Vector2(1920, 1080)
	var window_size = get_viewport().get_visible_rect().size

	# Scale uniformly based on smallest dimension
	var scale_x = window_size.x / base_size.x
	var scale_y = window_size.y / base_size.y
	var scale_factor = min(scale_x, scale_y)  # Use min to prevent stretching

	scale = Vector2(scale_factor, scale_factor)

	# Center the scaled content
	position = (window_size - base_size * scale_factor) / 2

func _on_battle_ended(won: bool):
	AudioManager.stop_music()
	battle_ended.emit(won)
