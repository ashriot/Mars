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
	assert_true(ResponsiveFixture.fits_output(menu.get_node("Header"), DECK_SIZE))
	assert_true(ResponsiveFixture.fits_output(menu.get_node("BackBtn"), DECK_SIZE))
	assert_true(ResponsiveFixture.fits_output(menu.get_node("Content"), DECK_SIZE))
	assert_gte(ResponsiveFixture.physical_rect(menu.get_node("BackBtn"), DECK_SIZE).size.y, 48.0)
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO)
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_eq(menu.inventory_view.grid, scroll.get_node("InventoryGrid"))


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
