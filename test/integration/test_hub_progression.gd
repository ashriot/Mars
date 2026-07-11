extends GutTest

const TEST_SLOT := 987653

var _saved_data: Dictionary
var _saved_roster: Array[HeroData]
var _saved_slot: int
var _test_save_path: String
var _test_save_existed: bool
var _test_save_bytes: PackedByteArray


func before_each() -> void:
	_saved_data = SaveSystem.data
	_saved_roster.assign(SaveSystem.party_roster)
	_saved_slot = SaveSystem.current_slot_index
	_test_save_path = SaveSystem._get_slot_path(TEST_SLOT)
	_test_save_existed = FileAccess.file_exists(_test_save_path)
	if _test_save_existed:
		_test_save_bytes = FileAccess.get_file_as_bytes(_test_save_path)
	SaveSystem.current_slot_index = TEST_SLOT
	SaveSystem.data = {}
	SaveSystem.party_roster.clear()


func after_each() -> void:
	SaveSystem.data = _saved_data
	SaveSystem.party_roster.assign(_saved_roster)
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


func test_successful_purchase_spends_unlocks_rebuilds_and_emits_once() -> void:
	var purchase := _make_purchase()
	var panel: RolePanel = purchase.panel
	var hero: HeroData = purchase.hero
	watch_signals(panel)

	panel._on_node_clicked(purchase.ui)

	assert_eq(hero.current_xp, 150)
	assert_eq(hero.unlocked_node_ids, ["test_1"])
	assert_true(hero.battle_roles.has("test"))
	assert_signal_emit_count(panel, "hero_progression_updated", 1)
	_free_purchase(purchase)


func test_stale_owned_click_spends_nothing_and_emits_nothing() -> void:
	var purchase := _make_purchase()
	var panel: RolePanel = purchase.panel
	var hero: HeroData = purchase.hero
	hero.unlocked_node_ids.append("test_1")
	watch_signals(panel)

	panel._on_node_clicked(purchase.ui)

	assert_eq(hero.current_xp, 250)
	assert_eq(hero.unlocked_node_ids.count("test_1"), 1)
	assert_signal_emit_count(panel, "hero_progression_updated", 0)
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
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	add_child_autofree(panel)
	watch_signals(panel)

	panel.setup(hero)
	var spawned_role_panel := panel.role_list_container.get_child(0) as RolePanel
	spawned_role_panel.hero_progression_updated.emit(hero)

	assert_signal_emit_count(panel, "hero_progression_updated", 1)
	_free_purchase(purchase)


func test_party_menu_saves_and_refreshes_stat_card_immediately() -> void:
	var purchase := _make_purchase()
	var hero: HeroData = purchase.hero
	SaveSystem.party_roster.assign([hero])
	var menu := preload("res://src/hub/party_menu.tscn").instantiate() as PartyMenu
	add_child_autofree(menu)
	menu.open()
	var card := menu.hero_list_container.get_child(0) as HeroPanel
	var attack_before := card.atk.text

	hero.unlocked_node_ids.append("test_1")
	hero.current_xp = 150
	menu._on_hero_progression_updated(hero)

	var saved := JSON.parse_string(FileAccess.get_file_as_string(_test_save_path)) as Dictionary
	assert_eq(int(saved.heroes[0].current_xp), 150)
	assert_eq(saved.heroes[0].unlocked_node_ids, ["test_1"])
	assert_ne(card.atk.text, attack_before)
	_free_purchase(purchase)
