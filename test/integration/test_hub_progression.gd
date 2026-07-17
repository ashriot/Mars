extends GutTest

var calls: Array = []
const TEST_SLOT := 987654
const TEST_SAVE_ROOT := "user://test_saves/hub_progression/"
var saved_roster: Array[HeroData] = []
var saved_slot: int
var saved_storage_root: String
var saved_input_mode: InputManager.InputMode
var saved_presentation_mode: InputManager.PresentationMode
var saved_inventory_equipment: Array[Equipment] = []


func before_each() -> void:
	calls.clear()
	saved_roster.assign(SaveSystem.party_roster)
	saved_slot = SaveSystem.current_slot_index
	saved_storage_root = SaveSystem.storage_root_override
	saved_input_mode = InputManager._active_mode
	saved_presentation_mode = InputManager._presentation_mode
	saved_inventory_equipment.assign(SaveSystem.inventory_equipment)
	SaveSystem.storage_root_override = TEST_SAVE_ROOT
	SaveSystem.current_slot_index = TEST_SLOT
	SaveSystem.party_roster.clear()


func after_each() -> void:
	for tween in get_tree().get_processed_tweens():
		tween.kill()
	for player in AudioManager._sfx_players:
		player.stop()
	SaveSystem.party_roster.assign(saved_roster)
	SaveSystem.inventory_equipment.assign(saved_inventory_equipment)
	SaveSystem.current_slot_index = saved_slot
	DirAccess.remove_absolute(SaveSystem._get_slot_path(TEST_SLOT))
	SaveSystem.storage_root_override = saved_storage_root
	InputManager._active_mode = saved_input_mode
	InputManager._presentation_mode = saved_presentation_mode


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


func _opened_party_with_three_heroes() -> PartyMenu:
	SaveSystem.party_roster.assign([
		load("res://data/heroes/asher/asher.tres").duplicate(true),
		load("res://data/heroes/echo/echo.tres").duplicate(true),
		load("res://data/heroes/sands/sands.tres").duplicate(true),
	])
	var party := preload("res://src/hub/party_menu.tscn").instantiate() as PartyMenu
	add_child_autofree(party)
	party.open()
	await get_tree().process_frame
	return party


func _assert_visible_controls_have_no_navigation_focus_pulse(node: Node) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		assert_false(node.has_meta("navigation_focus_pulse"), "%s must not use navigation focus pulse metadata" % node.get_path())
	for child in node.get_children():
		_assert_visible_controls_have_no_navigation_focus_pulse(child)


func test_hero_xp_uses_adaptive_shorthand() -> void:
	var expected := {
		-1: "0",
		0: "0",
		9999: "9,999",
		10000: "10.0K",
		99949: "99.9K",
		99950: "100K",
		200000: "200K",
		1000000: "1.0M",
		1260000: "1.3M",
	}
	for value: int in expected:
		assert_eq(HeroPanel.format_xp(value), expected[value], str(value))


func test_role_panel_swaps_names_and_exact_xp_before_expansion_tween() -> void:
	var panel := preload("res://src/hub/role_panel.tscn").instantiate() as RolePanel
	add_child(panel)
	panel.setup(_legacy_role(), _tree(), _hero(200000))
	panel.set_expanded(false, 0, false)

	assert_true(panel.header_label.visible)
	assert_false(panel.role_name_label.visible)
	assert_false(panel.xp_display.visible)
	panel.set_expanded(true, 0, true)
	assert_false(panel.header_label.visible, "abbreviation hides synchronously before the width tween advances")
	assert_true(panel.role_name_label.visible, "full role name shows synchronously before the width tween advances")
	assert_true(panel.xp_display.visible, "exact XP shows synchronously before the width tween advances")
	assert_eq(panel.xp_display.text, "AVAILABLE XP 200,000")
	panel.free()


