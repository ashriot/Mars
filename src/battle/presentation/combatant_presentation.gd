extends Node
class_name CombatantPresentation

enum TargetState { NORMAL, AVAILABLE, SELECTED }

signal target_hovered(combatant: BattleCombatant)
signal target_unhovered(combatant: BattleCombatant)
signal target_pressed(combatant: BattleCombatant)
signal particles_requested(position: Vector2, type: String)

var combatant: BattleCombatant
var target_state := TargetState.NORMAL
var acting := false
var _pending_operations: Array[PresentationOperation] = []


func _exit_tree() -> void:
	cancel_pending_operations()


func setup_view(value: BattleCombatant) -> bool:
	if not is_instance_valid(value):
		push_error("CombatantPresentation requires a valid BattleCombatant.")
		return false
	if combatant != null:
		push_error("CombatantPresentation cannot be rebound to another combatant.")
		return false
	bind(value)
	return combatant == value


func bind(value: BattleCombatant) -> void:
	combatant = value


func get_target_screen_position() -> Vector2:
	return Vector2.ZERO


func is_target_visible() -> bool:
	return false


func set_target_presentation(state: TargetState) -> void:
	target_state = state


func set_acting(active: bool):
	acting = active
	return PresentationOperation.already_completed()


func show_action(_action_name: String) -> void:
	pass


func hide_action():
	return PresentationOperation.already_completed()


func sync_visual_health():
	return PresentationOperation.already_completed()


func refresh_intent() -> void:
	pass


func _begin_operation() -> PresentationOperation:
	var operation := PresentationOperation.new()
	_pending_operations.append(operation)
	operation.completed.connect(
		_on_operation_completed.bind(operation), CONNECT_ONE_SHOT,
	)
	return operation


func _operation_for_tween(tween: Tween) -> PresentationOperation:
	if tween == null:
		return PresentationOperation.already_completed()
	var operation := _begin_operation()
	tween.finished.connect(operation.complete, CONNECT_ONE_SHOT)
	return operation


func cancel_pending_operations() -> void:
	for operation: PresentationOperation in _pending_operations.duplicate():
		operation.complete()


func _on_operation_completed(operation: PresentationOperation) -> void:
	_pending_operations.erase(operation)
