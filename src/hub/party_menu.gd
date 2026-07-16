extends Control
class_name PartyMenu

enum Tab { ROLES, ITEMS, OPTIONS, JOURNAL }
enum Depth { HERO_RAIL, CONTENT }

@export var hero_panel_scene: PackedScene

# --- REFERENCES ---
@onready var hero_list_container: VBoxContainer = $HeroList
@onready var skill_view: SkillTreePanel = $Content/SkillTreePanel
@onready var inventory_view: InventoryPanel = $Content/InventoryPanel
@onready var tab_buttons: Array[Button] = [
	$Header/TabStrip/Roles,
	$Header/TabStrip/Items,
	$Header/TabStrip/Options,
	$Header/TabStrip/Journal,
]
@onready var back_button: Button = $BackBtn

# --- STATE ---
var party_roster: Array[HeroData] = []
var current_hero_idx: int = 0
var current_tab: Tab = Tab.ROLES
var current_depth: Depth = Depth.HERO_RAIL
var _content_focus_memory: Dictionary = {}
var progression_service: ProgressionService = ProgressionSystem.service
var progression_catalog: ProgressionCatalog = ProgressionSystem.catalog
var save_progression: Callable = SaveSystem.save_current_slot
var play_progression_audio: Callable = AudioManager.play_sfx
var refresh_hero_stats: Callable = _refresh_matching_hero_stats
var _display_profile: int = DisplayProfileService.Profile.DESKTOP
var _display_window_size := DisplayProfileService.DESKTOP_WINDOW_SIZE
var _display_logical_size := DisplayProfileService.REFERENCE_SIZE

func _ready():
	DisplayProfile.bind(apply_display_profile)
	hide()
	skill_view.purchase_requested.connect(_on_purchase_requested)
	inventory_view.hero_stats_updated.connect(_on_hero_stats_updated)
	inventory_view.mode_changed.connect(_on_inventory_mode_changed)
	for index in range(tab_buttons.size()):
		tab_buttons[index].pressed.connect(_on_tab_pressed.bind(index))


func apply_display_profile(profile: int, window_size: Vector2i, logical_size: Vector2) -> void:
	_display_profile = profile
	_display_window_size = window_size
	_display_logical_size = logical_size
	var compact := profile == DisplayProfileService.Profile.COMPACT
	$BackBtn.offset_top = 489.0 if compact else 477.0
	$BackBtn.offset_bottom = 561.0 if compact else 525.0
	$Header/TabStrip.add_theme_constant_override(&"separation", 12 if compact else 8)
	inventory_view.apply_display_profile(profile, window_size, logical_size)
	for child in hero_list_container.get_children():
		if child is HeroPanel:
			(child as HeroPanel).apply_display_profile(profile, window_size, logical_size)


func _exit_tree() -> void:
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.remove_modal(self)

func open():
	party_roster = SaveSystem.party_roster
	if party_roster.is_empty(): return

	current_depth = Depth.HERO_RAIL
	_refresh_hero_list()
	_select_hero(0)
	show()
	var selected_hero := _get_panel_by_index(current_hero_idx)
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.push_modal(self, selected_hero)
	_publish_hints()
	_grab_focus_if_valid.call_deferred(selected_hero)

func _on_back_pressed():
	_close()


func _unhandled_input(event: InputEvent) -> void:
	var navigation := _navigation_ux_layer()
	if not visible or (navigation and not navigation.is_top_modal(self)):
		return
	if event.is_action_pressed(&"hub_tab_previous"):
		get_viewport().set_input_as_handled()
		change_tab(-1)
		return
	if event.is_action_pressed(&"hub_tab_next"):
		get_viewport().set_input_as_handled()
		change_tab(1)
		return
	if current_depth == Depth.CONTENT and event.is_action_pressed(&"nav_left"):
		get_viewport().set_input_as_handled()
		return_to_hero_rail()
		return
	if event.is_action_pressed(&"confirm"):
		var owner := get_viewport().gui_get_focus_owner()
		if owner == _get_panel_by_index(current_hero_idx):
			get_viewport().set_input_as_handled()
			enter_content()
			return
		var focused := get_viewport().gui_get_focus_owner() as BaseButton
		if focused and not (focused is SkillTreeNode) and not focused.disabled and (focused == self or is_ancestor_of(focused)):
			get_viewport().set_input_as_handled()
			focused.pressed.emit()
		return
	if event.is_action_pressed(&"cancel"):
		get_viewport().set_input_as_handled()
		if current_depth == Depth.CONTENT and skill_view.visible and skill_view.cancel_focus_layer():
			return
		if current_depth == Depth.CONTENT and inventory_view.visible and inventory_view.cancel_navigation():
			return
		if current_depth == Depth.CONTENT:
			return_to_hero_rail()
			return
		_close()

