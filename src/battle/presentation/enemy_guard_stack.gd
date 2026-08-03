extends Control
class_name EnemyGuardStack


const MAX_GUARD := 30
const PIPS_PER_LAYER := 10
const LAYER_STEP := 5.0
const WHITE := Color.WHITE
const MEDIUM_GRAY := Color(0.62, 0.65, 0.7, 1.0)
const DARK_GRAY := Color(0.34, 0.37, 0.42, 1.0)

@onready var layers: Array[Control] = [%Layer1, %Layer2, %Layer3]
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
		guard_value.text = str(value)
		guard_value.position = layers[current_layer].position + current_pip.position
	custom_minimum_size.y = %Layer1.size.y + LAYER_STEP * float(layer_count - 1)


func get_visual_layer_count() -> int:
	return clampi(ceili(float(maxi(_guard, 1)) / PIPS_PER_LAYER), 1, 3)


func _layer_color(layer_index: int, layer_count: int) -> Color:
	if layer_index == layer_count - 1:
		return WHITE
	if layer_count == 3 and layer_index == 0:
		return DARK_GRAY
	return MEDIUM_GRAY
