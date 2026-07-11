extends GutTest

var calls: Array = []


func before_each() -> void:
	calls.clear()


func _tree() -> RoleTreeDefinition:
	return RoleTreeDefinition.new("gun", 3, [
		ProgressionNodeDefinition.new("gun.root", "", 1, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.new("gun.left", "gun.root", 2, -1, 100, ProgressionEffect.stat("AIM", 2)),
		ProgressionNodeDefinition.new("gun.right", "gun.root", 2, 1, 100, ProgressionEffect.stat("PRE", 2)),
	])


func _hero(xp: int = 250) -> HeroData:
	var hero := HeroData.new()
	hero.hero_id = "asher"
	hero.current_xp = xp
	hero.unlocked_role_ids.assign(["gun"])
	return hero


func _legacy_role() -> RoleDefinition:
	var role := RoleDefinition.new()
	role.role_id = "gun"
	role.role_name = "Gunner"
	return role


func _record_save() -> void:
	calls.append("save")


func _record_audio(cue: String) -> void:
	calls.append(cue)


func _record_stats(_purchased_hero: HeroData) -> void:
	calls.append("stats")


func test_role_panel_submits_stable_ids_without_mutating_progression() -> void:
	var hero := _hero()
	var panel := RolePanel.new()
	panel.hero_data = hero
	panel.role_id = "gun"
	panel.is_currently_expanded = true
	var ui := SkillTreeNode.new()
	ui.node_definition = _tree().get_node("gun.root")
	watch_signals(panel)

	panel._on_node_clicked(ui)

	assert_signal_emitted_with_parameters(panel, "purchase_requested", [hero, "gun", "gun.root"])
	assert_eq(hero.current_xp, 250)
	assert_true(hero.role_progress.is_empty())
	ui.free()
	panel.free()


func test_role_panel_renders_explicit_rank_column_and_indexed_links() -> void:
	var panel := preload("res://src/hub/role_panel.tscn").instantiate() as RolePanel
	add_child(panel)
	panel.setup(_legacy_role(), _tree(), _hero())
	panel.set_expanded(true, 0, false)
	var root := panel.generated_nodes["gun.root"] as SkillTreeNode
	var left := panel.generated_nodes["gun.left"] as SkillTreeNode
	var right := panel.generated_nodes["gun.right"] as SkillTreeNode

	assert_eq(root.position.y, 0.0)
	assert_lt(left.position.x, root.position.x)
	assert_gt(right.position.x, root.position.x)
	assert_true(root.arrow_left.visible)
	assert_true(root.arrow_right.visible)
	panel.free()
	await get_tree().process_frame


func test_party_menu_owns_exactly_once_success_chain_and_refreshes_in_place() -> void:
	var hero := _hero()
	var catalog := ProgressionCatalog.from_validated_trees([_tree()])
	var menu := PartyMenu.new()
	menu.progression_service = ProgressionService.new(catalog, func(_purchased_hero): return true)
	menu.save_progression = _record_save
	menu.play_progression_audio = _record_audio
	menu.refresh_hero_stats = _record_stats

	menu._on_purchase_requested(hero, "gun", "gun.root")

	assert_eq(calls, ["terminal", "save", "stats"])
	assert_eq(hero.current_xp, 150)
	assert_eq(hero.role_progress.gun.owned_node_ids, ["gun.root"])
	menu.free()


func test_rejected_purchase_has_feedback_but_no_save_or_refresh() -> void:
	var hero := _hero(50)
	var catalog := ProgressionCatalog.from_validated_trees([_tree()])
	var menu := PartyMenu.new()
	menu.progression_service = ProgressionService.new(catalog, func(_purchased_hero): return true)
	menu.save_progression = _record_save
	menu.play_progression_audio = _record_audio
	menu.refresh_hero_stats = _record_stats

	menu._on_purchase_requested(hero, "gun", "gun.root")

	assert_eq(calls, ["press"])
	assert_eq(hero.current_xp, 50)
	assert_true(hero.role_progress.is_empty())
	menu.free()


func test_refresh_preserves_role_page_and_node_identity_and_updates_xp_affordability() -> void:
	var hero := _hero(150)
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	add_child(panel)
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_tree()])
	hero.role_definitions.assign([_legacy_role()])
	panel.setup(hero)
	var role_panel := panel.role_list_container.get_child(0) as RolePanel
	var sibling := role_panel.generated_nodes["gun.right"] as SkillTreeNode
	var sibling_id := sibling.get_instance_id()
	panel.current_role_idx = 0
	panel.current_page = 0
	hero.current_xp = 50

	panel.refresh_progression_state(hero)

	assert_eq(role_panel.xp_display.text, "50 XP")
	assert_true(sibling.disabled)
	assert_eq(sibling.get_instance_id(), sibling_id)
	assert_eq(panel.current_role_idx, 0)
	assert_eq(panel.current_page, 0)
	panel.free()
	await get_tree().process_frame
