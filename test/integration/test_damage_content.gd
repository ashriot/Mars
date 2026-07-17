extends GutTest


const CONTENT_ROOTS: Array[String] = [
	"res://data/heroes",
	"res://data/enemies",
]
const LEGACY_ACTION_FORMULAS: Dictionary = {
	"res://data/enemies/actions/shrapnel.tres": ["{atk*1.0}"],
	"res://data/heroes/asher/actions/fusion_ammo.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/energy_barrier.tres": ["{psy*2.0}"],
	"res://data/heroes/echo/actions/feedback.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/inversion.tres": ["{psy*0.75}"],
	"res://data/heroes/echo/actions/pain_transfer.tres": ["{psy*0.75}"],
	"res://data/heroes/echo/actions/psionic_pulse.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/rejuvenate.tres": ["{psy*1.5}"],
	"res://data/heroes/echo/actions/reverberate.tres": ["{psy*1.5}"],
	"res://data/heroes/echo/actions/static_charge.tres": ["{psy*2.0}"],
}
const NESTED_DAMAGE_CONTENT: Array[Dictionary] = [
	{
		"action": "res://data/enemies/actions/shrapnel.tres",
		"condition": "res://data/enemies/conditions/bleed.tres",
		"power": Action.PowerType.ATTACK,
		"potency": 1.0,
		"type": Action.DamageType.PIERCING,
		"formula": "{atk*1.0}",
		"icon": "{prc}",
		"shreds_guard": false,
	},
	{
		"action": "res://data/heroes/asher/actions/fusion_ammo.tres",
		"condition": "res://data/heroes/asher/conditions/fusion_ammo.tres",
		"power": Action.PowerType.PSYCHE,
		"potency": 0.5,
		"type": Action.DamageType.ENERGY,
		"formula": "{psy*0.5}",
		"icon": "{nrg}",
		"shreds_guard": true,
	},
	{
		"action": "res://data/heroes/echo/actions/energy_barrier.tres",
		"condition": "res://data/heroes/echo/conditions/energy_barrier.tres",
		"power": Action.PowerType.PSYCHE,
		"potency": 2.0,
		"type": Action.DamageType.ENERGY,
		"formula": "{psy*2.0}",
		"icon": "{nrg}",
		"shreds_guard": true,
	},
	{
		"action": "res://data/heroes/echo/actions/feedback.tres",
		"condition": "res://data/heroes/echo/conditions/feedback.tres",
		"power": Action.PowerType.PSYCHE,
		"potency": 0.5,
		"type": Action.DamageType.PIERCING,
		"formula": "{psy*0.5}",
		"icon": "{prc}",
		"shreds_guard": false,
	},
	{
		"action": "res://data/heroes/echo/actions/inversion.tres",
		"condition": "res://data/heroes/echo/conditions/inversion.tres",
		"power": Action.PowerType.PSYCHE,
		"potency": 0.75,
		"type": Action.DamageType.PIERCING,
		"formula": "{psy*0.75}",
		"icon": "{prc}",
		"shreds_guard": false,
	},
	{
		"action": "res://data/heroes/echo/actions/psionic_pulse.tres",
		"condition": "res://data/heroes/echo/conditions/psionic_pulse_cond.tres",
		"power": Action.PowerType.PSYCHE,
		"potency": 0.5,
		"type": Action.DamageType.ENERGY,
		"formula": "{psy*0.5}",
		"icon": "{nrg}",
		"shreds_guard": true,
		"timing": "at the start of Echo's next turn",
	},
	{
		"action": "res://data/heroes/echo/actions/reverberate.tres",
		"condition": "res://data/heroes/echo/conditions/reverberate.tres",
		"power": Action.PowerType.PSYCHE,
		"potency": 1.5,
		"type": Action.DamageType.ENERGY,
		"formula": "{psy*1.5}",
		"icon": "{nrg}",
		"shreds_guard": true,
	},
	{
		"action": "res://data/heroes/echo/actions/static_charge.tres",
		"condition": "res://data/heroes/echo/conditions/static_charge.tres",
		"power": Action.PowerType.PSYCHE,
		"potency": 2.0,
		"type": Action.DamageType.ENERGY,
		"formula": "{psy*2.0}",
		"icon": "{nrg}",
		"shreds_guard": true,
	},
]

var _effect_binding_regex := RegEx.new()
var _obsolete_damage_binding_regex := RegEx.new()
var _legacy_formula_regex := RegEx.new()
var _presentation_actor: HeroCard


