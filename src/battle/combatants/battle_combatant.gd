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
var _lethal_hit_reaction_depth := 0
var _condition_removal_batch_depth := 0
var _condition_removal_batch_dirty := false


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


func get_power(power_type: Action.PowerType) -> int:
	if power_type == Action.PowerType.ATTACK:
		return current_stats.attack
	elif power_type == Action.PowerType.PSYCHE:
		return current_stats.psyche
	return 0


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


func take_one_hit(
	result: DamageResult,
	damage_effect: Effect_Damage,
	attacker: Node,
	resolved_damage_type: Action.DamageType,
) -> int:
	if is_defeated:
		return 0

	var actual_damage := mini(result.final_damage, current_hp)
	current_hp -= actual_damage
	hp_changed.emit(self, current_hp, current_stats.max_hp)
	presentation_event.emit(self, &"damage_received", {
		"result": result,
		"damage_type": resolved_damage_type,
		"actual_damage": actual_damage,
	})
	print("Hit for ", result.final_damage, " damage!")

	var hit_was_lethal := current_hp == 0
	if hit_was_lethal:
		_lethal_hit_reaction_depth += 1
	var event_context := {
		"attacker": attacker,
		"target": self,
		"targets": [self],
		"damage_result": result,
		"attempted_damage": result.final_damage,
		"actual_damage": actual_damage,
		"resolved_damage_type": resolved_damage_type,
		"is_critical": result.is_critical,
		"was_breached": result.was_breached,
		"source_effect": result.source_effect,
		"source_action": result.source_action,
	}
	if resolved_damage_type == Action.DamageType.KINETIC:
		await _fire_condition_event(
			Trigger.TriggerType.ON_TAKING_KINETIC_DAMAGE, event_context,
		)
	elif resolved_damage_type == Action.DamageType.ENERGY:
		await _fire_condition_event(
			Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE, event_context,
		)
	if not damage_effect.is_indirect:
		await _fire_condition_event(Trigger.TriggerType.ON_BEING_HIT, event_context)

	if hit_was_lethal:
		_lethal_hit_reaction_depth -= 1
	if current_hp == 0 and not is_defeated:
		defeat()
	return actual_damage


func take_healing(heal_amount: int, is_revive: bool = false) -> void:
	if _lethal_hit_reaction_depth > 0 \
		or (is_defeated and not is_revive) \
		or heal_amount <= 0:
		return

	current_hp = mini(current_stats.max_hp, current_hp + heal_amount)
	hp_changed.emit(self, current_hp, current_stats.max_hp)
	presentation_event.emit(self, &"healing_received", {
		"amount": heal_amount,
		"is_revive": is_revive,
	})
	print(actor_name, " healed for ", heal_amount, ". HP is now: ", current_hp)


func modify_guard(amount: int, is_recovering: bool = false) -> void:
	current_guard = clampi(current_guard + amount, 0, MAX_GUARD)
	guard_changed.emit(self, current_guard)
	presentation_event.emit(self, &"guard_changed", {
		"amount": amount,
		"is_recovering": is_recovering,
	})
	print(actor_name, " gained ", amount, " guard. Total: ", current_guard)
	var context := {"targets": [self], "guard_gained": amount}
	if amount > 0 and not is_recovering:
		await _fire_condition_event(Trigger.TriggerType.ON_GAINING_GUARD, context)
	if current_guard == 0 and not is_breached:
		in_danger(true)
	elif is_in_danger:
		in_danger(false)


func in_danger(value: bool) -> void:
	if is_in_danger == value:
		return
	is_in_danger = value
	danger_changed.emit(self, is_in_danger)
	presentation_event.emit(
		self,
		&"danger_started" if is_in_danger else &"danger_ended",
		{},
	)


func breach() -> void:
	is_breached = true
	in_danger(false)
	current_ct = 0
	breached.emit(self)
	presentation_event.emit(self, &"breach_started", {})
	print("Breached: ", actor_name, " -> CT: ", current_ct)
	await _fire_condition_event(Trigger.TriggerType.ON_BREACHED)


func recover_breach() -> void:
	is_breached = false
	var guard_recovery: int = current_stats.starting_guard
	if is_hero():
		guard_recovery /= 2
	await modify_guard(guard_recovery, true)


func defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	current_ct = 0
	defeated.emit(self)
	presentation_event.emit(self, &"defeat_started", {})
	print(actor_name, " is defeated!")


