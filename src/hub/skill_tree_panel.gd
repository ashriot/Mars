extends Control
class_name SkillTreePanel

signal purchase_requested(hero: HeroData, role_id: String, node_id: String)
signal progression_refreshed(hero: HeroData)

@export var role_panel_scene: PackedScene

@onready var role_scroll: ScrollContainer = $RoleScroll
@onready var role_list_container: HBoxContainer = $RoleScroll/RoleList
@onready var tabs_container: HBoxContainer = $Tabs/Container

# --- STATE ---
var party_roster: Array[HeroData] = []
var current_hero: HeroData

var current_hero_idx: int = 0
var current_role_idx: int = 0
var current_page: int = 0
var progression_catalog: ProgressionCatalog
var focused_node_id: String = ""
var _focus_memory: Dictionary = {}
var _hero_context_memory: Dictionary = {}
var _display_profile: int = DisplayProfileService.Profile.DESKTOP


func _ready() -> void:
	DisplayProfile.bind(apply_display_profile)
	for index in range(tabs_container.get_child_count()):
		var button := tabs_container.get_child(index) as Button
		button.pressed.connect(_on_tab_pressed.bind(index))
		button.set_meta("navigation_focus_pulse", true)


func apply_display_profile(profile: int, _window_size: Vector2i, _logical_size: Vector2) -> void:
	_display_profile = profile
	for child in role_list_container.get_children():
		if child is RolePanel:
			child.apply_display_profile(profile)
	if not focused_node_id.is_empty():
		focus_node(focused_node_id)


func setup(hero: HeroData):
	_store_focus_memory()
	_store_hero_context()
	current_hero = hero

	var remembered: Dictionary = _hero_context_memory.get(hero.hero_id, {})
	current_role_idx = int(remembered.get("role", 0))
	current_page = int(remembered.get("page", 0))

	# Setup the View
	_refresh_role_list()
	_update_tab_visuals()
	focus_node(_remembered_node_for_current_context())

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
		panel.apply_display_profile(_display_profile)
		panel.setup(def, tree, current_hero)
		panel.panel_selected.connect(_on_role_panel_selected)
		panel.purchase_requested.connect(_on_purchase_requested)
		panel.node_focused.connect(_on_role_node_focused.bind(panel))

		if rendered_index == current_role_idx:
			panel.set_expanded(true, current_page, true)
			color = panel.def.color
		else:
			panel.set_expanded(false, current_page, false)
		rendered_index += 1
	_refresh_role_shortcuts()
	update_tabs(color)
	_update_tab_visuals()

func refresh_progression_state(hero: HeroData) -> void:
	for child in role_list_container.get_children():
		var panel := child as RolePanel
		if panel and is_same(panel.hero_data, hero):
			panel.refresh_progression_state()
	progression_refreshed.emit(hero)


func _on_purchase_requested(hero: HeroData, role_id: String, node_id: String) -> void:
	purchase_requested.emit(hero, role_id, node_id)


func _on_role_node_focused(node_id: String, role_panel: RolePanel) -> void:
	if role_panel != _current_role_panel():
		return
	if focused_node_id != node_id:
		focused_node_id = node_id
		_focus_memory[_memory_key()] = node_id
	var node := role_panel.generated_nodes.get(node_id) as Control
	if node:
		_publish_hints(node)
		call_deferred(&"ensure_node_visible", node)

func _on_role_panel_selected(selected_panel: RolePanel):
	var panels = role_list_container.get_children()
	for i in range(panels.size()):
		var p = panels[i] as RolePanel
		if p == selected_panel:
			current_role_idx = i
			p.set_expanded(true, current_page)
		else:
			p.set_expanded(false, current_page)
	_refresh_role_shortcuts()
	update_tabs(selected_panel.def.color)
	_update_tab_visuals()
	call_deferred(&"ensure_node_visible", selected_panel)

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
	var button := tabs_container.get_child(page_index) as Button
	if button == null or not button.visible or button.disabled or current_page == page_index:
		return

	var anchor := _focused_position()
	_store_focus_memory()
	current_page = page_index

	var panels = role_list_container.get_children()
	for child in panels:
		if child is RolePanel:
			child.render_tree(current_page)

	_update_tab_visuals()
	var remembered := _remembered_node_for_current_context()
	if remembered.is_empty() and anchor != Vector2.INF:
		focus_node(_nearest_node_to(anchor))
	else:
		focus_node(remembered)