func before_all() -> void:
	assert_eq(_effect_binding_regex.compile("\\{effect:([^}]+)\\}"), OK)
	assert_eq(_obsolete_damage_binding_regex.compile("\\{dmg[0-9]+\\}"), OK)
	assert_eq(_legacy_formula_regex.compile("\\{(?:atk|psy)[^}]*\\}"), OK)
	_presentation_actor = HeroCard.new()
	_presentation_actor.current_stats = ActorStats.new()
	_presentation_actor.current_stats.attack = 100
	_presentation_actor.current_stats.psyche = 100
	_presentation_actor.current_stats.max_hp = 100
	_presentation_actor.current_hp = 100
	_presentation_actor.current_focus = 5
	_presentation_actor.current_guard = 3


func after_all() -> void:
	_presentation_actor.free()


func test_all_production_damage_resources_are_structured_and_valid() -> void:
	var paths: Array[String] = []
	for root: String in CONTENT_ROOTS:
		_collect_resource_paths(root, paths)
	paths.sort()
	assert_gt(paths.size(), 0, "production damage scan found resources")
	for path: String in paths:
		var resource := ResourceLoader.load(path)
		assert_not_null(resource, "%s loads" % path)
		if resource is Action:
			_validate_action(resource as Action, path)
		elif resource is Condition:
			_validate_condition(resource as Condition, path, {})


func test_nested_condition_damage_prose_matches_referenced_mechanics() -> void:
	for expected: Dictionary in NESTED_DAMAGE_CONTENT:
		var action := load(expected.action) as Action
		var condition := load(expected.condition) as Condition
		assert_not_null(action, expected.action)
		assert_not_null(condition, expected.condition)
		if action == null or condition == null:
			continue
		assert_true(_action_applies_condition(action, condition), expected.action)
		var effect := _first_condition_damage(condition)
		assert_not_null(effect, "%s nested damage" % expected.condition)
		if effect == null:
			continue
		assert_eq(effect.power_type, expected.power, "%s power" % expected.condition)
		assert_almost_eq(effect.potency, expected.potency, 0.0001, "%s potency" % expected.condition)
		assert_eq(effect.damage_type, expected.type, "%s type" % expected.condition)
		for prose: String in [action.description, condition.description]:
			assert_string_contains(prose, expected.formula, "%s power and potency prose" % expected.condition)
			assert_string_contains(prose, expected.icon, "%s type prose" % expected.condition)
			if expected.shreds_guard:
				assert_string_contains(prose.to_lower(), "shred", "%s Guard behavior prose" % expected.condition)
				assert_string_contains(prose, "{grd}", "%s Guard icon prose" % expected.condition)
			else:
				assert_false("shred" in prose.to_lower(), "%s Piercing does not claim to shred Guard" % expected.condition)
				var normalized_guard_prose := prose.replace("{grd}", "Guard").to_lower()
				assert_false(
					"lose" in normalized_guard_prose and "guard" in normalized_guard_prose,
					"%s Piercing does not claim intrinsic Guard loss" % expected.condition,
				)
			if expected.has("timing"):
				assert_string_contains(
					prose.to_lower(), str(expected.timing).to_lower(),
					"%s trigger timing prose" % expected.condition,
				)


func test_return_fire_prose_matches_both_nested_damage_effects() -> void:
	var condition := load(
		"res://data/heroes/sands/conditions/return_fire.tres"
	) as Condition
	var counter := condition.triggers[0].effects_to_run[0] as Effect_Damage
	var trigger := counter.on_hit_triggers[0]
	var extra_hit := trigger.effects_to_run[0] as Effect_Damage
	assert_almost_eq(counter.potency, 0.5, 0.0001)
	assert_eq(counter.power_type, Action.PowerType.ATTACK)
	assert_eq(counter.damage_type, Action.DamageType.PIERCING)
	assert_eq(trigger.condition, HitTrigger.HitCondition.IF_ATTACKER_HAS_BUFF)
	assert_eq(trigger.context, "Overwatch")
	assert_almost_eq(extra_hit.potency, 0.5, 0.0001)
	assert_eq(extra_hit.power_type, Action.PowerType.ATTACK)
	assert_eq(extra_hit.damage_type, Action.DamageType.KINETIC)
	assert_eq(condition.description.count("{atk*0.5}"), 2)
	assert_string_contains(condition.description, "{prc}")
	assert_string_contains(condition.description, "{kin}")
	assert_string_contains(condition.description.to_lower(), "shred")
	assert_string_contains(condition.description, "{grd}")


