extends GutTest

var calls: Array = []
const TEST_SLOT := 987654
const TEST_SAVE_ROOT := "user://test_saves/hub_progression/"
var saved_roster: Array[HeroData] = []
var saved_slot: int
var saved_storage_root: String


func before_each() -> void:
	calls.clear()
	saved_roster.assign(SaveSystem.party_roster)
	saved_slot = SaveSystem.current_slot_index
	saved_storage_root = SaveSystem.storage_root_override
	SaveSystem.storage_root_override = TEST_SAVE_ROOT
	SaveSystem.current_slot_index = TEST_SLOT
	SaveSystem.party_roster.clear()


func after_each() -> void:
	for tween in get_tree().get_processed_tweens():
		tween.kill()
	for player in AudioManager._sfx_players:
		player.stop()
	SaveSystem.party_roster.assign(saved_roster)
	SaveSystem.current_slot_index = saved_slot
	DirAccess.remove_absolute(SaveSystem._get_slot_path(TEST_SLOT))
	SaveSystem.storage_root_override = saved_storage_root


func _tree() -> RoleTreeDefinition:
	return RoleTreeDefinition.new("gun", 3, [
		ProgressionNodeDefinition.role_anchor("gun.anchor", 1, 0),
		ProgressionNodeDefinition.progression("gun.start1", "gun.anchor", 1, -1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/double_tap.tres", 1), true),
		ProgressionNodeDefinition.progression("gun.start2", "gun.anchor", 1, 1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/fusion_ammo.tres", 2), true),
		ProgressionNodeDefinition.progression("gun.root", "gun.anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.progression("gun.left", "gun.root", 3, -1, 100, ProgressionEffect.stat("AIM", 2)),
		ProgressionNodeDefinition.progression("gun.right", "gun.root", 3, 1, 100, ProgressionEffect.stat("PRE", 2)),
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


func _role(role_id: String) -> RoleDefinition:
	var role := RoleDefinition.new()
	role.role_id = role_id
	role.role_name = role_id.capitalize()
	return role


func _single_tree(role_id: String, cost: int = 100) -> RoleTreeDefinition:
	return _tree_with_paid(role_id, 1, [
		ProgressionNodeDefinition.progression(role_id + ".root", role_id + ".anchor", 2, 0, cost, ProgressionEffect.stat("ATK", 1)),
	])


func _tree_with_paid(role_id: String, version: int, paid_nodes: Array[ProgressionNodeDefinition]) -> RoleTreeDefinition:
	var nodes: Array[ProgressionNodeDefinition] = [
		ProgressionNodeDefinition.role_anchor(role_id + ".anchor", 1, 0),
		ProgressionNodeDefinition.progression(role_id + ".start1", role_id + ".anchor", 1, -1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/double_tap.tres", 1), true),
		ProgressionNodeDefinition.progression(role_id + ".start2", role_id + ".anchor", 1, 1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/fusion_ammo.tres", 2), true),
	]
	nodes.append_array(paid_nodes)
	return RoleTreeDefinition.new(role_id, version, nodes)


func _record_save() -> void:
	calls.append("save")


func _record_audio(cue: String) -> void:
	calls.append(cue)


func _record_real_audio(cue: String) -> void:
	calls.append(cue)
	AudioManager.play_sfx(cue)


func _record_real_save() -> void:
	calls.append("save")
	SaveSystem.save_current_slot()


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
	ui.state = SkillTreeNode.NodeState.AVAILABLE
	ui.set_meta("cursor_state", NavigationCursor.CursorState.UPGRADE)
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

	assert_eq(root.position.y, float(panel.VERTICAL_SPACING))
	assert_lt(left.position.x, root.position.x)
	assert_gt(right.position.x, root.position.x)
	assert_true(root.arrow_left.visible)
	assert_true(root.arrow_right.visible)
	panel.free()


func test_role_panel_renders_focusable_starting_role_header_geometry() -> void:
	var role := _legacy_role()
	role.description = "Reliable ranged pressure."
	var panel := preload("res://src/hub/role_panel.tscn").instantiate() as RolePanel
	add_child(panel)
	panel.setup(role, _tree(), _hero())
	panel.set_expanded(true, 0, false)
	var anchor := panel.generated_nodes["gun.anchor"] as RoleAnchorNode
	var first := panel.generated_nodes["gun.start1"] as SkillTreeNode
	var second := panel.generated_nodes["gun.start2"] as SkillTreeNode
	var paid := panel.generated_nodes["gun.root"] as SkillTreeNode
	var header_center := Vector2(panel.expanded_x / 2.0 - 10.0, 25.0)

	assert_eq(anchor.size, Vector2(250, 50))
	assert_eq(anchor.custom_minimum_size, Vector2(250, 50))
	assert_null(anchor.get_node_or_null("Description"))
	assert_eq(anchor.label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
	assert_eq(first.size, Vector2(250, 50))
	assert_eq(second.size, Vector2(250, 50))
	assert_eq(paid.size, Vector2(250, 50))
	assert_eq(panel.node_positions()["gun.anchor"], header_center)
	assert_eq(panel.node_positions()["gun.start1"], header_center + Vector2.LEFT * panel.HORIZONTAL_SPACING)
	assert_eq(panel.node_positions()["gun.start2"], header_center + Vector2.RIGHT * panel.HORIZONTAL_SPACING)
	assert_eq(panel.node_positions()["gun.root"], header_center + Vector2.DOWN * panel.VERTICAL_SPACING)
	for control: Control in [anchor, first, second, paid]:
		assert_eq(control.focus_mode, Control.FOCUS_ALL)
	assert_eq(anchor.get_node("Label").text, "Gunner")
	assert_false(anchor.has_node("XpCost"))
	assert_eq(anchor.get_meta("cursor_state"), NavigationCursor.CursorState.INTERACT)
	assert_true(anchor.get_node("Arrows/Left").visible)
	assert_true(anchor.get_node("Arrows/Right").visible)
	assert_true(anchor.get_node("Arrows/Down").visible)
	assert_false(first.cost_label.visible)
	assert_false(second.cost_label.visible)
	panel.free()


func test_role_header_navigation_and_confirmation_suppress_non_paid_purchases() -> void:
	var hero := _hero(150)
	hero.role_definitions.assign([_legacy_role()])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_tree()])
	add_child(panel)
	panel.setup(hero)
	watch_signals(panel)

	assert_true(panel.focus_node("gun.anchor"))
	panel.confirm_focused_node()
	assert_signal_not_emitted(panel, "purchase_requested")
	assert_true(panel.move_focus(Vector2.LEFT))
	assert_eq(panel.focused_node_id, "gun.start1")
	panel.confirm_focused_node()
	assert_signal_not_emitted(panel, "purchase_requested")
	assert_true(panel.move_focus(Vector2.RIGHT))
	assert_eq(panel.focused_node_id, "gun.anchor")
	assert_true(panel.move_focus(Vector2.RIGHT))
	assert_eq(panel.focused_node_id, "gun.start2")
	assert_true(panel.move_focus(Vector2.LEFT))
	assert_eq(panel.focused_node_id, "gun.anchor")
	assert_true(panel.move_focus(Vector2.DOWN))
	assert_eq(panel.focused_node_id, "gun.root")
	panel.confirm_focused_node()
	assert_signal_emit_count(panel, "purchase_requested", 1)
	assert_signal_emitted_with_parameters(panel, "purchase_requested", [hero, "gun", "gun.root"])
	panel.free()
	await get_tree().process_frame


func test_real_focus_events_update_stable_id_before_navigation_and_page_restoration() -> void:
	var hero := _hero(150)
	hero.role_definitions.assign([_legacy_role()])
	var tree := _tree_with_paid("gun", 2, [
		ProgressionNodeDefinition.progression("gun.root", "gun.anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.progression("gun.page2", "gun.root", 11, 0, 100, ProgressionEffect.stat("AIM", 1)),
	])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([tree])
	add_child(panel)
	panel.setup(hero)
	var starting := panel._current_role_panel().generated_nodes["gun.start1"] as SkillTreeNode

	starting.grab_focus()
	assert_eq(panel.focused_node_id, "gun.start1")
	assert_true(panel.move_focus(Vector2.RIGHT))
	assert_eq(panel.focused_node_id, "gun.anchor")
	panel.change_page(1)
	assert_eq(panel.focused_node_id, "gun.page2")
	panel.change_page(-1)
	assert_eq(panel.focused_node_id, "gun.anchor")
	assert_eq(get_viewport().gui_get_focus_owner(), panel.get_focused_node())
	panel.free()
	await get_tree().process_frame


func test_rendered_button_activation_only_requests_purchase_for_paid_available_node() -> void:
	var hero := _hero(150)
	hero.role_definitions.assign([_legacy_role()])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_tree()])
	add_child(panel)
	panel.setup(hero)
	var role_panel := panel._current_role_panel()
	var anchor := role_panel.generated_nodes["gun.anchor"] as Button
	var starting := role_panel.generated_nodes["gun.start1"] as SkillTreeNode
	var paid := role_panel.generated_nodes["gun.root"] as SkillTreeNode
	watch_signals(panel)
	assert_false(paid.toggle_mode)
	assert_false(starting.toggle_mode)

	anchor.pressed.emit()
	assert_signal_not_emitted(panel, "purchase_requested")
	starting._pressed()
	assert_false(starting.button_pressed)
	assert_signal_not_emitted(panel, "purchase_requested")
	paid._pressed()
	assert_false(paid.button_pressed)
	assert_signal_emit_count(panel, "purchase_requested", 1)
	assert_signal_emitted_with_parameters(panel, "purchase_requested", [hero, "gun", "gun.root"])
	assert_true(starting.owned_highlight.visible)
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
	assert_false(sibling.disabled)
	assert_eq(sibling.get_meta("cursor_state"), NavigationCursor.CursorState.INTERACT)
	assert_eq(sibling.get_instance_id(), sibling_id)
	assert_eq(panel.current_role_idx, 0)
	assert_eq(panel.current_page, 0)
	panel.free()
	await get_tree().process_frame


func test_stale_double_click_runs_success_side_effects_and_tree_refresh_once() -> void:
	var hero := _hero()
	hero.role_definitions.assign([_legacy_role()])
	var catalog := ProgressionCatalog.from_validated_trees([_tree()])
	var menu := preload("res://src/hub/party_menu.tscn").instantiate() as PartyMenu
	menu.progression_catalog = catalog
	menu.progression_service = ProgressionService.new(catalog, func(_purchased_hero): return true)
	menu.save_progression = _record_save
	menu.play_progression_audio = _record_audio
	menu.refresh_hero_stats = _record_stats
	SaveSystem.party_roster.assign([hero])
	add_child(menu)
	menu.open()
	watch_signals(menu.skill_view)
	var role_panel := menu.skill_view.role_list_container.get_child(0) as RolePanel
	var node := role_panel.generated_nodes["gun.root"] as SkillTreeNode

	node.node_clicked.emit(node)
	node.node_clicked.emit(node)

	assert_eq(calls.count("terminal"), 1)
	assert_eq(calls.count("press"), 0)
	assert_eq(calls.count("save"), 1)
	assert_eq(calls.count("stats"), 1)
	assert_signal_emit_count(menu.skill_view, "progression_refreshed", 1)
	menu.free()
	await get_tree().process_frame


func test_success_refreshes_all_matching_roles_and_leaves_other_hero_unchanged() -> void:
	var hero := _hero(150)
	hero.unlocked_role_ids.assign(["gun", "snp"])
	hero.role_definitions.assign([_role("gun"), _role("snp")])
	var other := _hero(999)
	other.hero_id = "echo"
	other.unlocked_role_ids.assign(["other"])
	other.role_definitions.assign([_role("other")])
	var catalog := ProgressionCatalog.from_validated_trees([_single_tree("gun"), _single_tree("snp"), _single_tree("other")])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = catalog
	add_child(panel)
	panel.setup(hero)
	var first := panel.role_list_container.get_child(0) as RolePanel
	var sibling := panel.role_list_container.get_child(1) as RolePanel
	var sibling_node := sibling.generated_nodes["snp.root"] as SkillTreeNode
	var sibling_id := sibling_node.get_instance_id()
	var other_panel := preload("res://src/hub/role_panel.tscn").instantiate() as RolePanel
	add_child(other_panel)
	other_panel.setup(_role("other"), catalog.get_role("other"), other)
	other_panel.set_expanded(true, 0, false)
	var other_text := other_panel.xp_display.text
	var other_node := other_panel.generated_nodes["other.root"] as SkillTreeNode
	var other_node_id := other_node.get_instance_id()
	var other_disabled := other_node.disabled
	ProgressionService.new(catalog, func(_purchased_hero): return true).purchase_node(hero, "gun", "gun.root")

	panel.refresh_progression_state(hero)

	assert_eq(first.xp_display.text, "50 XP")
	assert_eq(sibling.xp_display.text, "50 XP")
	assert_false(sibling_node.disabled)
	assert_eq(sibling_node.get_meta("cursor_state"), NavigationCursor.CursorState.DISABLED)
	assert_eq(sibling_node.get_instance_id(), sibling_id)
	assert_eq(other_panel.xp_display.text, other_text)
	assert_eq(other_node.get_instance_id(), other_node_id)
	assert_eq(other_node.disabled, other_disabled)
	other_panel.free()
	panel.free()
	await get_tree().process_frame


func test_real_party_menu_purchase_writes_save_refreshes_matching_card_and_tree_once() -> void:
	var asher := load("res://data/heroes/asher/asher.tres").duplicate(true) as HeroData
	var echo := load("res://data/heroes/echo/echo.tres").duplicate(true) as HeroData
	asher.current_xp = 250
	var catalog := ProgressionCatalog.from_validated_trees([_tree()])
	SaveSystem.party_roster.assign([asher, echo])
	var menu := preload("res://src/hub/party_menu.tscn").instantiate() as PartyMenu
	menu.progression_catalog = catalog
	menu.progression_service = ProgressionService.new(catalog, func(_purchased_hero): return true)
	menu.save_progression = _record_real_save
	menu.play_progression_audio = _record_real_audio
	add_child(menu)
	menu.open()
	var asher_card := menu.hero_list_container.get_child(0) as HeroPanel
	var echo_card := menu.hero_list_container.get_child(1) as HeroPanel
	asher_card.atk.text = "STALE"
	var echo_before := [echo_card.hp.text, echo_card.atk.text, echo_card.psy.text]
	watch_signals(menu.skill_view)
	var role_panel := menu.skill_view.role_list_container.get_child(0) as RolePanel
	var node := role_panel.generated_nodes["gun.root"] as SkillTreeNode

	node.node_clicked.emit(node)

	var saved := JSON.parse_string(FileAccess.get_file_as_string(SaveSystem._get_slot_path(TEST_SLOT))) as Dictionary
	assert_eq(int(saved.heroes[0].current_xp), 150)
	assert_eq(saved.heroes[0].role_progress.gun.owned_node_ids, ["gun.root"])
	assert_eq(calls.count("save"), 1)
	assert_eq(calls.count("terminal"), 1)
	assert_ne(asher_card.atk.text, "STALE")
	assert_eq([echo_card.hp.text, echo_card.atk.text, echo_card.psy.text], echo_before)
	assert_signal_emit_count(menu.skill_view, "progression_refreshed", 1)
	menu.free()
	await get_tree().process_frame


func test_partial_catalog_selects_and_expands_first_rendered_role() -> void:
	var hero := _hero()
	hero.unlocked_role_ids.assign(["missing", "gun"])
	hero.role_definitions.assign([_role("missing"), _role("gun")])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_tree()])
	add_child(panel)

	panel.setup(hero)

	assert_eq(panel.role_list_container.get_child_count(), 1)
	assert_eq(panel.current_role_idx, 0)
	var rendered := panel.role_list_container.get_child(0) as RolePanel
	assert_true(rendered.is_currently_expanded)
	assert_eq(rendered.role_id, "gun")
	panel.free()
	await get_tree().process_frame


func test_skill_navigation_changes_page_and_role_and_restores_stable_node() -> void:
	var hero := _hero()
	hero.unlocked_role_ids.assign(["gun", "snp"])
	hero.role_definitions.assign([_role("gun"), _role("snp")])
	var page_tree := _tree_with_paid("gun", 2, [
		ProgressionNodeDefinition.progression("gun.root", "gun.anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.new("gun.page2", "gun.root", 11, 0, 100, ProgressionEffect.stat("AIM", 1)),
	])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([page_tree, _single_tree("snp")])
	add_child(panel)
	panel.setup(hero)
	assert_true(panel.focus_node("gun.root"))
	panel.change_page(1)
	assert_eq(panel.current_page, 1)
	assert_eq(panel.focused_node_id, "gun.page2")
	panel.change_page(-1)
	assert_eq(panel.focused_node_id, "gun.root")
	panel.change_role(1)
	assert_eq(panel.current_role_idx, 1)
	panel.change_role(-1)
	assert_eq(panel.focused_node_id, "gun.root")
	panel.free()
	await get_tree().process_frame


func test_confirm_emits_existing_purchase_signal_once_and_locked_node_is_inspectable() -> void:
	var hero := _hero(150)
	hero.role_definitions.assign([_legacy_role()])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_tree()])
	add_child(panel)
	panel.setup(hero)
	assert_true(panel.focus_node("gun.left"))
	var locked := panel.get_focused_node()
	assert_false(locked.disabled)
	assert_eq(locked.get_meta("cursor_state"), NavigationCursor.CursorState.INTERACT)
	watch_signals(panel)
	panel.confirm_focused_node()
	assert_signal_not_emitted(panel, "purchase_requested")
	assert_true(panel.focus_node("gun.root"))
	panel.confirm_focused_node()
	assert_signal_emitted_with_parameters(panel, "purchase_requested", [hero, "gun", "gun.root"])
	assert_signal_emit_count(panel, "purchase_requested", 1)
	assert_eq(hero.current_xp, 150)
	assert_true(hero.role_progress.is_empty())
	panel.free()
	await get_tree().process_frame


func test_inventory_and_equipment_controls_publish_controller_semantics() -> void:
	var item := preload("res://src/hub/item_button.tscn").instantiate() as ItemButton
	add_child(item)
	assert_eq(item.get_focus_control().focus_mode, Control.FOCUS_ALL)
	assert_eq(item.get_focus_control().get_meta("cursor_state"), NavigationCursor.CursorState.CAN_GRAB)
	item.set_dragging(true)
	assert_eq(item.get_focus_control().get_meta("cursor_state"), NavigationCursor.CursorState.DRAGGING)
	var slot := preload("res://src/hub/mod_slot.tscn").instantiate() as ModSlot
	add_child(slot)
	slot.setup(null, true)
	slot.set_drop_validity(true)
	assert_eq(slot.get_focus_control().get_meta("cursor_state"), NavigationCursor.CursorState.INTERACT)
	slot.set_drop_validity(false)
	assert_eq(slot.get_focus_control().get_meta("cursor_state"), NavigationCursor.CursorState.DISABLED)
	item.free()
	slot.free()


func test_cancel_moves_from_node_to_page_layer_before_leaving_skill_panel() -> void:
	var hero := _hero()
	hero.role_definitions.assign([_legacy_role()])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_tree()])
	add_child(panel)
	panel.setup(hero)
	panel.focus_node("gun.root")
	assert_true(panel.cancel_focus_layer())
	assert_true(panel.tabs_container.get_child(panel.current_page).has_focus())
	assert_false(panel.cancel_focus_layer())
	panel.free()
	await get_tree().process_frame


