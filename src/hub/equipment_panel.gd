extends Panel
class_name EquipmentPanel

signal equip_requested(current_item)
signal tune_requested(current_item)
signal mod_requested(current_item, slot_index)

@onready var icon_rect: TextureRect = $Border/Content/Icon
@onready var type_icon: TextureRect = $Icon
@onready var name_label: Label = $Label
@onready var xp_label: Label = $Border/Content/XP/Gauge/Value
@onready var xp_gauge: ProgressBar = $Border/Content/XP/Gauge
@onready var rank_label: Label = $Border/Content/XP/Gauge/Rank
@onready var weapon_stats: GridContainer = $Border/Content/WeaponStats
@onready var armor_stats: GridContainer = $Border/Content/ArmorStats
@onready var mods_container: HBoxContainer = $Border/Content/Mods
@onready var header: Panel = $Header

@onready var equip_button: TextureButton = $EquipBtn
@onready var tune_btn: TextureButton = $Border/Content/XP/TuneBtn

var equipment: Equipment
var _highlight_tween: Tween


func setup(item: Equipment):
	if not item:
		name_label.text = "Empty"
		icon_rect.texture = null
		return
	equipment = item
	if equipment.stats_changed.is_connected(_refresh_details):
		equipment.stats_changed.disconnect(_refresh_details)

	if not equipment.stats_changed.is_connected(_refresh_details):
		equipment.stats_changed.connect(_refresh_details)

	type_icon.texture = ItemDatabase.get_equipment_icon(equipment)
	name_label.text = equipment.get_display_name()
	icon_rect.texture = equipment.icon

	for slot in mods_container.get_children():
		var max_slots = equipment.get_max_mod_slots()
		var enable = slot.get_index() < max_slots
		slot.setup(null, enable)

	set_visual_state("none")
	_refresh_details()

func _refresh_details():
	if not equipment: return
	name_label.text = equipment.get_display_name()
	var next = (equipment.rank + 1) * 100
	xp_gauge.max_value = next
	xp_gauge.value = equipment.current_xp
	next -= equipment.current_xp
	if equipment.rank == equipment.get_rank_cap():
		xp_label.text = "MAX"
		xp_gauge.value = next
		rank_label.text = str(equipment.rank) + "/" + str(equipment.get_rank_cap())

	else:
		xp_label.text = Utils.commafy(next) + " EP"
		rank_label.text = "-> " + str(equipment.rank + 1) + "/" + str(equipment.get_rank_cap())
	if equipment.slot == Equipment.Slot.WEAPON:
		_refresh_weapon()
	else:
		_refresh_armor()
	_refresh_mods()

func _refresh_weapon():
	armor_stats.hide()
	var stats: ActorStats = equipment.calculate_stats()
	weapon_stats.get_child(0).text = "ATK+" + Utils.stringify(stats.attack, 3)
	weapon_stats.get_child(1).text = "PSY+" + Utils.stringify(stats.psyche, 3)
	weapon_stats.get_child(2).text = "OVR+" + Utils.stringify(stats.overload, 3)
	weapon_stats.get_child(3).text = "SPD+" + Utils.stringify(stats.speed, 3)
	weapon_stats.get_child(4).text = "AIM+" + Utils.stringify(stats.aim) + "%"
	weapon_stats.get_child(5).text = "PRE+" + Utils.stringify(stats.precision, 3)
	weapon_stats.show()

func _refresh_armor():
	weapon_stats.hide()
	var stats: ActorStats = equipment.calculate_stats()
	armor_stats.get_child(0).text = "GRD+" + str(stats.starting_guard)
	armor_stats.get_child(1).text = "FOC+" + str(stats.starting_focus)
	armor_stats.get_child(2).text = "HP+" + Utils.stringify(stats.max_hp, 4)
	armor_stats.get_child(3).text = "SPD+" + Utils.stringify(stats.speed, 3)
	armor_stats.get_child(4).text = "KIN+" + Utils.stringify(stats.kinetic_defense) + "%"
	armor_stats.get_child(5).text = "NRG+" + Utils.stringify(stats.energy_defense) + "%"
	armor_stats.show()

func _refresh_mods():
	# 1. Get Limits
	# e.g. Tier 3 item has 3 slots.
	var max_slots = equipment.get_max_mod_slots()

	# 2. Iterate through the UI slots
	var ui_slots = mods_container.get_children()

	for i in range(ui_slots.size()):
		var slot_ui = ui_slots[i] as ModSlot
		if not slot_ui: continue

		# 3. Disconnect old signals (Safety)
		if slot_ui.clicked.is_connected(_on_mod_slot_clicked):
			slot_ui.clicked.disconnect(_on_mod_slot_clicked)

		# 4. Determine Data
		var mod_data = null
		if i < equipment.installed_mods.size():
			mod_data = equipment.installed_mods[i]

		# 5. Determine State
		# Slot is enabled if it's within the Tier limit
		var is_enabled = (i < max_slots)

		# 6. Setup
		slot_ui.setup(mod_data, is_enabled)

		# 7. Connect Signal
		if is_enabled:
			slot_ui.clicked.connect(_on_mod_slot_clicked.bind(i))

func _on_mod_slot_clicked(slot_index: int):
	mod_requested.emit(equipment, slot_index)

	var ui_slots = mods_container.get_children()
	for i in range(ui_slots.size()):
		var slot = ui_slots[i] as ModSlot
		if not slot: continue

		if i == slot_index:
			slot.pulse(Color.CYAN)
		else:
			slot.stop_pulse()

func set_visual_state(mode: String):
	if _highlight_tween: _highlight_tween.kill()
	header.modulate = Color.WHITE

	# 3. Handle Tune Button State
	# We forcibly set the button state to match the mode
	tune_btn.set_pressed_no_signal(mode == "tune")
	tune_btn.modulate = Color.WHITE

	var target_color = Color.WHITE
	var do_pulse = false

	match mode:
		"equip":
			target_color = Color.GOLD
			do_pulse = true
		"tune":
			target_color = Color.GREEN
			tune_btn.modulate = target_color
			do_pulse = true
		"mod":
			target_color = Color.CYAN
			do_pulse = true
		"none":
			do_pulse = false

	if do_pulse:
		_highlight_tween = create_tween().set_loops()
		_highlight_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_highlight_tween.tween_property(header, "modulate", target_color, 0.5)
		_highlight_tween.tween_property(header, "modulate", Color.WHITE, 0.5)

	if mode != "mod":
		var ui_slots = mods_container.get_children()
		for child in ui_slots:
			if child is ModSlot:
				child.stop_pulse()

func _exit_tree():
	if _highlight_tween: _highlight_tween.kill()

func _on_equip_btn_pressed() -> void:
	equip_requested.emit(equipment)

func _on_tune_btn_pressed() -> void:
	tune_requested.emit(equipment)
