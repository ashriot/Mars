extends Panel
class_name HeroPanel

signal panel_selected(hero_panel)
signal content_requested(hero_panel: HeroPanel)
signal equip_requested(item, slot_type)
signal tune_requested(item)
signal mod_requested(item, slot_index)

@onready var stats_content: Control = $Content
@onready var name_label: Label = $Content/Header/Label
@onready var hp: RichTextLabel = $Content/Stats/HP/Value
@onready var guard: RichTextLabel = $Content/Stats/Resources/Guard/Value
@onready var focus: RichTextLabel = $Content/Stats/Resources/Focus/Value
@onready var atk: RichTextLabel = $Content/Stats/POW/ATK/Value
@onready var psy: RichTextLabel = $Content/Stats/POW/PSY/Value
@onready var ovr: RichTextLabel = $Content/Stats/SUB/OVR/Value
@onready var spd: RichTextLabel = $Content/Stats/SUB/SPD/Value
@onready var aim: RichTextLabel = $Content/Stats/AIM/AIM/Value
@onready var pre: RichTextLabel = $Content/Stats/AIM/PRE/Value
@onready var kin: RichTextLabel = $Content/Stats/DEF/KIN/Value
@onready var nrg: RichTextLabel = $Content/Stats/DEF/NRG/Value

@onready var weapon_panel: EquipmentPanel = $Equipment/WeaponPanel
@onready var armor_panel: EquipmentPanel = $Equipment/ArmorPanel

var collapsed_y: float = 96.0
var expanded_y: float = 296.0
var data: HeroData
var _size_tween: Tween
var _is_expanded := false


func _ready():
	DisplayProfile.bind(apply_display_profile)
	set_meta("navigation_focus_surface", NodePath("FocusOutline"))
	set_meta("navigation_focus_pulse", true)
	custom_minimum_size.y = collapsed_y
	HubChrome.capture($FocusOutline)
	# 1. WEAPON SIGNALS
	weapon_panel.equip_requested.connect(func(item):
		equip_requested.emit(item, Equipment.Slot.WEAPON)
	)
	weapon_panel.tune_requested.connect(func(item):
		tune_requested.emit(item)
	)
	weapon_panel.mod_requested.connect(func(item, slot):
		mod_requested.emit(item, slot)
	)

	# 2. ARMOR SIGNALS
	armor_panel.equip_requested.connect(func(item):
		equip_requested.emit(item, Equipment.Slot.ARMOR)
	)
	armor_panel.tune_requested.connect(func(item):
		tune_requested.emit(item)
	)
	armor_panel.mod_requested.connect(func(item, slot):
		mod_requested.emit(item, slot)
	)


func apply_display_profile(profile: int, window_size: Vector2i, logical_size: Vector2) -> void:
	var compact := profile == DisplayProfileService.Profile.COMPACT
	collapsed_y = 126.0 if compact else 96.0
	weapon_panel.apply_display_profile(profile, window_size, logical_size)
	armor_panel.apply_display_profile(profile, window_size, logical_size)
	expanded_y = maxf(296.0, maxf(weapon_panel.get_expanded_minimum_height(), armor_panel.get_expanded_minimum_height()))
	set_expanded(_is_expanded, false)

func setup(hero_data: HeroData):
	data = hero_data
	name_label.text = data.hero_name.to_upper()
	_refresh_stats()
	weapon_panel.setup(data.weapon)
	armor_panel.setup(data.armor)
	_refresh_items_focus_neighbors()


func _refresh_items_focus_neighbors() -> void:
	weapon_panel.equip_button.focus_neighbor_top = weapon_panel.equip_button.get_path_to(armor_panel.equip_button)
	weapon_panel.equip_button.focus_neighbor_bottom = weapon_panel.equip_button.get_path_to(armor_panel.equip_button)
	armor_panel.equip_button.focus_neighbor_top = armor_panel.equip_button.get_path_to(weapon_panel.equip_button)
	armor_panel.equip_button.focus_neighbor_bottom = armor_panel.equip_button.get_path_to(weapon_panel.equip_button)

func _refresh_stats():
	data.calculate_stats()
	var stats = data.stats
	hp.text = Utils.stringify(stats.max_hp, 4)
	guard.text = Utils.stringify(stats.starting_guard)
	guard.text += "  " + Utils.stringify(ceili(stats.starting_guard / 2.0))
	focus.text = Utils.stringify(stats.starting_focus)
	atk.text = Utils.stringify(stats.attack, 3)
	psy.text = Utils.stringify(stats.psyche, 3)
	ovr.text = Utils.stringify(stats.overload, 3)
	spd.text = Utils.stringify(stats.speed, 3)
	aim.text = Utils.stringify(stats.aim) + "%"
	pre.text = Utils.stringify(stats.precision, 3)
	kin.text = Utils.stringify(stats.kinetic_defense) + "%"
	nrg.text = Utils.stringify(stats.energy_defense) + "%"

func refresh_stats() -> void:
	_refresh_stats()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		panel_selected.emit(self)
		return
	if has_focus() and (event.is_action_pressed(&"confirm") or event.is_action_pressed(&"nav_right")):
		get_viewport().set_input_as_handled()
		content_requested.emit(self)


func set_chrome_active(active: bool) -> void:
	HubChrome.set_active($FocusOutline, active)
	weapon_panel.set_chrome_active(active)
	armor_panel.set_chrome_active(active)


func items_default_focus() -> Control:
	for control: Control in [weapon_panel.equip_button, armor_panel.equip_button]:
		if control.is_visible_in_tree() and not (control is BaseButton and control.disabled):
			return control
	return null


func items_focus_key(control: Control) -> String:
	return "hero:%s" % get_path_to(control) if is_instance_valid(control) and is_ancestor_of(control) else ""


func restore_items_focus(key: String) -> bool:
	var relative_path := key.trim_prefix("hero:")
	var control := get_node_or_null(NodePath(relative_path)) as Control if key.begins_with("hero:") else items_default_focus()
	if control == null or not control.is_visible_in_tree() or (control is BaseButton and control.disabled):
		control = items_default_focus()
	if control == null:
		return false
	control.grab_focus()
	return true

func set_mode(is_inventory_mode: bool):
	weapon_panel.visible = is_inventory_mode
	armor_panel.visible = is_inventory_mode

func set_expanded(is_expanded: bool, animate: bool = true):
	_is_expanded = is_expanded
	var target_h = expanded_y if is_expanded else collapsed_y
	if _size_tween and _size_tween.is_running():
		_size_tween.kill()
	if not animate:
		custom_minimum_size.y = target_h
		return

	_size_tween = create_tween().set_parallel(true)
	_size_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_size_tween.tween_property(self, "custom_minimum_size:y", target_h, 0.3)

func set_active_mode(active_child: EquipmentPanel, mode_string: String):
	active_child.set_visual_state(mode_string)

	if active_child == weapon_panel:
		armor_panel.set_visual_state("none")
	else:
		weapon_panel.set_visual_state("none")

func clear_highlights():
	weapon_panel.set_visual_state("none")
	armor_panel.set_visual_state("none")