func test_inventory_cancel_returns_outward_without_mutating_active_item() -> void:
	var panel := preload("res://src/hub/inventory_panel.tscn").instantiate() as InventoryPanel
	add_child(panel)
	var item := Equipment.new()
	panel.active_equipment = item
	panel.current_mode = InventoryPanel.Mode.EQUIP
	assert_true(panel.cancel_navigation())
	assert_eq(panel.current_mode, InventoryPanel.Mode.VIEW)
	assert_null(panel.active_equipment)
	assert_false(panel.cancel_navigation())
	panel.free()


func test_reentering_hero_restores_role_page_and_stable_node_context() -> void:
	var hero := _hero()
	hero.unlocked_role_ids.assign(["gun", "snp"])
	hero.role_definitions.assign([_role("gun"), _role("snp")])
	var other := _hero()
	other.hero_id = "echo"
	other.role_definitions.assign([_legacy_role()])
	var gun := _tree_with_paid("gun", 2, [
		ProgressionNodeDefinition.progression("gun.root", "gun.anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.new("gun.page2", "gun.root", 11, 0, 100, ProgressionEffect.stat("AIM", 1)),
	])
	var snp := _tree_with_paid("snp", 2, [
		ProgressionNodeDefinition.progression("snp.root", "snp.anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.new("snp.page2", "snp.root", 11, 0, 100, ProgressionEffect.stat("AIM", 1)),
	])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([gun, snp])
	add_child(panel)
	panel.setup(hero)
	panel.change_role(1)
	panel.change_page(1)
	panel.focus_node("snp.page2")
	panel.setup(other)
	panel.setup(hero)
	assert_eq(panel.current_role_idx, 1)
	assert_eq(panel.current_page, 1)
	assert_eq(panel.focused_node_id, "snp.page2")
	panel.free()
	await get_tree().process_frame


func test_role_change_selects_closest_supported_page_and_keeps_focus() -> void:
	var hero := _hero()
	hero.unlocked_role_ids.assign(["gun", "snp"])
	hero.role_definitions.assign([_role("gun"), _role("snp")])
	var gun := _tree_with_paid("gun", 2, [
		ProgressionNodeDefinition.progression("gun.root", "gun.anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.new("gun.page2", "gun.root", 11, 1, 100, ProgressionEffect.stat("AIM", 1)),
	])
	var snp := _tree_with_paid("snp", 3, [
		ProgressionNodeDefinition.progression("snp.root", "snp.anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.new("snp.page3", "snp.root", 21, 0, 100, ProgressionEffect.stat("AIM", 1)),
	])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([gun, snp])
	add_child(panel)
	panel.setup(hero)
	panel.change_page(1)
	assert_eq(panel.current_page, 1)
	var source_center := panel._current_role_panel().node_positions()["gun.page2"] as Vector2
	panel.change_role(1)
	assert_eq(panel.current_page, 0, "equal-distance supported pages prefer the lower page")
	assert_eq(panel.focused_node_id, "snp.start2")
	var target_positions := panel._current_role_panel().node_positions()
	assert_eq(target_positions["snp.start2"], source_center, "the starting skill occupies the exact prior screen coordinate")
	assert_lt(
		(target_positions["snp.start2"] as Vector2).distance_squared_to(source_center),
		(target_positions["snp.root"] as Vector2).distance_squared_to(source_center),
		"nearest-focus restoration must choose the zero-distance starting skill over the paid root",
	)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.get_focused_node())
	panel.free()
	await get_tree().process_frame


func test_inventory_spawn_path_retains_dragging_and_links_every_enabled_slot() -> void:
	var party := preload("res://src/hub/party_menu.tscn").instantiate() as PartyMenu
	add_child(party)
	party.show()
	var panel := party.inventory_view
	panel.show()
	panel.current_mode = InventoryPanel.Mode.EQUIP
	var first := panel._spawn_grid_button(load("res://data/equipment/weapons/pistol.tres"), Equipment.Slot.WEAPON, 1) as ItemButton
	var second := panel._spawn_grid_button(load("res://data/equipment/weapons/rifle.tres"), Equipment.Slot.WEAPON, 1) as ItemButton
	var third := panel._spawn_grid_button(load("res://data/equipment/weapons/smg.tres"), Equipment.Slot.WEAPON, 1) as ItemButton
	assert_eq(first.get_focus_control().get_meta("cursor_state"), NavigationCursor.CursorState.DRAGGING)
	assert_eq(second.get_focus_control().get_meta("cursor_state"), NavigationCursor.CursorState.DRAGGING)
	assert_eq(first.get_focus_control().focus_neighbor_bottom, first.get_focus_control().get_path_to(second.get_focus_control()))
	assert_eq(second.get_focus_control().focus_neighbor_bottom, second.get_focus_control().get_path_to(third.get_focus_control()))
	assert_eq(third.get_focus_control().focus_neighbor_bottom, third.get_focus_control().get_path_to(first.get_focus_control()))
	watch_signals(second)
	second.get_focus_control().grab_focus()
	party._unhandled_input(_action_event(&"confirm"))
	assert_signal_emit_count(second, "pressed", 1)
	party.free()


func test_equipment_panel_reuse_with_null_clears_and_disables_controller_actions() -> void:
	var panel := preload("res://src/hub/equipment_panel.tscn").instantiate() as EquipmentPanel
	add_child(panel)
	panel.setup(load("res://data/equipment/weapons/pistol.tres"))
	panel.setup(null)
	assert_null(panel.equipment)
	assert_true(panel.equip_button.disabled)
	assert_true(panel.tune_btn.disabled)
	assert_eq(panel.equip_button.focus_mode, Control.FOCUS_NONE)
	assert_eq(panel.tune_btn.focus_mode, Control.FOCUS_NONE)
	assert_false(panel.xp_container.visible)
	assert_eq(panel.xp_label.text, "")
	assert_eq(panel.rank_label.text, "")
	watch_signals(panel)
	panel._on_equip_btn_pressed()
	panel._on_tune_btn_pressed()
	assert_signal_not_emitted(panel, "equip_requested")
	assert_signal_not_emitted(panel, "tune_requested")
	panel.free()


func test_invalid_mod_drop_uses_disabled_cursor_without_focus_override() -> void:
	var slot := preload("res://src/hub/mod_slot.tscn").instantiate() as ModSlot
	add_child(slot)
	slot.setup(null, true)
	slot.get_focus_control().grab_focus()
	NavigationFocus.apply(slot.get_focus_control())
	slot.set_drop_validity(false)
	assert_eq(slot.get_focus_control().get_meta("cursor_state"), NavigationCursor.CursorState.DISABLED)
	assert_false(slot.get_focus_control().has_theme_stylebox_override(&"focus"))
	NavigationFocus.clear(slot.get_focus_control())
	slot.free()


func test_shoulder_events_change_pages_and_roles_at_node_focus() -> void:
	var hero := _hero()
	hero.unlocked_role_ids.assign(["gun", "snp"])
	hero.role_definitions.assign([_role("gun"), _role("snp")])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_tree(), _single_tree("snp")])
	add_child(panel)
	panel.setup(hero)
	panel.focus_node("gun.root")
	var root := panel.get_focused_node()
	panel._unhandled_input(_action_event(&"page_next"))
	assert_eq(panel.current_page, 0)
	assert_eq(panel.get_focused_node(), root)
	assert_eq(get_viewport().gui_get_focus_owner(), root)
	panel._unhandled_input(_action_event(&"section_next"))
	assert_eq(panel.current_role_idx, 1)
	panel.get_focused_node().release_focus()
	panel._unhandled_input(_action_event(&"section_previous"))
	assert_eq(panel.current_role_idx, 0, "role shoulders remain active at every focus depth")
	panel.free()
	await get_tree().process_frame


func test_keyboard_and_controller_skill_navigation_synchronize_cursor_without_changing_keyboard_family() -> void:
	var hero := _hero()
	hero.role_definitions.assign([_legacy_role()])
	var navigation := preload("res://src/ui/navigation/navigation_ux_layer.tscn").instantiate() as NavigationUXLayer
	navigation.name = "NavigationUXLayer"
	add_child(navigation)
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_tree()])
	add_child(panel)
	panel.setup(hero)
	navigation.register_screen(panel, panel.get_focused_node())
	panel.focus_node("gun.start1")
	await get_tree().process_frame
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_D
	keyboard.pressed = true
	InputManager._input(keyboard)
	panel._unhandled_input(_action_event(&"nav_right"))
	await get_tree().process_frame
	var keyboard_target := panel.get_focused_node()
	var keyboard_anchor: Vector2 = keyboard_target.get_meta("cursor_anchor", keyboard_target.size * 0.5)
	var keyboard_destination := keyboard_target.get_global_transform_with_canvas() * keyboard_anchor
	navigation.cursor.update_position_for_behavior(InputManager.get_cursor_behavior(), Vector2.ZERO, true)
	assert_eq(panel.focused_node_id, "gun.anchor")
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.KEYBOARD_MOUSE)
	assert_eq(InputManager._expected_warp_position, keyboard_destination)
	panel.focus_node("gun.start2")
	await get_tree().process_frame
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_DPAD_LEFT
	controller.pressed = true
	InputManager._input(controller)
	panel._unhandled_input(_action_event(&"nav_left"))
	await get_tree().process_frame
	var controller_target := panel.get_focused_node()
	var controller_anchor: Vector2 = controller_target.get_meta("cursor_anchor", controller_target.size * 0.5)
	var controller_destination := controller_target.get_global_transform_with_canvas() * controller_anchor
	navigation.cursor.update_position_for_behavior(InputManager.get_cursor_behavior(), Vector2.ZERO, true)
	assert_eq(panel.focused_node_id, "gun.anchor")
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
	assert_eq(InputManager._expected_warp_position, controller_destination)
	panel.free()
	navigation.free()
	await get_tree().process_frame