func _refresh_hero_list():
	for child in hero_list_container.get_children():
		hero_list_container.remove_child(child)
		child.queue_free()

	for i in range(party_roster.size()):
		var hero_data = party_roster[i]
		var panel = hero_panel_scene.instantiate() as HeroPanel
		hero_list_container.add_child(panel)
		panel.apply_display_profile(_display_profile, _display_window_size, _display_logical_size)

		panel.setup(hero_data)
		panel.panel_selected.connect(_on_hero_panel_selected)
		panel.focus_entered.connect(_on_hero_panel_selected.bind(panel))
		panel.content_requested.connect(_on_hero_content_requested)
		panel.equip_requested.connect(_on_hero_equip_requested.bind(i))
		panel.tune_requested.connect(_on_hero_tune_requested.bind(i))
		panel.mod_requested.connect(_on_hero_mod_requested.bind(i))

		# Visual selection state
		if i == current_hero_idx:
			panel.set_expanded(true)
		else:
			panel.set_expanded(false)

	for index in range(hero_list_container.get_child_count()):
		var panel := hero_list_container.get_child(index) as HeroPanel
		var previous := hero_list_container.get_child(posmod(index - 1, hero_list_container.get_child_count())) as HeroPanel
		var next := hero_list_container.get_child(posmod(index + 1, hero_list_container.get_child_count())) as HeroPanel
		panel.focus_neighbor_top = panel.get_path_to(previous)
		panel.focus_neighbor_bottom = panel.get_path_to(next)

func _on_inventory_mode_changed(mode, item, slot):
	# A. Clear ALL highlights first (Safety)
	for i in range(hero_list_container.get_child_count()):
		var p = hero_list_container.get_child(i) as HeroPanel
		p.clear_highlights()

	# B. If we are in VIEW mode, stop here.
	if mode == InventoryPanel.Mode.VIEW:
		return

	# C. Apply Highlight based on the authoritative state
	# We know 'current_hero_idx' is correct because we switch heroes before requesting mode
	var active_panel = _get_panel_by_index(current_hero_idx)
	if not active_panel: return

	if mode == InventoryPanel.Mode.EQUIP:
		if slot == Equipment.Slot.WEAPON:
			active_panel.set_active_mode(active_panel.weapon_panel, "equip")
		else:
			active_panel.set_active_mode(active_panel.armor_panel, "equip")

	elif mode == InventoryPanel.Mode.TUNE:
		if item == active_panel.data.weapon:
			active_panel.set_active_mode(active_panel.weapon_panel, "tune")
		else:
			active_panel.set_active_mode(active_panel.armor_panel, "tune")

	elif mode == InventoryPanel.Mode.MOD:
		if item == active_panel.data.weapon:
			active_panel.set_active_mode(active_panel.weapon_panel, "mod")
		else:
			active_panel.set_active_mode(active_panel.armor_panel, "mod")

func _on_hero_panel_selected(selected_panel: HeroPanel):
	var index := selected_panel.get_index()
	if index < 0 or index >= hero_list_container.get_child_count():
		return
	if current_hero_idx != index:
		_select_hero(index)
	if current_depth == Depth.HERO_RAIL and not selected_panel.has_focus():
		_grab_focus_if_valid(selected_panel)


func _on_hero_content_requested(selected_panel: HeroPanel) -> void:
	_on_hero_panel_selected(selected_panel)
	enter_content()

