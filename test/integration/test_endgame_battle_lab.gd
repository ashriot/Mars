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


func test_enemy_level_is_editable_from_one_through_thirty_in_inspector() -> void:
	var lab := LabScene.instantiate() as EndgameBattleLab
	lab.auto_start = false
	add_child_autofree(lab)
	var enemy_level_properties := lab.get_property_list().filter(
		func(property: Dictionary) -> bool: return property.name == "enemy_level"
	)

	assert_eq(enemy_level_properties.size(), 1)
	assert_eq(enemy_level_properties[0].hint, PROPERTY_HINT_RANGE)
	assert_eq(enemy_level_properties[0].hint_string, "1.0,30.0,1.0")


func test_enemy_hp_multiplier_is_editable_from_one_through_twenty_in_inspector() -> void:
	var lab := LabScene.instantiate() as EndgameBattleLab
	lab.auto_start = false
	add_child_autofree(lab)
	var hp_multiplier_properties := lab.get_property_list().filter(
		func(property: Dictionary) -> bool: return property.name == "enemy_hp_multiplier"
	)

	assert_eq(hp_multiplier_properties.size(), 1)
	if hp_multiplier_properties.is_empty():
		return
	assert_eq(hp_multiplier_properties[0].hint, PROPERTY_HINT_RANGE)
	assert_eq(hp_multiplier_properties[0].hint_string, "1.0,20.0,0.25")
	assert_eq(lab.get("enemy_hp_multiplier"), 5.0)


func test_lab_builds_max_party_and_forwards_rank_twenty_five_fixed_seed() -> void:
	var lab := LabScene.instantiate() as EndgameBattleLab
	var authored_enemies := lab.encounter.enemies.duplicate()
	var authored_levels: Array[int] = []
	var authored_stats: Array[ActorStats] = []
	for authored_enemy: EnemyData in authored_enemies:
		authored_levels.append(authored_enemy.level)
		authored_stats.append(authored_enemy.stats)
	add_child_autofree(lab)
	await get_tree().process_frame

	assert_true(lab.last_build_succeeded)
	assert_true(lab.battle_scene.manager.actor_list.all(
		func(actor: BattleCombatant) -> bool: return actor is BattleCombatant
	))
	var heroes := lab.battle_scene.manager.get_living_heroes()
	var enemies := lab.battle_scene.manager.get_living_enemies()
	var expected_enemy_ids: Array[String] = [
		"attack_drone",
		"defense_drone",
		"riot_drone",
		"scout_drone",
	]
	assert_eq(heroes.size(), 3)
	assert_eq(_authored_enemy_ids(authored_enemies), expected_enemy_ids)
	assert_eq(_spawned_enemy_ids(enemies), expected_enemy_ids)
	assert_eq(lab.equipment_preset, EndgamePartyFactory.EquipmentPreset.MAX_EQUIPMENT)
	for hero: HeroCombatant in heroes:
		assert_eq(hero.hero_data.weapon.tier, 5, hero.actor_name)
		assert_eq(hero.hero_data.weapon.rank, 30, hero.actor_name)
		assert_eq(hero.hero_data.weapon.current_xp, 0, hero.actor_name)
		assert_eq(hero.hero_data.armor.tier, 5, hero.actor_name)
		assert_eq(hero.hero_data.armor.rank, 30, hero.actor_name)
		assert_eq(hero.hero_data.armor.current_xp, 0, hero.actor_name)
	assert_eq(lab.enemy_level, 25)
	assert_false(enemies.is_empty())
	for enemy_index in enemies.size():
		var enemy := enemies[enemy_index] as EnemyCombatant
		var presentation := lab.battle_scene.manager.presentation_for(enemy) \
			as EnemyDronePresentation
		var authored_enemy := authored_enemies[enemy_index] as EnemyData
		var unscaled_stats := _enemy_stats_at_level(authored_enemy, lab.enemy_level)
		var expected_hp := roundi(unscaled_stats.max_hp * lab.enemy_hp_multiplier)
		assert_eq(enemy.enemy_data.level, 25, enemy.actor_name)
		assert_not_null(presentation, enemy.actor_name)
		if presentation != null:
			assert_same(presentation.combatant, enemy, enemy.actor_name)
			assert_same(presentation.hud.combatant, enemy, enemy.actor_name)
		assert_eq(enemy.current_stats.max_hp, expected_hp, enemy.actor_name)
		assert_eq(enemy.current_hp, expected_hp, enemy.actor_name)
		assert_eq(enemy.current_stats.attack, unscaled_stats.attack, enemy.actor_name)
		assert_eq(enemy.current_stats.speed, unscaled_stats.speed, enemy.actor_name)
		assert_not_same(enemy.enemy_data, authored_enemy, enemy.actor_name)
		assert_same(lab.encounter.enemies[enemy_index], authored_enemy, enemy.actor_name)
		assert_eq(authored_enemy.level, authored_levels[enemy_index], enemy.actor_name)
		assert_same(authored_enemy.stats, authored_stats[enemy_index], enemy.actor_name)
	assert_eq(lab.battle_scene.manager.encounter_seed, lab.encounter_seed)
	assert_true(lab.battle_scene.manager.has_local_combat_rng())
	assert_false(lab.battle_scene.manager.rewards_enabled)
	assert_null(lab.find_child("GameManager", true, false))


