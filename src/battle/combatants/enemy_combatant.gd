extends BattleCombatant
class_name EnemyCombatant

var enemy_data: EnemyData
var ai_state := EnemyAIRuntimeState.new()
var intended_decision := EnemyDecision.new()
var encounter_seed := 0
var intended_action: Action
var intended_targets: Array[BattleCombatant] = []
var recover_action: Action
var is_elite := false
var is_boss := false


func setup(
	data: EnemyData,
	fight_level: int,
	elite: bool,
	boss: bool,
	hp_multiplier: float,
	manager: BattleManager = null,
) -> void:
	assert(data != null, "EnemyCombatant requires EnemyData.")
	enemy_data = data.duplicate(true) as EnemyData
	enemy_data.level = fight_level
	enemy_data.calculate_stats()
	is_elite = elite
	is_boss = boss
	if is_elite:
		_apply_elite_scaling(enemy_data.stats)
	elif is_boss:
		pass
	enemy_data.stats.max_hp = maxi(
		1,
		roundi(enemy_data.stats.max_hp * maxf(hp_multiplier, 1.0)),
	)
	recover_action = enemy_data.recover_action
	setup_base(enemy_data.stats, Faction.ENEMY, manager)


func _apply_elite_scaling(stats: ActorStats) -> void:
	stats.max_hp = int(stats.max_hp * 5.0)
	stats.attack = int(stats.attack * 1.15)
	stats.psyche = int(stats.psyche * 1.15)
	stats.speed = int(stats.speed * 1.15)


func initialize_ai(seed_value: int) -> void:
	encounter_seed = seed_value
	ai_state.initialize(enemy_data.abilities)


func decide_intent(context: EnemyAIContext) -> void:
	var next := EnemyDecision.new()
	if is_breached and recover_action != null:
		next.action = recover_action
		next.targets = [self]
		next.reason = "recover_breach"
		next.is_recovery = true
	else:
		next = EnemyDecisionEngine.choose(
			self, enemy_data.abilities, ai_state, context,
		)
	if not next.is_valid():
		push_error("Enemy '%s' could not produce a valid intent on AI turn %d." % [
			actor_name, ai_state.completed_turns,
		])
		clear_intent()
		return
	var intent_changed := intended_action != next.action \
		or not _targets_match(next.targets)
	intended_decision = next
	intended_action = next.action
	intended_targets.assign(next.targets)
	presentation_event.emit(self, &"intent_changed", {
		"changed": intent_changed,
	})


func complete_ai_turn(used_ability_id: StringName = &"") -> void:
	ai_state.complete_turn(used_ability_id)


func revalidate_intent_targets(context: EnemyAIContext) -> bool:
	if intended_action == null or intended_decision.is_recovery:
		return false
	var ability := intended_decision.ability
	var rule := intended_decision.rule
	if ability == null or rule == null or rule.selector == null:
		return false
	if rule.selector.targets_are_legal(self, intended_targets, context):
		return false
	var rule_index := ability.rules.find(rule)
	if rule_index < 0:
		return false
	var salt := "%s:%d" % [ability.ability_id, rule_index]
	var next_targets := rule.selector.select(self, ai_state, context, salt)
	if next_targets == intended_targets:
		return false
	intended_decision.targets.assign(next_targets)
	intended_targets.assign(next_targets)
	presentation_event.emit(self, &"intent_changed", {"changed": true})
	return true


func clear_intent() -> void:
	intended_decision = EnemyDecision.new()
	intended_action = null
	intended_targets = []
	presentation_event.emit(self, &"intent_changed", {"changed": false})


func _targets_match(other_targets: Array[BattleCombatant]) -> bool:
	if intended_targets.size() != other_targets.size():
		return false
	for index in intended_targets.size():
		if intended_targets[index] != other_targets[index]:
			return false
	return true
