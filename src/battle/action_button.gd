extends Control
class_name ActionButton

signal pressed(action_button: ActionButton)

@onready var tooltip: RichTooltip = $RichTooltip
@onready var label = $Title
@onready var icon: TextureRect = $Mask/Icon
@onready var button : Button = $Button
@onready var focus_pips = $FocusPips
@onready var highlight_panel: Panel = $Highlight
@onready var dynamic_glyph: DynamicGlyph = $DynamicGlyph

var glyph_backing: Panel

@export var glyph_action: StringName = &"action_1"

var action : Action
var user_focus: int
var focus_cost: int
var override_disabled: bool :
	set(value):
		override_disabled = value
		button.disabled = value
		_refresh_disabled_presentation()
var disabled:
	set(value):
		button.disabled = value or override_disabled
		if action:
			if not value:
				button.disabled = user_focus < focus_cost or override_disabled
		_refresh_disabled_presentation()
	get: return button.disabled


func _ready() -> void:
	_ensure_glyph_backing()
	dynamic_glyph.set_action(glyph_action)


func _ensure_glyph_backing() -> void:
	glyph_backing = get_node_or_null("GlyphBacking") as Panel
	if glyph_backing or not dynamic_glyph:
		return
	glyph_backing = Panel.new()
	glyph_backing.name = "GlyphBacking"
	glyph_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph_backing.anchor_left = dynamic_glyph.anchor_left
	glyph_backing.anchor_top = dynamic_glyph.anchor_top
	glyph_backing.anchor_right = dynamic_glyph.anchor_right
	glyph_backing.anchor_bottom = dynamic_glyph.anchor_bottom
	glyph_backing.offset_left = dynamic_glyph.offset_left + 8.0
	glyph_backing.offset_top = dynamic_glyph.offset_top + 8.0
	glyph_backing.offset_right = dynamic_glyph.offset_right - 8.0
	glyph_backing.offset_bottom = dynamic_glyph.offset_bottom - 8.0
	glyph_backing.grow_horizontal = dynamic_glyph.grow_horizontal
	glyph_backing.grow_vertical = dynamic_glyph.grow_vertical
	var backing_style := StyleBoxFlat.new()
	backing_style.bg_color = Color(0.025, 0.035, 0.08, 1.0)
	backing_style.corner_radius_top_left = 8
	backing_style.corner_radius_top_right = 8
	backing_style.corner_radius_bottom_right = 8
	backing_style.corner_radius_bottom_left = 8
	glyph_backing.add_theme_stylebox_override("panel", backing_style)
	add_child(glyph_backing)
	move_child(glyph_backing, dynamic_glyph.get_index())


func setup(_action: Action, actor: HeroCard, scaled_focus: int, color: Color):
	action = _action
	tooltip.bbcode_text = action.get_rich_description(actor)
	user_focus = actor.current_focus
	focus_cost = scaled_focus
	label.text = action.action_name
	icon.texture = action.icon
	update_cost(user_focus)
	button.modulate = color
	icon.modulate = color
	label.modulate = color
	focus_pips.modulate = color
	highlight_panel.modulate = color
	dynamic_glyph.modulate = color
	_refresh_disabled_presentation()
	highlight_panel.hide()

func update_cost(current_focus: int):
	user_focus = current_focus
	var pips = focus_pips.get_children()
	var unfilled_pips = max(0, focus_cost - user_focus)
	for i in pips.size():
		var pip_node = pips[i]
		if i < focus_cost:
			pip_node.visible = true
			if i < unfilled_pips:
				pip_node.modulate.a = 0.33
			else:
				pip_node.modulate.a = 1.0
		else:
			pip_node.visible = false
	self.disabled = false

func _on_button_pressed():
	pressed.emit()

func focused(value: bool):
	highlight_panel.visible = value


func _refresh_disabled_presentation() -> void:
	if dynamic_glyph:
		dynamic_glyph.modulate.a = 0.33 if button and button.disabled else 1.0
