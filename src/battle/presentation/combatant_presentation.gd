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


func set_acting(active: bool) -> void:
	acting = active


func show_action(_action_name: String) -> void:
	pass


func hide_action() -> void:
	pass


func sync_visual_health() -> Tween:
	return null


func refresh_intent() -> void:
	pass
