extends Panel
class_name HeroPanel

signal panel_selected(hero_panel)

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


func _ready():
	custom_minimum_size.y = collapsed_y

func setup(hero_data: HeroData):
	data = hero_data
	name_label.text = data.hero_name.to_upper()
	_refresh_stats()
	weapon_panel.setup(data.weapon)
	armor_panel.setup(data.armor)

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

# --- INPUT HANDLING ---
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		panel_selected.emit(self)

func set_mode(is_inventory_mode: bool):
	weapon_panel.visible = is_inventory_mode
	armor_panel.visible = is_inventory_mode

func set_expanded(is_expanded: bool, animate: bool = true):
	var target_h = expanded_y if is_expanded else collapsed_y
	if not animate:
		custom_minimum_size.y = target_h
		return

	if _size_tween and _size_tween.is_running():
		_size_tween.kill()

	_size_tween = create_tween().set_parallel(true)
	_size_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_size_tween.tween_property(self, "custom_minimum_size:y", target_h, 0.3)
