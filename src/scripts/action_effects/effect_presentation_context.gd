class_name EffectPresentationContext
extends RefCounted

var _actor: ActorCard
var _target: ActorCard
var _action: Action
var _effect_index: int
var _distribution_count: int
var _critical: bool
var _damage_context: DamageContext
var _targets: Array[ActorCard]
var _battle_manager: BattleManager
var _is_complete: bool

var actor: ActorCard:
	get: return _actor
var target: ActorCard:
	get: return _target
var action: Action:
	get: return _action
var effect_index: int:
	get: return _effect_index
var distribution_count: int:
	get: return _distribution_count
var critical: bool:
	get: return _critical
var damage_context: DamageContext:
	get: return _damage_context
var targets: Array[ActorCard]:
	get:
		var copy: Array[ActorCard] = []
		copy.assign(_targets)
		return copy
var battle_manager: BattleManager:
	get: return _battle_manager
var is_complete: bool:
	get: return _is_complete


func _init(
	presentation_actor: ActorCard,
	presentation_target: ActorCard = null,
	presentation_action: Action = null,
	presentation_effect_index: int = -1,
	presentation_distribution_count: int = 1,
	presentation_critical: bool = false,
	presentation_damage_context: DamageContext = null,
	presentation_targets: Array[ActorCard] = [],
	presentation_battle_manager: BattleManager = null,
	presentation_is_complete: bool = false,
) -> void:
	_actor = presentation_actor
	_target = presentation_target
	_action = presentation_action
	_effect_index = presentation_effect_index
	_distribution_count = maxi(1, presentation_distribution_count)
	_critical = presentation_critical
	_damage_context = presentation_damage_context
	_targets.assign(presentation_targets)
	if presentation_target != null and _targets.is_empty():
		_targets.append(presentation_target)
	_battle_manager = presentation_battle_manager
	_is_complete = presentation_is_complete
