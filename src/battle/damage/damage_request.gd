class_name DamageRequest
extends RefCounted

var _base_power: int
var _overload_power: int
var _precision_power: int
var _potency: float
var _distribution_count: int
var _damage_type: Action.DamageType
var _defense: int
var _outgoing_modifier: float
var _incoming_modifier: float
var _contributions: Array[DamageContribution]
var _power_bonus: float

var base_power: int:
	get: return _base_power
var overload_power: int:
	get: return _overload_power
var precision_power: int:
	get: return _precision_power
var potency: float:
	get: return _potency
var distribution_count: int:
	get: return _distribution_count
var damage_type: Action.DamageType:
	get: return _damage_type
var defense: int:
	get: return _defense
var outgoing_modifier: float:
	get: return _outgoing_modifier
var incoming_modifier: float:
	get: return _incoming_modifier
var contributions: Array[DamageContribution]:
	get: return _contributions.duplicate()
var power_bonus: float:
	get: return _power_bonus


func _init(
	request_base_power: int,
	request_overload_power: int,
	request_precision_power: int,
	request_potency: float,
	request_distribution_count: int,
	request_damage_type: Action.DamageType,
	request_defense: int,
	request_outgoing_modifier: float = 0.0,
	request_incoming_modifier: float = 0.0,
	request_contributions: Array[DamageContribution] = [],
	request_power_bonus: float = 0.0,
) -> void:
	_base_power = request_base_power
	_overload_power = request_overload_power
	_precision_power = request_precision_power
	_potency = request_potency
	_distribution_count = request_distribution_count
	_damage_type = request_damage_type
	_defense = request_defense
	_outgoing_modifier = request_outgoing_modifier
	_incoming_modifier = request_incoming_modifier
	_contributions = request_contributions.duplicate()
	_power_bonus = request_power_bonus