func _skill_panel_with_multi_page_role() -> SkillTreePanel:
	var hero := _hero()
	hero.unlocked_role_ids.assign(["gun", "snp"])
	hero.role_definitions.assign([_role("gun"), _role("snp")])
	var gun := _tree_with_paid("gun", 2, [
		ProgressionNodeDefinition.progression("gun.atk_1", "gun.anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.new("gun.page2", "gun.atk_1", 11, 0, 100, ProgressionEffect.stat("AIM", 1)),
	])
	var snp := RoleTreeDefinition.new("snp", 1, [
		ProgressionNodeDefinition.role_anchor("snp.zz_anchor", 1, 0),
		ProgressionNodeDefinition.progression("snp.zz_start1", "snp.zz_anchor", 1, -1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/double_tap.tres", 1), true),
		ProgressionNodeDefinition.progression("snp.zz_start2", "snp.zz_anchor", 1, 1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/fusion_ammo.tres", 2), true),
		ProgressionNodeDefinition.progression("snp.aaa", "snp.zz_anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
	])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([gun, snp])
	add_child(panel)
	panel.setup(hero)
	return panel


func test_party_opens_on_expanded_hero_and_up_down_select_immediately() -> void:
	var party := await _opened_party_with_three_heroes()
	assert_eq(party.current_depth, PartyMenu.Depth.HERO_RAIL)
	assert_eq(party.current_hero_idx, 0)
	assert_same(get_viewport().gui_get_focus_owner(), party.hero_list_container.get_child(0))
	party.hero_list_container.get_child(1).grab_focus()
	await get_tree().process_frame
	assert_eq(party.current_hero_idx, 1)
	assert_true((party.hero_list_container.get_child(1) as HeroPanel)._is_expanded)
	assert_false((party.hero_list_container.get_child(0) as HeroPanel)._is_expanded)


func test_roles_unwind_hero_role_tree_one_depth_at_a_time() -> void:
	var party := await _opened_party_with_three_heroes()
	assert_true(party.enter_content())
	assert_eq(party.skill_view.navigation_depth, SkillTreePanel.NavigationDepth.ROLE_SELECT)
	assert_same(get_viewport().gui_get_focus_owner(), party.skill_view._current_role_panel())
	party._unhandled_input(_action_event(&"confirm"))
	assert_eq(party.skill_view.navigation_depth, SkillTreePanel.NavigationDepth.TREE)
	assert_same(get_viewport().gui_get_focus_owner(), party.skill_view.get_focused_node())
	party._unhandled_input(_action_event(&"cancel"))
	assert_eq(party.skill_view.navigation_depth, SkillTreePanel.NavigationDepth.ROLE_SELECT)
	assert_same(get_viewport().gui_get_focus_owner(), party.skill_view._current_role_panel())
	party._unhandled_input(_action_event(&"cancel"))
	assert_eq(party.current_depth, PartyMenu.Depth.HERO_RAIL)


func test_role_selection_uses_down_to_enter_and_left_right_clamp() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	assert_true(panel.enter_role_select())
	assert_false(panel.select_adjacent_role(-1), "role selection does not wrap before the first role")
	assert_eq(panel.current_role_idx, 0)
	panel._unhandled_input(_action_event(&"nav_right"))
	assert_eq(panel.current_role_idx, 1)
	assert_same(get_viewport().gui_get_focus_owner(), panel._current_role_panel())
	assert_false(panel.select_adjacent_role(1), "role selection does not wrap after the last role")
	panel._unhandled_input(_action_event(&"nav_down"))
	assert_eq(panel.navigation_depth, SkillTreePanel.NavigationDepth.TREE)
	assert_same(get_viewport().gui_get_focus_owner(), panel.get_focused_node())
	panel.free()
	await get_tree().process_frame


func test_role_selection_ignores_page_triggers_until_tree_entry() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	assert_true(panel.enter_role_select())
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(panel.current_page, 0)
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	assert_true(panel.enter_tree())
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(panel.current_page, 1)
	panel.free()
	await get_tree().process_frame


func test_roles_publish_depth_specific_hints_without_role_shoulders() -> void:
	var navigation := preload("res://src/ui/navigation/navigation_ux_layer.tscn").instantiate() as NavigationUXLayer
	navigation.name = "NavigationUXLayer"
	add_child(navigation)
	var panel := await _skill_panel_with_multi_page_role()
	assert_true(panel.enter_role_select())
	var role_hints := {}
	for index in navigation.hint_bar.get_hint_count():
		var hint := navigation.hint_bar.get_hint(index)
		role_hints[hint.action] = hint.label.text
	assert_eq(role_hints, {
		&"confirm": "Open Role",
		&"cancel": "Back",
	})
	assert_true(panel.enter_tree())
	var tree_hints := {}
	for index in navigation.hint_bar.get_hint_count():
		var hint := navigation.hint_bar.get_hint(index)
		tree_hints[hint.action] = hint.label.text
	assert_eq(tree_hints.get(&"confirm"), "Inspect")
	assert_eq(tree_hints.get(&"cancel"), "Back")
	assert_eq(tree_hints.get(&"hub_page_previous"), "Previous Page")
	assert_eq(tree_hints.get(&"hub_page_next"), "Next Page")
	assert_false(tree_hints.has(&"hub_role_previous"))
	assert_false(tree_hints.has(&"hub_role_next"))
	panel.free()
	navigation.free()
	await get_tree().process_frame


func test_roles_remember_role_per_hero_but_reenter_at_role_selection() -> void:
	var party := await _opened_party_with_three_heroes()
	assert_true(party.enter_content())
	assert_true(party.skill_view.select_adjacent_role(1))
	var remembered_role := party.skill_view._current_role_panel().role_id
	assert_true(party.skill_view.enter_tree())
	party._select_hero(1)
	party._select_hero(0)
	assert_eq(party.skill_view._current_role_panel().role_id, remembered_role)
	assert_eq(party.skill_view.navigation_depth, SkillTreePanel.NavigationDepth.ROLE_SELECT)
	assert_same(get_viewport().gui_get_focus_owner(), party.skill_view._current_role_panel())
	party.change_tab(1)
	party.change_tab(-1)
	assert_eq(party.skill_view._current_role_panel().role_id, remembered_role)
	assert_eq(party.skill_view.navigation_depth, SkillTreePanel.NavigationDepth.ROLE_SELECT)


func test_role_memory_uses_role_id_across_reorder_and_missing_role_fallback() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	var hero := panel.current_hero
	assert_true(panel.enter_role_select())
	assert_true(panel.select_adjacent_role(1))
	assert_eq(panel._current_role_panel().role_id, "snp")
	panel.remember_focus()

	hero.role_definitions.assign([_role("snp"), _role("gun")])
	panel.setup(hero)
	assert_true(panel.enter_role_select())
	assert_eq(panel.current_role_idx, 0)
	assert_eq(panel._current_role_panel().role_id, "snp", "semantic role memory survives authored reorder")

	hero.unlocked_role_ids.assign(["gun"])
	hero.role_definitions.assign([_role("snp"), _role("gun")])
	panel.setup(hero)
	assert_true(panel.enter_role_select())
	assert_eq(panel.current_role_idx, 0)
	assert_eq(panel._current_role_panel().role_id, "gun", "missing remembered role falls back to first rendered role")
	panel.free()
	await get_tree().process_frame


func test_node_memory_never_leaks_between_heroes_at_role_selection() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	var hero_a := panel.current_hero
	var hero_b := _hero()
	hero_b.hero_id = "echo"
	hero_b.role_definitions.assign([_legacy_role()])
	assert_true(panel.focus_node("gun.atk_1"))

	panel.setup(hero_b)
	assert_true(panel.enter_role_select())
	assert_eq(panel.focused_node_id, "", "new hero loads only its own remembered node context")
	panel.setup(hero_a)
	assert_true(panel.enter_role_select())
	panel.setup(hero_b)
	assert_true(panel.enter_role_select())
	assert_true(panel.enter_tree())
	assert_ne(panel.focused_node_id, "gun.atk_1", "leaving the second hero at role selection does not persist the first hero's node")

	panel.setup(hero_a)
	assert_true(panel.enter_role_select())
	assert_true(panel.enter_tree())
	assert_eq(panel.focused_node_id, "gun.atk_1", "the first hero retains its own stable node")
	panel.free()
	await get_tree().process_frame


func test_role_selection_disables_tree_focus_and_rejects_node_activation_until_entry() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	assert_true(panel.enter_role_select())
	var node := panel._current_role_panel().generated_nodes["gun.atk_1"] as SkillTreeNode
	assert_eq(node.focus_mode, Control.FOCUS_NONE)
	assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab)
	await get_tree().process_frame
	assert_true(get_viewport().gui_get_focus_owner() is RolePanel, "Tab remains isolated to role selection targets")
	watch_signals(panel)
	node._pressed()
	assert_signal_not_emitted(panel, "purchase_requested")

	assert_true(panel.enter_tree())
	assert_eq(node.focus_mode, Control.FOCUS_ALL)
	assert_eq(node.mouse_filter, Control.MOUSE_FILTER_STOP)
	var collapsed_node := (panel.role_list_container.get_child(1) as RolePanel).generated_nodes["snp.aaa"] as SkillTreeNode
	assert_eq(collapsed_node.focus_mode, Control.FOCUS_NONE)
	assert_eq(collapsed_node.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	node._pressed()
	assert_signal_emitted_with_parameters(panel, "purchase_requested", [panel.current_hero, "gun", "gun.atk_1"])
	assert_signal_emit_count(panel, "purchase_requested", 1)
	panel.free()
	await get_tree().process_frame


func test_role_selection_profile_changes_keep_every_tree_node_isolated() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	assert_true(panel.enter_role_select())
	for profile in [DisplayProfileService.Profile.COMPACT, DisplayProfileService.Profile.DESKTOP]:
		panel.apply_display_profile(profile, Vector2i.ZERO, Vector2.ZERO)
		assert_eq(panel.navigation_depth, SkillTreePanel.NavigationDepth.ROLE_SELECT)
		for child in panel.role_list_container.get_children():
			var role_panel := child as RolePanel
			assert_eq(role_panel.focus_mode, Control.FOCUS_ALL)
			for node: Control in role_panel.generated_nodes.values():
				assert_eq(node.focus_mode, Control.FOCUS_NONE)
				assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		get_viewport().push_input(tab)
		await get_tree().process_frame
		var owner := get_viewport().gui_get_focus_owner()
		for child in panel.role_list_container.get_children():
			for node: Control in (child as RolePanel).generated_nodes.values():
				assert_false(owner == node or (owner != null and node.is_ancestor_of(owner)), "Tab cannot enter a generated tree node")
	assert_false(panel.cancel_navigation(), "Back still belongs to the outward depth at role selection")
	panel.free()
	await get_tree().process_frame


func test_tree_profile_change_restores_current_node_and_only_current_tree_interaction() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	assert_true(panel.enter_tree())
	assert_true(panel.focus_node("gun.atk_1"))
	panel.apply_display_profile(DisplayProfileService.Profile.COMPACT, Vector2i.ZERO, Vector2.ZERO)
	assert_eq(panel.navigation_depth, SkillTreePanel.NavigationDepth.TREE)
	assert_eq(panel.focused_node_id, "gun.atk_1")
	assert_same(get_viewport().gui_get_focus_owner(), panel.get_focused_node())
	for index in range(panel.role_list_container.get_child_count()):
		var role_panel := panel.role_list_container.get_child(index) as RolePanel
		assert_eq(role_panel.focus_mode, Control.FOCUS_NONE)
		for node: Control in role_panel.generated_nodes.values():
			var expected_focus := Control.FOCUS_ALL if index == panel.current_role_idx else Control.FOCUS_NONE
			var expected_mouse := Control.MOUSE_FILTER_STOP if index == panel.current_role_idx else Control.MOUSE_FILTER_IGNORE
			assert_eq(node.focus_mode, expected_focus)
			assert_eq(node.mouse_filter, expected_mouse)
	assert_true(panel.cancel_navigation())
	assert_eq(panel.navigation_depth, SkillTreePanel.NavigationDepth.ROLE_SELECT)
	assert_same(get_viewport().gui_get_focus_owner(), panel._current_role_panel())
	panel.free()
	await get_tree().process_frame


func test_role_selection_is_safe_without_rendered_roles_or_tree_nodes() -> void:
	var no_roles := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	no_roles.progression_catalog = ProgressionCatalog.from_validated_trees([])
	add_child(no_roles)
	no_roles.setup(_hero())
	assert_false(no_roles.enter_role_select())
	assert_false(no_roles.enter_tree())
	assert_false(no_roles.cancel_navigation())
	no_roles.free()

	var empty := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	empty.progression_catalog = ProgressionCatalog.from_validated_trees([_tree()])
	add_child(empty)
	var hero := _hero()
	hero.role_definitions.assign([_legacy_role()])
	empty.setup(hero)
	empty.current_page = 4
	empty._current_role_panel().render_tree(empty.current_page)
	assert_true(empty.enter_role_select())
	assert_false(empty.enter_tree())
	assert_eq(empty.navigation_depth, SkillTreePanel.NavigationDepth.ROLE_SELECT)
	empty.free()
	await get_tree().process_frame


func test_roles_are_spatial_and_rank_pages_use_triggers() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	var role_before := panel.current_role_idx
	panel._on_role_panel_selected(panel.role_list_container.get_child(1))
	assert_eq(panel.current_role_idx, posmod(role_before + 1, panel.role_list_container.get_child_count()))
	panel._on_role_panel_selected(panel.role_list_container.get_child(0))
	panel.focus_node(panel._nearest_node_id(panel._current_role_panel()))
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(panel.current_page, 1)
	assert_true(panel.focus_current_page_tab())
	assert_true(panel.tabs_container.is_ancestor_of(get_viewport().gui_get_focus_owner()) or get_viewport().gui_get_focus_owner() in panel.tabs_container.get_children())
	assert_true(panel.focus_node_from_page_tabs())
	assert_true(panel._node_owns_focus())
	panel.free()
	await get_tree().process_frame


func test_page_triggers_require_roles_owner_and_tree_or_page_focus() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	var ownership := {"owns_roles": false}
	panel.set_role_navigation_owner(func() -> bool: return ownership.owns_roles)
	panel.focus_node(panel._nearest_node_id(panel._current_role_panel()))
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(panel.current_page, 0, "non-owner does not route page triggers")
	ownership.owns_roles = true
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(panel.current_page, 1, "Roles tree focus owns page triggers")
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	var outsider := Button.new()
	add_child_autofree(outsider)
	outsider.grab_focus()
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(panel.current_page, 1, "focus outside tree and page strip does not route triggers")
	panel.free()
	await get_tree().process_frame


func test_roles_same_frame_rebuild_restores_focus_to_current_role() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	assert_true(panel.focus_node("gun.atk_1"))
	var hero := panel.current_hero
	panel.setup(hero)
	assert_true(panel.enter_role_select())
	assert_eq(panel.role_list_container.get_child_count(), 2, "retired role panels are detached immediately")
	var immediate_focus := get_viewport().gui_get_focus_owner()
	assert_same(immediate_focus, panel._current_role_panel())
	assert_false(immediate_focus.is_queued_for_deletion())
	await get_tree().process_frame
	var settled_focus := get_viewport().gui_get_focus_owner()
	assert_not_null(settled_focus)
	if settled_focus:
		assert_same(settled_focus, panel._current_role_panel())
		assert_false(settled_focus.is_queued_for_deletion())
	panel.free()
	await get_tree().process_frame


func test_roles_single_role_rebuild_has_one_panel_and_no_obsolete_role_glyphs() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	var hero := _hero()
	hero.unlocked_role_ids.assign(["gun"])
	hero.role_definitions.assign([_role("gun")])
	panel.setup(hero)
	assert_eq(panel.role_list_container.get_child_count(), 1)
	var role_panel := panel.role_list_container.get_child(0) as RolePanel
	assert_false(role_panel.has_node("Content/PreviousRoleGlyph"))
	assert_false(role_panel.has_node("Content/NextRoleGlyph"))
	await get_tree().process_frame
	assert_eq(panel.role_list_container.get_child_count(), 1)
	panel.free()
	await get_tree().process_frame


func test_roles_restore_stable_node_per_hero_role_and_page() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	assert_true(panel.focus_node("gun.atk_1"))
	var remembered: String = panel.remember_focus()
	assert_eq(remembered, "gun.atk_1")
	panel.change_role(1)
	panel.change_role(-1)
	assert_true(panel.restore_focus())
	assert_eq(panel.focused_node_id, "gun.atk_1")
	assert_same(get_viewport().gui_get_focus_owner(), panel._current_role_panel())
	assert_true(panel.enter_tree())
	assert_eq(panel.focused_node_id, "gun.atk_1")
	panel.free()
	await get_tree().process_frame


func test_party_content_entry_back_and_stub_tabs_keep_focus_valid() -> void:
	var party := await _opened_party_with_three_heroes()
	assert_true(party.enter_content())
	assert_eq(party.current_depth, PartyMenu.Depth.CONTENT)
	assert_true(party.skill_view.is_ancestor_of(get_viewport().gui_get_focus_owner()))
	party.change_tab(1)
	assert_eq(party.current_tab, PartyMenu.Tab.ITEMS)
	party.change_tab(1)
	assert_eq(party.current_tab, PartyMenu.Tab.OPTIONS)
	assert_eq(party.current_depth, PartyMenu.Depth.HERO_RAIL)
	assert_same(get_viewport().gui_get_focus_owner(), party.hero_list_container.get_child(party.current_hero_idx))
	assert_true(party.get_node("Content/OptionsComingSoon").visible)
	party.change_tab(1)
	assert_true(party.get_node("Content/JournalComingSoon").visible)
	party.change_tab(1)
	assert_eq(party.current_tab, PartyMenu.Tab.ROLES)


func test_analog_page_trigger_requires_release_before_another_page_move() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	panel.focus_node(panel._nearest_node_id(panel._current_role_panel()))
	var press := _joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	panel._unhandled_input(press)
	assert_eq(panel.current_page, 1)
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 0.92))
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 0.81))
	assert_eq(panel.current_page, 1, "held trigger changes exactly one page")
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	panel._unhandled_input(press)
	assert_eq(panel.current_page, 0, "release rearms the trigger")
	panel.free()
	await get_tree().process_frame


