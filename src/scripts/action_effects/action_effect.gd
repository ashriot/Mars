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
	var _attacker := BattleCombatant.resolve_model(attacker_node)
	var _targets := BattleCombatant.resolve_models(parent_targets)
	await battle_manager.wait()


func get_presentation(_context: EffectPresentationContext) -> EffectPresentation:
	return null
