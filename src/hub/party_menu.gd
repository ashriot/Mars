extends Control
class_name PartyMenu

@export var hero_panel_scene: PackedScene

# --- REFERENCES ---
@onready var hero_list_container: VBoxContainer = $HeroList
@onready var skill_view: SkillTreePanel = $Content/SkillTreePanel
@onready var inventory_view: InventoryPanel = $Content/InventoryPanel
@onready var mode_tabs: HBoxContainer = $Header/ModeTabs

# --- STATE ---
var party_roster: Array[HeroData] = []
var current_hero_idx: int = 0
var current_mode: int = 0 # 0=Skills, 1=Inventory

func _ready():
	hide()
	inventory_view.hero_stats_updated.connect(_on_hero_stats_updated)
	inventory_view.mode_changed.connect(_on_inventory_mode_changed)
	for i in range(mode_tabs.get_child_count()):
		var btn = mode_tabs.get_child(i) as Button
		btn.pressed.connect(_on_mode_changed.bind(i))

func open():
	party_roster = SaveSystem.party_roster
	if party_roster.is_empty(): return

	_refresh_hero_list()
	_select_hero(0)
	var btn: Button = mode_tabs.get_child(0)
	btn.set_pressed_no_signal(true)
	show()

func _on_back_pressed():
	hide()

func _refresh_hero_list():
	for child in hero_list_container.get_children():
		child.queue_free()

	for i in range(party_roster.size()):
		var hero_data = party_roster[i]
		var panel = hero_panel_scene.instantiate() as HeroPanel
		hero_list_container.add_child(panel)

		panel.setup(hero_data)
		panel.panel_selected.connect(_on_hero_panel_selected)
		panel.equip_requested.connect(_on_hero_equip_requested.bind(i))
		panel.tune_requested.connect(_on_hero_tune_requested.bind(i))
		panel.mod_requested.connect(_on_hero_mod_requested.bind(i))

		# Visual selection state
		if i == current_hero_idx:
			panel.set_expanded(true)
		else:
			panel.set_expanded(false)

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
	var panels = hero_list_container.get_children()
	for i in range(panels.size()):
		var p = panels[i] as HeroPanel
		if p == selected_panel:
			p.set_expanded(true)
			_select_hero(i)
		else:
			p.set_expanded(false)

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

func _on_mode_changed(mode_index: int):
	if current_mode == mode_index: return
	current_mode = mode_index
	var btn: Button = mode_tabs.get_child(mode_index)
	btn.button_pressed = true
	_update_active_view()

func _update_active_view():
	var hero = party_roster[current_hero_idx]
	var is_inventory = (current_mode == 1)
	for i in range(hero_list_container.get_child_count()):
		var panel = hero_list_container.get_child(i) as HeroPanel
		panel.set_mode(is_inventory)
		if i == current_hero_idx:
			panel.set_expanded(true)
		else:
			panel.set_expanded(false)
			panel.clear_highlights()

	if current_mode == 0:
		# SKILLS
		inventory_view.hide()
		skill_view.show()
		skill_view.setup(hero)

	elif current_mode == 1:
		# INVENTORY
		skill_view.hide()
		inventory_view.show()
		inventory_view.setup(hero)

func _get_panel_by_index(index: int) -> HeroPanel:
	if index >= 0 and index < hero_list_container.get_child_count():
		return hero_list_container.get_child(index) as HeroPanel
	return null

func _on_hero_stats_updated():
	SaveSystem.save_current_slot()
	if current_hero_idx < hero_list_container.get_child_count():
		var panel = hero_list_container.get_child(current_hero_idx) as HeroPanel
		panel.setup(party_roster[current_hero_idx])

func _on_back_btn_pressed() -> void:
	hide()
