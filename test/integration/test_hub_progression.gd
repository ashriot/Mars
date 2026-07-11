extends GutTest

const TEST_SLOT := 987653

var _saved_data: Dictionary
var _saved_roster: Array[HeroData]
var _saved_slot: int
var _saved_bits: int
var _saved_total_xp: int
var _saved_inventory: Dictionary
var _saved_equipment: Array[Equipment]
var _saved_mods: Array[EquipmentMod]
var _test_save_path: String
var _test_save_existed: bool
var _test_save_bytes: PackedByteArray


func before_each() -> void:
	_saved_data = SaveSystem.data
	_saved_roster.assign(SaveSystem.party_roster)
	_saved_slot = SaveSystem.current_slot_index
	_saved_bits = SaveSystem.bits
	_saved_total_xp = SaveSystem.total_lifetime_xp
	_saved_inventory = SaveSystem.inventory
	_saved_equipment.assign(SaveSystem.inventory_equipment)
	_saved_mods.assign(SaveSystem.inventory_mods)
	_test_save_path = SaveSystem._get_slot_path(TEST_SLOT)
	_test_save_existed = FileAccess.file_exists(_test_save_path)
	if _test_save_existed:
		_test_save_bytes = FileAccess.get_file_as_bytes(_test_save_path)
	SaveSystem.current_slot_index = TEST_SLOT
	SaveSystem.data = {}
	SaveSystem.party_roster.clear()
	SaveSystem.bits = 0
	SaveSystem.total_lifetime_xp = 0
	SaveSystem.inventory = {}
	SaveSystem.inventory_equipment.clear()
	SaveSystem.inventory_mods.clear()


func after_each() -> void:
	for player in AudioManager._sfx_players:
		player.stop()
	SaveSystem.data = _saved_data
	SaveSystem.party_roster.assign(_saved_roster)
	SaveSystem.bits = _saved_bits
	SaveSystem.total_lifetime_xp = _saved_total_xp
	SaveSystem.inventory = _saved_inventory
	SaveSystem.inventory_equipment.assign(_saved_equipment)
	SaveSystem.inventory_mods.assign(_saved_mods)
	if _test_save_existed:
		var file := FileAccess.open(_test_save_path, FileAccess.WRITE)
		file.store_buffer(_test_save_bytes)
	else:
		DirAccess.remove_absolute(_test_save_path)
	SaveSystem.current_slot_index = _saved_slot


func _make_purchase(cost: int = 100) -> Dictionary:
	var node := RoleNode.new()
	node.generated_id = "test_1"
	node.calculated_xp_cost = cost
	node.stat_type = ActorStats.Stats.ATK
	node.stat_value = 5
	var definition := RoleDefinition.new()
	definition.role_id = "test"
	definition.root_node = node
	var hero := HeroData.new()
	hero.hero_id = "test"
	hero.hero_name = "Test"
	hero.current_xp = 250
	hero.role_definitions.assign([definition])
	hero.unlocked_role_ids.assign(["test"])
	var role_panel := RolePanel.new()
	role_panel.hero_data = hero
	role_panel.def = definition
	role_panel.is_currently_expanded = true
	var ui_node := SkillTreeNode.new()
	ui_node.role_node_data = node
	return {"hero": hero, "node": node, "panel": role_panel, "ui": ui_node}


func _free_purchase(purchase: Dictionary) -> void:
	(purchase.ui as SkillTreeNode).free()
	(purchase.panel as RolePanel).free()


func _displayed_stat(panel: HeroPanel, stat: ActorStats.Stats) -> String:
	match stat:
		ActorStats.Stats.HP: return panel.hp.text
		ActorStats.Stats.GRD: return panel.guard.text
		ActorStats.Stats.FOC: return panel.focus.text
		ActorStats.Stats.ATK: return panel.atk.text
		ActorStats.Stats.PSY: return panel.psy.text
		ActorStats.Stats.OVR: return panel.ovr.text
		ActorStats.Stats.SPD: return panel.spd.text
		ActorStats.Stats.AIM: return panel.aim.text
		ActorStats.Stats.PRE: return panel.pre.text
		ActorStats.Stats.KIN_DEF: return panel.kin.text
		ActorStats.Stats.NRG_DEF: return panel.nrg.text
	return ""


func _kill_test_tweens() -> void:
	for tween in get_tree().get_processed_tweens():
		tween.kill()


