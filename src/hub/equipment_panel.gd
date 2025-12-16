extends Panel
class_name EquipmentPanel

signal equip_requested(current_item)
signal tune_requested(current_item)
signal mod_requested(current_item, slot_index)

@onready var icon_rect: TextureRect = $Border/Content/Icon
@onready var type_icon: TextureRect = $Header/Icon
@onready var name_label: Label = $Header/Label
@onready var xp_label: Label = $Border/Content/XP/Gauge/Value
@onready var xp_gauge: ProgressBar = $Border/Content/XP/Gauge
@onready var rank_label: Label = $Border/Content/XP/Gauge/Rank
@onready var weapon_stats: GridContainer = $Border/Content/WeaponStats
@onready var armor_stats: GridContainer = $Border/Content/ArmorStats
@onready var mods_container: HBoxContainer = $Border/Content/Mods

@onready var equip_button: TextureButton = $Header/EquipBtn
@onready var tune_button: TextureButton = $Border/Content/XP/TuneBtn

var equipment: Equipment

# Setup visuals based on the Equipment Data
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
		var enable = slot.get_index() < equipment.tier
		slot.setup(null, enable)

	_refresh_details()

func _refresh_details():
	# Here you would populate the StatsContainer and ModsContainer
	# based on the item.installed_mods and calculated stats.
	var next = (equipment.rank + 1) * 100
	xp_gauge.max_value = next
	xp_gauge.value = equipment.current_xp
	next -= equipment.current_xp
	if equipment.rank == equipment.get_rank_cap():
		xp_label.text = "MAX"
		xp_gauge.value = next
	else:
		xp_label.text = "-" + Utils.commafy(next) + " EP"
	rank_label.text = "Rk." + str(equipment.rank) + "/" + str(equipment.get_rank_cap())
	if equipment.slot == Equipment.Slot.WEAPON:
		_refresh_weapon()
	else:
		_refresh_armor()

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

func _on_equip_btn_pressed() -> void:
	equip_requested.emit(equipment)
	print("Equip requested!")

func _on_tune_btn_pressed() -> void:
	tune_requested.emit(equipment)
	print("Tune requested!")