func test_analog_page_trigger_rearms_when_released_under_nested_modal() -> void:
	var navigation := preload("res://src/ui/navigation/navigation_ux_layer.tscn").instantiate() as NavigationUXLayer
	navigation.name = "NavigationUXLayer"
	add_child_autofree(navigation)
	await get_tree().process_frame
	var panel := await _skill_panel_with_multi_page_role()
	panel.focus_node(panel._nearest_node_id(panel._current_role_panel()))
	navigation.push_modal(panel, panel.get_focused_node())
	panel.set_role_navigation_owner(func() -> bool: return navigation.is_top_modal(panel))
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(panel.current_page, 1)
	var nested := Control.new()
	add_child_autofree(nested)
	navigation.push_modal(nested, null, true, true)
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	navigation.pop_modal(nested)
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(panel.current_page, 0, "release under a nested modal rearms the next pull")
	panel.free()
	await get_tree().process_frame


func test_hub_focus_and_depth_styles_never_change_content_colors() -> void:
	var party := await _opened_party_with_three_heroes()
	var hero := party.hero_list_container.get_child(0) as HeroPanel
	var header_style: StyleBox = hero.get_node("Content/Header").get_theme_stylebox(&"panel")
	var hp_modulate: Color = hero.get_node("Content/Stats/Summary/HP").modulate
	var role := party.skill_view.role_list_container.get_child(0) as RolePanel
	var role_header_modulate: Color = role.get_node("Header").modulate
	assert_false(hero.has_meta("navigation_focus_pulse"))
	assert_false(hero.has_node("FocusOutline"))
	_assert_visible_controls_have_no_navigation_focus_pulse(party)
	assert_true(party.enter_content())
	assert_same(hero.get_node("Content/Header").get_theme_stylebox(&"panel"), header_style)
	assert_eq(hero.get_node("Content/Stats/Summary/HP").modulate, hp_modulate)
	assert_eq(role.get_node("Header").modulate, role_header_modulate)
	party.return_to_hero_rail()
	assert_same(hero.get_node("Content/Header").get_theme_stylebox(&"panel"), header_style)
	assert_eq(hero.get_node("Content/Stats/Summary/HP").modulate, hp_modulate)
	assert_eq(role.get_node("Header").modulate, role_header_modulate)

	var replacement := hero.data.weapon.duplicate(true) as Equipment
	SaveSystem.inventory_equipment.assign([replacement])
	party.change_tab(1)
	assert_true(party.enter_content())
	party.inventory_view.request_equip_mode(hero.data.weapon, Equipment.Slot.WEAPON)
	var item := party.inventory_view.grid.get_child(0) as ItemButton
	var item_header_modulate: Color = item.get_node("Button/Header").modulate
	assert_false(item.has_node("Button/FocusOutline"))
	_assert_visible_controls_have_no_navigation_focus_pulse(party)
	party.return_to_hero_rail()
	assert_same(hero.get_node("Content/Header").get_theme_stylebox(&"panel"), header_style)
	assert_eq(hero.get_node("Content/Stats/Summary/HP").modulate, hp_modulate)
	assert_eq(item.get_node("Button/Header").modulate, item_header_modulate)


