class_name DamageResult
extends RefCounted

var _request: DamageRequest
var _effective_power: int
var _clamped_defense: int
var _defense_multiplier: float
var _outgoing_multiplier: float
var _incoming_multiplier: float
var _raw_damage: float
var _final_damage: int

var request: DamageRequest:
	get: return _request
var effective_power: int:
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


func _init(
	result_request: DamageRequest,
	result_effective_power: int,
	result_clamped_defense: int,
	result_defense_multiplier: float,
	result_outgoing_multiplier: float,
	result_incoming_multiplier: float,
	result_raw_damage: float,
	result_final_damage: int,
) -> void:
	_request = result_request
	_effective_power = result_effective_power
	_clamped_defense = result_clamped_defense
	_defense_multiplier = result_defense_multiplier
	_outgoing_multiplier = result_outgoing_multiplier
	_incoming_multiplier = result_incoming_multiplier
	_raw_damage = result_raw_damage
	_final_damage = result_final_damage