func test_focused_bolt_uses_approved_remaining_focus_curve() -> void:
	var action := load("res://data/heroes/echo/actions/focused_bolt.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	assert_almost_eq(effect.potency, 0.2, 0.0001)
	assert_eq(effect.power_type, Action.PowerType.ATTACK)
	assert_eq(effect.damage_type, Action.DamageType.ENERGY)
	assert_eq(effect.scaling_rules.size(), 1)
	assert_true(effect.scaling_rules[0] is DamageScalingFlatPerResource)
	var rule := effect.scaling_rules[0] as DamageScalingFlatPerResource
	assert_eq(rule.resource, DamageScalingFlatPerResource.ResourceType.FOCUS)
	assert_almost_eq(rule.potency_per_point, 0.2, 0.0001)
	assert_string_contains(action.description, "{effect:1}")
	assert_string_contains(action.description, "20% ATK plus 20% per remaining Focus after paying the cost")


func test_charged_shot_remains_one_hundred_fifty_percent_attack() -> void:
	var action := load("res://data/heroes/asher/actions/charged_shot.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	assert_almost_eq(effect.potency, 1.5, 0.0001)
	assert_eq(effect.power_type, Action.PowerType.ATTACK)
	assert_string_contains(action.description, "{effect:1}")
	assert_false("{atk*1.25}" in action.description)


func test_booster_shots_executes_and_presents_three_fifty_percent_hits() -> void:
	var action := load("res://data/heroes/sands/actions/booster_shots.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	assert_almost_eq(effect.potency, 0.5, 0.0001)
	assert_eq(effect.power_type, Action.PowerType.ATTACK)
	assert_eq(effect.hit_count, 3)
	assert_string_contains(action.description, "{effect:1}")
	assert_string_contains(action.get_rich_description(_presentation_actor), "50x3")
	assert_false("twice" in action.description.to_lower())


func test_shatter_splits_its_guard_scaled_damage() -> void:
	var action := load("res://data/heroes/echo/actions/shatter.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	assert_true(effect.split_damage)
	assert_string_contains(action.description, "{effect:1}")
	assert_string_contains(action.description, "current Guard")


func test_telekinesis_deals_energy_damage() -> void:
	var action := load("res://data/heroes/echo/actions/telekinesis.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	assert_eq(effect.damage_type, Action.DamageType.ENERGY)
	assert_string_contains(action.description, "{effect:1}")


func test_reverberate_uses_psyche_for_direct_and_triggered_damage() -> void:
	var action := load("res://data/heroes/echo/actions/reverberate.tres") as Action
	var direct := action.effects[0] as Effect_Damage
	var nested := _first_condition_damage(load(
		"res://data/heroes/echo/conditions/reverberate.tres"
	) as Condition)
	assert_eq(direct.power_type, Action.PowerType.PSYCHE)
	assert_eq(nested.power_type, Action.PowerType.PSYCHE)
	assert_string_contains(action.description, "{effect:1}")


func test_shrapnel_has_kinetic_initial_hit_and_piercing_bleed() -> void:
	var action := load("res://data/enemies/actions/shrapnel.tres") as Action
	var direct := action.effects[0] as Effect_Damage
	var bleed := _first_condition_damage(load(
		"res://data/enemies/conditions/bleed.tres"
	) as Condition)
	assert_almost_eq(direct.potency, 2.0, 0.0001)
	assert_eq(direct.power_type, Action.PowerType.ATTACK)
	assert_eq(direct.damage_type, Action.DamageType.KINETIC)
	assert_almost_eq(bleed.potency, 1.0, 0.0001)
	assert_eq(bleed.power_type, Action.PowerType.ATTACK)
	assert_eq(bleed.damage_type, Action.DamageType.PIERCING)
	assert_string_contains(action.description, "{effect:1}")


func test_rapid_fire_uses_fixed_three_hit_split() -> void:
	var action := load("res://data/enemies/actions/rapid_fire.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	assert_eq(effect.hit_count, 3)
	assert_true(effect.split_damage)
	assert_string_contains(action.description, "{effect:1}")


func test_psionic_pulse_and_static_charge_are_guard_shredding_energy() -> void:
	for path: String in [
		"res://data/heroes/echo/conditions/psionic_pulse_cond.tres",
		"res://data/heroes/echo/conditions/static_charge.tres",
	]:
		var effect := _first_condition_damage(load(path) as Condition)
		assert_eq(effect.damage_type, Action.DamageType.ENERGY, path)
		assert_true(effect._resolved_type_shreds_guard(effect.damage_type), path)
		assert_false(effect.get_property_list().any(func(property):
			return property.name == "shreds_guard"
		), "%s has no obsolete Guard override" % path)


func test_weapon_aim_uses_aim_rating() -> void:
	var weapon := Equipment.new()
	weapon.slot = Equipment.Slot.WEAPON
	weapon.star_aim = 5
	weapon.star_kin_def = 0
	assert_gt(weapon.calculate_stats().aim, 10)


func test_enemy_defense_generation_never_exceeds_ninety() -> void:
	var enemy := EnemyData.new()
	enemy.kinetic_defense_rank = 10
	enemy.energy_defense_rank = 10
	enemy.calculate_stats()
	assert_eq(enemy.stats.kinetic_defense, 90)
	assert_eq(enemy.stats.energy_defense, 90)


func _collect_resource_paths(root: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(root)
	assert_not_null(directory, root)
	if directory == null:
		return
	for filename: String in directory.get_files():
		if filename.get_extension().to_lower() == "tres":
			paths.append(root.path_join(filename))
	for child: String in directory.get_directories():
		_collect_resource_paths(root.path_join(child), paths)


func _validate_action(action: Action, path: String) -> void:
	assert_null(_obsolete_damage_binding_regex.search(action.description), "%s has no obsolete damage binding" % path)
	var actual_formulas: Array[String] = []
	for match_result: RegExMatch in _legacy_formula_regex.search_all(action.description):
		actual_formulas.append(match_result.get_string(0))
	var expected_formulas: Array = LEGACY_ACTION_FORMULAS.get(path, [])
	assert_eq(actual_formulas, expected_formulas, "%s has only explicitly approved nested/healing formulas" % path)
	var binding_counts: Dictionary = {}
	for match_result: RegExMatch in _effect_binding_regex.search_all(action.description):
		var index_text := match_result.get_string(1)
		assert_true(index_text.is_valid_int(), "%s valid effect binding %s" % [path, index_text])
		if not index_text.is_valid_int():
			continue
		var effect_index := index_text.to_int() - 1
		assert_true(effect_index >= 0 and effect_index < action.effects.size(), "%s effect binding %s exists" % [path, index_text])
		if effect_index < 0 or effect_index >= action.effects.size():
			continue
		var effect := action.effects[effect_index]
		assert_not_null(effect, "%s effect binding %s is non-null" % [path, index_text])
		if effect == null:
			continue
		var context := EffectPresentationContext.new(
			_presentation_actor, null, action, effect_index, 1, false,
		)
		assert_not_null(effect.get_presentation(context), "%s effect binding %s is presentable" % [path, index_text])
		binding_counts[effect_index] = int(binding_counts.get(effect_index, 0)) + 1
	for effect_index in action.effects.size():
		var effect := action.effects[effect_index]
		if effect is Effect_Damage:
			assert_eq(int(binding_counts.get(effect_index, 0)), 1, "%s effect %d has exactly one structured binding" % [path, effect_index + 1])
	_validate_effects(action.effects, path, {})


func _validate_condition(condition: Condition, path: String, visited: Dictionary) -> void:
	if condition == null or visited.has(condition.get_instance_id()):
		return
	visited[condition.get_instance_id()] = true
	for trigger: Trigger in condition.triggers:
		if trigger != null:
			_validate_effects(trigger.effects_to_run, path, visited)


func _validate_effects(effects: Array, path: String, visited: Dictionary) -> void:
	for effect_index in effects.size():
		var effect := effects[effect_index] as ActionEffect
		assert_not_null(effect, "%s effect %d is non-null" % [path, effect_index + 1])
		if effect == null or visited.has(effect.get_instance_id()):
			continue
		visited[effect.get_instance_id()] = true
		if effect is Effect_Damage:
			_validate_damage_effect(effect as Effect_Damage, path, effect_index + 1)
			for hit_trigger: HitTrigger in (effect as Effect_Damage).on_hit_triggers:
				if hit_trigger != null:
					_validate_effects(hit_trigger.effects_to_run, path, visited)
		elif effect is Effect_ApplyCondition:
			_validate_condition((effect as Effect_ApplyCondition).condition, path, visited)


func _validate_damage_effect(effect: Effect_Damage, path: String, effect_index: int) -> void:
	assert_true(effect.potency >= 0.0, "%s effect %d nonnegative potency" % [path, effect_index])
	assert_true(effect.hit_count >= 1, "%s effect %d positive hit count" % [path, effect_index])
	assert_true(effect.damage_type != Action.DamageType.NONE, "%s effect %d concrete damage type" % [path, effect_index])
	assert_false(effect.get_property_list().any(func(property):
		return property.name == "shreds_guard"
	), "%s effect %d has no obsolete Guard override" % [path, effect_index])


func _action_applies_condition(action: Action, condition: Condition) -> bool:
	for effect: ActionEffect in action.effects:
		if effect is Effect_ApplyCondition \
			and (effect as Effect_ApplyCondition).condition == condition:
			return true
	return false


func _first_condition_damage(condition: Condition) -> Effect_Damage:
	if condition == null:
		return null
	for trigger: Trigger in condition.triggers:
		if trigger == null:
			continue
		for effect: ActionEffect in trigger.effects_to_run:
			if effect is Effect_Damage:
				return effect as Effect_Damage
	return null