func test_hp_multiplier_remains_active_when_enemy_rank_changes_to_thirty() -> void:
	var lab := LabScene.instantiate() as EndgameBattleLab
	var authored_enemies := lab.encounter.enemies.duplicate()
	lab.auto_start = false
	lab.enemy_level = 30
	add_child_autofree(lab)

	assert_true(lab.start_benchmark())
	await get_tree().process_frame
	var enemies := lab.battle_scene.manager.get_living_enemies()
	for enemy_index in enemies.size():
		var enemy := enemies[enemy_index] as EnemyCombatant
		var authored_enemy := authored_enemies[enemy_index] as EnemyData
		var unscaled_stats := _enemy_stats_at_level(authored_enemy, lab.enemy_level)
		assert_eq(
			enemy.current_stats.max_hp,
			roundi(unscaled_stats.max_hp * lab.enemy_hp_multiplier),
			enemy.actor_name,
		)
		assert_eq(enemy.current_stats.attack, unscaled_stats.attack, enemy.actor_name)


func test_spawned_heroes_retain_complete_benchmark_kits() -> void:
	var lab := LabScene.instantiate() as EndgameBattleLab
	add_child_autofree(lab)
	await get_tree().process_frame

	assert_true(lab.last_build_succeeded)
	for hero: HeroCombatant in _spawned_heroes(lab):
		for definition: RoleDefinition in hero.hero_data.role_definitions:
			var role := _loaded_role(hero, definition.role_id)
			assert_not_null(role, "%s/%s" % [hero.hero_data.hero_id, definition.role_id])
			if not definition.actions.is_empty():
				assert_eq(role.actions.size(), definition.actions.size(), definition.role_id)
				for action_index in definition.actions.size():
					assert_same(role.actions[action_index], definition.actions[action_index])
			if definition.passive != null:
				assert_same(role.passive, definition.passive, definition.role_id)
			if definition.shift_action != null:
				assert_same(role.shift_action, definition.shift_action, definition.role_id)

	var echo := _spawned_hero_by_id(lab, "echo")
	var psion := _loaded_role(echo, "psi")
	assert_eq(psion.shift_action.action_name, "Shatter")
	assert_true(psion.shift_action.is_shift_action)
	var has_mind_storm := false
	for action: Action in psion.actions:
		if action != null and action.action_name == "Mind Storm":
			has_mind_storm = true
	assert_true(has_mind_storm)

	var asher := _spawned_hero_by_id(lab, "asher")
	var operative := _loaded_role(asher, "opr")
	assert_eq(
		operative.actions.map(func(action: Action) -> String: return action.action_name),
		["Coordinate", "Decoy", "Debilitate", "Ensnare"],
	)
	assert_eq(operative.shift_action.action_name, "Dismantle")
	assert_eq(operative.passive.action_name, "Teamwork")

	var telepath := _loaded_role(echo, "dom")
	assert_eq(telepath.role_name, "Telepath")
	assert_eq(
		telepath.actions.map(func(action: Action) -> String: return action.action_name),
		["Displace", "Feedback", "Static Charge", "Inversion"],
	)
	assert_eq(telepath.shift_action.action_name, "Suppress")
	assert_eq(telepath.passive.action_name, "Precognition")


func test_lab_start_and_result_do_not_mutate_save_or_run_singletons() -> void:
	var before := _snapshot_global_state()
	var lab := LabScene.instantiate() as EndgameBattleLab
	add_child_autofree(lab)
	await get_tree().process_frame

	lab._on_battle_ended(true)

	assert_eq(_snapshot_global_state(), before)


func test_isolation_snapshot_tracks_and_restores_run_manager_roster_alias() -> void:
	var snapshot := _snapshot_global_state()

	assert_has(snapshot, "run_roster")
	RunManager.party_roster.clear()
	RunManager.party_roster.append(HeroData.new())
	_restore_global_state(snapshot)

	assert_eq(RunManager.party_roster, snapshot.run_roster)
	assert_eq(SaveSystem.party_roster, snapshot.roster)


func _snapshot_global_state() -> Dictionary:
	return {
		"slot": SaveSystem.current_slot_index,
		"bits": SaveSystem.bits,
		"data": SaveSystem.data.duplicate(true),
		"roster": SaveSystem.party_roster.duplicate(),
		"run_roster": RunManager.party_roster.duplicate(),
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
	SaveSystem.party_roster.assign(state.run_roster)
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


func _spawned_heroes(lab: EndgameBattleLab) -> Array[HeroCombatant]:
	return lab.battle_scene.manager.get_living_heroes()


func _enemy_stats_at_level(authored_enemy: EnemyData, level: int) -> ActorStats:
	var runtime_enemy := authored_enemy.duplicate(true) as EnemyData
	runtime_enemy.level = level
	runtime_enemy.calculate_stats()
	return runtime_enemy.stats


func _authored_enemy_ids(enemies: Array) -> Array[String]:
	var ids: Array[String] = []
	for enemy: EnemyData in enemies:
		ids.append(enemy.enemy_id)
	return ids


func _spawned_enemy_ids(enemies: Array) -> Array[String]:
	var ids: Array[String] = []
	for enemy: EnemyCombatant in enemies:
		ids.append(enemy.enemy_data.enemy_id)
	return ids


func _spawned_hero_by_id(lab: EndgameBattleLab, hero_id: String) -> HeroCombatant:
	for hero: HeroCombatant in _spawned_heroes(lab):
		if hero.hero_data.hero_id == hero_id:
			return hero
	return null


func _loaded_role(hero: HeroCombatant, role_id: String) -> RoleData:
	for role: RoleData in hero.loaded_roles:
		if role.source_definition.role_id == role_id:
			return role
	return null