func _update_tab_visuals():
	var supported_pages := _supported_pages(_current_role_panel())
	var visible_buttons: Array[Button] = []
	for i in range(tabs_container.get_child_count()):
		var btn := tabs_container.get_child(i) as Button
		var supported := i in supported_pages
		btn.visible = supported
		btn.disabled = not supported
		btn.set_pressed_no_signal(i == current_page)
		btn.focus_neighbor_left = NodePath()
		btn.focus_neighbor_right = NodePath()
		if supported:
			visible_buttons.append(btn)
	for index in range(visible_buttons.size()):
		var button := visible_buttons[index]
		var previous := visible_buttons[posmod(index - 1, visible_buttons.size())]
		var next := visible_buttons[posmod(index + 1, visible_buttons.size())]
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)


func focus_node(node_id: String) -> bool:
	var role_panel := _current_role_panel()
	if role_panel == null or role_panel.generated_nodes.is_empty():
		focused_node_id = ""
		return false
	var target_id := node_id
	if not role_panel.generated_nodes.has(target_id):
		target_id = _nearest_node_id(role_panel)
	var target := role_panel.generated_nodes.get(target_id) as Control
	if target == null:
		return false
	focused_node_id = target_id
	_focus_memory[_memory_key()] = target_id
	if target.is_inside_tree() and target.is_visible_in_tree(): target.grab_focus()
	_publish_hints(target)
	call_deferred(&"ensure_node_visible", target)
	return true


func ensure_node_visible(node: Control) -> void:
	if is_instance_valid(node):
		role_scroll.ensure_control_visible(node)


func get_focused_node() -> Control:
	var panel := _current_role_panel()
	return panel.generated_nodes.get(focused_node_id) as Control if panel else null


func move_focus(direction: Vector2) -> bool:
	var panel := _current_role_panel()
	if panel == null: return false
	var candidate := SkillTreeNavigation.find_directional_candidate(focused_node_id, direction, panel.node_positions())
	return focus_node(candidate) if not candidate.is_empty() else false


func change_page(delta: int) -> void:
	if delta == 0: return
	var role_panel := _current_role_panel()
	var supported_pages := _supported_pages(role_panel)
	if supported_pages.is_empty(): return
	var page_index := supported_pages.find(current_page)
	if page_index < 0:
		current_page = _closest_supported_page(role_panel, current_page)
		page_index = supported_pages.find(current_page)
	var next_page: int = supported_pages[posmod(page_index + signi(delta), supported_pages.size())]
	if next_page == current_page:
		return
	var anchor := _focused_position()
	_store_focus_memory()
	current_page = next_page
	for child in role_list_container.get_children():
		if child is RolePanel: child.render_tree(current_page)
	_update_tab_visuals()
	var remembered := _remembered_node_for_current_context()
	if remembered.is_empty() and anchor != Vector2.INF:
		focus_node(_nearest_node_to(anchor))
	else:
		focus_node(remembered)


func change_role(delta: int) -> void:
	var count := role_list_container.get_child_count()
	if delta == 0 or count == 0: return
	var anchor := _focused_position()
	_store_focus_memory()
	current_role_idx = posmod(current_role_idx + delta, count)
	var selected := role_list_container.get_child(current_role_idx) as RolePanel
	current_page = _closest_supported_page(selected, current_page)
	_on_role_panel_selected(selected)
	var remembered := _remembered_node_for_current_context()
	if selected.generated_nodes.has(remembered):
		focus_node(remembered)
	elif anchor != Vector2.INF:
		focus_node(_nearest_node_to(anchor))
	else:
		focus_node("")


func confirm_focused_node() -> void:
	var node := get_focused_node()
	if node is SkillTreeNode and node.is_purchasable():
		_on_purchase_requested(current_hero, _current_role_panel().role_id, node.node_definition.id)


func remember_focus() -> String:
	_store_focus_memory()
	_store_hero_context()
	return focused_node_id


func restore_focus() -> bool:
	return focus_node(_remembered_node_for_current_context())


func cancel_navigation() -> bool:
	return false


func set_chrome_active(active: bool) -> void:
	for child in role_list_container.get_children():
		if child is RolePanel:
			(child as RolePanel).set_chrome_active(active)


func focus_current_page_tab() -> bool:
	var button := tabs_container.get_child(current_page) as Button
	if button == null or not button.visible or button.disabled:
		return false
	button.grab_focus()
	return true


func focus_node_from_page_tabs() -> bool:
	return focus_node(_remembered_node_for_current_context())


