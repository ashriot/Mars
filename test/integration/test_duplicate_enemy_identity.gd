extends GutTest


const ACTOR_QUEUE_SCENE := preload("res://src/battle/actor_queue.tscn")
const BATTLE_WORLD_SCENE := preload(
	"res://src/battle/presentation/battle_world_3d.tscn"
)
const ENEMY_HUD_SCENE := preload(
	"res://src/battle/presentation/enemy_world_hud.tscn"
)
const SCOUT_DRONE := preload("res://data/enemies/actors/scout_drone.tres")
const EXPECTED_NAMES := [
	"Scout Drone A",
	"Scout Drone B",
	"Scout Drone C",
	"Scout Drone D",
	"Scout Drone E",
]
const EXPECTED_ABBREVIATIONS := ["SD A", "SD B", "SD C", "SD D", "SD E"]


class IdentityBattleManager extends BattleManager:
	func _ready() -> void:
		pass

	func _fade_in(_duration: float = 0.5) -> void:
		pass

	func wait(_duration: float = 0.01) -> void:
		pass

	func _flush_all_health_animations() -> void:
		pass

	func _apply_starting_passives() -> void:
		pass

	func _finalize_initial_ai_timing(_head_start_rolls: Array = []) -> void:
		pass

	func find_and_start_next_turn() -> void:
		pass


class IdentityPresentation extends CombatantPresentation:
	var bound_actor_name := ""

	func setup_view(value: BattleCombatant) -> bool:
		if not super.setup_view(value):
			return false
		bound_actor_name = value.actor_name
		return true


func test_five_identical_authored_enemies_publish_unique_a_through_e_identity() -> void:
	var manager := _spawn_manager()
	var repeated_enemies: Array[EnemyData] = []
	for _index in 5:
		repeated_enemies.append(SCOUT_DRONE)
	manager.current_encounter.enemies = repeated_enemies

	await manager.spawn_encounter([], 3, 41, false)

	var model_names: Array[String] = []
	var stats_names: Array[String] = []
	var names_seen_by_presentations: Array[String] = []
	var hud_names: Array[String] = []
	var ctb_abbreviations: Array[String] = []
	for combatant: BattleCombatant in manager.actor_list:
		var enemy := combatant as EnemyCombatant
		model_names.append(enemy.actor_name)
		stats_names.append(enemy.current_stats.actor_name)
		var presentation := manager.presentation_for(enemy) as IdentityPresentation
		names_seen_by_presentations.append(presentation.bound_actor_name)

		var hud := ENEMY_HUD_SCENE.instantiate() as EnemyWorldHUD
		add_child_autofree(hud)
		assert_true(hud.bind_combatant(enemy))
		hud_names.append(hud.name_label.text)

		var queue_item := ACTOR_QUEUE_SCENE.instantiate() as ActorQueue
		add_child_autofree(queue_item)
		queue_item.setup(enemy, 0, false, 0)
		ctb_abbreviations.append(queue_item.enemy_label.text)

	model_names.sort()
	stats_names.sort()
	names_seen_by_presentations.sort()
	hud_names.sort()
	ctb_abbreviations.sort()
	assert_eq(model_names, EXPECTED_NAMES)
	assert_eq(stats_names, EXPECTED_NAMES)
	assert_eq(names_seen_by_presentations, EXPECTED_NAMES)
	assert_eq(hud_names, EXPECTED_NAMES)
	assert_eq(ctb_abbreviations, EXPECTED_ABBREVIATIONS)


func _spawn_manager() -> IdentityBattleManager:
	var manager := IdentityBattleManager.new()
	manager.combatant_root = Node.new()
	manager.hero_area = Control.new()
	var world := BATTLE_WORLD_SCENE.instantiate() as BattleWorld3D
	manager.add_child(manager.combatant_root)
	manager.add_child(manager.hero_area)
	manager.add_child(world)
	manager.battle_world = world
	manager.enemy_view_scene = _identity_view_scene()
	manager.current_encounter = Encounter.new()
	add_child_autofree(manager)
	return manager


func _identity_view_scene() -> PackedScene:
	var scene := PackedScene.new()
	var view_root := Node3D.new()
	view_root.name = "IdentityEnemyView"
	var presentation := IdentityPresentation.new()
	presentation.name = "CombatantPresentation"
	view_root.add_child(presentation)
	presentation.owner = view_root
	assert_eq(scene.pack(view_root), OK)
	view_root.free()
	return scene