func _perform_party_swap(hero_a_idx: int, hero_b_idx: int, slot: Equipment.Slot):
	var hero_a = party_roster[hero_a_idx]
	var hero_b = party_roster[hero_b_idx]

	# Swap Logic
	if slot == Equipment.Slot.WEAPON:
		var temp = hero_a.weapon
		hero_a.weapon = hero_b.weapon
		hero_b.weapon = temp
	elif slot == Equipment.Slot.ARMOR:
		var temp = hero_a.armor
		hero_a.armor = hero_b.armor
		hero_b.armor = temp

	AudioManager.play_sfx("terminal")

	var panel_a = _get_panel_by_index(hero_a_idx)
	var panel_b = _get_panel_by_index(hero_b_idx)

	if panel_a: panel_a.setup(hero_a)
	if panel_b: panel_b.setup(hero_b)

func _on_hero_equip_requested(item, slot, hero_index):
	# Check Swap
	var is_same_slot = (inventory_view.active_slot == slot)
	var is_equip_mode = (inventory_view.current_mode == InventoryPanel.Mode.EQUIP)
	var is_diff_hero = (current_hero_idx != hero_index)

	if is_equip_mode and is_same_slot and is_diff_hero:
		_perform_party_swap(current_hero_idx, hero_index, slot)
		inventory_view.request_equip_mode(inventory_view.active_equipment, slot)
		return

	_handle_auto_select_hero(hero_index)
	inventory_view.request_equip_mode(item, slot)

func _on_hero_tune_requested(item, hero_index):
	_handle_auto_select_hero(hero_index)
	inventory_view.request_tune_mode(item)

func _on_hero_mod_requested(item, slot, hero_index):
	_handle_auto_select_hero(hero_index)
	inventory_view.request_mod_mode(item, slot)

func _handle_auto_select_hero(index: int):
	# If we clicked a collapsed hero, switch to them!
	if current_hero_idx != index:
		_select_hero(index)

func _select_hero(index: int):
	current_hero_idx = index
	_update_active_view()


func _on_tab_pressed(tab_index: int) -> void:
	change_tab(tab_index - int(current_tab))


# Retained for callers transitioning from the former two-mode menu API.
func _on_mode_changed(mode_index: int) -> void:
	if mode_index in [Tab.ROLES, Tab.ITEMS]:
		_on_tab_pressed(mode_index)


func change_tab(delta: int) -> void:
	if delta == 0:
		return
	_store_content_focus()
	current_tab = posmod(int(current_tab) + delta, tab_buttons.size()) as Tab
	if current_tab in [Tab.OPTIONS, Tab.JOURNAL]:
		current_depth = Depth.HERO_RAIL
	_update_active_view()
	if current_depth == Depth.CONTENT and current_tab in [Tab.ROLES, Tab.ITEMS]:
		_restore_content_focus()
	else:
		_focus_selected_hero()


func enter_content() -> bool:
	if current_tab in [Tab.OPTIONS, Tab.JOURNAL]:
		return false
	current_depth = Depth.CONTENT
	_update_depth_presentation()
	return _restore_content_focus()


func return_to_hero_rail() -> void:
	_store_content_focus()
	current_depth = Depth.HERO_RAIL
	_update_depth_presentation()
	_focus_selected_hero()


func _content_memory_key() -> String:
	if party_roster.is_empty() or current_hero_idx < 0 or current_hero_idx >= party_roster.size():
		return ""
	return "%s:%d" % [party_roster[current_hero_idx].hero_id, int(current_tab)]


func _store_content_focus() -> void:
	if current_depth != Depth.CONTENT:
		return
	var key := _content_memory_key()
	if key.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner and is_ancestor_of(owner):
		_content_focus_memory[key] = get_path_to(owner)


func _restore_content_focus() -> bool:
	var remembered: Control
	var remembered_path: NodePath = _content_focus_memory.get(_content_memory_key(), NodePath())
	if not remembered_path.is_empty():
		remembered = get_node_or_null(remembered_path) as Control
	if _is_valid_focus(remembered):
		remembered.grab_focus()
		return true
	if current_tab == Tab.ROLES:
		return skill_view.focus_node("")
	if current_tab == Tab.ITEMS:
		var panel := _get_panel_by_index(current_hero_idx)
		var fallback := _first_focusable_descendant(panel)
		if fallback:
			fallback.grab_focus()
			return true
	return false


