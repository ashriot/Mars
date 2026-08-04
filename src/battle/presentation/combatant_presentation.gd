extends Node
class_name CombatantPresentation

enum TargetState { NORMAL, AVAILABLE, SELECTED }

signal target_hovered(combatant: BattleCombatant)
signal target_unhovered(combatant: BattleCombatant)
signal target_pressed(combatant: BattleCombatant)
signal particles_requested(position: Vector2, type: String)
signal projectile_requested(
	from_screen: Vector2,
	to_screen: Vector2,
	effect_type: StringName,
)

var combatant: BattleCombatant
var target_state := TargetState.NORMAL
var acting := false
var inspection_focused := false
var _pending_operations: Array[PresentationOperation] = []


func _exit_tree() -> void:
	for operation: PresentationOperation in _pending_operations.duplicate():
		operation.call_deferred(&"complete")


func setup_view(value: BattleCombatant) -> bool:
	return bind(value)


func bind(value: BattleCombatant) -> bool:
	if not is_instance_valid(value):
		push_error("CombatantPresentation requires a valid BattleCombatant.")
		return false
	if combatant != null:
		push_error("CombatantPresentation cannot be rebound to another combatant.")
		return false
	combatant = value
	return true


func get_target_screen_position() -> Vector2:
	return Vector2.ZERO


func is_target_visible() -> bool:
	return false


func set_target_presentation(state: TargetState) -> void:
	target_state = state


func set_inspection_focused(focused: bool) -> void:
	inspection_focused = focused


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


func _operation_when_all(
	operations: Array[PresentationOperation],
) -> PresentationOperation:
	var pending: Array[PresentationOperation] = []
	for operation: PresentationOperation in operations:
		if operation != null and not operation.is_completed:
			pending.append(operation)
	if pending.is_empty():
		return PresentationOperation.already_completed()
	var joined := _begin_operation()
	var remaining := {
		&"count": pending.size(),
		&"observers": [] as Array[PresentationOperation],
	}
	for child: PresentationOperation in pending:
		var observer := PresentationOperation.new()
		(remaining[&"observers"] as Array[PresentationOperation]).append(observer)
		observer.completed.connect(
			_on_joined_child_completed.bind(joined, remaining),
			CONNECT_ONE_SHOT,
		)
		child.completed.connect(observer.complete, CONNECT_ONE_SHOT)
	return joined


func _on_joined_child_completed(
	joined: PresentationOperation,
	remaining: Dictionary,
) -> void:
	if joined.is_completed:
		(remaining[&"observers"] as Array[PresentationOperation]).clear()
		return
	remaining[&"count"] = int(remaining[&"count"]) - 1
	if int(remaining[&"count"]) == 0:
		(remaining[&"observers"] as Array[PresentationOperation]).clear()
		joined.complete()


func cancel_pending_operations() -> void:
	for operation: PresentationOperation in _pending_operations.duplicate():
		operation.complete()


func _on_operation_completed(operation: PresentationOperation) -> void:
	_pending_operations.erase(operation)