func test_successful_purchase_spends_unlocks_rebuilds_and_emits_once() -> void:
	var purchase := _make_purchase()
	var panel: RolePanel = purchase.panel
	var hero: HeroData = purchase.hero
	watch_signals(panel)

	panel._on_node_clicked(purchase.ui)

	assert_eq(hero.current_xp, 150)
	assert_eq(250 - hero.current_xp, purchase.node.calculated_xp_cost)
	assert_eq(hero.unlocked_node_ids.count("test_1"), 1)
	assert_true(hero.battle_roles.has("test"))
	assert_signal_emit_count(panel, "hero_progression_updated", 1)
	assert_true(is_same(get_signal_parameters(panel, "hero_progression_updated")[0], hero))
	_free_purchase(purchase)


func test_stale_double_click_spends_and_emits_only_once() -> void:
	var purchase := _make_purchase()
	var panel: RolePanel = purchase.panel
	var hero: HeroData = purchase.hero
	watch_signals(panel)

	panel._on_node_clicked(purchase.ui)
	panel._on_node_clicked(purchase.ui)

	assert_eq(hero.current_xp, 150)
	assert_eq(hero.unlocked_node_ids.count("test_1"), 1)
	assert_signal_emit_count(panel, "hero_progression_updated", 1)
	_free_purchase(purchase)


func test_unaffordable_click_emits_nothing() -> void:
	var purchase := _make_purchase(300)
	var panel: RolePanel = purchase.panel
	var hero: HeroData = purchase.hero
	var save_bytes_before := FileAccess.get_file_as_bytes(_test_save_path) if FileAccess.file_exists(_test_save_path) else PackedByteArray()
	watch_signals(panel)

	panel._on_node_clicked(purchase.ui)

	assert_eq(hero.current_xp, 250)
	assert_true(hero.unlocked_node_ids.is_empty())
	assert_signal_emit_count(panel, "hero_progression_updated", 0)
	var save_bytes_after := FileAccess.get_file_as_bytes(_test_save_path) if FileAccess.file_exists(_test_save_path) else PackedByteArray()
	assert_eq(save_bytes_after, save_bytes_before)
	_free_purchase(purchase)


func test_skill_tree_panel_forwards_progression_once() -> void:
	var purchase := _make_purchase()
	var hero: HeroData = purchase.hero
	var second_definition := RoleDefinition.new()
	second_definition.role_id = "second"
	second_definition.root_node = RoleNode.new()
	hero.role_definitions.append(second_definition)
	hero.unlocked_role_ids.append("second")
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	add_child(panel)
	watch_signals(panel)

	panel.setup(hero)
	assert_eq(panel.role_list_container.get_child_count(), 2)
	var first_role_panel := panel.role_list_container.get_child(0) as RolePanel
	var second_role_panel := panel.role_list_container.get_child(1) as RolePanel
	assert_true(first_role_panel.hero_progression_updated.is_connected(panel._on_hero_progression_updated))
	assert_true(second_role_panel.hero_progression_updated.is_connected(panel._on_hero_progression_updated))
	first_role_panel.hero_progression_updated.emit(hero)
	second_role_panel.hero_progression_updated.emit(hero)

	assert_signal_emit_count(panel, "hero_progression_updated", 2)
	assert_true(is_same(get_signal_parameters(panel, "hero_progression_updated", 0)[0], hero))
	assert_true(is_same(get_signal_parameters(panel, "hero_progression_updated", 1)[0], hero))
	_free_purchase(purchase)
	_kill_test_tweens()
	panel.free()
	await get_tree().process_frame


