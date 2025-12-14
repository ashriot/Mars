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
	# Connect Mode Tabs (assuming 2 buttons)
	for i in range(mode_tabs.get_child_count()):
		var btn = mode_tabs.get_child(i) as Button
		btn.pressed.connect(_on_mode_changed.bind(i))

func open():
	party_roster = SaveSystem.party_roster
	if party_roster.is_empty(): return

	_refresh_hero_list()

	_select_hero(0)
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

		# Visual selection state
		if i == current_hero_idx:
			panel.set_expanded(true)
		else:
			panel.set_expanded(false)

func _on_hero_panel_selected(selected_panel: HeroPanel):
	var panels = hero_list_container.get_children()
	for i in range(panels.size()):
		var p = panels[i] as HeroPanel
		if p == selected_panel:
			p.set_expanded(true)
			_select_hero(i)
		else:
			p.set_expanded(false)

func _select_hero(index: int):
	current_hero_idx = index
	_update_active_view()

func _on_mode_changed(mode_index: int):
	if current_mode == mode_index: return
	current_mode = mode_index
	_update_active_view()

func _update_active_view():
	var is_inventory = (current_mode == 1)
	for child in hero_list_container.get_children():
		if child is HeroPanel:
			child.set_mode(is_inventory)

	var hero = party_roster[current_hero_idx]

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

func _on_back_btn_pressed() -> void:
	hide()
