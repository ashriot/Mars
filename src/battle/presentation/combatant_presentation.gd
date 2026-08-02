extends Node
class_name CombatantPresentation

enum TargetState { NORMAL, AVAILABLE, SELECTED }

signal target_hovered(combatant: BattleCombatant)
signal target_unhovered(combatant: BattleCombatant)
signal target_pressed(combatant: BattleCombatant)

var combatant: BattleCombatant


func bind(value: BattleCombatant) -> void:
	combatant = value


func get_target_screen_position() -> Vector2:
	return Vector2.ZERO


func is_target_visible() -> bool:
	return false


func set_target_presentation(_state: TargetState) -> void:
	pass


func set_acting(_active: bool) -> void:
	pass


func show_action(_action_name: String) -> void:
	pass


func hide_action() -> void:
	pass


func sync_visual_health() -> Tween:
	return null
