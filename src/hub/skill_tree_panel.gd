extends Control
class_name SkillTreePanel

signal purchase_requested(hero: HeroData, role_id: String, node_id: String)
signal progression_refreshed(hero: HeroData)

@export var role_panel_scene: PackedScene

@onready var role_list_container: HBoxContainer = $RoleList
@onready var tabs_container: HBoxContainer = $Tabs/Container

# --- STATE ---
var party_roster: Array[HeroData] = []
var current_hero: HeroData

var current_hero_idx: int = 0
var current_role_idx: int = 0
var current_page: int = 0
var progression_catalog: ProgressionCatalog


func setup(hero: HeroData):
	current_hero = hero

	# Reset local state
	current_role_idx = 0
	current_page = 0

	# Setup the View
	_refresh_role_list()
	_update_tab_visuals()

	# Trigger initial selection
	# (Your existing logic to select role 0)
	#_on_role_panel_selected(role_list_container.get_child(0))


func _refresh_role_list():
	for child in role_list_container.get_children():
		child.queue_free()

	var roles = current_hero.unlocked_roles
	var rendered_roles: Array[RoleDefinition] = []
	for candidate: RoleDefinition in roles:
		if progression_catalog and progression_catalog.get_role(candidate.role_id):
			rendered_roles.append(candidate)
	current_role_idx = clampi(current_role_idx, 0, rendered_roles.size() - 1) if not rendered_roles.is_empty() else 0

	var color := Color.WHITE
	var rendered_index := 0
	for def: RoleDefinition in rendered_roles:
		var tree := progression_catalog.get_role(def.role_id)
		var panel = role_panel_scene.instantiate() as RolePanel
		role_list_container.add_child(panel)
		panel.setup(def, tree, current_hero)
		panel.panel_selected.connect(_on_role_panel_selected)
		panel.purchase_requested.connect(_on_purchase_requested)

		if rendered_index == current_role_idx:
			panel.set_expanded(true, current_page, true)
			color = panel.def.color
		else:
			panel.set_expanded(false, current_page, false)
		rendered_index += 1
	update_tabs(color)

func refresh_progression_state(hero: HeroData) -> void:
	for child in role_list_container.get_children():
		var panel := child as RolePanel
		if panel and is_same(panel.hero_data, hero):
			panel.refresh_progression_state()
	progression_refreshed.emit(hero)


func _on_purchase_requested(hero: HeroData, role_id: String, node_id: String) -> void:
	purchase_requested.emit(hero, role_id, node_id)

func _on_role_panel_selected(selected_panel: RolePanel):
	var panels = role_list_container.get_children()
	for i in range(panels.size()):
		var p = panels[i] as RolePanel
		if p == selected_panel:
			current_role_idx = i
			p.set_expanded(true, current_page)
		else:
			p.set_expanded(false, current_page)
	update_tabs(selected_panel.def.color)

func update_tabs(color: Color, animate: bool = true):
	var pos = current_role_idx * 290 + current_role_idx * 20
	if not animate:
		tabs_container.position.x = pos
		return

	var tab_tween = create_tween().set_parallel()
	tab_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tab_tween.tween_property(tabs_container, "position:x", pos, 0.3)
	tab_tween.tween_property(tabs_container, "modulate", color, 0.3)

func _on_tab_pressed(page_index: int):
	if current_page == page_index: return

	current_page = page_index

	var panels = role_list_container.get_children()
	for child in panels:
		if child is RolePanel:
			child.render_tree(current_page)

	_update_tab_visuals()

func _update_tab_visuals():
	for i in range(tabs_container.get_child_count()):
		var btn = tabs_container.get_child(i) as Button
		if i == current_page:
			btn.set_pressed_no_signal(true)
