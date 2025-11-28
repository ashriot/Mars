extends Control
class_name BattleScene

signal battle_ended(won)

@export var manager: BattleManager

func _ready():
	manager.battle_ended.connect(_on_battle_ended)

# Update signature to take the full resource
func setup_battle(encounter: Encounter):
	manager.current_encounter = encounter
	manager.spawn_encounter()

func _on_battle_ended(won: bool):
	battle_ended.emit(won)
