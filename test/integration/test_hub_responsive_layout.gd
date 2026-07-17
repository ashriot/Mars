extends GutTest

const ResponsiveFixture = preload("res://test/fixtures/responsive_viewport_fixture.gd")
const PartyMenuScene = preload("res://src/hub/party_menu.tscn")
const DECK_SIZE := Vector2i(1280, 800)

var _saved_roster: Array[HeroData] = []


func before_each() -> void:
	_saved_roster.assign(SaveSystem.party_roster)
	SaveSystem.party_roster.clear()


func after_each() -> void:
	for tween in get_tree().get_processed_tweens():
		tween.kill()
	SaveSystem.party_roster.assign(_saved_roster)


func test_compact_hub_shell_and_inventory_scroll_fit_deck_output() -> void:
	var menu := await _compact_party_menu()
	var scroll := menu.get_node("Content/InventoryPanel/InventoryScroll") as ScrollContainer

	assert_true(ResponsiveFixture.fits_output(menu.get_node("HeroList"), DECK_SIZE))
	assert_true(ResponsiveFixture.fits_output(menu.get_node("BackBtn"), DECK_SIZE))
	assert_true(ResponsiveFixture.fits_output(menu.get_node("Content"), DECK_SIZE))
	assert_gte(ResponsiveFixture.physical_rect(menu.get_node("BackBtn"), DECK_SIZE).size.y, 48.0)
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_eq(menu.inventory_view.grid, scroll.get_node("InventoryGrid"))


func test_compact_hub_top_tabs_and_stub_content_fit_deck_output() -> void:
	var menu := await _compact_party_menu()
	var tab_strip := menu.get_node("Header/TabStrip") as Control
	assert_true(ResponsiveFixture.fits_output(tab_strip, DECK_SIZE))
	for button: Button in menu.tab_buttons:
		assert_true(ResponsiveFixture.fits_output(button, DECK_SIZE))
		assert_gte(ResponsiveFixture.physical_rect(button, DECK_SIZE).size.y, 48.0)
	menu.change_tab(2)
	assert_true(ResponsiveFixture.fits_output(menu.get_node("Content/OptionsComingSoon"), DECK_SIZE))
	assert_same(menu.get_viewport().gui_get_focus_owner(), menu.hero_list_container.get_child(menu.current_hero_idx))


func test_compact_inventory_scrolls_and_wraps_enabled_button_focus() -> void:
	var menu := await _compact_party_menu()
	var panel := menu.inventory_view
	var scroll := panel.get_node("InventoryScroll") as ScrollContainer
	var resources: Array[Resource] = [
		load("res://data/equipment/weapons/pistol.tres"),
		load("res://data/equipment/weapons/rifle.tres"),
		load("res://data/equipment/weapons/smg.tres"),
	]
	var buttons: Array[ItemButton] = []
	for index in range(20):
		buttons.append(panel._spawn_grid_button(resources[index % resources.size()], Equipment.Slot.WEAPON, 1))
	await get_tree().process_frame

	var first: BaseButton = buttons.front().get_focus_control()
	var last: BaseButton = buttons.back().get_focus_control()
	assert_gt(scroll.get_v_scroll_bar().max_value, scroll.size.y)
	assert_eq(first.focus_neighbor_top, first.get_path_to(last))
	assert_eq(last.focus_neighbor_bottom, last.get_path_to(first))
	last.grab_focus()
	await get_tree().process_frame
	assert_gt(scroll.scroll_vertical, 0)


func test_compact_equipment_controls_are_large_and_content_stays_inside_panel() -> void:
	var menu := await _compact_party_menu()
	var hero_panel := menu.hero_list_container.get_child(0) as HeroPanel
	for equipment_panel: EquipmentPanel in [hero_panel.weapon_panel, hero_panel.armor_panel]:
		var header_style := equipment_panel.header.get_theme_stylebox(&"panel") as StyleBoxFlat
		assert_eq(header_style.border_width_top, 72)
		_assert_compact_surface(equipment_panel.equip_button)
		_assert_compact_surface(equipment_panel.tune_btn)
		for slot: ModSlot in equipment_panel.mods_container.get_children():
			if slot.is_active:
				_assert_compact_surface(slot.get_focus_control())
		for child: Control in [
			equipment_panel.name_label,
			equipment_panel.xp_label,
			equipment_panel.rank_label,
			equipment_panel.xp_gauge,
			equipment_panel.weapon_stats if equipment_panel.weapon_stats.visible else equipment_panel.armor_stats,
			equipment_panel.mods_container,
		]:
			assert_true(_contains_control(equipment_panel, child), "%s %s must remain inside %s %s" % [child.name, child.get_global_rect(), equipment_panel.name, equipment_panel.get_global_rect()])