func _page_tabs_own_focus() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner != null and (owner == tabs_container or tabs_container.is_ancestor_of(owner))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"hub_role_previous"):
		change_role(-1)
	elif event.is_action_pressed(&"hub_role_next"):
		change_role(1)
	elif _node_owns_focus() and event.is_action_pressed(&"nav_up"):
		move_focus(Vector2.UP)
	elif _node_owns_focus() and event.is_action_pressed(&"nav_down"):
		if not move_focus(Vector2.DOWN):
			focus_current_page_tab()
	elif _node_owns_focus() and event.is_action_pressed(&"nav_left"):
		move_focus(Vector2.LEFT)
	elif _node_owns_focus() and event.is_action_pressed(&"nav_right"):
		move_focus(Vector2.RIGHT)
	elif _page_tabs_own_focus() and event.is_action_pressed(&"nav_up"):
		focus_node_from_page_tabs()
	elif _node_owns_focus() and event.is_action_pressed(&"confirm"):
		confirm_focused_node()
	else:
		return
	get_viewport().set_input_as_handled()


func _current_role_panel() -> RolePanel:
	if current_role_idx < 0 or current_role_idx >= role_list_container.get_child_count(): return null
	return role_list_container.get_child(current_role_idx) as RolePanel


func _memory_key() -> String:
	var panel := _current_role_panel()
	return "%s:%s:%d" % [current_hero.hero_id if current_hero else "", panel.role_id if panel else "", current_page]


func _store_focus_memory() -> void:
	if not focused_node_id.is_empty() and current_hero and _current_role_panel(): _focus_memory[_memory_key()] = focused_node_id


func _store_hero_context() -> void:
	if current_hero:
		_hero_context_memory[current_hero.hero_id] = {"role": current_role_idx, "page": current_page}


func _remembered_node_for_current_context() -> String:
	return _focus_memory.get(_memory_key(), "")


func _nearest_node_id(panel: RolePanel) -> String:
	var ids: Array = panel.generated_nodes.keys()
	ids.sort()
	return ids[0] if not ids.is_empty() else ""


func _node_owns_focus() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	var node := get_focused_node()
	return node != null and owner != null and (owner == node or node.is_ancestor_of(owner))


func _focused_position() -> Vector2:
	var node := get_focused_node()
	return node.position + node.size * 0.5 if node else Vector2.INF


func _nearest_node_to(anchor: Vector2) -> String:
	var panel := _current_role_panel()
	if panel == null: return ""
	var best_id := ""
	var best_distance := INF
	for node_id: String in panel.node_positions():
		var distance: float = (panel.node_positions()[node_id] as Vector2).distance_squared_to(anchor)
		if distance < best_distance or (distance == best_distance and node_id < best_id):
			best_distance = distance
			best_id = node_id
	return best_id


func _closest_supported_page(panel: RolePanel, desired_page: int) -> int:
	var pages := _supported_pages(panel)
	if pages.is_empty():
		return 0
	pages.sort_custom(func(a: int, b: int) -> bool:
		var a_distance := absi(a - desired_page)
		var b_distance := absi(b - desired_page)
		return a_distance < b_distance if a_distance != b_distance else a < b
	)
	return pages[0]


func _supported_pages(panel: RolePanel) -> Array[int]:
	var pages: Array[int] = []
	if panel and panel.tree_definition:
		for node: ProgressionNodeDefinition in panel.tree_definition.nodes:
			var page := (node.rank - 1) / 10
			if page not in pages:
				pages.append(page)
	pages.sort()
	return pages


func _refresh_role_shortcuts() -> void:
	var enabled := role_list_container.get_child_count() > 1
	for child in role_list_container.get_children():
		if child is RolePanel:
			(child as RolePanel).set_role_shortcuts_enabled(enabled)


func _publish_hints(node: Control) -> void:
	var navigation := get_tree().root.find_child("NavigationUXLayer", true, false) as NavigationUXLayer
	if navigation:
		var purchasable: bool = node is SkillTreeNode and node.is_purchasable()
		var inspectable: bool = not (node is SkillTreeNode) or node.state == SkillTreeNode.NodeState.LOCKED
		var hints: Array[Dictionary] = [
			{action = &"confirm", label = "Upgrade" if purchasable else "Inspect", enabled = purchasable or inspectable},
			{action = &"cancel", label = "Back", enabled = true},
			{action = &"hub_role_previous", label = "Role", enabled = role_list_container.get_child_count() > 1},
		]
		navigation.publish_hints(hints)
