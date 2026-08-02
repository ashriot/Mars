extends GutTest


func test_single_target_damage_preserves_amount_type_hits_and_target() -> void:
	var target := _hero("ASHE")
	var enemy := _enemy(100)
	var action := _damage_action(Action.TargetType.ONE_ENEMY, 0.25, 2)
	enemy.intended_action = action
	enemy.intended_targets = [target]

	var result := EnemyIntentFormatter.format(enemy, null)

	assert_string_contains(result.text, "25")
	assert_string_contains(result.text, "2")
	assert_string_contains(result.text, Action._get_bbcode_icon("kinetic", 28))
	assert_string_contains(result.text, "ASHE")
	assert_string_contains(result.tooltip, action.action_name)
	enemy.free()
	target.free()


func test_random_multi_hit_preserves_random_suffix() -> void:
	var first := _hero("ASHE")
	var second := _hero("ECHO")
	var enemy := _enemy(100)
	var action := _damage_action(Action.TargetType.RANDOM_ENEMY, 0.5, 3)
	enemy.intended_action = action
	enemy.intended_targets = [first, second]

	var result := EnemyIntentFormatter.format(enemy, null)

	assert_string_contains(result.text, "RANDOM")
	assert_string_contains(result.text, "3 hits")
	enemy.free()
	first.free()
	second.free()


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