func test_hero_summary_aligns_hp_and_xp_inside_desktop_and_compact_cards() -> void:
	var menu := await _compact_party_menu()
	var hero_panel := menu.hero_list_container.get_child(0) as HeroPanel
	hero_panel.data.current_xp = 9999
	hero_panel.refresh_stats()
	for profile: int in [DisplayProfileService.Profile.COMPACT, DisplayProfileService.Profile.DESKTOP]:
		var window_size := DECK_SIZE if profile == DisplayProfileService.Profile.COMPACT else Vector2i(1920, 1080)
		menu.apply_display_profile(profile, window_size, Vector2(window_size))
		await get_tree().process_frame
		var summary := hero_panel.get_node("Content/Stats/Summary") as Control
		var hp_group := summary.get_node("HP") as Control
		var xp_group := summary.get_node("XP") as Control
		assert_lt(hp_group.get_global_rect().position.x, xp_group.get_global_rect().position.x)
		assert_eq(hp_group.get_global_rect().position.x, summary.get_global_rect().position.x)
		var gap := xp_group.get_global_rect().position.x - hp_group.get_global_rect().end.x
		var right_padding := summary.get_global_rect().end.x - xp_group.get_global_rect().end.x
		assert_lte(gap, 8.0, "HP and XP use only the authored compact gap")
		assert_gte(right_padding, 8.0, "XP retains a readable right inset")
		assert_eq(hero_panel.xp.text, "9999")
		assert_false(hero_panel.xp.text.contains(","))
		assert_true(_contains_control(hero_panel, hp_group))
		assert_true(_contains_control(hero_panel, xp_group))
		assert_true(_contains_control(hero_panel, hero_panel.xp))


func test_compact_role_headers_fit_widest_abbreviation_and_six_digit_exact_xp() -> void:
	var panel := preload("res://src/hub/role_panel.tscn").instantiate() as RolePanel
	add_child_autofree(panel)
	var role := RoleDefinition.new()
	role.role_id = "WWW"
	role.role_name = "Wide Role Name"
	var hero := HeroData.new()
	hero.current_xp = 200000
	panel.setup(role, RoleTreeDefinition.new("WWW", 1, []), hero)
	panel.apply_display_profile(DisplayProfileService.Profile.COMPACT)
	panel.set_expanded(false, 0, false)
	panel.size.x = panel.collapsed_x
	await get_tree().process_frame
	assert_true(_contains_control(panel, panel.header_label))
	panel.set_expanded(true, 0, false)
	panel.size.x = panel.expanded_x
	await get_tree().process_frame
	assert_eq(panel.xp_display.text, "AVAILABLE XP 200,000")
	assert_true(_contains_control(panel, panel.role_name_label))
	assert_true(_contains_control(panel, panel.xp_display), "%s must remain inside %s" % [panel.xp_display.get_global_rect(), panel.get_global_rect()])


func test_rank_page_glyphs_fit_beside_explicit_page_buttons() -> void:
	var menu := await _compact_party_menu()
	var panel := menu.skill_view
	assert_eq(panel.page_buttons.size(), 5)
	assert_eq(panel.tabs_container.get_child(0), panel.previous_page_glyph)
	assert_eq(panel.tabs_container.get_child(panel.tabs_container.get_child_count() - 1), panel.next_page_glyph)
	assert_true(ResponsiveFixture.fits_output(panel.tabs_container, DECK_SIZE))


func test_desktop_profile_restores_authored_hub_control_sizes() -> void:
	var menu := await _compact_party_menu()
	menu.apply_display_profile(DisplayProfileService.Profile.DESKTOP, Vector2i(1920, 1080), Vector2(1920, 1080))
	var hero_panel := menu.hero_list_container.get_child(0) as HeroPanel
	var equipment_panel := hero_panel.weapon_panel
	var mod_slot := equipment_panel.mods_container.get_child(0) as ModSlot

	assert_eq(menu.get_node("BackBtn").size.y, 48.0)
	assert_eq(hero_panel.collapsed_y, 96.0)
	assert_eq(hero_panel.expanded_y, 296.0)
	assert_eq(equipment_panel.equip_button.size.y, 42.0)
	assert_eq(equipment_panel.xp_container.size.y, 40.0)
	assert_eq(equipment_panel.tune_btn.size, Vector2(44.0, 44.0))
	assert_eq(mod_slot.custom_minimum_size, Vector2(64.0, 64.0))
	assert_eq((equipment_panel.header.get_theme_stylebox(&"panel") as StyleBoxFlat).border_width_top, 42)


func _compact_party_menu() -> PartyMenu:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ResponsiveFixture.logical_size_for(DECK_SIZE))
	add_child_autofree(viewport)
	var asher := load("res://data/heroes/asher/asher.tres").duplicate(true) as HeroData
	SaveSystem.party_roster.assign([asher])
	var menu := PartyMenuScene.instantiate() as PartyMenu
	viewport.add_child(menu)
	menu.apply_display_profile(DisplayProfileService.Profile.COMPACT, DECK_SIZE, viewport.size)
	menu.open()
	menu._on_mode_changed(1)
	await get_tree().process_frame
	(menu.hero_list_container.get_child(0) as HeroPanel).set_expanded(true, false)
	await get_tree().process_frame
	return menu


func _assert_compact_surface(control: Control) -> void:
	var physical := ResponsiveFixture.physical_rect(control, DECK_SIZE)
	assert_gte(physical.size.x, 48.0)
	assert_gte(physical.size.y, 48.0)


func _contains_control(parent: Control, child: Control) -> bool:
	var parent_rect := parent.get_global_rect()
	var child_rect := child.get_global_rect()
	return parent_rect.encloses(child_rect)
