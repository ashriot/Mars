extends Control
class_name EnemyGuardStack


const MAX_GUARD := 30
const PIPS_PER_LAYER := 10
const LAYER_STEP := 5.0
const PIP_SIZE := Vector2(21.0, 22.0)
const PIP_STEP := 22.0
const ACTIVE_PIP_SIZE := Vector2(36.0, 34.0)
const ACTIVE_LEFT_SHIFT := 7.0
const ACTIVE_SHADOW_OFFSET := Vector2(2.0, 3.0)
const WHITE := Color.WHITE
const MEDIUM_GRAY := Color(0.62, 0.65, 0.7, 1.0)
const DARK_GRAY := Color(0.34, 0.37, 0.42, 1.0)

@onready var layers: Array[Control] = [%Layer1, %Layer2, %Layer3]
@onready var active_shadow: TextureRect = %ActiveShieldShadow
@onready var guard_value: Label = %GuardValue
@onready var status_label: Label = %StatusLabel

var _guard := 0


func render(guard: int, is_in_danger: bool, is_breached: bool) -> void:
	var value := clampi(guard, 0, MAX_GUARD)
	_guard = value
	var layer_count := get_visual_layer_count()
	status_label.text = "BREACHED" if is_breached \
		else ("VULNERABLE" if is_in_danger else "")
	status_label.visible = value == 0 and not status_label.text.is_empty()
	guard_value.visible = value > 0
	active_shadow.visible = false
	_reset_pip_geometry()
	for layer_index: int in layers.size():
		var visible_count := clampi(value - layer_index * PIPS_PER_LAYER, 0, PIPS_PER_LAYER)
		for pip_index: int in PIPS_PER_LAYER:
			var pip := layers[layer_index].get_child(pip_index) as TextureRect
			pip.visible = pip_index < visible_count
			pip.modulate = _layer_color(layer_index, layer_count)
	if value > 0:
		var current_layer := floori(float(value - 1) / PIPS_PER_LAYER)
		var current_column := (value - 1) % PIPS_PER_LAYER
		var current_pip := layers[current_layer].get_child(current_column) as TextureRect
		var base_position := Vector2(PIP_STEP * current_column, 0.0)
		var active_position := Vector2(maxf(0.0, base_position.x - ACTIVE_LEFT_SHIFT), -5.0)
		current_pip.position = active_position
		current_pip.size = ACTIVE_PIP_SIZE
		current_pip.z_index = 10
		active_shadow.position = layers[current_layer].position \
			+ active_position + ACTIVE_SHADOW_OFFSET
		active_shadow.size = ACTIVE_PIP_SIZE
		active_shadow.z_index = 9
		active_shadow.visible = true
		guard_value.text = str(value)
		guard_value.position = layers[current_layer].position + active_position
		guard_value.size = ACTIVE_PIP_SIZE
		guard_value.z_index = 11
	var required_height: float = %Layer1.size.y + LAYER_STEP * float(layer_count - 1)
	var visual_rect := get_visual_rect()
	if visual_rect.has_area():
		required_height = maxf(required_height, ceilf(visual_rect.end.y))
	if guard_value.visible:
		required_height = maxf(required_height, ceilf(_get_label_ink_rect(guard_value).end.y))
	if status_label.visible:
		required_height = maxf(required_height, ceilf(_get_label_ink_rect(status_label).end.y))
	custom_minimum_size.y = required_height


func get_visual_layer_count() -> int:
	return clampi(ceili(float(maxi(_guard, 1)) / PIPS_PER_LAYER), 1, 3)


func _layer_color(layer_index: int, layer_count: int) -> Color:
	if layer_index == layer_count - 1:
		return WHITE
	if layer_count == 3 and layer_index == 0:
		return DARK_GRAY
	return MEDIUM_GRAY


func _reset_pip_geometry() -> void:
	for layer_index: int in layers.size():
		for pip_index: int in PIPS_PER_LAYER:
			var pip := layers[layer_index].get_child(pip_index) as TextureRect
			pip.position = Vector2(PIP_STEP * pip_index, 0.0)
			pip.size = PIP_SIZE
			pip.z_index = 0


func get_visual_rect() -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	for layer: Control in layers:
		for child: Node in layer.get_children():
			var pip := child as TextureRect
			if pip == null or not pip.visible:
				continue
			var pip_rect := Rect2(layer.position + pip.position, pip.size)
			bounds = bounds.merge(pip_rect) if has_bounds else pip_rect
			has_bounds = true
	if active_shadow.visible:
		var shadow_rect := Rect2(active_shadow.position, active_shadow.size)
		bounds = bounds.merge(shadow_rect) if has_bounds else shadow_rect
		has_bounds = true
	if guard_value.visible:
		var value_rect := Rect2(guard_value.position, guard_value.size)
		bounds = bounds.merge(value_rect) if has_bounds else value_rect
		has_bounds = true
	if status_label.visible:
		var status_rect := Rect2(status_label.position, status_label.size)
		bounds = bounds.merge(status_rect) if has_bounds else status_rect
		has_bounds = true
	return bounds


func _get_label_ink_rect(label: Label) -> Rect2:
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var text_size := Vector2(
		font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
		font.get_height(font_size),
	)
	var ink_position := label.position
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			ink_position.x += (label.size.x - text_size.x) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			ink_position.x += label.size.x - text_size.x
	match label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			ink_position.y += (label.size.y - text_size.y) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			ink_position.y += label.size.y - text_size.y
	return Rect2(ink_position, text_size).grow(
		float(label.get_theme_constant(&"outline_size")),
	)