func test_items_mode_pulses_change_only_dedicated_outer_edges() -> void:
	var party := await _opened_party_with_three_heroes()
	party.change_tab(1)
	assert_true(party.enter_content())
	var hero := party.hero_list_container.get_child(0) as HeroPanel
	var equipment := hero.weapon_panel
	var header_modulate := equipment.header.modulate
	var gauge := equipment.get_node("Border/Content/XP/Gauge") as Control
	var gauge_modulate := gauge.modulate
	equipment.set_visual_state("equip")
	equipment._highlight_tween.custom_step(0.25)
	assert_eq(equipment.header.modulate, header_modulate)
	assert_eq(gauge.modulate, gauge_modulate)
	assert_ne(equipment.get_node("ModeOutline").modulate.a, 0.0)

	var slot := equipment.mods_container.get_child(0) as ModSlot
	var slot_content_modulate := slot.self_modulate
	slot.pulse(Color.CYAN)
	slot._pulse_tween.custom_step(0.25)
	assert_eq(slot.self_modulate, slot_content_modulate)
	assert_true(slot.has_node("SelectionOutline"))
	assert_ne(slot.get_node("SelectionOutline").modulate, Color.WHITE)


func test_pointer_tab_and_hero_selection_update_controller_context() -> void:
	var party := await _opened_party_with_three_heroes()
	party.tab_buttons[PartyMenu.Tab.ITEMS].pressed.emit()
	assert_eq(party.current_tab, PartyMenu.Tab.ITEMS)
	var second := party.hero_list_container.get_child(1) as HeroPanel
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	second._gui_input(click)
	assert_eq(party.current_hero_idx, 1)
	party.return_to_hero_rail()
	assert_same(get_viewport().gui_get_focus_owner(), second)