func test_purchase_refreshes_affordability_on_matching_sibling_without_rerender() -> void:
	var hero := HeroData.new()
	hero.hero_id = "shared"
	hero.hero_name = "Shared"
	hero.current_xp = 150
	for role_id in ["first", "second"]:
		var node := RoleNode.new()
		node.generated_id = role_id + "_1"
		node.calculated_xp_cost = 100
		node.stat_type = ActorStats.Stats.ATK
		node.stat_value = 1
		var definition := RoleDefinition.new()
		definition.role_id = role_id
		definition.role_name = role_id.capitalize()
		definition.root_node = node
		hero.role_definitions.append(definition)
		hero.unlocked_role_ids.append(role_id)

	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	add_child(panel)
	panel.setup(hero)
	var first_role_panel := panel.role_list_container.get_child(0) as RolePanel
	var sibling_role_panel := panel.role_list_container.get_child(1) as RolePanel
	var first_node := first_role_panel.generated_nodes.values()[0] as SkillTreeNode
	var sibling_node := sibling_role_panel.generated_nodes.values()[0] as SkillTreeNode
	var sibling_node_id := sibling_node.get_instance_id()
	var role_index_before := panel.current_role_idx
	var page_before := panel.current_page
	assert_eq(sibling_node.state, SkillTreeNode.NodeState.AVAILABLE)
	assert_false(sibling_node.disabled)
	assert_eq(sibling_node.modulate, Color.WHITE)

	var other_hero := HeroData.new()
	other_hero.hero_id = "other"
	other_hero.hero_name = "Other"
	other_hero.current_xp = 999
	var other_definition := RoleDefinition.new()
	other_definition.role_id = "other"
	other_definition.role_name = "Other"
	other_definition.root_node = RoleNode.new()
	var nonmatching_panel := panel.role_panel_scene.instantiate() as RolePanel
	panel.role_list_container.add_child(nonmatching_panel)
	nonmatching_panel.setup(other_definition, other_hero)
	nonmatching_panel.set_expanded(false, panel.current_page, false)
	other_hero.current_xp = 500
	var nonmatching_xp_text_before := nonmatching_panel.xp_display.text
	watch_signals(panel)

	first_node.node_clicked.emit(first_node)

	assert_eq(hero.current_xp, 50)
	assert_eq(sibling_node.get_instance_id(), sibling_node_id)
	assert_eq(sibling_node.state, SkillTreeNode.NodeState.AVAILABLE)
	assert_true(sibling_node.disabled)
	assert_ne(sibling_node.modulate, Color.WHITE)
	assert_eq(sibling_role_panel.xp_display.text, "50 XP")
	assert_eq(panel.current_role_idx, role_index_before)
	assert_eq(panel.current_page, page_before)
	assert_eq(nonmatching_panel.xp_display.text, nonmatching_xp_text_before)
	assert_signal_emit_count(panel, "hero_progression_updated", 1)
	assert_true(is_same(get_signal_parameters(panel, "hero_progression_updated")[0], hero))
	_kill_test_tweens()
	panel.free()
	await get_tree().process_frame


func test_party_menu_real_purchase_saves_and_refreshes_only_matching_card() -> void:
	var asher := load("res://data/heroes/asher/asher.tres").duplicate(true) as HeroData
	var echo := load("res://data/heroes/echo/echo.tres").duplicate(true) as HeroData
	asher.current_xp = 1000
	SaveSystem.party_roster.assign([asher, echo])
	var menu := preload("res://src/hub/party_menu.tscn").instantiate() as PartyMenu
	add_child(menu)
	menu.open()
	var asher_card := menu.hero_list_container.get_child(0) as HeroPanel
	var echo_card := menu.hero_list_container.get_child(1) as HeroPanel
	var echo_values_before := [echo_card.hp.text, echo_card.atk.text, echo_card.psy.text]
	var first_role_panel := menu.skill_view.role_list_container.get_child(0) as RolePanel
	var second_role_panel := menu.skill_view.role_list_container.get_child(1) as RolePanel
	first_role_panel.set_expanded(false, 0, false)
	second_role_panel.set_expanded(true, 0, false)
	menu.skill_view.current_role_idx = 1
	menu.skill_view.current_page = 3
	var role_index_before := menu.skill_view.current_role_idx
	var page_before := menu.skill_view.current_page
	var target_node: RoleNode
	var target_ui: SkillTreeNode
	for node in second_role_panel.generated_nodes:
		if node.type == RoleNode.RewardType.STAT and not node.generated_id in asher.unlocked_node_ids:
			target_node = node
			target_ui = second_role_panel.generated_nodes[node]
			break
	assert_not_null(target_node)
	assert_not_null(target_ui)
	var asher_stat_before := _displayed_stat(asher_card, target_node.stat_type)
	var xp_before := asher.current_xp
	watch_signals(second_role_panel)
	watch_signals(menu.skill_view)

	target_ui.node_clicked.emit(target_ui)

	var saved := JSON.parse_string(FileAccess.get_file_as_string(_test_save_path)) as Dictionary
	assert_eq(int(saved.heroes[0].current_xp), xp_before - target_node.calculated_xp_cost)
	assert_eq(saved.heroes[0].unlocked_node_ids.count(target_node.generated_id), 1)
	assert_ne(_displayed_stat(asher_card, target_node.stat_type), asher_stat_before)
	assert_eq([echo_card.hp.text, echo_card.atk.text, echo_card.psy.text], echo_values_before)
	assert_eq(menu.skill_view.current_role_idx, role_index_before)
	assert_eq(menu.skill_view.current_page, page_before)
	assert_signal_emit_count(second_role_panel, "hero_progression_updated", 1)
	assert_signal_emit_count(menu.skill_view, "hero_progression_updated", 1)
	assert_true(is_same(get_signal_parameters(menu.skill_view, "hero_progression_updated")[0], asher))
	_kill_test_tweens()
	menu.free()
	await get_tree().process_frame
