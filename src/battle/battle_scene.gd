extends Control
class_name BattleScene

signal battle_ended(won)

@export var manager: BattleManager

func _ready():
	manager.battle_ended.connect(_on_battle_ended)

func setup_battle(enemy_roster: Array[EnemyData]):
	manager.spawn_encounter(enemy_roster)

func _on_battle_ended(won: bool):
	battle_ended.emit(won)
