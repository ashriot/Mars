extends Panel
class_name HeroPanel

signal panel_selected(hero_panel)

@onready var content: Control = $Content
@onready var name_label: Label = $Header/Label
@onready var hp_value: RichTextLabel = $Content/Stats/HP/Value
@onready var grd_value: RichTextLabel = $Content/Stats/Resources/Guard/Value
@onready var foc_value: RichTextLabel = $Content/Stats/Resources/Focus/Value
@onready var atk_value: RichTextLabel = $Content/Stats/POW/ATK/Value
@onready var psy_value: RichTextLabel = $Content/Stats/POW/PSY/Value
@onready var ovr_value: RichTextLabel = $Content/Stats/SUB/OVR/Value
@onready var spd_value: RichTextLabel = $Content/Stats/SUB/SPD/Value
@onready var aim_value: RichTextLabel = $Content/Stats/AIM/AIM/Value
@onready var pre_value: RichTextLabel = $Content/Stats/AIM/PRE/Value
@onready var kin_value: RichTextLabel = $Content/Stats/DEF/KIN/Value
@onready var nrg_value: RichTextLabel = $Content/Stats/DEF/NRG/Value


var collapsed_y: float = 96.0
var expanded_y: float = 296.0
var data: HeroData
var _size_tween: Tween


func _ready():
	# Ensure clipping is on so content doesn't spill out while shrinking
	# Start collapsed by default
	custom_minimum_size.y = collapsed_y

func setup(hero_data: HeroData):
	data = hero_data
	name_label.text = data.hero_name.to_upper()
	_refresh_stats()

func _refresh_stats():
	data.calculate_stats()
	var stats = data.stats
	hp_value.text = str(stats.max_hp)
	grd_value.text = str(stats.starting_guard)
	foc_value.text = str(stats.starting_focus)

# --- INPUT HANDLING ---
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		panel_selected.emit(self)

# --- ANIMATION LOGIC ---
func set_expanded(is_expanded: bool):
	if _size_tween and _size_tween.is_running():
		_size_tween.kill()

	_size_tween = create_tween().set_parallel(true)
	_size_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var target_h = expanded_y if is_expanded else collapsed_y

	# 1. Animate Height (The VBox will update automatically)
	_size_tween.tween_property(self, "custom_minimum_size:y", target_h, 0.3)