func revive() -> void:
	if not is_defeated:
		return
	is_defeated = false
	revived.emit(self)


func add_condition(condition_resource: Condition) -> void:
	if not condition_resource:
		push_error("add_condition was called with a null resource!")
		return

	var is_debuff := condition_resource.condition_type == Condition.ConditionType.DEBUFF
	for active_cond: Condition in active_conditions:
		for trigger: Trigger in active_cond.triggers:
			if trigger.trigger_type == Trigger.TriggerType.BEFORE_DEBUFF_RECEIVED and is_debuff:
				print(
					"Condition '", active_cond.condition_name,
					"' is blocking the new condition: ", condition_resource.condition_name,
				)
				for effect: ActionEffect in trigger.effects_to_run:
					await battle_manager.execute_triggered_effect(
						self, effect, [self], null, {},
					)
				return

	if has_condition(condition_resource.condition_name):
		return
	var new_condition := condition_resource.duplicate(true) as Condition
	new_condition.attacker = condition_resource.attacker
	active_conditions.append(new_condition)
	print(actor_name, " gained condition: ", new_condition.condition_name)

	await _fire_condition_event(Trigger.TriggerType.ON_APPLIED)
	conditions_changed.emit(self)


func has_condition(condition_name: String) -> bool:
	for condition: Condition in active_conditions:
		if condition.condition_name == condition_name:
			return true
	return false


func remove_condition(condition_name: String, report_missing: bool = true) -> bool:
	for condition: Condition in active_conditions.duplicate():
		if condition.condition_name == condition_name:
			return await _remove_condition_instance(condition)
	if report_missing:
		push_error(
			"[ERROR] Trying to remove an invalid condition: %s -> %s" % [
				actor_name, condition_name,
			],
		)
	return false


func remove_debuffs(quantity: int) -> int:
	if quantity <= 0:
		return 0
	var removed_count := 0
	var snapshot := active_conditions.duplicate()
	snapshot.reverse()
	_condition_removal_batch_depth += 1
	for condition: Condition in snapshot:
		if condition == null \
			or condition.condition_type != Condition.ConditionType.DEBUFF:
			continue
		if await _remove_condition_instance(condition):
			removed_count += 1
		if removed_count >= quantity:
			break
	_condition_removal_batch_depth -= 1
	_flush_condition_removal_notification()
	return removed_count


func count_debuffs() -> int:
	var count := 0
	for condition: Condition in active_conditions:
		if condition.condition_type == Condition.ConditionType.DEBUFF and not condition.is_passive:
			count += 1
	return count


func _fire_condition_event(
	event_type: Trigger.TriggerType,
	context: Dictionary = {},
) -> void:
	var snapshot := active_conditions.duplicate()
	for condition: Condition in snapshot:
		if condition == null or not active_conditions.has(condition):
			continue
		await _execute_condition_triggers(condition, event_type, context)
		if condition.remove_on_triggers.has(event_type) \
			and active_conditions.has(condition):
			print(actor_name, "'s ", condition.condition_name, " needs to be removed.")
			await _remove_condition_instance(condition)


func _execute_condition_triggers(
	condition: Condition,
	event_type: Trigger.TriggerType,
	context: Dictionary,
) -> void:
	for trigger: Trigger in condition.triggers:
		if trigger == null or trigger.trigger_type != event_type:
			continue
		if trigger.is_attack:
			await battle_manager.wait(0.25)
		print(
			"Condition '", condition.condition_name,
			"' is firing effects for '", event_type, "'",
		)
		var targets: Array = []
		if context.has("targets"):
			targets.assign(context.targets)
		var contextual_attacker := context.get("attacker") as Node
		var action := context.get("action") as Action
		for effect: ActionEffect in trigger.effects_to_run:
			if effect == null:
				continue
			if effect.target_type == Action.TargetType.SELF:
				targets = [self]
			else:
				var effect_source := condition.attacker \
					if is_instance_valid(condition.attacker) else self
				var source_is_hero: bool = effect_source.is_hero() \
					if effect_source is BattleCombatant else effect_source is HeroCard
				targets = battle_manager.get_targets(
					effect.target_type,
					source_is_hero,
					targets,
					contextual_attacker,
				)
			if battle_manager.current_actor is BattleCombatant \
				and condition.is_passive \
				and event_type == Trigger.TriggerType.ON_TURN_START:
				presentation_event.emit(self, &"passive_fired", {})
			await battle_manager.execute_triggered_effect(
				condition.attacker, effect, targets, action, context,
			)
			if condition.update_turn_order:
				battle_manager.update_turn_order()


