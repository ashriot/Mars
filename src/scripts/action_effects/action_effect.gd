extends Resource
class_name ActionEffect

@export var target_type: Action.TargetType = Action.TargetType.PARENT

func execute(
	attacker_node: Node,
	parent_targets: Array,
	battle_manager: BattleManager,
	_action: Action = null,
	_context: Dictionary = {}
) -> void:
	BattleCombatant.resolve_model(attacker_node)
	for target_node: Node in parent_targets:
		BattleCombatant.resolve_model(target_node)
	await battle_manager.wait()


func get_presentation(_context: EffectPresentationContext) -> EffectPresentation:
	return null
