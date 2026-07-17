class_name DamageResult
extends RefCounted

var _request: DamageRequest
var _effective_power: float
var _clamped_defense: int
var _defense_multiplier: float
var _outgoing_multiplier: float
var _incoming_multiplier: float
var _raw_damage: float
var _final_damage: int
var _is_critical: bool
var _was_breached: bool
var _source_effect: ActionEffect
var _source_action: Action

var request: DamageRequest:
	get: return _request
var effective_power: float:
	get: return _effective_power
var clamped_defense: int:
	get: return _clamped_defense
var defense_multiplier: float:
	get: return _defense_multiplier
var outgoing_multiplier: float:
	get: return _outgoing_multiplier
var incoming_multiplier: float:
	get: return _incoming_multiplier
var raw_damage: float:
	get: return _raw_damage
var final_damage: int:
	get: return _final_damage
var is_critical: bool:
	get: return _is_critical
var was_breached: bool:
	get: return _was_breached
var source_effect: ActionEffect:
	get: return _source_effect
var source_action: Action:
	get: return _source_action


func _init(
	result_request: DamageRequest,
	result_effective_power: float,
	result_clamped_defense: int,
	result_defense_multiplier: float,
	result_outgoing_multiplier: float,
	result_incoming_multiplier: float,
	result_raw_damage: float,
	result_final_damage: int,
	result_is_critical: bool = false,
	result_was_breached: bool = false,
	result_source_effect: ActionEffect = null,
	result_source_action: Action = null,
) -> void:
	_request = result_request
	_effective_power = result_effective_power
	_clamped_defense = result_clamped_defense
	_defense_multiplier = result_defense_multiplier
	_outgoing_multiplier = result_outgoing_multiplier
	_incoming_multiplier = result_incoming_multiplier
	_raw_damage = result_raw_damage
	_final_damage = result_final_damage
	_is_critical = result_is_critical
	_was_breached = result_was_breached
	_source_effect = result_source_effect
	_source_action = result_source_action


static func with_hit_facts(
	calculated: DamageResult,
	result_is_critical: bool,
	result_was_breached: bool,
	result_source_effect: ActionEffect,
	result_source_action: Action,
) -> DamageResult:
	return DamageResult.new(
		calculated.request,
		calculated.effective_power,
		calculated.clamped_defense,
		calculated.defense_multiplier,
		calculated.outgoing_multiplier,
		calculated.incoming_multiplier,
		calculated.raw_damage,
		calculated.final_damage,
		result_is_critical,
		result_was_breached,
		result_source_effect,
		result_source_action,
	)
