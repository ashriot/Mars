extends Control
class_name EndgameBattleLab

@export var encounter: Encounter
@export var equipment_preset := EndgamePartyFactory.EquipmentPreset.MAX_EQUIPMENT
@export_range(1, 30, 1) var enemy_level := 20
@export_range(1.0, 20.0, 0.25) var enemy_hp_multiplier := 10.0
@export var encounter_seed := 4242
@export var auto_start := true

@onready var battle_scene: BattleScene = $BattleScene

var last_build_succeeded := false


func _ready() -> void:
	if auto_start:
		start_benchmark()


func start_benchmark() -> bool:
	last_build_succeeded = false
	if encounter == null:
		push_error("EndgameBattleLab requires an encounter.")
		return false
	var result := EndgamePartyFactory.build(
		ProgressionSystem.catalog,
		equipment_preset,
	)
	if not result.success:
		push_error("EndgameBattleLab: %s" % result.error)
		return false

	last_build_succeeded = true
	if not battle_scene.battle_ended.is_connected(_on_battle_ended):
		battle_scene.battle_ended.connect(_on_battle_ended)
	battle_scene.setup_battle(
		encounter,
		result.roster,
		enemy_level,
		encounter_seed,
		false,
		enemy_hp_multiplier,
	)
	return true


func _on_battle_ended(won: bool) -> void:
	print("Endgame benchmark result: %s" % ("VICTORY" if won else "DEFEAT"))
