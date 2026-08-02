extends RefCounted
class_name EnemyIntentFormatter


static func format(enemy: EnemyCombatant, manager: BattleManager) -> Dictionary:
	if enemy == null or enemy.intended_action == null:
		return {"text": "", "tooltip": ""}
	var targets: Array[BattleCombatant] = []
	targets.assign(enemy.intended_targets)
	var tooltip_target: BattleCombatant = targets[0] if targets.size() == 1 else null
	return {
		"text": _format_text(enemy, targets, manager),
		"tooltip": enemy.intended_action.get_rich_description(
			enemy, tooltip_target, targets, manager,
		),
	}


static func _format_text(
	enemy: EnemyCombatant,
	targets: Array[BattleCombatant],
	manager: BattleManager,
) -> String:
	if enemy.intended_action.effects.is_empty():
		return ""

	var first_effect := enemy.intended_action.effects[0]
	if first_effect is Effect_Damage:
		return _format_damage(enemy, first_effect as Effect_Damage, targets, manager)

	var final_text := enemy.intended_action.action_name
	if targets.size() > 1:
		final_text += " EVERYONE"
	elif targets.size() == 1 and targets[0].actor_name != enemy.actor_name:
		final_text += " " + targets[0].actor_name
	return final_text


static func _format_damage(
	enemy: EnemyCombatant,
	damage_effect: Effect_Damage,
	targets: Array[BattleCombatant],
	manager: BattleManager,
) -> String:
	var resolved_hit_count := damage_effect._resolve_hit_count(enemy)
	var sequence := DamagePreview.for_plan(
		damage_effect,
		enemy,
		targets,
		enemy.intended_action,
		false,
		manager,
	)
	var damage_bindings: Dictionary
	if sequence.is_complete and not sequence.results.is_empty():
		damage_bindings = damage_effect._get_sequence_bindings(sequence, 28)
	else:
		var context := EffectPresentationContext.new(
			enemy, null, enemy.intended_action,
		)
		damage_bindings = damage_effect.get_presentation(context).bindings
		damage_bindings.damage_type = damage_effect._get_damage_type_icon(
			damage_effect.damage_type, 28,
		)

	var final_text := "%s%s%s %s" % [
		damage_bindings.amount,
		damage_bindings.amount_qualifier,
		damage_bindings.hit_count_text,
		damage_bindings.damage_type,
	]
	if enemy.intended_action.target_type == Action.TargetType.RANDOM_ENEMY \
		and resolved_hit_count > 1 \
		and damage_bindings.hit_count_text.is_empty():
		final_text += " (%d hits)" % resolved_hit_count
	if enemy.intended_action.effects.size() > 1:
		final_text += " *"

	if targets.size() > 1:
		if enemy.intended_action.target_type == Action.TargetType.RANDOM_ENEMY:
			final_text += " RANDOM"
		else:
			final_text += " EVERYONE"
	elif targets.size() == 1:
		var target := targets[0] as HeroCombatant
		var color := target.get_current_role().color.to_html()
		final_text += " [color=%s]%s" % [color, target.actor_name]
	return final_text