func test_pointer_back_returns_to_hero_rail_before_closing() -> void:
	var party := await _opened_party_with_three_heroes()
	assert_true(party.enter_content())
	assert_eq(party.current_depth, PartyMenu.Depth.CONTENT)
	assert_true(party.skill_view.is_ancestor_of(get_viewport().gui_get_focus_owner()))

	party.back_button.pressed.emit()
	assert_true(party.visible)
	assert_eq(party.current_depth, PartyMenu.Depth.HERO_RAIL)
	assert_same(get_viewport().gui_get_focus_owner(), party.hero_list_container.get_child(0))

	party.back_button.pressed.emit()
	assert_false(party.visible)


func test_items_back_unwinds_mode_before_returning_to_hero() -> void:
	var party := await _opened_party_with_three_heroes()
	party.change_tab(1)
	assert_true(party.enter_content())
	var hero_panel := party.hero_list_container.get_child(party.current_hero_idx) as HeroPanel
	party.inventory_view.request_equip_mode(hero_panel.data.weapon, Equipment.Slot.WEAPON)
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.EQUIP)
	party._unhandled_input(_action_event(&"cancel"))
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.VIEW)
	assert_eq(party.current_depth, PartyMenu.Depth.CONTENT)
	party._unhandled_input(_action_event(&"cancel"))
	assert_eq(party.current_depth, PartyMenu.Depth.HERO_RAIL)


func test_items_nested_back_restores_each_originating_equipment_control() -> void:
	var party := await _opened_party_with_three_heroes()
	party.change_tab(1)
	assert_true(party.enter_content())
	var hero_panel := party.hero_list_container.get_child(party.current_hero_idx) as HeroPanel
	var weapon := hero_panel.weapon_panel

	weapon.equip_button.pressed.emit()
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.EQUIP)
	hero_panel.armor_panel.equip_button.grab_focus()
	party._unhandled_input(_action_event(&"cancel"))
	assert_same(get_viewport().gui_get_focus_owner(), weapon.equip_button)

	weapon.equip_button.grab_focus()
	party._unhandled_input(_action_event(&"hub_upgrade"))
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.TUNE)
	hero_panel.armor_panel.equip_button.grab_focus()
	party._unhandled_input(_action_event(&"cancel"))
	assert_same(get_viewport().gui_get_focus_owner(), weapon.equip_button)

	hero_panel.data.weapon.tier = 1
	weapon.setup(hero_panel.data.weapon)
	var mod_slot := weapon.mods_container.get_child(0) as ModSlot
	mod_slot.get_focus_control().pressed.emit()
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.MOD)
	hero_panel.armor_panel.equip_button.grab_focus()
	party._unhandled_input(_action_event(&"cancel"))
	assert_same(get_viewport().gui_get_focus_owner(), mod_slot.get_focus_control())


func test_items_restore_stable_equipment_and_inventory_focus() -> void:
	var party := await _opened_party_with_three_heroes()
	party.change_tab(1)
	assert_true(party.enter_content())
	var hero_panel := party.hero_list_container.get_child(0) as HeroPanel
	hero_panel.armor_panel.equip_button.grab_focus()
	party.return_to_hero_rail()
	assert_true(party.enter_content())
	assert_same(get_viewport().gui_get_focus_owner(), hero_panel.armor_panel.equip_button)


