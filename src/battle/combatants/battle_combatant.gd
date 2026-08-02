extends Node
class_name BattleCombatant

enum Faction { HERO, ENEMY }

signal hp_changed(combatant: BattleCombatant, current_hp: int, max_hp: int)
signal guard_changed(combatant: BattleCombatant, current_guard: int)
signal conditions_changed(combatant: BattleCombatant)
signal breached(combatant: BattleCombatant)
signal defeated(combatant: BattleCombatant)
signal revived(combatant: BattleCombatant)
signal danger_changed(combatant: BattleCombatant, is_in_danger: bool)
signal presentation_event(
	combatant: BattleCombatant,
	event: StringName,
	payload: Dictionary,
)

const MAX_GUARD := 10

var battle_manager: BattleManager
var faction := Faction.HERO
var actor_name := ""
var current_stats: ActorStats
var current_hp := 0
var current_guard := 0
var current_ct := 0
var ct_speed_scale := 1.0
var battle_priority := 0
var is_valid_target := false
var is_breached := false
var is_in_danger := false
var is_defeated := false
var active_conditions: Array[Condition] = []
var active_traits: Array[Trait] = []


func setup_base(
	stats: ActorStats,
	combatant_faction: Faction,
	manager: BattleManager = null,
) -> void:
	assert(stats != null, "BattleCombatant requires ActorStats.")
	current_stats = stats
	faction = combatant_faction
	battle_manager = manager
	actor_name = stats.actor_name
	current_hp = stats.max_hp
	current_guard = stats.starting_guard
	current_ct = 0
	is_breached = false
	is_in_danger = false
	is_defeated = false


func is_hero() -> bool:
	return faction == Faction.HERO


func is_enemy() -> bool:
	return faction == Faction.ENEMY


func get_attack() -> int:
	return current_stats.attack


func get_psyche() -> int:
	return current_stats.psyche


func get_speed() -> int:
	var scalar: float = 1.0
	for condition in active_conditions:
		scalar += condition.speed_scalar
	return int(current_stats.speed * scalar)


func get_ct_speed() -> int:
	return CTBSpeed.normalize(get_speed(), ct_speed_scale)


func get_action_ct_percent(action: Action) -> int:
	if action == null:
		return 100
	var result := float(action.ct_cost_percent)
	for condition: Condition in active_conditions:
		result *= condition.action_ct_multiplier
	for active_trait: Trait in active_traits:
		result *= active_trait.get_action_ct_multiplier(action)
	return clampi(roundi(result), 10, 200)


func get_aim() -> int:
	var mod: int = 0
	for condition in active_conditions:
		mod += condition.aim_mod
	return current_stats.aim + mod


func get_incoming_aim_mods() -> int:
	var mod: int = 0
	for condition in active_conditions:
		mod += condition.incoming_aim_mod
	return mod


func get_crit_damage_bonus() -> int:
	return current_stats.precision
