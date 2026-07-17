extends GutTest


class IntentEnemy extends EnemyCard:
	func flash_intent(_duration: float = 0.3) -> void:
		return


func test_focused_bolt_preview_uses_post_cost_remaining_focus_curve() -> void:
	var attacker := _hero(100, 5)
	var action := load("res://data/heroes/echo/actions/focused_bolt.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	var result := DamagePreview.for_effect(effect, attacker, null, Action.new(), 1, false)
	assert_eq(result.request.potency, 1.2)
	assert_eq(result.final_damage, 120)
	attacker.free()


func test_preview_uses_post_cost_focus_without_mutating_attacker() -> void:
	var attacker := _hero(100, 5)
	var rule := DamageScalingFlatPerResource.new()
	rule.resource = DamageScalingFlatPerResource.ResourceType.FOCUS
	rule.potency_per_point = 0.2
	var effect := _damage_effect(0.0)
	effect.damage_type = Action.DamageType.PIERCING
	effect.scaling_rules = [rule]
	var action := Action.new()
	action.focus_cost = 2

	var result := DamagePreview.for_effect(effect, attacker, null, action, 1, false)

	assert_almost_eq(result.request.potency, 0.6, 0.0001)
	assert_eq(result.final_damage, 60)
	assert_eq(attacker.current_focus, 5)
	attacker.free()


func test_target_preview_matches_runtime_request_for_normal_and_critical_hits() -> void:
	var attacker := _hero(100, 0, 50, 200)
	var target := _target(true, 50, 0)
	var effect := Effect_Damage.new()
	effect.potency = 1.0
	var normal := DamagePreview.for_effect(effect, attacker, target, Action.new(), 1, false)
	var critical := DamagePreview.for_effect(effect, attacker, target, Action.new(), 1, true)
	assert_eq(normal.effective_power, 150)
	assert_eq(normal.final_damage, 75)
	assert_eq(critical.effective_power, 350)
	assert_eq(critical.final_damage, 175)
	attacker.free()
	target.free()


func test_target_preview_includes_incoming_damage_modifier() -> void:
	var attacker := _hero(100, 0)
	var target := _target(false, 0, 0.5)
	var result := DamagePreview.for_effect(
		_damage_effect(1.0), attacker, target, Action.new(), 1, false,
	)
	assert_eq(result.request.incoming_modifier, 0.5)
	assert_eq(result.final_damage, 150)
	attacker.free()
	target.free()


func test_exact_target_preview_uses_current_unbreached_state() -> void:
	var attacker := _hero(100, 0, 50)
	var target := _target(false, 0, 0)
	target.current_guard = 1
	var result := DamagePreview.for_effect(
		_damage_effect(1.0), attacker, target, Action.new(), 1, false,
	)
	assert_eq(result.request.overload_power, 0)
	assert_eq(result.effective_power, 100)
	attacker.free()
	target.free()


func test_danger_target_preview_matches_runtime_breach_before_damage() -> void:
	var attacker := _hero(100, 0, 50)
	var target := _target(false, 0, 0)
	var result := DamagePreview.for_effect(
		_damage_effect(1.0), attacker, target, Action.new(), 1, false,
	)
	assert_eq(result.request.overload_power, 50)
	assert_eq(result.effective_power, 150)
	assert_false(target.is_breached, "preview does not mutate the target")
	attacker.free()
	target.free()


func test_forced_piercing_preview_bypasses_defense_without_consuming_condition() -> void:
	var attacker := _hero(100, 0, 50)
	attacker.actor_name = "Asher"
	var target := _target(false, 90, 0)
	var forced_piercing := load(
		"res://data/heroes/asher/conditions/targeting_laser.tres"
	) as Condition
	target.active_conditions = [forced_piercing]
	var effect := _damage_effect(1.0)
	var action := Action.new()
	action.description = "{effect:1}"
	action.effects = [effect]

	var result := DamagePreview.for_effect(effect, attacker, target, action, 1, false)
	var text := action.get_rich_description(attacker, target)

	assert_eq(result.request.damage_type, Action.DamageType.PIERCING)
	assert_eq(result.request.overload_power, 0)
	assert_eq(result.request.defense, 0)
	assert_eq(result.final_damage, 100)
	assert_eq(target.active_conditions, [forced_piercing], "preview does not consume condition")
	assert_string_contains(text, Action._get_bbcode_icon("pierce"))
	assert_false(text.contains(Action._get_bbcode_icon("kinetic")))
	attacker.free()
	target.free()


func test_no_target_preview_uses_explicit_neutral_target_state() -> void:
	var attacker := _hero(100, 0, 50)
	var result := DamagePreview.for_effect(
		_damage_effect(1.0), attacker, null, Action.new(), 1, false,
	)
	assert_eq(result.request.overload_power, 0)
	assert_eq(result.request.defense, 0)
	assert_eq(result.request.incoming_modifier, 0.0)
	assert_eq(result.final_damage, 100)
	attacker.free()


func test_effect_tokens_bind_by_action_effect_index() -> void:
	var action := Action.new()
	action.description = "First {effect:1}; second {effect:2}"
	action.effects = [_damage_effect(0.5), _damage_effect(1.0)]
	var attacker := _attacker()
	var target := _target(false, 0, 0)
	var text := action.get_rich_description(attacker, target)
	assert_false(text.contains("{effect:"))
	assert_string_contains(text, "First ")
	assert_string_contains(text, "; second ")
	attacker.free()
	target.free()


func test_empty_action_description_joins_presentable_effects_in_order() -> void:
	var action := Action.new()
	action.effects = [_damage_effect(0.5), _damage_effect(1.0)]
	var attacker := _attacker()
	var text := action.get_rich_description(attacker)
	assert_string_contains(text, "50")
	assert_string_contains(text, "100")
	assert_lt(text.find("50"), text.find("100"))
	attacker.free()


func test_damage_presentation_exposes_generic_render_bindings() -> void:
	var attacker := _hero(120, 0)
	var target := _target(false, 0, 0)
	var action := Action.new()
	var effect := _damage_effect(1.25)
	effect.hit_count = 3
	effect.split_damage = true
	var context := EffectPresentationContext.new(
		attacker, target, action, 0, 3, false,
	)
	var presentation := effect.get_presentation(context)
	var bindings := presentation.bindings
	assert_eq(bindings.amount, 50)
	assert_eq(bindings.selected_power, 120)
	assert_eq(bindings.hit_count, 3)
	assert_eq(bindings.split_behavior, " split across 3 hits")
	assert_false(presentation.render().contains("{amount}"))
	bindings.amount = 999
	assert_eq(presentation.bindings.amount, 50, "presentation bindings are defensive")
	attacker.free()
	target.free()


func test_all_target_split_without_target_count_describes_total_budget() -> void:
	var action := Action.new()
	action.target_type = Action.TargetType.ALL_ENEMIES
	var effect := _damage_effect(1.0)
	effect.split_damage = true
	effect.hit_count = 3
	action.effects = [effect]
	var attacker := _attacker()

	var text := action.get_rich_description(attacker)

	assert_string_contains(text, "100 total")
	assert_string_contains(text, "split across all targets and 3 hits")
	assert_false(text.contains("33"))
	assert_false(text.contains("100x3"))
	attacker.free()


func test_legacy_expression_and_icon_description_remain_compatible() -> void:
	var action := Action.new()
	action.description = "Deals {atk*0.5} {kin} damage, gains {grd}, then deals {prc}."
	var attacker := _attacker()
	var text := action.get_rich_description(attacker)
	assert_string_contains(text, "Deals 50 ")
	assert_string_contains(text, Action._get_bbcode_icon("kinetic"))
	assert_string_contains(text, Action._get_bbcode_icon("guard"))
	assert_string_contains(text, Action._get_bbcode_icon("pierce"))
	attacker.free()


func test_enemy_intent_uses_fixed_split_and_same_resolver() -> void:
	var attacker := _hero(120, 0)
	var target := _target(false, 0, 0)
	var action := load("res://data/enemies/actions/rapid_fire.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	var result := DamagePreview.for_effect(effect, attacker, target, Action.new(), 3, false)
	assert_eq(result.request.distribution_count, 3)
	assert_eq(result.final_damage, 50)
	attacker.free()
	target.free()


func test_enemy_intent_displays_per_target_preview_range_without_averaging() -> void:
	var enemy := IntentEnemy.new()
	enemy.current_stats = _stats(120, 0, 0, 0, 0)
	enemy.intent_text = RichTextLabel.new()
	enemy.intent_tooltip = RichTooltip.new()
	enemy.intended_action = load("res://data/enemies/actions/rapid_fire.tres") as Action
	var unarmored := _target(false, 0, 0)
	var armored := _target(false, 50, 0)
	enemy.intended_targets = [unarmored, armored]

	enemy._update_intent_ui()

	assert_string_contains(enemy.intent_text.text, "25-50x3")
	assert_string_contains(enemy.intent_text.text, "RANDOM")
	enemy.intent_text.free()
	enemy.intent_tooltip.free()
	enemy.free()
	unarmored.free()
	armored.free()


func _hero(
	attack: int,
	focus: int,
	overload: int = 0,
	precision: int = 0,
) -> HeroCard:
	var hero := HeroCard.new()
	hero.current_stats = _stats(attack, 0, overload, precision, 0)
	hero.current_focus = focus
	hero.current_hp = hero.current_stats.max_hp
	return hero


func _target(
	is_breached: bool,
	defense: int,
	incoming_modifier: float,
) -> ActorCard:
	var target := ActorCard.new()
	target.current_stats = _stats(0, 0, 0, 0, defense)
	target.current_hp = target.current_stats.max_hp
	target.is_breached = is_breached
	if not is_zero_approx(incoming_modifier):
		var modifier := Condition.new()
		modifier.damage_taken_scalar = incoming_modifier
		target.active_conditions = [modifier]
	return target


func _attacker() -> ActorCard:
	var attacker := ActorCard.new()
	attacker.current_stats = _stats(100, 0, 0, 0, 0)
	attacker.current_hp = attacker.current_stats.max_hp
	return attacker


func _damage_effect(effect_potency: float) -> Effect_Damage:
	var effect := Effect_Damage.new()
	effect.potency = effect_potency
	effect.damage_type = Action.DamageType.KINETIC
	return effect


func _stats(
	attack: int,
	psyche: int,
	overload: int,
	precision: int,
	defense: int,
) -> ActorStats:
	var stats := ActorStats.new()
	stats.max_hp = 1000
	stats.attack = attack
	stats.psyche = psyche
	stats.overload = overload
	stats.precision = precision
	stats.kinetic_defense = defense
	stats.energy_defense = defense
	return stats