func test_items_use_equipment_rows_and_controller_upgrade_hotkey() -> void:
	var replacement := (load("res://data/equipment/weapons/rifle.tres") as Equipment).duplicate(true) as Equipment
	SaveSystem.inventory_equipment.assign([replacement])
	var party := await _opened_party_with_three_heroes()
	party.change_tab(1)
	assert_true(party.enter_content())
	var hero := party.hero_list_container.get_child(0) as HeroPanel
	var weapon := hero.weapon_panel
	var armor := hero.armor_panel
	assert_same(get_viewport().gui_get_focus_owner(), weapon.equip_button)
	assert_eq(weapon.tune_btn.focus_mode, Control.FOCUS_NONE)
	assert_eq(weapon.equip_button.focus_neighbor_bottom, weapon.equip_button.get_path_to(armor.equip_button))
	assert_eq(armor.equip_button.focus_neighbor_top, armor.equip_button.get_path_to(weapon.equip_button))

	party._unhandled_input(_action_event(&"hub_upgrade"))
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.TUNE)
	party._unhandled_input(_action_event(&"cancel"))
	assert_same(get_viewport().gui_get_focus_owner(), weapon.equip_button)

	weapon.equip_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.EQUIP)
	assert_same(get_viewport().gui_get_focus_owner(), party.inventory_view.default_focus())


func test_inventory_restores_item_focus_by_resource_identity_after_rebuild() -> void:
	var panel := preload("res://src/hub/inventory_panel.tscn").instantiate() as InventoryPanel
	add_child_autofree(panel)
	await get_tree().process_frame
	var pistol := load("res://data/equipment/weapons/pistol.tres") as Equipment
	var original := panel._spawn_grid_button(pistol, Equipment.Slot.WEAPON, 1) as ItemButton
	original.get_focus_control().grab_focus()
	var key: String = panel.focus_key(original.get_focus_control())
	assert_eq(key, "equipment:%s" % pistol.id)
	panel._clear_grid()
	var replacement := panel._spawn_grid_button(pistol, Equipment.Slot.WEAPON, 1) as ItemButton
	assert_true(panel.restore_focus(key))
	assert_same(get_viewport().gui_get_focus_owner(), replacement.get_focus_control())
	assert_eq(panel.grid.get_child_count(), 1, "retired item controls are detached immediately")
	assert_false(replacement.get_focus_control().is_queued_for_deletion())
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), replacement.get_focus_control())
	var settled_focus := get_viewport().gui_get_focus_owner()
	assert_not_null(settled_focus)
	if settled_focus:
		assert_true(panel.grid.is_ancestor_of(settled_focus))
		assert_false(settled_focus.is_queued_for_deletion())


func test_equipment_item_button_survives_its_pressed_dispatch_until_queued_cleanup() -> void:
	var navigation := preload("res://src/ui/navigation/navigation_ux_layer.tscn").instantiate() as NavigationUXLayer
	navigation.name = "NavigationUXLayer"
	add_child_autofree(navigation)
	var replacement := (load("res://data/equipment/weapons/rifle.tres") as Equipment).duplicate(true) as Equipment
	SaveSystem.inventory_equipment.assign([replacement])
	var party := await _opened_party_with_three_heroes()
	party.change_tab(1)
	assert_true(party.enter_content())
	var hero_panel := party.hero_list_container.get_child(party.current_hero_idx) as HeroPanel
	hero_panel.weapon_panel.equip_button.pressed.emit()
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.EQUIP)
	assert_eq(party.inventory_view.grid.get_child_count(), 1)
	var emitter := party.inventory_view.grid.get_child(0) as ItemButton
	var emitter_id := emitter.get_instance_id()
	emitter.get_focus_control().grab_focus()
	emitter.get_focus_control().pressed.emit()

	assert_same(hero_panel.data.weapon, replacement)
	assert_eq(party.inventory_view.current_mode, InventoryPanel.Mode.VIEW)
	assert_eq(party.inventory_view.grid.get_child_count(), 0, "retired emitter is detached during its pressed dispatch")
	assert_true(is_instance_valid(emitter), "emitter remains alive until signal dispatch unwinds")
	if is_instance_valid(emitter):
		assert_true(emitter.is_queued_for_deletion())
		assert_false(party.inventory_view.grid.is_ancestor_of(emitter))
	await get_tree().process_frame
	assert_null(instance_from_id(emitter_id), "queued emitter is gone on the next frame")
	var focus := get_viewport().gui_get_focus_owner()
	assert_not_null(focus)
	if focus:
		assert_true(party == focus or party.is_ancestor_of(focus))
		assert_false(focus.is_queued_for_deletion())
	assert_engine_error_count(0)


func test_pointer_hero_change_in_content_keeps_memory_content_scoped() -> void:
	var party := await _opened_party_with_three_heroes()
	assert_true(party.enter_content())
	var first_role_id := party.skill_view._current_role_panel().role_id
	var first := party.hero_list_container.get_child(0) as HeroPanel
	var second := party.hero_list_container.get_child(1) as HeroPanel
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true

	# Godot may focus a FOCUS_ALL Control before its mouse event reaches _gui_input.
	second.grab_focus()
	second._gui_input(click)

	assert_eq(party.current_hero_idx, 1)
	assert_eq(party.current_depth, PartyMenu.Depth.CONTENT)
	var second_focus := get_viewport().gui_get_focus_owner()
	assert_true(party.skill_view.is_ancestor_of(second_focus))
	assert_ne(second_focus, second)
	assert_same(second_focus, party.skill_view._current_role_panel())

	first._gui_input(click)

	assert_eq(party.current_hero_idx, 0)
	assert_eq(party.current_depth, PartyMenu.Depth.CONTENT)
	assert_same(get_viewport().gui_get_focus_owner(), party.skill_view._current_role_panel())
	assert_eq(party.skill_view._current_role_panel().role_id, first_role_id)


func test_role_panel_submits_stable_ids_without_mutating_progression() -> void:
	var hero := _hero()
	var panel := RolePanel.new()
	panel.hero_data = hero
	panel.role_id = "gun"
	panel.is_currently_expanded = true
	var ui := preload("res://src/hub/skill_tree_node.tscn").instantiate() as SkillTreeNode
	add_child(ui)
	await get_tree().process_frame
	ui.node_definition = _tree().get_node("gun.root")
	ui.set_availability(true, true)
	watch_signals(panel)

	panel._on_node_clicked(ui)

	assert_signal_emitted_with_parameters(panel, "purchase_requested", [hero, "gun", "gun.root"])
	assert_eq(hero.current_xp, 250)
	assert_true(hero.role_progress.is_empty())
	ui.free()
	panel.free()