func test_single_page_role_omits_page_shoulder_hints() -> void:
	var hero := _hero()
	hero.role_definitions.assign([_legacy_role()])
	var navigation := preload("res://src/ui/navigation/navigation_ux_layer.tscn").instantiate() as NavigationUXLayer
	navigation.name = "NavigationUXLayer"
	add_child(navigation)
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_single_tree("gun")])
	add_child(panel)
	panel.setup(hero)
	panel.focus_node("gun.root")
	panel._publish_hints(panel.get_focused_node())
	var actions: Array[StringName] = []
	for index in navigation.hint_bar.get_hint_count():
		actions.append(navigation.hint_bar.get_hint(index).action)
	assert_does_not_have(actions, &"page_previous", "one-page roles must not advertise L1 paging")
	assert_does_not_have(actions, &"page_next", "one-page roles must not advertise R1 paging")
	panel.free()
	navigation.free()
	await get_tree().process_frame


func test_page_shoulder_wraps_across_supported_pages_and_focuses_nearest_node() -> void:
	var hero := _hero()
	hero.role_definitions.assign([_legacy_role()])
	var tree := _tree_with_paid("gun", 3, [
		ProgressionNodeDefinition.progression("gun.root", "gun.anchor", 2, 1, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.new("gun.page3.near", "gun.root", 21, 1, 100, ProgressionEffect.stat("AIM", 1)),
		ProgressionNodeDefinition.new("gun.page3.far", "gun.root", 22, -1, 100, ProgressionEffect.stat("PRE", 1)),
	])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([tree])
	add_child(panel)
	panel.setup(hero)
	panel.focus_node("gun.root")
	panel._unhandled_input(_action_event(&"page_next"))
	assert_eq(panel.current_page, 2)
	assert_eq(panel.focused_node_id, "gun.page3.near")
	assert_eq(get_viewport().gui_get_focus_owner(), panel.get_focused_node())
	panel._unhandled_input(_action_event(&"page_next"))
	assert_eq(panel.current_page, 0)
	assert_eq(panel.focused_node_id, "gun.root")
	panel._unhandled_input(_action_event(&"page_previous"))
	assert_eq(panel.current_page, 2)
	panel.free()
	await get_tree().process_frame


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
