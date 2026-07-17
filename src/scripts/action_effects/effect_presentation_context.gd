class_name EffectPresentationContext
extends RefCounted

var _actor: ActorCard
var _target: ActorCard
var _action: Action
var _effect_index: int
var _distribution_count: int
var _critical: bool
var _damage_context: DamageContext

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


func _init(
	presentation_actor: ActorCard,
	presentation_target: ActorCard = null,
	presentation_action: Action = null,
	presentation_effect_index: int = -1,
	presentation_distribution_count: int = 1,
	presentation_critical: bool = false,
	presentation_damage_context: DamageContext = null,
) -> void:
	_actor = presentation_actor
	_target = presentation_target
	_action = presentation_action
	_effect_index = presentation_effect_index
	_distribution_count = maxi(1, presentation_distribution_count)
	_critical = presentation_critical
	_damage_context = presentation_damage_context