func test_skill_node_purchase_authority_uses_availability_and_affordability() -> void:
	var ui := preload("res://src/hub/skill_tree_node.tscn").instantiate() as SkillTreeNode
	add_child_autofree(ui)
	await get_tree().process_frame
	ui.set_availability(true, true)
	assert_true(ui.is_purchasable())
	ui.set_availability(true, false)
	assert_false(ui.is_purchasable())
	ui.set_availability(false, true)
	assert_false(ui.is_purchasable())


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


func test_role_panel_profile_switch_restores_authored_node_geometry() -> void:
	var panel := preload("res://src/hub/role_panel.tscn").instantiate() as RolePanel
	add_child(panel)
	panel.setup(_legacy_role(), _tree(), _hero())
	panel.set_expanded(true, 0, false)

	panel.apply_display_profile(DisplayProfileService.Profile.COMPACT)
	var compact_root := panel.generated_nodes["gun.root"] as SkillTreeNode
	assert_eq(compact_root.custom_minimum_size, Vector2(250, 72))
	assert_eq(compact_root.position.y, 108.0)
	assert_eq(panel.content.offset_bottom, 0.0)
	assert_eq(panel.node_layer.anchor_top, 0.0)
	assert_eq(panel.node_layer.offset_top, 40.0)

	panel.apply_display_profile(DisplayProfileService.Profile.DESKTOP)
	var desktop_root := panel.generated_nodes["gun.root"] as SkillTreeNode
	assert_eq(desktop_root.custom_minimum_size, Vector2(250, 50))
	assert_eq(desktop_root.position.y, 90.0)
	assert_eq(panel.content.offset_bottom, -9.0)
	assert_eq(panel.node_layer.anchor_top, 0.5)
	assert_eq(panel.node_layer.offset_top, -397.0)
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
	assert_true(panel.enter_tree())
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
	assert_true(panel.enter_tree())
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

	assert_eq(role_panel.xp_display.text, "AVAILABLE XP 50")
	assert_false(sibling.disabled)
	assert_false(sibling.is_purchasable())
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
	assert_true(menu.skill_view.enter_tree())
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

	assert_eq(first.xp_display.text, "AVAILABLE XP 50")
	assert_eq(sibling.xp_display.text, "AVAILABLE XP 50")
	assert_false(sibling_node.disabled)
	assert_false(sibling_node.is_purchasable())
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
	assert_true(menu.skill_view.enter_tree())
	var asher_card := menu.hero_list_container.get_child(0) as HeroPanel
	var echo_card := menu.hero_list_container.get_child(1) as HeroPanel
	asher_card.atk.text = "STALE"
	asher_card.xp.text = "STALE"
	var echo_before := [echo_card.hp.text, echo_card.xp.text, echo_card.atk.text, echo_card.psy.text]
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
	assert_eq(asher_card.xp.text, "150")
	assert_eq([echo_card.hp.text, echo_card.xp.text, echo_card.atk.text, echo_card.psy.text], echo_before)
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
	assert_same(get_viewport().gui_get_focus_owner(), panel._current_role_panel())
	assert_true(panel.enter_tree())
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
	assert_false(locked.is_purchasable())
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


func test_inventory_and_equipment_controls_keep_only_semantic_mode_surfaces() -> void:
	var item := preload("res://src/hub/item_button.tscn").instantiate() as ItemButton
	add_child(item)
	assert_eq(item.get_focus_control().focus_mode, Control.FOCUS_ALL)
	assert_false(item.get_focus_control().has_meta("navigation_focus_surface"))
	var slot := preload("res://src/hub/mod_slot.tscn").instantiate() as ModSlot
	add_child(slot)
	slot.setup(null, true)
	assert_eq(slot.get_focus_control().focus_mode, Control.FOCUS_ALL)
	assert_eq(slot.get_focus_control().get_meta("navigation_focus_surface"), NodePath(".."))
	assert_true(slot.has_node("SelectionOutline"))
	item.free()
	slot.free()


func test_nonstandard_hub_controls_expose_valid_focus_surfaces() -> void:
	var item := preload("res://src/hub/item_button.tscn").instantiate() as ItemButton
	var slot := preload("res://src/hub/mod_slot.tscn").instantiate() as ModSlot
	var equipment := preload("res://src/hub/equipment_panel.tscn").instantiate() as EquipmentPanel
	add_child_autofree(item)
	add_child_autofree(slot)
	add_child_autofree(equipment)
	await get_tree().process_frame
	assert_false(item.get_focus_control().has_meta("navigation_focus_surface"))
	assert_false(equipment.equip_button.has_meta("navigation_focus_surface"))
	for control in [slot.get_focus_control()]:
		assert_true(control.has_meta("navigation_focus_surface"))
		var surface := control.get_node_or_null(control.get_meta("navigation_focus_surface")) as Control
		assert_not_null(surface)
		if not surface:
			continue
		var style_name := &"focus" if surface is Button else &"panel"
		NavigationFocus.apply(control)
		var style := surface.get_theme_stylebox(style_name) as StyleBoxFlat
		assert_almost_eq(style.bg_color.a, NavigationFocus.FOCUS_STYLE.bg_color.a, 0.001)
		NavigationFocus.clear(control)
	assert_eq(equipment.tune_btn.focus_mode, Control.FOCUS_NONE)


