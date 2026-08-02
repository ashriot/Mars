class_name DamageContext
extends RefCounted

var _attacker: CombatantSnapshot
var _target: CombatantSnapshot
var _other_living_allies: int
var _other_living_enemies: int
var _source_action: Action
var _source_effect: ActionEffect
var _trigger_context: Dictionary

var attacker: CombatantSnapshot:
	get: return _attacker
var target: CombatantSnapshot:
	get: return _target
var other_living_allies: int:
	get: return _other_living_allies
var other_living_enemies: int:
	get: return _other_living_enemies
var source_action: Action:
	get: return _source_action
var source_effect: ActionEffect:
	get: return _source_effect
var trigger_context: Dictionary:
	get: return _trigger_context.duplicate(true)


func _init(
	context_attacker: CombatantSnapshot,
	context_target: CombatantSnapshot,
	context_other_living_allies: int,
	context_other_living_enemies: int,
	context_source_action: Action,
	context_source_effect: ActionEffect,
	context_trigger_context: Dictionary = {},
) -> void:
	_attacker = context_attacker
	_target = context_target
	_other_living_allies = context_other_living_allies
	_other_living_enemies = context_other_living_enemies
	_source_action = context_source_action
	_source_effect = context_source_effect
	_trigger_context = context_trigger_context.duplicate(true)


static func capture(
	attacker_node: Node,
	target_node: Node,
	battle_manager: BattleManager = null,
	source_action: Action = null,
	source_effect: ActionEffect = null,
	trigger_context: Dictionary = {},
) -> DamageContext:
	var attacker := BattleCombatant.resolve_model(attacker_node)
	var target := BattleCombatant.resolve_model(target_node) \
		if is_instance_valid(target_node) else null
	var other_living_allies := 0
	var other_living_enemies := 0
	if battle_manager != null:
		for value: Node in battle_manager.actor_list:
			if not is_instance_valid(value):
				continue
			var combatant := BattleCombatant.resolve_model(value)
			if combatant.is_defeated:
				continue
			if combatant.faction == attacker.faction:
				if combatant != attacker:
					other_living_allies += 1
			elif combatant != target:
				other_living_enemies += 1
	return DamageContext.new(
		CombatantSnapshot.capture(attacker),
		CombatantSnapshot.capture(target) if target != null else null,
		other_living_allies,
		other_living_enemies,
		source_action,
		source_effect,
		trigger_context,
	)
