extends Panel
class_name HeroStatus

@onready var role_ui: Control = $Role
@onready var box: Control = $Role/Window/HBox
@onready var role_name: Label = $Role/Window/HBox/Name
@onready var next_role_name: Label = $Role/Window/HBox/Next
@onready var prev_role_name: Label = $Role/Window/HBox/Prev
@onready var hero_name: Label = $HeroName
@onready var injuries: HBoxContainer = $Injuries
@onready var focused_boon: TextureRect = $Boons/Focused
@onready var armored_boon: TextureRect = $Boons/Armored

@onready var stats_panel: Control = $StatsPanel
@onready var hp: RichTextLabel = $StatsPanel/Panel/Stats/HP/Value
@onready var guard: RichTextLabel = $StatsPanel/Panel/Stats/Resources/Guard/Value
@onready var focus: RichTextLabel = $StatsPanel/Panel/Stats/Resources/Focus/Value
@onready var atk: RichTextLabel = $StatsPanel/Panel/Stats/POW/ATK/Value
@onready var psy: RichTextLabel = $StatsPanel/Panel/Stats/POW/PSY/Value
@onready var ovr: RichTextLabel = $StatsPanel/Panel/Stats/SUB/OVR/Value
@onready var spd: RichTextLabel = $StatsPanel/Panel/Stats/SUB/SPD/Value
@onready var aim: RichTextLabel = $StatsPanel/Panel/Stats/AIM/AIM/Value
@onready var dmg: RichTextLabel = $StatsPanel/Panel/Stats/AIM/AimBonus/Value
@onready var kin: RichTextLabel = $StatsPanel/Panel/Stats/DEF/KIN/Value
@onready var nrg: RichTextLabel = $StatsPanel/Panel/Stats/DEF/NRG/Value

var busy := false
var label_width := 0

var active_color = Color(0.118, 0.118, 0.118, 1.0)
var inactive_color = Color(0.212, 0.212, 0.212, 0.686)

var linked_hero_data: HeroData

var stats_home_pos: Vector2
var stats_home_size_y: int
var is_stats_popped: bool = false
var pop_tween: Tween
const POP_OFFSET_Y: float = 200.0 # How far UP it slides (Negative is Up)

func _ready():
	label_width = int(role_name.size.x)
	_reset_positions()
	await get_tree().process_frame
	stats_home_pos = stats_panel.position
	stats_home_size_y = int(stats_panel.size.y)
	stats_panel.gui_input.connect(_on_stats_panel_input)

func _on_stats_panel_input(event: InputEvent):
	if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_stats_pop()

func _toggle_stats_pop():
	if pop_tween and pop_tween.is_running():
		pop_tween.kill()

	pop_tween = create_tween().set_parallel()
	# TRANS_BACK gives it that nice "overshoot" bounce effect
	pop_tween.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

	if is_stats_popped:
		# Pop Down (Return to Home)
		pop_tween.tween_property(stats_panel, "position", stats_home_pos, 0.3)
		pop_tween.tween_property(stats_panel, "size:y", stats_home_size_y, 0.3)
		is_stats_popped = false
	else:
		# Pop Up (Apply Offset)
		var target_pos = stats_home_pos - Vector2(0, POP_OFFSET_Y)
		var target_size = stats_home_size_y + POP_OFFSET_Y
		pop_tween.tween_property(stats_panel, "position", target_pos, 0.4)
		pop_tween.tween_property(stats_panel, "size:y", target_size, 0.4)
		is_stats_popped = true

func setup(data: HeroData):
	linked_hero_data = data
	refresh_view()

func refresh_view():
	if not linked_hero_data:
		return
	linked_hero_data.calculate_stats()
	var stats: ActorStats = linked_hero_data.stats
	if not stats:
		return

	var defs = linked_hero_data.unlocked_roles
	var idx = linked_hero_data.active_role_index

	var prev_idx = (idx - 1 + defs.size()) % defs.size()
	var next_idx = (idx + 1) % defs.size()

	prev_role_name.text = defs[prev_idx].role_id
	role_name.text = defs[idx].role_id
	next_role_name.text = defs[next_idx].role_id

	hero_name.text = linked_hero_data.hero_name
	var role_color = linked_hero_data.current_role.color
	self.self_modulate = role_color
	$StatsPanel/Panel/Stats/Resources.modulate = role_color
	$StatsPanel/Panel.self_modulate = linked_hero_data.current_role.color
	$StatsPanel/Panel/CloseBtn.self_modulate = linked_hero_data.current_role.color

	# Stats
	var cur_hp = max(0, stats.max_hp * (1 - linked_hero_data.injuries * .34))
	hp.text = _stringify(cur_hp, 4) + "[color=fff]/" + _stringify(stats.max_hp, 4)
	guard.text = _stringify(stats.starting_guard + (5 if linked_hero_data.boon_armored else 0))
	focus.text = _stringify(stats.starting_focus + (5 if linked_hero_data.boon_focused else 0))
	atk.text = _stringify(stats.attack, 3)
	psy.text = _stringify(stats.psyche, 3)
	ovr.text = _stringify(stats.overload, 3)
	spd.text = _stringify(stats.speed, 3)
	aim.text = _stringify(stats.aim) + "%"
	dmg.text = _stringify(stats.aim_bonus, 3)
	kin.text = _stringify(stats.kinetic_defense) + "%"
	nrg.text = _stringify(stats.energy_defense) + "%"

	focused_boon.modulate = active_color if linked_hero_data.boon_focused else inactive_color
	armored_boon.modulate = active_color if linked_hero_data.boon_armored else inactive_color

	var count = linked_hero_data.injuries
	for i in range(injuries.get_child_count()):
		var icon = injuries.get_child(i)
		icon.modulate = active_color if i < count else inactive_color

func _stringify(value: int, pad: int = 2) -> String:
	var full_string = "%0*d" % [pad, value]

	var value_len = str(value).length()
	var zero_count = max(0, full_string.length() - value_len)

	if zero_count == 0:
		return "[color=#fff]%s[/color]" % full_string

	var zeros = full_string.substr(0, zero_count)
	var digits = full_string.substr(zero_count)

	return "[color=#fff2]%s[/color][color=#fff]%s[/color]" % [zeros, digits]

func _reset_positions():
	box.position.x = -63.0

func _slide(direction: int):
	if busy:
		return
	busy = true

	var duration = 0.1

	var defs = linked_hero_data.unlocked_roles
	var idx = linked_hero_data.active_role_index
	var incoming = 0
	if direction == 1:
		incoming = (idx + 1) % defs.size()
		next_role_name.text = defs[incoming].role_id
	else:
		incoming = (idx - 1 + defs.size()) % defs.size()
		prev_role_name.text = defs[incoming].role_id

	var tween := create_tween()

	tween.parallel().tween_property(box, "position:x",
			box.position.x - label_width * direction,
			duration).set_ease(Tween.EASE_OUT)

	var new_color = defs[incoming].color
	tween.parallel().tween_property(self, "self_modulate",
			new_color, duration)

	tween.parallel().tween_property($StatsPanel/Panel, "self_modulate",
			new_color, duration)

	tween.parallel().tween_property($StatsPanel/Panel/CloseBtn, "self_modulate",
			new_color, duration)

	tween.finished.connect(func():
		if direction == 1:
			linked_hero_data.active_role_index = (idx + 1) % defs.size()
		else:
			linked_hero_data.active_role_index = (idx - 1 + defs.size()) % defs.size()

		refresh_view()
		_reset_positions()
		busy = false
	)

func _on_left_pressed() -> void:
	_slide(-1)

func _on_right_pressed() -> void:
	_slide(+1)
