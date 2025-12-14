extends Panel
class_name EquipmentPanel

@export var weapon_icon: Texture2D
@export var armor_icon: Texture2D

@onready var icon_rect: TextureRect = $Border/Content/Icon
@onready var type_icon: TextureRect = $Header/Icon
@onready var name_label: Label = $Header/Label
@onready var xp_label: Label = $Border/Content/XP/Value
@onready var xp_gauge: ProgressBar = $Border/Content/XP/ProgressBar
@onready var details: Control = $VBox/Details
@onready var stars: HBoxContainer = $Border/Content/XP/Stars
@onready var shadows: HBoxContainer = $Border/Content/XP/Shadows

# Setup visuals based on the Equipment Data
func setup(item: Equipment):
	if not item:
		# Empty State
		name_label.text = "Empty"
		icon_rect.texture = null # Or a "Empty Slot" texture
		details.modulate.a = 0.0
		return

	type_icon.texture = ItemDatabase.get_type_icon(item)
	name_label.text = item.get_display_name()
	icon_rect.texture = item.icon

	# Color by Rarity (Optional polish)
	# self.self_modulate = get_rarity_color(item.rarity)

	_refresh_details(item)

func _refresh_details(item: Equipment):
	# Here you would populate the StatsContainer and ModsContainer
	# based on the item.installed_mods and calculated stats.
	for child in stars.get_children():
		var i = child.get_index()
		var display = i < item.tier
		child.visible = display
		shadows.get_child(i).visible = display

	var next = (item.rank + 1) * 100
	xp_gauge.max_value = next
	xp_gauge.value = item.current_xp
	next -= item.current_xp
	xp_label.text = Utils.commafy(next)

# Called by HeroPanel to animate visibility
func set_expanded_visuals(is_expanded: bool, duration: float, tween: Tween):
	var target_alpha = 1.0 if is_expanded else 0.0
	tween.parallel().tween_property(details, "modulate:a", target_alpha, duration)

func _on_button_gui_input(_event: InputEvent) -> void:
	pass # Replace with function body.