func _remove_condition_instance(condition: Condition) -> bool:
	if condition == null or not active_conditions.has(condition):
		return false
	active_conditions.erase(condition)
	print(actor_name, " is removing condition: ", condition.condition_name)
	await _execute_condition_triggers(condition, Trigger.TriggerType.ON_REMOVED, {})
	_condition_removal_batch_dirty = true
	_flush_condition_removal_notification()
	return true


func _flush_condition_removal_notification() -> void:
	if _condition_removal_batch_depth > 0 or not _condition_removal_batch_dirty:
		return
	_condition_removal_batch_dirty = false
	conditions_changed.emit(self)


func is_taunting() -> bool:
	for condition: Condition in active_conditions:
		if condition.is_taunting:
			return true
	return false


func is_untargetable() -> bool:
	for condition: Condition in active_conditions:
		if condition.is_untargetable:
			return true
	return false


func get_damage_dealt_modifier(target: Node) -> float:
	return _damage_contribution_total(
		get_damage_dealt_contributions(target), DamageContribution.Stage.OUTGOING,
	)


func get_damage_dealt_contributions(target: Node) -> Array[DamageContribution]:
	var contributions: Array[DamageContribution] = []
	for condition: Condition in active_conditions:
		var power_bonus := condition.get_damage_dealt_power_bonus(self, target)
		if not is_zero_approx(power_bonus):
			contributions.append(DamageContribution.new(
				_damage_modifier_source(
					"condition", condition.condition_name, condition.resource_path,
				),
				DamageContribution.Stage.POWER,
				power_bonus,
			))
		var amount := condition.get_damage_dealt_modifier(self, target)
		if not is_zero_approx(amount):
			contributions.append(DamageContribution.new(
				_damage_modifier_source(
					"condition", condition.condition_name, condition.resource_path,
				),
				DamageContribution.Stage.OUTGOING,
				amount,
			))
	for trait_item: Trait in active_traits:
		var amount := trait_item.get_damage_dealt_modifier(target)
		if is_zero_approx(amount):
			continue
		contributions.append(DamageContribution.new(
			_damage_modifier_source(
				"trait", trait_item.trait_name, trait_item.resource_path,
			),
			DamageContribution.Stage.OUTGOING,
			amount,
		))
	return contributions


func get_damage_taken_modifier(attacker: Node) -> float:
	return _damage_contribution_total(
		get_damage_taken_contributions(attacker), DamageContribution.Stage.INCOMING,
	)


func get_damage_taken_contributions(attacker: Node) -> Array[DamageContribution]:
	var contributions: Array[DamageContribution] = []
	for condition: Condition in active_conditions:
		var amount := condition.get_damage_taken_modifier(attacker, self)
		if is_zero_approx(amount):
			continue
		contributions.append(DamageContribution.new(
			_damage_modifier_source(
				"condition", condition.condition_name, condition.resource_path,
			),
			DamageContribution.Stage.INCOMING,
			amount,
		))
	for trait_item: Trait in active_traits:
		var amount := trait_item.get_damage_taken_modifier(attacker)
		if is_zero_approx(amount):
			continue
		contributions.append(DamageContribution.new(
			_damage_modifier_source(
				"trait", trait_item.trait_name, trait_item.resource_path,
			),
			DamageContribution.Stage.INCOMING,
			amount,
		))
	return contributions


func _add_trait(trait_resource: Trait, tier: int) -> void:
	var trait_copy := trait_resource.duplicate() as Trait
	trait_copy.current_tier = tier
	active_traits.append(trait_copy)


func _damage_contribution_total(
	contributions: Array[DamageContribution],
	stage: DamageContribution.Stage,
) -> float:
	var total := 0.0
	for contribution: DamageContribution in contributions:
		if contribution.stage == stage:
			total += contribution.amount
	return total


func _damage_modifier_source(
	prefix: String,
	display_name: String,
	modifier_resource_path: String,
) -> StringName:
	var identity := display_name.strip_edges()
	if identity.is_empty() and not modifier_resource_path.is_empty():
		identity = modifier_resource_path.get_file().get_basename()
	if identity.is_empty():
		identity = "unnamed"
	return StringName("%s_%s" % [prefix, identity.to_snake_case()])