func test_roles_cancel_unwinds_tree_to_role_selection_then_returns_outward() -> void:
	var hero := _hero()
	hero.role_definitions.assign([_legacy_role()])
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_tree()])
	add_child(panel)
	panel.setup(hero)
	panel.focus_node("gun.root")
	assert_true(panel.cancel_navigation())
	assert_same(get_viewport().gui_get_focus_owner(), panel._current_role_panel())
	assert_false(panel.cancel_navigation())
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
	assert_true(panel.select_adjacent_role(1))
	assert_eq(panel.current_page, 0, "equal-distance supported pages prefer the lower page")
	assert_same(get_viewport().gui_get_focus_owner(), panel._current_role_panel())
	var target_positions := panel._current_role_panel().node_positions()
	assert_eq(target_positions["snp.start2"], source_center, "the starting skill occupies the exact prior screen coordinate")
	assert_lt(
		(target_positions["snp.start2"] as Vector2).distance_squared_to(source_center),
		(target_positions["snp.root"] as Vector2).distance_squared_to(source_center),
		"nearest-focus restoration must choose the zero-distance starting skill over the paid root",
	)
	assert_true(panel.enter_tree())
	assert_eq(panel.focused_node_id, "snp.anchor")
	assert_eq(get_viewport().gui_get_focus_owner(), panel.get_focused_node())
	panel.free()
	await get_tree().process_frame


func test_inventory_spawn_path_links_every_enabled_slot() -> void:
	var party := preload("res://src/hub/party_menu.tscn").instantiate() as PartyMenu
	add_child(party)
	party.show()
	var panel := party.inventory_view
	panel.show()
	panel.current_mode = InventoryPanel.Mode.EQUIP
	var first := panel._spawn_grid_button(load("res://data/equipment/weapons/pistol.tres"), Equipment.Slot.WEAPON, 1) as ItemButton
	var second := panel._spawn_grid_button(load("res://data/equipment/weapons/rifle.tres"), Equipment.Slot.WEAPON, 1) as ItemButton
	var third := panel._spawn_grid_button(load("res://data/equipment/weapons/smg.tres"), Equipment.Slot.WEAPON, 1) as ItemButton
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


func test_disabled_mod_slot_cannot_focus_or_activate() -> void:
	var slot := preload("res://src/hub/mod_slot.tscn").instantiate() as ModSlot
	add_child(slot)
	slot.setup(null, false)
	assert_true(slot.get_focus_control().disabled)
	assert_eq(slot.get_focus_control().focus_mode, Control.FOCUS_NONE)
	assert_false(NavigationFocus._states.has(slot.get_focus_control().get_instance_id()))
	slot.free()


func test_page_triggers_work_from_tree_nodes_and_page_strip() -> void:
	var panel := await _skill_panel_with_multi_page_role()
	panel.focus_node(panel._nearest_node_id(panel._current_role_panel()))
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(panel.current_page, 1)
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	assert_true(panel.focus_current_page_tab())
	panel._unhandled_input(_joy_motion(JOY_AXIS_TRIGGER_LEFT, 1.0))
	assert_eq(panel.current_page, 0, "page strip retains page-trigger ownership")
	panel.free()
	await get_tree().process_frame


func test_keyboard_and_controller_skill_navigation_share_retained_focus() -> void:
	var hero := _hero()
	hero.role_definitions.assign([_legacy_role()])
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	var navigation := preload("res://src/ui/navigation/navigation_ux_layer.tscn").instantiate() as NavigationUXLayer
	navigation.name = "NavigationUXLayer"
	add_child(navigation)
	var panel := preload("res://src/hub/skill_tree_panel.tscn").instantiate() as SkillTreePanel
	panel.progression_catalog = ProgressionCatalog.from_validated_trees([_tree()])
	add_child(panel)
	panel.setup(hero)
	navigation.register_screen(panel, panel.get_focused_node())
	panel.focus_node("gun.start1")
	await get_tree().create_timer(0.35).timeout
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_D
	keyboard.pressed = true
	get_viewport().push_input(keyboard)
	await get_tree().process_frame
	await get_tree().process_frame
	var keyboard_target := panel.get_focused_node()
	assert_eq(panel.focused_node_id, "gun.anchor")
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.KEYBOARD_MOUSE)
	assert_same(navigation.get_focus_target(), keyboard_target)
	assert_true(NavigationFocus._states.has(keyboard_target.get_instance_id()))
	assert_false(navigation.cursor.visible)
	keyboard.pressed = false
	get_viewport().push_input(keyboard)
	panel.focus_node("gun.start2")
	await get_tree().process_frame
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_DPAD_LEFT
	controller.pressed = true
	get_viewport().push_input(controller)
	await get_tree().process_frame
	await get_tree().process_frame
	var controller_target := panel.get_focused_node()
	assert_eq(panel.focused_node_id, "gun.anchor")
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
	assert_same(navigation.get_focus_target(), controller_target)
	assert_true(NavigationFocus._states.has(controller_target.get_instance_id()))
	assert_false(navigation.cursor.visible)
	panel.free()
	navigation.free()
	await get_tree().process_frame


func test_single_role_does_not_advertise_removed_role_bumper_hint() -> void:
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
	var role_hint: ActionHint
	for index in navigation.hint_bar.get_hint_count():
		var hint := navigation.hint_bar.get_hint(index)
		if hint.action == &"hub_role_previous":
			role_hint = hint
	assert_null(role_hint)
	panel.free()
	navigation.free()
	await get_tree().process_frame


func test_rank_page_buttons_switch_across_supported_pages_and_focus_nearest_node() -> void:
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
	assert_true(panel.page_buttons[2].visible)
	assert_false(panel.page_buttons[1].visible)
	assert_eq(panel.tabs_container.get_child(0), panel.previous_page_glyph)
	assert_eq(panel.tabs_container.get_child(panel.tabs_container.get_child_count() - 1), panel.next_page_glyph)
	assert_true(panel.previous_page_glyph.visible)
	assert_true(panel.next_page_glyph.visible)
	panel._on_tab_pressed(2)
	assert_eq(panel.current_page, 2)
	assert_eq(panel.focused_node_id, "gun.page3.near")
	assert_eq(get_viewport().gui_get_focus_owner(), panel.get_focused_node())
	panel._on_tab_pressed(0)
	assert_eq(panel.current_page, 0)
	assert_eq(panel.focused_node_id, "gun.root")
	panel._on_tab_pressed(2)
	assert_eq(panel.current_page, 2)
	panel.free()
	await get_tree().process_frame


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _joy_motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _push_action_event(action: StringName) -> void:
	get_viewport().push_input(_action_event(action))
	await get_tree().process_frame
	var released := InputEventAction.new()
	released.action = action
	released.pressed = false
	get_viewport().push_input(released)
	await get_tree().process_frame
