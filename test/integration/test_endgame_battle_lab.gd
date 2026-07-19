extends GutTest

const LabScene := preload("res://src/dev/endgame_battle_lab.tscn")
const TEST_SAVE_ROOT := "user://test_saves/endgame_battle_lab/"

var _saved_storage_root := ""
var _saved_state: Dictionary = {}


func before_each() -> void:
	_saved_storage_root = SaveSystem.storage_root_override
	SaveSystem.storage_root_override = TEST_SAVE_ROOT
	_saved_state = _snapshot_global_state()


func after_each() -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		tween.kill()
	_restore_global_state(_saved_state)
	SaveSystem.storage_root_override = _saved_storage_root


func test_lab_builds_max_party_and_forwards_rank_ten_fixed_seed() -> void:
	var lab := LabScene.instantiate() as EndgameBattleLab
	add_child_autofree(lab)
	await get_tree().process_frame

	assert_true(lab.last_build_succeeded)
	var heroes := lab.battle_scene.manager.actor_list.filter(
		func(actor: ActorCard) -> bool: return actor is HeroCard
	)
	var enemies := lab.battle_scene.manager.actor_list.filter(
		func(actor: ActorCard) -> bool: return actor is EnemyCard
	)
	assert_eq(heroes.size(), 3)
	assert_eq(lab.equipment_preset, EndgamePartyFactory.EquipmentPreset.MAX_EQUIPMENT)
	for hero: HeroCard in heroes:
		assert_eq(hero.hero_data.weapon.tier, 5, hero.actor_name)
		assert_eq(hero.hero_data.weapon.rank, 30, hero.actor_name)
		assert_eq(hero.hero_data.armor.tier, 5, hero.actor_name)
		assert_eq(hero.hero_data.armor.rank, 30, hero.actor_name)
	assert_eq(lab.enemy_level, 10)
	assert_false(enemies.is_empty())
	for enemy: EnemyCard in enemies:
		assert_eq(enemy.enemy_data.level, 10, enemy.actor_name)
		assert_eq(enemy.get_node("Panel/Info/Text").text, "Rk. 10", enemy.actor_name)
	assert_eq(lab.battle_scene.manager.encounter_seed, lab.encounter_seed)
	assert_true(lab.battle_scene.manager.has_local_combat_rng())
	assert_false(lab.battle_scene.manager.rewards_enabled)
	assert_null(lab.find_child("GameManager", true, false))


func test_lab_start_and_result_do_not_mutate_save_or_run_singletons() -> void:
	var before := _snapshot_global_state()
	var lab := LabScene.instantiate() as EndgameBattleLab
	add_child_autofree(lab)
	await get_tree().process_frame

	lab._on_battle_ended(true)

	assert_eq(_snapshot_global_state(), before)


func _snapshot_global_state() -> Dictionary:
	return {
		"slot": SaveSystem.current_slot_index,
		"bits": SaveSystem.bits,
		"data": SaveSystem.data.duplicate(true),
		"roster": SaveSystem.party_roster.duplicate(),
		"inventory": SaveSystem.inventory.duplicate(true),
		"equipment": SaveSystem.inventory_equipment.duplicate(),
		"mods": SaveSystem.inventory_mods.duplicate(),
		"lifetime_xp": SaveSystem.total_lifetime_xp,
		"load_issues": SaveSystem.last_load_issues.duplicate(),
		"run_active": RunManager.is_run_active,
		"active_map": RunManager.active_dungeon_map,
		"profile": RunManager.dungeon_profile,
		"tier": RunManager.current_dungeon_tier,
		"seed": RunManager.current_run_seed,
		"run_bits": RunManager.run_bits,
		"run_xp": RunManager.run_xp,
		"run_inventory": RunManager.run_inventory.duplicate(true),
		"run_equipment": RunManager.run_equipment_loot.duplicate(),
		"run_mods": RunManager.run_mods_loot.duplicate(),
		"rewards_committed": RunManager._rewards_committed,
		"slot_file": _snapshot_current_slot_file(),
	}


func _restore_global_state(state: Dictionary) -> void:
	SaveSystem.current_slot_index = state.slot
	SaveSystem.bits = state.bits
	SaveSystem.data = state.data
	SaveSystem.party_roster.assign(state.roster)
	SaveSystem.inventory = state.inventory
	SaveSystem.inventory_equipment.assign(state.equipment)
	SaveSystem.inventory_mods.assign(state.mods)
	SaveSystem.total_lifetime_xp = state.lifetime_xp
	SaveSystem.last_load_issues.assign(state.load_issues)
	RunManager.is_run_active = state.run_active
	RunManager.active_dungeon_map = state.active_map \
		if is_instance_valid(state.active_map) else null
	RunManager.dungeon_profile = state.profile \
		if is_instance_valid(state.profile) else null
	RunManager.current_dungeon_tier = state.tier
	RunManager.current_run_seed = state.seed
	RunManager.run_bits = state.run_bits
	RunManager.run_xp = state.run_xp
	RunManager.run_inventory = state.run_inventory
	RunManager.run_equipment_loot.assign(state.run_equipment)
	RunManager.run_mods_loot.assign(state.run_mods)
	RunManager._rewards_committed = state.rewards_committed
	_restore_current_slot_file(state.slot_file)


func _snapshot_current_slot_file() -> Dictionary:
	var path := SaveSystem._get_slot_path(SaveSystem.current_slot_index)
	var exists := FileAccess.file_exists(path)
	return {
		"path": path,
		"exists": exists,
		"bytes": FileAccess.get_file_as_bytes(path) if exists else PackedByteArray(),
	}


func _restore_current_slot_file(state: Dictionary) -> void:
	var path: String = state.path
	if state.exists:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(state.bytes)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