func _first_focusable_descendant(root: Control) -> Control:
	if root == null:
		return null
	for child in root.find_children("*", "Control", true, false):
		var control := child as Control
		if _is_valid_focus(control):
			return control
	return null


func _is_valid_focus(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and control.disabled)


func _focus_selected_hero() -> void:
	_grab_focus_if_valid(_get_panel_by_index(current_hero_idx))

func _update_active_view():
	if party_roster.is_empty() or current_hero_idx < 0 or current_hero_idx >= party_roster.size():
		return
	var hero = party_roster[current_hero_idx]
	var is_inventory := current_tab == Tab.ITEMS
	for i in range(hero_list_container.get_child_count()):
		var panel = hero_list_container.get_child(i) as HeroPanel
		panel.set_mode(is_inventory)
		if i == current_hero_idx:
			panel.set_expanded(true)
		else:
			panel.set_expanded(false)
			panel.clear_highlights()

	skill_view.visible = current_tab == Tab.ROLES
	inventory_view.visible = current_tab == Tab.ITEMS
	$Content/OptionsComingSoon.visible = current_tab == Tab.OPTIONS
	$Content/JournalComingSoon.visible = current_tab == Tab.JOURNAL
	for index in range(tab_buttons.size()):
		tab_buttons[index].set_pressed_no_signal(index == current_tab)

	if current_tab == Tab.ROLES:
		skill_view.progression_catalog = progression_catalog
		skill_view.setup(hero)
	elif current_tab == Tab.ITEMS:
		inventory_view.setup(hero)
	_update_depth_presentation()


func _update_depth_presentation() -> void:
	for index in range(hero_list_container.get_child_count()):
		var panel := hero_list_container.get_child(index) as HeroPanel
		panel.set_chrome_active(current_depth == Depth.HERO_RAIL or index == current_hero_idx)

func _get_panel_by_index(index: int) -> HeroPanel:
	if index >= 0 and index < hero_list_container.get_child_count():
		return hero_list_container.get_child(index) as HeroPanel
	return null

func _on_hero_stats_updated():
	SaveSystem.save_current_slot()
	if current_hero_idx < hero_list_container.get_child_count():
		var panel = hero_list_container.get_child(current_hero_idx) as HeroPanel
		panel.setup(party_roster[current_hero_idx])

func _refresh_matching_hero_stats(hero: HeroData) -> void:
	for child in hero_list_container.get_children():
		var panel := child as HeroPanel
		if panel and panel.data == hero:
			panel.refresh_stats()


func _on_purchase_requested(hero: HeroData, role_id: String, node_id: String) -> void:
	if progression_service == null:
		play_progression_audio.call("press")
		return
	var result := progression_service.purchase_node(hero, role_id, node_id)
	if result.status != ProgressionPurchaseResult.Status.PURCHASED:
		play_progression_audio.call("press")
		return
	play_progression_audio.call("terminal")
	save_progression.call()
	refresh_hero_stats.call(hero)
	if skill_view:
		skill_view.refresh_progression_state(hero)

func _on_back_btn_pressed() -> void:
	_close()


func _close() -> void:
	var navigation := _navigation_ux_layer()
	if navigation and not navigation.is_top_modal(self):
		return
	if navigation:
		navigation.pop_modal(self)
	hide()


func _navigation_ux_layer() -> NavigationUXLayer:
	return get_tree().root.find_child("NavigationUXLayer", true, false) as NavigationUXLayer


func _publish_hints() -> void:
	var navigation := _navigation_ux_layer()
	if navigation and navigation.is_top_modal(self):
		navigation.publish_hints([
			{action = &"confirm", label = "Select", enabled = true},
			{action = &"cancel", label = "Back", enabled = true},
		])


func _grab_focus_if_valid(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and not (control is BaseButton and control.disabled):
		control.grab_focus()
