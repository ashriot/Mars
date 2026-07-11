extends HBoxContainer
class_name ActionHintBar

const HINT_SCENE := preload("res://src/ui/navigation/action_hint.tscn")
var _hints: Array[ActionHint] = []


func _ready() -> void:
	InputManager.input_mode_changed.connect(_on_input_changed)
	InputManager.controller_type_changed.connect(_on_input_changed)


func set_hints(hints: Array[Dictionary]) -> void:
	for hint in _hints:
		hint.queue_free()
	_hints.clear()
	for data in hints:
		var hint := HINT_SCENE.instantiate() as ActionHint
		add_child(hint)
		hint.configure(data)
		_hints.append(hint)
	refresh(InputManager.get_active_mode(), InputManager.get_active_controller_type())


func refresh(mode: InputManager.InputMode, controller_type: InputIconMap.ControllerType) -> void:
	for hint in _hints:
		hint.refresh(mode, controller_type)


func get_hint_count() -> int:
	return _hints.size()


func get_hint(index: int) -> ActionHint:
	return _hints[index]


func _on_input_changed(_value: Variant) -> void:
	refresh(InputManager.get_active_mode(), InputManager.get_active_controller_type())
