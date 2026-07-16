extends GutTest

const ResponsiveFixture = preload("res://test/fixtures/responsive_viewport_fixture.gd")
const SkillTreePanelScene = preload("res://src/hub/skill_tree_panel.tscn")
const DECK_SIZE := Vector2i(1280, 800)


func test_compact_tree_scroll_reveals_each_focused_role_and_tier_node() -> void:
	var panel := await _compact_skill_panel()
	var scroll := panel.get_node_or_null("RoleScroll") as ScrollContainer
	assert_not_null(scroll)
	if scroll == null:
		return
	assert_eq(scroll.focus_mode, Control.FOCUS_NONE)
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)

	for role_index in range(panel.role_list_container.get_child_count()):
		if role_index != panel.current_role_idx:
			panel.change_role(role_index - panel.current_role_idx)
		await _finish_layout_tweens()
		for page in [0, 1]:
			if panel.current_page != page:
				panel.change_page(page - panel.current_page)
			var selected_role := panel._current_role_panel()
			for node: Control in selected_role.generated_nodes.values():
				var node_id: String = selected_role.generated_nodes.find_key(node)
				var physical_size := ResponsiveFixture.physical_rect(node, DECK_SIZE).size
				assert_gte(physical_size.x, 48.0)
				assert_gte(physical_size.y, 48.0)
				assert_true(panel.focus_node(node_id))
				await get_tree().process_frame
				assert_true(scroll.get_global_rect().encloses(node.get_global_rect()), "%s should be fully visible in the scroll region after focus" % node_id)
				assert_true(selected_role.content.get_global_rect().encloses(node.get_global_rect()), "%s %s should stay within role content %s" % [node_id, node.get_global_rect(), selected_role.content.get_global_rect()])


func test_compact_role_and_page_changes_retain_remembered_nodes() -> void:
	var panel := await _compact_skill_panel()
	if panel.get_node_or_null("RoleScroll") == null:
		assert_not_null(panel.get_node_or_null("RoleScroll"))
		return

	assert_true(panel.focus_node("gun.root"))
	panel.change_page(1)
	assert_true(panel.focus_node("gun.page2"))
	panel.change_role(1)
	assert_true(panel.focus_node("snp.page2"))
	panel.change_page(-1)
	assert_true(panel.focus_node("snp.root"))
	panel.change_role(-1)
	assert_eq(panel.focused_node_id, "gun.root")
	panel.change_page(1)
	assert_eq(panel.focused_node_id, "gun.page2")
	panel.change_role(1)
	assert_eq(panel.focused_node_id, "snp.page2")


func _compact_skill_panel() -> SkillTreePanel:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ResponsiveFixture.logical_size_for(DECK_SIZE))
	add_child_autofree(viewport)
	var content_shell := Control.new()
	content_shell.size = Vector2(1571, 1064)
	viewport.add_child(content_shell)
	var hero := HeroData.new()
	hero.hero_id = "responsive"
	hero.current_xp = 500
	var role_ids := ["gun", "snp", "bio", "kin", "psi"]
	hero.unlocked_role_ids.assign(role_ids)
	for role_id: String in role_ids:
		hero.role_definitions.append(_role(role_id))
	var panel := SkillTreePanelScene.instantiate() as SkillTreePanel
	var trees: Array[RoleTreeDefinition] = []
	for role_id: String in role_ids:
		trees.append(_tree(role_id))
	panel.progression_catalog = ProgressionCatalog.from_validated_trees(trees)
	content_shell.add_child(panel)
	if panel.get_node_or_null("RoleScroll") == null:
		return panel
	panel.apply_display_profile(DisplayProfileService.Profile.COMPACT, DECK_SIZE, viewport.size)
	panel.setup(hero)
	await _finish_layout_tweens()
	return panel


func _finish_layout_tweens() -> void:
	for tween in get_tree().get_processed_tweens():
		tween.custom_step(1.0)
	await get_tree().process_frame


func _role(role_id: String) -> RoleDefinition:
	var role := RoleDefinition.new()
	role.role_id = role_id
	role.role_name = role_id.capitalize()
	return role


func _tree(role_id: String) -> RoleTreeDefinition:
	return RoleTreeDefinition.new(role_id, 2, [
		ProgressionNodeDefinition.role_anchor(role_id + ".anchor", 1, 0),
		ProgressionNodeDefinition.progression(role_id + ".start1", role_id + ".anchor", 1, -1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/double_tap.tres", 1), true),
		ProgressionNodeDefinition.progression(role_id + ".start2", role_id + ".anchor", 1, 1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/fusion_ammo.tres", 2), true),
		ProgressionNodeDefinition.progression(role_id + ".root", role_id + ".anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.progression(role_id + ".deep", role_id + ".root", 9, 0, 100, ProgressionEffect.stat("PRE", 1)),
		ProgressionNodeDefinition.new(role_id + ".page2", role_id + ".root", 11, 0, 100, ProgressionEffect.stat("AIM", 1)),
	])
