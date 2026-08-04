extends GutTest

const KINETIC_ICON_28 := "[img width=28 height=28]res://assets/graphics/icons/img/bullet_out.png[/img]"
const KINETIC_ICON_24 := "[img width=24 height=24]res://assets/graphics/icons/img/bullet_out.png[/img]"


func test_single_target_damage_exactly_preserves_order_hits_icon_and_target_markup() -> void:
	var target := _hero("ASHE")
	var enemy := _enemy(100)
	var action := _damage_action(Action.TargetType.ONE_ENEMY, 0.25, 2)
	enemy.intended_action = action
	enemy.intended_targets = [target]

	var result := EnemyIntentFormatter.format(enemy, null)

	assert_eq(
		result.text,
		"25x2 %s [color=ffffffff]ASHE[/color]" % KINETIC_ICON_28,
	)
	var label := RichTextLabel.new()
	add_child_autofree(label)
	label.bbcode_enabled = true
	label.text = "[center]%s[/center]" % result.text
	var parsed := label.get_parsed_text()
	assert_true(parsed.ends_with("ASHE"))
	assert_false(parsed.contains("[/center]"))
	assert_false(parsed.contains("[/color]"))
	assert_eq(
		result.tooltip,
		"Locked Burst incoming: Deals 25x2 %s damage." % KINETIC_ICON_24,
	)
	enemy.free()
	target.free()


func test_random_multi_hit_uses_compact_hit_count_and_random_suffix() -> void:
	var first := _hero("ASHE")
	var second := _hero("ECHO")
	var enemy := _enemy(100)
	var action := _damage_action(Action.TargetType.RANDOM_ENEMY, 0.5, 3)
	enemy.intended_action = action
	enemy.intended_targets = [first, second]

	var result := EnemyIntentFormatter.format(enemy, null)

	assert_eq(
		result.text,
		"50x3 %s RANDOM" % KINETIC_ICON_28,
	)
	enemy.free()
	first.free()
	second.free()


func test_group_damage_uses_compact_amount_and_everyone_suffix() -> void:
	var first := _hero("ASHE")
	var second := _hero("ECHO")
	var enemy := _enemy(100)
	var action := _damage_action(Action.TargetType.ALL_ENEMIES, 0.5, 1)
	enemy.intended_action = action
	enemy.intended_targets = [first, second]

	var result := EnemyIntentFormatter.format(enemy, null)

	assert_eq(
		result.text,
		"50 %s EVERYONE" % KINETIC_ICON_28,
	)
	enemy.free()
	first.free()
	second.free()


func test_authored_rapid_fire_uses_compact_resolved_damage_language_and_detailed_tooltip() -> void:
	var first := _hero("ASHE")
	var second := _hero("ECHO")
	var enemy := _enemy(120)
	enemy.intended_action = load("res://data/enemies/actions/rapid_fire.tres") as Action
	enemy.intended_targets = [first, second]

	var result := EnemyIntentFormatter.format(enemy, null)

	assert_eq(result.text, "50x3 %s RANDOM" % KINETIC_ICON_28)
	assert_false(result.text.contains("Rapid Fire"))
	assert_false(result.text.contains("per target"))
	assert_false(result.text.contains("(3 hits)"))
	assert_string_contains(result.tooltip, "Targets three enemies at random.")
	assert_string_contains(result.tooltip, "split across 3 hits")
	enemy.free()
	first.free()
	second.free()


func test_missing_targets_exactly_preserve_authored_fallback_and_multi_effect_marker() -> void:
	var enemy := _enemy(100)
	var action := _damage_action(Action.TargetType.RANDOM_ENEMY, 0.5, 3)
	var damage_effect := action.effects[0] as Effect_Damage
	damage_effect.split_damage = true
	action.effects.append(ActionEffect.new())
	enemy.intended_action = action

	var result := EnemyIntentFormatter.format(enemy, null)

	assert_eq(
		result.text,
		"50% ATK total x3 " + KINETIC_ICON_28 + " *",
	)
	assert_false(result.text.contains("(3 hits)"))
	enemy.free()


func test_non_damage_intent_preserves_action_and_everyone_suffix() -> void:
	var first := _hero("ASHE")
	var second := _hero("ECHO")
	var enemy := _enemy(100)
	var action := Action.new()
	action.action_name = "Reinforce"
	action.target_type = Action.TargetType.ALL_ALLIES
	action.effects = [ActionEffect.new()]
	enemy.intended_action = action
	enemy.intended_targets = [first, second]

	var result := EnemyIntentFormatter.format(enemy, null)

	assert_eq(result.text, "Reinforce EVERYONE")
	enemy.free()
	first.free()
	second.free()


func test_non_damage_single_target_preserves_named_target() -> void:
	var ally := _enemy(100, "ALLY")
	var enemy := _enemy(100, "SOURCE")
	var action := Action.new()
	action.action_name = "Repair"
	action.target_type = Action.TargetType.ONE_ALLY
	action.effects = [ActionEffect.new()]
	enemy.intended_action = action
	enemy.intended_targets = [ally]

	var result := EnemyIntentFormatter.format(enemy, null)

	assert_eq(result.text, "Repair ALLY")
	enemy.free()
	ally.free()


func test_missing_intent_returns_empty_text_and_tooltip() -> void:
	var enemy := _enemy(100)

	var result := EnemyIntentFormatter.format(enemy, null)

	assert_eq(result, {"text": "", "tooltip": ""})
	enemy.free()


func _damage_action(
	target_type: Action.TargetType,
	potency: float,
	hit_count: int,
) -> Action:
	var effect := Effect_Damage.new()
	effect.potency = potency
	effect.damage_type = Action.DamageType.KINETIC
	effect.hit_count = hit_count
	var action := Action.new()
	action.action_name = "Locked Burst"
	action.description = "Locked Burst incoming: {effect:1}"
	action.target_type = target_type
	action.effects = [effect]
	return action


func _enemy(attack: int, actor_name := "ENEMY") -> EnemyCombatant:
	var enemy := EnemyCombatant.new()
	var stats := ActorStats.new()
	stats.actor_name = actor_name
	stats.attack = attack
	stats.max_hp = 100
	enemy.setup_base(stats, BattleCombatant.Faction.ENEMY)
	enemy.current_hp = stats.max_hp
	return enemy


func _hero(actor_name: String) -> HeroCombatant:
	var hero := HeroCombatant.new()
	var stats := ActorStats.new()
	stats.actor_name = actor_name
	stats.max_hp = 100
	var definition := RoleDefinition.new()
	definition.color = Color.WHITE
	var role := RoleData.new()
	role.source_definition = definition
	hero.setup_base(stats, BattleCombatant.Faction.HERO)
	hero.loaded_roles = [role]
	hero.current_hp = stats.max_hp
	return hero
