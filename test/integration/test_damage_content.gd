extends GutTest


class UnsupportedScalingRule extends DamageScalingRule:
	func resolve(_base_potency: float, _context: DamageContext) -> DamageContribution:
		return DamageContribution.new(&"unsupported", DamageContribution.Stage.POTENCY, 0.5)


class MisleadingDamagePresentation extends Effect_Damage:
	func get_presentation(_context: EffectPresentationContext) -> EffectPresentation:
		return EffectPresentation.new(
			"Deals {amount} {damage_type} damage.",
			{
				"amount": 999,
				"amount_qualifier": "",
				"selected_power": 999,
				"damage_type": "wrong type",
				"hit_count": 99,
				"hit_count_text": "x99",
				"split_behavior": " wrong split",
				"contextual_scaling": " wrong scaling",
			},
		)


const CONTENT_ROOTS: Array[String] = [
	"res://data/heroes",
	"res://data/enemies",
]
const SUPPORTED_DAMAGE_SCALING_RULE_SCRIPTS: Array[String] = [
	"res://src/battle/damage/damage_scaling_flat_per_resource.gd",
	"res://src/battle/damage/damage_scaling_base_per_resource.gd",
]
const APPROVED_DESCRIPTION_FORMULAS: Dictionary = {
	"res://data/enemies/actions/shrapnel.tres": ["{atk*1.0}"],
	"res://data/enemies/conditions/bleed.tres": ["{atk*1.0}"],
	"res://data/heroes/asher/actions/fusion_ammo.tres": ["{psy*0.5}"],
	"res://data/heroes/asher/conditions/fusion_ammo.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/energy_barrier.tres": ["{psy*2.0}"],
	"res://data/heroes/echo/actions/feedback.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/inversion.tres": ["{psy*0.75}"],
	"res://data/heroes/echo/actions/pain_transfer.tres": ["{psy*0.75}"],
	"res://data/heroes/echo/actions/psionic_pulse.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/rejuvenate.tres": ["{psy*1.5}"],
	"res://data/heroes/echo/actions/reverberate.tres": ["{psy*1.5}"],
	"res://data/heroes/echo/actions/static_charge.tres": ["{psy*2.0}"],
	"res://data/heroes/echo/conditions/energy_barrier.tres": ["{psy*2.0}"],
	"res://data/heroes/echo/conditions/feedback.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/conditions/inversion.tres": ["{psy*0.75}"],
	"res://data/heroes/echo/conditions/psionic_pulse_cond.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/conditions/reverberate.tres": ["{psy*1.5}"],
	"res://data/heroes/echo/conditions/static_charge.tres": ["{psy*2.0}"],
	"res://data/heroes/sands/conditions/return_fire.tres": ["{atk*0.5}", "{atk*0.5}"],
}
const NESTED_COMPATIBILITY_CASES: Array[Dictionary] = [
	{
		"id": "bleed",
		"action": "res://data/enemies/actions/shrapnel.tres",
		"condition": "res://data/enemies/conditions/bleed.tres",
		"condition_type": Condition.ConditionType.DEBUFF,
		"trigger_type": Trigger.TriggerType.ON_TURN_START,
		"remove_on_triggers": [],
		"required_action_prose": ["applies debuff", "at the start of your turn"],
		"required_condition_prose": ["at the start of this hero's turn"],
		"formula": "{atk*1.0}",
		"icon": "{prc}",
		"shreds_guard": false,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.SELF,
			"kind": "damage",
			"power": Action.PowerType.ATTACK,
			"potency": 1.0,
			"damage_type": Action.DamageType.PIERCING,
			"hit_count": 1,
			"split_damage": false,
			"is_indirect": true,
		},
	},
	{
		"id": "fusion_ammo",
		"action": "res://data/heroes/asher/actions/fusion_ammo.tres",
		"condition": "res://data/heroes/asher/conditions/fusion_ammo.tres",
		"condition_type": Condition.ConditionType.BUFF,
		"trigger_type": Trigger.TriggerType.AFTER_ATTACKING,
		"remove_on_triggers": [Trigger.TriggerType.ON_BREACHED, Trigger.TriggerType.ON_SHIFT],
		"required_action_prose": [
			"boosts asher's next turn by 15%",
			"gains buff",
			"attacks land an extra",
			"lasts until asher shifts or is breached",
		],
		"required_condition_prose": [
			"attacks land an extra",
			"lasts until asher shifts or is breached",
		],
		"formula": "{psy*0.5}",
		"icon": "{nrg}",
		"shreds_guard": true,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.PARENT,
			"kind": "damage",
			"power": Action.PowerType.PSYCHE,
			"potency": 0.5,
			"damage_type": Action.DamageType.ENERGY,
			"hit_count": 1,
			"split_damage": false,
			"is_indirect": false,
		},
	},
	{
		"id": "energy_barrier",
		"action": "res://data/heroes/echo/actions/energy_barrier.tres",
		"condition": "res://data/heroes/echo/conditions/energy_barrier.tres",
		"condition_type": Condition.ConditionType.BUFF,
		"trigger_type": Trigger.TriggerType.ON_BEING_HIT,
		"remove_on_triggers": [Trigger.TriggerType.ON_BEING_HIT],
		"required_action_prose": ["grants any hero", "buff", "next enemy to hit this hero"],
		"required_condition_prose": ["next enemy to hit this hero"],
		"formula": "{psy*2.0}",
		"icon": "{nrg}",
		"shreds_guard": true,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.ATTACKER,
			"kind": "damage",
			"power": Action.PowerType.PSYCHE,
			"potency": 2.0,
			"damage_type": Action.DamageType.ENERGY,
			"hit_count": 1,
			"split_damage": false,
			"is_indirect": false,
		},
	},
	{
		"id": "feedback",
		"action": "res://data/heroes/echo/actions/feedback.tres",
		"condition": "res://data/heroes/echo/conditions/feedback.tres",
		"condition_type": Condition.ConditionType.DEBUFF,
		"trigger_type": Trigger.TriggerType.ON_HIT,
		"remove_on_triggers": [Trigger.TriggerType.AFTER_ATTACKING],
		"required_action_prose": [
			"applies debuff", "next time this enemy attacks", "for each hit",
		],
		"required_condition_prose": ["next time this enemy attacks", "for each hit"],
		"formula": "{psy*0.5}",
		"icon": "{prc}",
		"shreds_guard": false,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.SELF,
			"kind": "damage",
			"power": Action.PowerType.PSYCHE,
			"potency": 0.5,
			"damage_type": Action.DamageType.PIERCING,
			"hit_count": 1,
			"split_damage": false,
			"is_indirect": false,
		},
	},
	{
		"id": "inversion",
		"action": "res://data/heroes/echo/actions/inversion.tres",
		"condition": "res://data/heroes/echo/conditions/inversion.tres",
		"condition_type": Condition.ConditionType.DEBUFF,
		"trigger_type": Trigger.TriggerType.ON_GAINING_GUARD,
		"remove_on_triggers": [Trigger.TriggerType.ON_GAINING_GUARD],
		"required_action_prose": [
			"applies debuff", "next time this enemy gains", "for each point of",
		],
		"required_condition_prose": [
			"next time this enemy gains guard", "for each point of guard",
		],
		"formula": "{psy*0.75}",
		"icon": "{prc}",
		"shreds_guard": false,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage_inversion.gd",
			"target_type": Action.TargetType.PARENT,
			"kind": "damage",
			"power": Action.PowerType.PSYCHE,
			"potency": 0.75,
			"damage_type": Action.DamageType.PIERCING,
			"hit_count": 1,
			"split_damage": false,
			"is_indirect": false,
			"remove_guard_gained": true,
		},
	},
	{
		"id": "pain_transfer",
		"action": "res://data/heroes/echo/actions/pain_transfer.tres",
		"condition": "res://data/heroes/echo/conditions/pain_transfer.tres",
		"condition_type": Condition.ConditionType.DEBUFF,
		"trigger_type": Trigger.TriggerType.ON_BEING_HIT,
		"remove_on_triggers": [],
		"required_action_prose": [
			"applies debuff", "heal themselves on each hit", "lasts until echo's next turn",
		],
		"required_condition_prose": ["heal hp", "for each hit", "on this enemy"],
		"formula": "{psy*0.75}",
		"effect": {
			"script": "res://src/scripts/action_effects/effect_healing.gd",
			"target_type": Action.TargetType.ATTACKER,
			"kind": "healing",
			"power": Action.PowerType.PSYCHE,
			"potency": 0.75,
			"focus_scalar": 0.0,
			"scales_with_missing_hp": false,
			"is_revive": false,
		},
		"auxiliary_removal": {
			"action_effect_count": 3,
			"apply_effect_index": 2,
			"apply_target_type": Action.TargetType.SELF,
			"condition_name": "Pain Transfer Removal",
			"is_passive": true,
			"trigger_type": Trigger.TriggerType.ON_TURN_START,
			"remove_on_triggers": [Trigger.TriggerType.ON_TURN_START],
			"effect_script": "res://src/scripts/action_effects/effect_remove_condition.gd",
			"effect_target_type": Action.TargetType.ALL_ENEMIES,
			"removed_condition_name": "Pain Transfer",
		},
	},
	{
		"id": "psionic_pulse",
		"action": "res://data/heroes/echo/actions/psionic_pulse.tres",
		"condition": "res://data/heroes/echo/conditions/psionic_pulse_cond.tres",
		# Passive-only marker: intentionally outside Buff/Debuff gameplay classification.
		"condition_type": 2,
		"trigger_type": Trigger.TriggerType.ON_TURN_START,
		"remove_on_triggers": [Trigger.TriggerType.ON_SHIFT],
		"is_passive": true,
		"required_action_prose": ["at the start of echo's next turn", "all enemies take"],
		"required_condition_prose": ["at the start of echo's next turn", "all enemies take"],
		"formula": "{psy*0.5}",
		"icon": "{nrg}",
		"shreds_guard": true,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.ALL_ENEMIES,
			"kind": "damage",
			"power": Action.PowerType.PSYCHE,
			"potency": 0.5,
			"damage_type": Action.DamageType.ENERGY,
			"hit_count": 1,
			"split_damage": false,
			"is_indirect": false,
		},
	},
	{
		"id": "reverberate",
		"action": "res://data/heroes/echo/actions/reverberate.tres",
		"condition": "res://data/heroes/echo/conditions/reverberate.tres",
		"condition_type": Condition.ConditionType.DEBUFF,
		"trigger_type": Trigger.TriggerType.ON_TAKING_KINETIC_DAMAGE,
		"remove_on_triggers": [Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE],
		"required_action_prose": [
			"applies debuff", "next time this enemy takes {kin} damage", "damage hit",
		],
		"required_condition_prose": [
			"next time this enemy takes {kin} damage", "damage hit",
		],
		"formula": "{psy*1.5}",
		"icon": "{nrg}",
		"shreds_guard": true,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.PARENT,
			"kind": "damage",
			"power": Action.PowerType.PSYCHE,
			"potency": 1.5,
			"damage_type": Action.DamageType.ENERGY,
			"hit_count": 1,
			"split_damage": false,
			"is_indirect": false,
		},
	},
	{
		"id": "static_charge",
		"action": "res://data/heroes/echo/actions/static_charge.tres",
		"condition": "res://data/heroes/echo/conditions/static_charge.tres",
		"condition_type": Condition.ConditionType.DEBUFF,
		"trigger_type": Trigger.TriggerType.ON_TURN_START,
		"remove_on_triggers": [Trigger.TriggerType.ON_TURN_START],
		"required_action_prose": [
			"delays an enemy by 25%", "applies debuff", "at the start of their next turn",
		],
		"required_condition_prose": ["slowed", "at the start of their next turn"],
		"formula": "{psy*2.0}",
		"icon": "{nrg}",
		"shreds_guard": true,
		"condition_fields": {"speed_scalar": -0.25},
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.SELF,
			"kind": "damage",
			"power": Action.PowerType.PSYCHE,
			"potency": 2.0,
			"damage_type": Action.DamageType.ENERGY,
			"hit_count": 1,
			"split_damage": false,
			"is_indirect": false,
		},
	},
	{
		"id": "return_fire",
		"action": "",
		"condition": "res://data/heroes/sands/conditions/return_fire.tres",
		"condition_type": Condition.ConditionType.BUFF,
		"trigger_type": Trigger.TriggerType.ON_BEING_HIT,
		"remove_on_triggers": [Trigger.TriggerType.ON_SHIFT],
		"is_passive": true,
		"required_condition_prose": ["counterattacks enemy hits", "with overwatch", "add a"],
		"formula": "{atk*0.5}",
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.ATTACKER,
			"kind": "damage",
			"power": Action.PowerType.ATTACK,
			"potency": 0.5,
			"damage_type": Action.DamageType.PIERCING,
			"hit_count": 1,
			"split_damage": false,
			"is_indirect": false,
			"on_hit": {
				"condition": HitTrigger.HitCondition.IF_ATTACKER_HAS_BUFF,
				"context": "Overwatch",
				"effect": {
					"script": "res://src/scripts/action_effects/effect_damage.gd",
					"target_type": Action.TargetType.ATTACKER,
					"kind": "damage",
					"power": Action.PowerType.ATTACK,
					"potency": 0.5,
					"damage_type": Action.DamageType.KINETIC,
					"hit_count": 1,
					"split_damage": false,
					"is_indirect": false,
				},
			},
		},
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


func test_static_charge_condition_is_authored_as_debuff() -> void:
	var condition := load(
		"res://data/heroes/echo/conditions/static_charge.tres"
	) as Condition
	assert_eq(condition.condition_type, Condition.ConditionType.DEBUFF)


func test_each_compatibility_case_declares_classification_and_semantic_clauses() -> void:
	var missing_requirements: Array[String] = []
	for expected: Dictionary in NESTED_COMPATIBILITY_CASES:
		if not expected.has("condition_type"):
			missing_requirements.append("%s condition_type" % expected.id)
		if not expected.has("required_condition_prose") \
		or (expected.get("required_condition_prose", []) as Array).is_empty():
			missing_requirements.append("%s condition prose" % expected.id)
		if not str(expected.action).is_empty() \
		and (not expected.has("required_action_prose") \
		or (expected.get("required_action_prose", []) as Array).is_empty()):
			missing_requirements.append("%s action prose" % expected.id)
	assert_eq(
		missing_requirements,
		[],
		"every compatibility case declares classification and semantic/timing prose",
	)


func test_nested_case_validator_rejects_condition_classification_drift() -> void:
	var expected := _nested_case_by_id("feedback").duplicate(true)
	expected["condition_type"] = Condition.ConditionType.DEBUFF
	var action := load(expected.action) as Action
	var condition := (load(expected.condition) as Condition).duplicate(true) as Condition
	condition.condition_type = Condition.ConditionType.BUFF
	var errors := _nested_case_errors(expected, action, condition)
	assert_string_contains("\n".join(errors), "condition classification drifted")


func test_semantic_clause_validator_rejects_missing_required_meaning() -> void:
	assert_eq(
		_missing_semantic_clauses(
			"At the end of the turn, deal damage.",
			["at the start of the turn", "heal"],
		),
		["at the start of the turn", "heal"],
	)


func test_formula_allowlist_covers_every_action_and_condition_description() -> void:
	var paths: Array[String] = []
	for root: String in CONTENT_ROOTS:
		_collect_resource_paths(root, paths)
	paths.sort()
	var actual_formulas: Dictionary = {}
	for path: String in paths:
		var resource := ResourceLoader.load(path)
		if not (resource is Action or resource is Condition):
			continue
		var description: String = resource.description
		var formulas: Array[String] = []
		for match_result: RegExMatch in _legacy_formula_regex.search_all(description):
			formulas.append(match_result.get_string(0))
		if not formulas.is_empty():
			actual_formulas[path] = formulas
	assert_eq(
		actual_formulas,
		APPROVED_DESCRIPTION_FORMULAS,
		"the formula allowlist exactly covers Action and Condition descriptions",
	)


func test_nested_cases_cover_every_authorized_formula_except_rejuvenate() -> void:
	var paths: Array[String] = []
	for root: String in CONTENT_ROOTS:
		_collect_resource_paths(root, paths)
	paths.sort()
	var formula_paths: Array[String] = []
	for path: String in paths:
		if path == "res://data/heroes/echo/actions/rejuvenate.tres":
			continue
		var resource := ResourceLoader.load(path)
		if not (resource is Action or resource is Condition):
			continue
		if not _legacy_formula_regex.search_all(resource.description).is_empty():
			formula_paths.append(path)
	var covered_paths: Array[String] = []
	for expected: Dictionary in NESTED_COMPATIBILITY_CASES:
		for key: String in ["action", "condition"]:
			var path: String = expected.get(key, "")
			if not path.is_empty() and path in formula_paths:
				covered_paths.append(path)
	covered_paths.sort()
	assert_eq(
		covered_paths,
		formula_paths,
		"every non-deferred formula owner has an explicit compatibility case",
	)


func test_nested_case_validator_detects_topology_shape_and_healing_drift() -> void:
	var inversion_expected := _nested_case_by_id("inversion")
	assert_false(inversion_expected.is_empty())
	var inversion := load(inversion_expected.condition) as Condition
	var inversion_action := load(inversion_expected.action) as Action
	var errors := _nested_case_errors(inversion_expected, inversion_action, inversion)
	assert_eq(errors, [], "the authored Inversion topology is valid")

	var trigger_drift := inversion.duplicate(true) as Condition
	trigger_drift.triggers[0].trigger_type = Trigger.TriggerType.ON_TURN_END
	errors = _nested_case_errors(inversion_expected, inversion_action, trigger_drift)
	assert_string_contains("\n".join(errors), "owning trigger type drifted")

	var target_drift := inversion.duplicate(true) as Condition
	target_drift.triggers[0].effects_to_run[0].target_type = Action.TargetType.SELF
	errors = _nested_case_errors(inversion_expected, inversion_action, target_drift)
	assert_string_contains("\n".join(errors), "target type drifted")

	var class_drift := inversion.duplicate(true) as Condition
	var base_damage := Effect_Damage.new()
	base_damage.potency = 0.75
	base_damage.power_type = Action.PowerType.PSYCHE
	base_damage.damage_type = Action.DamageType.PIERCING
	class_drift.triggers[0].effects_to_run[0] = base_damage
	errors = _nested_case_errors(inversion_expected, inversion_action, class_drift)
	assert_string_contains("\n".join(errors), "script drifted")
	assert_string_contains("\n".join(errors), "specialized Inversion shape")

	var removal_drift := inversion.duplicate(true) as Condition
	removal_drift.remove_on_triggers.clear()
	errors = _nested_case_errors(inversion_expected, inversion_action, removal_drift)
	assert_string_contains("\n".join(errors), "removal timing drifted")

	var pain_expected := _nested_case_by_id("pain_transfer")
	assert_false(pain_expected.is_empty())
	var pain := load(pain_expected.condition) as Condition
	var pain_action := load(pain_expected.action) as Action
	errors = _nested_case_errors(pain_expected, pain_action, pain)
	assert_eq(errors, [], "the authored Pain Transfer healing topology is valid")
	var healing_drift := pain.duplicate(true) as Condition
	(healing_drift.triggers[0].effects_to_run[0] as Effect_Healing).potency = 0.5
	errors = _nested_case_errors(pain_expected, pain_action, healing_drift)
	assert_string_contains("\n".join(errors), "healing potency drifted")


func test_serialized_guard_override_scan_rejects_stale_property_text() -> void:
	assert_true(
		_has_serialized_shreds_guard("[resource]\n\tshreds_guard= true\n"),
		"a serialized obsolete property is rejected even if loading ignores it",
	)
	assert_false(
		_has_serialized_shreds_guard("description = \"shreds_guard = true\"\n"),
		"ordinary source text is not mistaken for a serialized property",
	)


func test_all_production_damage_resources_are_structured_and_valid() -> void:
	var paths: Array[String] = []
	for root: String in CONTENT_ROOTS:
		_collect_resource_paths(root, paths)
	paths.sort()
	assert_gt(paths.size(), 0, "production damage scan found resources")
	for path: String in paths:
		assert_false(
			_has_serialized_shreds_guard(FileAccess.get_file_as_string(path)),
			"%s has no serialized obsolete shreds_guard property" % path,
		)
		var resource := ResourceLoader.load(path)
		assert_not_null(resource, "%s loads" % path)
		if resource is Action:
			_validate_action(resource as Action, path)
		elif resource is Condition:
			_validate_condition(resource as Condition, path, {})


func test_damage_validator_rejects_unsupported_scaling_rule_classes_and_phases() -> void:
	var effect := Effect_Damage.new()
	effect.scaling_rules = [UnsupportedScalingRule.new()]
	var errors := _damage_effect_errors(effect)
	assert_string_contains("\n".join(errors), "unsupported scaling rule class")

	var invalid_phase_rule := DamageScalingFlatPerResource.new()
	invalid_phase_rule.set("phase", 99)
	effect.scaling_rules = [invalid_phase_rule]
	errors = _damage_effect_errors(effect)
	assert_string_contains("\n".join(errors), "unsupported scaling phase")


func test_direct_damage_validator_compares_structured_incomplete_relationship() -> void:
	var action := Action.new()
	var effect := Effect_Damage.new()
	effect.potency = 1.25
	effect.hit_count = 3
	effect.split_damage = true
	var rule := DamageScalingFlatPerResource.new()
	rule.resource = DamageScalingFlatPerResource.ResourceType.FOCUS
	rule.potency_per_point = 0.1
	effect.scaling_rules = [rule]
	action.effects = [effect]
	assert_eq(
		_direct_damage_presentation_errors(action, effect, 0),
		[],
		"ordinary direct damage presentation matches its authored relationship",
	)

	var misleading := MisleadingDamagePresentation.new()
	misleading.potency = effect.potency
	misleading.hit_count = effect.hit_count
	misleading.split_damage = effect.split_damage
	misleading.scaling_rules = [rule]
	action.effects = [misleading]
	var errors := _direct_damage_presentation_errors(action, misleading, 0)
	var combined_errors := "\n".join(errors)
	for binding_name: String in [
		"amount", "amount_qualifier", "selected_power", "damage_type", "hit_count",
		"hit_count_text", "split_behavior", "contextual_scaling",
	]:
		assert_string_contains(
			combined_errors,
			"%s presentation binding" % binding_name,
		)
	assert_string_contains(combined_errors, "presentation clause missing")


func test_nested_condition_content_matches_referenced_topology_and_mechanics() -> void:
	for expected: Dictionary in NESTED_COMPATIBILITY_CASES:
		var action: Action = null
		if not str(expected.action).is_empty():
			action = load(expected.action) as Action
		var condition := load(expected.condition) as Condition
		if not str(expected.action).is_empty():
			assert_not_null(action, expected.action)
		assert_not_null(condition, expected.condition)
		if (not str(expected.action).is_empty() and action == null) or condition == null:
			continue
		var errors := _nested_case_errors(expected, action, condition)
		assert_eq(errors, [], "%s topology and mechanics: %s" % [expected.id, errors])
		if action != null:
			var missing_action_clauses := _missing_semantic_clauses(
				action.description, expected.required_action_prose,
			)
			assert_eq(
				missing_action_clauses,
				[],
				"%s action semantic/timing prose: %s" % [expected.id, missing_action_clauses],
			)
		var missing_condition_clauses := _missing_semantic_clauses(
			condition.description, expected.required_condition_prose,
		)
		assert_eq(
			missing_condition_clauses,
			[],
			"%s condition semantic/timing prose: %s" % [expected.id, missing_condition_clauses],
		)
		var prose_descriptions: Array[String] = []
		if action != null and APPROVED_DESCRIPTION_FORMULAS.has(expected.action):
			prose_descriptions.append(action.description)
		if APPROVED_DESCRIPTION_FORMULAS.has(expected.condition):
			prose_descriptions.append(condition.description)
		for prose: String in prose_descriptions:
			assert_string_contains(prose, expected.formula, "%s power and potency prose" % expected.condition)
			if expected.has("icon"):
				assert_string_contains(prose, expected.icon, "%s type prose" % expected.condition)
			if expected.get("shreds_guard", false):
				assert_string_contains(prose.to_lower(), "shred", "%s Guard behavior prose" % expected.condition)
				assert_string_contains(prose, "{grd}", "%s Guard icon prose" % expected.condition)
			elif expected.has("shreds_guard"):
				assert_false("shred" in prose.to_lower(), "%s Piercing does not claim to shred Guard" % expected.condition)
				var normalized_guard_prose := prose.replace("{grd}", "Guard").to_lower()
				assert_false(
					"lose" in normalized_guard_prose and "guard" in normalized_guard_prose,
					"%s Piercing does not claim intrinsic Guard loss" % expected.condition,
				)


func test_rejuvenate_formula_is_allowlisted_but_mechanic_parity_is_deferred() -> void:
	const REJUVENATE_PATH := "res://data/heroes/echo/actions/rejuvenate.tres"
	assert_eq(APPROVED_DESCRIPTION_FORMULAS[REJUVENATE_PATH], ["{psy*1.5}"])
	assert_false(NESTED_COMPATIBILITY_CASES.any(func(expected: Dictionary):
		return expected.get("action", "") == REJUVENATE_PATH
	), "Rejuvenate remains outside nested/healing mechanic-parity claims")


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
	assert_string_contains(action.get_rich_description(_presentation_actor), "50% ATKx3")
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
	_validate_description_formulas(action.description, path)
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
			_validate_direct_damage_presentation(
				action,
				effect as Effect_Damage,
				path,
				effect_index,
			)
	_validate_effects(action.effects, path, {})


func _validate_condition(condition: Condition, path: String, visited: Dictionary) -> void:
	if condition == null or visited.has(condition.get_instance_id()):
		return
	visited[condition.get_instance_id()] = true
	if not condition.resource_path.is_empty():
		_validate_description_formulas(condition.description, condition.resource_path)
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
	var errors := _damage_effect_errors(effect)
	assert_eq(
		errors,
		[],
		"%s effect %d has supported scaling configuration: %s" % [
			path, effect_index, errors,
		],
	)


func _damage_effect_errors(effect: Effect_Damage) -> Array[String]:
	var errors: Array[String] = []
	for rule_index in effect.scaling_rules.size():
		var rule := effect.scaling_rules[rule_index]
		if rule == null:
			errors.append("scaling rule %d is null" % [rule_index + 1])
			continue
		var rule_script := rule.get_script() as Script
		var script_path := rule_script.resource_path if rule_script != null else ""
		if script_path not in SUPPORTED_DAMAGE_SCALING_RULE_SCRIPTS:
			errors.append(
				"scaling rule %d has unsupported scaling rule class %s" % [
					rule_index + 1,
					script_path if not script_path.is_empty() else rule.get_class(),
				],
			)
		if not DamageScalingRule.is_supported_phase(rule.phase):
			errors.append(
				"scaling rule %d has unsupported scaling phase %s" % [
					rule_index + 1, rule.phase,
				],
			)
	return errors


func _validate_direct_damage_presentation(
	action: Action,
	effect: Effect_Damage,
	path: String,
	effect_index: int,
) -> void:
	var errors := _direct_damage_presentation_errors(action, effect, effect_index)
	assert_eq(
		errors,
		[],
		"%s effect %d presentation matches runtime configuration: %s" % [
			path, effect_index + 1, errors,
		],
	)


func _direct_damage_presentation_errors(
	action: Action,
	effect: Effect_Damage,
	effect_index: int,
) -> Array[String]:
	var errors: Array[String] = []
	var distribution_count := _direct_damage_distribution_count(action, effect)
	var context := EffectPresentationContext.new(
		_presentation_actor,
		null,
		action,
		effect_index,
		distribution_count,
		false,
	)
	var presentation := effect.get_presentation(context)
	if presentation == null:
		errors.append("direct damage presentation is null")
		return errors
	var expected_bindings := _expected_direct_damage_bindings(
		action,
		effect,
		distribution_count,
	)
	var actual_bindings := presentation.bindings
	for binding_name: String in expected_bindings:
		if not actual_bindings.has(binding_name):
			errors.append("%s presentation binding is missing" % binding_name)
		else:
			var actual_value: Variant = actual_bindings[binding_name]
			var expected_value: Variant = expected_bindings[binding_name]
			var mismatches := typeof(actual_value) != typeof(expected_value)
			if not mismatches:
				mismatches = actual_value != expected_value
			if not mismatches:
				continue
			errors.append(
				"%s presentation binding mismatches authored relationship: %s != %s" % [
					binding_name,
					actual_value,
					expected_value,
				],
			)
	for binding_name: String in [
		"amount",
		"amount_qualifier",
		"hit_count_text",
		"damage_type",
		"split_behavior",
		"contextual_scaling",
	]:
		if not ("{%s}" % binding_name) in presentation.clause_template:
			errors.append("presentation clause missing {%s}" % binding_name)
	if "{" in presentation.render():
		errors.append("presentation contains an unresolved binding")
	return errors


func _direct_damage_distribution_count(action: Action, effect: Effect_Damage) -> int:
	if not effect.split_damage or action.target_type in [
		Action.TargetType.ALL_ENEMIES,
		Action.TargetType.ENEMY_GROUP,
		Action.TargetType.ALL_ALLIES,
		Action.TargetType.ALLIES_ONLY,
	]:
		return 1
	return maxi(1, effect._resolve_hit_count(_presentation_actor))


func _expected_direct_damage_bindings(
	action: Action,
	effect: Effect_Damage,
	distribution_count: int,
) -> Dictionary:
	var group_distribution_unavailable := action.target_type in [
		Action.TargetType.ALL_ENEMIES,
		Action.TargetType.ENEMY_GROUP,
		Action.TargetType.ALL_ALLIES,
		Action.TargetType.ALLIES_ONLY,
	]
	var amount_qualifier := ""
	var hit_count_text := "x%d" % effect.hit_count if effect.hit_count > 1 else ""
	var split_behavior := ""
	if effect.split_damage:
		amount_qualifier = " total"
		hit_count_text = ""
		if group_distribution_unavailable:
			split_behavior = " split across all targets"
			if effect.hit_count > 1:
				split_behavior += " and %d hits" % effect.hit_count
		else:
			split_behavior = " split across %d hits" % distribution_count
	var power_label := "PSY" \
		if effect.power_type == Action.PowerType.PSYCHE else "ATK"
	return {
		"amount": "%s%% %s" % [
			_format_damage_number(effect.potency * 100.0), power_label,
		],
		"amount_qualifier": amount_qualifier,
		"selected_power": _presentation_actor.get_power(effect.power_type),
		"damage_type": _damage_type_icon(effect.damage_type),
		"hit_count": effect.hit_count,
		"hit_count_text": hit_count_text,
		"split_behavior": split_behavior,
		"contextual_scaling": " (includes contextual scaling)" \
			if not effect.scaling_rules.is_empty() else "",
		"is_exact": false,
	}


func _format_damage_number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) \
		else "%.1f" % value


func _damage_type_icon(damage_type: Action.DamageType) -> String:
	match damage_type:
		Action.DamageType.KINETIC:
			return Action._get_bbcode_icon("kinetic")
		Action.DamageType.ENERGY:
			return Action._get_bbcode_icon("energy")
		Action.DamageType.PIERCING:
			return Action._get_bbcode_icon("pierce")
	return ""


func _validate_description_formulas(description: String, path: String) -> void:
	assert_eq(
		_description_formulas(description),
		APPROVED_DESCRIPTION_FORMULAS.get(path, []),
		"%s has only explicitly approved nested/healing formulas" % path,
	)


func _description_formulas(description: String) -> Array[String]:
	var formulas: Array[String] = []
	for match_result: RegExMatch in _legacy_formula_regex.search_all(description):
		formulas.append(match_result.get_string(0))
	return formulas


func _missing_semantic_clauses(prose: String, required_clauses: Array) -> Array[String]:
	var normalized_prose := prose.to_lower()
	for separator: String in ["\n", "\r", "\t", "[p]", "[/p]", "[i]", "[/i]"]:
		normalized_prose = normalized_prose.replace(separator, " ")
	while "  " in normalized_prose:
		normalized_prose = normalized_prose.replace("  ", " ")
	var missing: Array[String] = []
	for required_clause: String in required_clauses:
		if not required_clause.to_lower() in normalized_prose:
			missing.append(required_clause)
	return missing


func _has_serialized_shreds_guard(source_text: String) -> bool:
	for raw_line: String in source_text.split("\n"):
		var line := raw_line.strip_edges()
		if not line.begins_with("shreds_guard"):
			continue
		var suffix := line.trim_prefix("shreds_guard").strip_edges()
		if suffix.begins_with("="):
			return true
	return false


func _nested_case_by_id(case_id: String) -> Dictionary:
	for expected: Dictionary in NESTED_COMPATIBILITY_CASES:
		if expected.id == case_id:
			return expected
	return {}


func _nested_case_errors(
	expected: Dictionary,
	action: Action,
	condition: Condition,
) -> Array[String]:
	var errors: Array[String] = []
	var action_path := str(expected.get("action", ""))
	var condition_path := str(expected.get("condition", ""))
	if not action_path.is_empty():
		if action == null:
			errors.append("missing action %s" % action_path)
		else:
			if action.resource_path != action_path:
				errors.append("action resource path drifted from %s" % action_path)
			if _count_action_condition_references(action, condition_path) != 1:
				errors.append("%s must directly apply %s exactly once" % [action_path, condition_path])
	if condition == null:
		errors.append("missing condition %s" % condition_path)
		return errors
	if condition.resource_path != condition_path:
		errors.append("condition resource path drifted from %s" % condition_path)
	if int(condition.condition_type) != int(expected.condition_type):
		errors.append("%s condition classification drifted" % condition_path)
	if condition.triggers.size() != 1:
		errors.append("%s expected exactly one owning trigger" % condition_path)
		return errors
	var trigger := condition.triggers[0] as Trigger
	if trigger == null:
		errors.append("%s owning trigger is null" % condition_path)
		return errors
	if trigger.trigger_type != expected.trigger_type:
		errors.append("%s owning trigger type drifted" % condition_path)
	if not _array_values_equal(condition.remove_on_triggers, expected.remove_on_triggers):
		errors.append("%s removal timing drifted" % condition_path)
	if expected.has("is_passive") and condition.is_passive != expected.is_passive:
		errors.append("%s passive shape drifted" % condition_path)
	for property_name: String in expected.get("condition_fields", {}).keys():
		if not _values_equal(condition.get(property_name), expected.condition_fields[property_name]):
			errors.append("%s condition field %s drifted" % [condition_path, property_name])
	if trigger.effects_to_run.size() != 1:
		errors.append("%s expected exactly one primary triggered effect" % condition_path)
		return errors
	_append_effect_spec_errors(
		errors,
		trigger.effects_to_run[0] as ActionEffect,
		expected.effect,
		"%s primary effect" % condition_path,
	)
	if expected.has("auxiliary_removal"):
		_append_auxiliary_removal_errors(errors, action, expected.auxiliary_removal, action_path)
	return errors


func _append_effect_spec_errors(
	errors: Array[String],
	effect: ActionEffect,
	expected: Dictionary,
	label: String,
) -> void:
	if effect == null:
		errors.append("%s is null" % label)
		return
	var effect_script := effect.get_script() as Script
	var script_path := effect_script.resource_path if effect_script != null else ""
	if script_path != expected.script:
		errors.append("%s script drifted" % label)
	if effect.target_type != expected.target_type:
		errors.append("%s target type drifted" % label)
	match str(expected.kind):
		"damage":
			if not effect is Effect_Damage:
				errors.append("%s is not damage" % label)
				return
			var damage := effect as Effect_Damage
			if damage.power_type != expected.power:
				errors.append("%s power type drifted" % label)
			if not is_equal_approx(damage.potency, float(expected.potency)):
				errors.append("%s potency drifted" % label)
			if damage.damage_type != expected.damage_type:
				errors.append("%s damage type drifted" % label)
			if damage.hit_count != expected.hit_count:
				errors.append("%s hit count drifted" % label)
			if damage.split_damage != expected.split_damage:
				errors.append("%s split shape drifted" % label)
			if damage.is_indirect != expected.is_indirect:
				errors.append("%s indirect shape drifted" % label)
			if not damage.scaling_rules.is_empty():
				errors.append("%s unexpectedly has scaling rules" % label)
			if not is_zero_approx(damage.lifedrain_scalar):
				errors.append("%s unexpectedly has lifedrain" % label)
			if not damage.pre_hit_triggers.is_empty():
				errors.append("%s unexpectedly has pre-hit triggers" % label)
			if expected.has("remove_guard_gained"):
				if not damage is Effect_Damage_Inversion:
					errors.append("%s lost its specialized Inversion shape" % label)
				elif (damage as Effect_Damage_Inversion).remove_guard_gained \
					!= expected.remove_guard_gained:
					errors.append("%s Guard-removal shape drifted" % label)
			_append_on_hit_spec_errors(errors, damage, expected.get("on_hit", null), label)
		"healing":
			if not effect is Effect_Healing:
				errors.append("%s is not healing" % label)
				return
			var healing := effect as Effect_Healing
			if healing.power_type != expected.power:
				errors.append("%s healing power type drifted" % label)
			if not is_equal_approx(healing.potency, float(expected.potency)):
				errors.append("%s healing potency drifted" % label)
			if not is_equal_approx(healing.focus_scalar, float(expected.focus_scalar)):
				errors.append("%s healing Focus curve drifted" % label)
			if healing.scales_with_missing_hp != expected.scales_with_missing_hp:
				errors.append("%s missing-HP curve drifted" % label)
			if healing.is_revive != expected.is_revive:
				errors.append("%s revive shape drifted" % label)
		_:
			errors.append("%s has unsupported expected kind" % label)


func _append_on_hit_spec_errors(
	errors: Array[String],
	damage: Effect_Damage,
	expected_on_hit: Variant,
	label: String,
) -> void:
	if expected_on_hit == null:
		if not damage.on_hit_triggers.is_empty():
			errors.append("%s unexpectedly has on-hit triggers" % label)
		return
	if damage.on_hit_triggers.size() != 1:
		errors.append("%s expected exactly one on-hit trigger" % label)
		return
	var hit_trigger := damage.on_hit_triggers[0] as HitTrigger
	if hit_trigger == null:
		errors.append("%s on-hit trigger is null" % label)
		return
	if hit_trigger.condition != expected_on_hit.condition:
		errors.append("%s on-hit condition drifted" % label)
	if hit_trigger.context != expected_on_hit.context:
		errors.append("%s on-hit context drifted" % label)
	if hit_trigger.effects_to_run.size() != 1:
		errors.append("%s expected exactly one on-hit effect" % label)
		return
	_append_effect_spec_errors(
		errors,
		hit_trigger.effects_to_run[0] as ActionEffect,
		expected_on_hit.effect,
		"%s on-hit effect" % label,
	)


func _append_auxiliary_removal_errors(
	errors: Array[String],
	action: Action,
	expected: Dictionary,
	label: String,
) -> void:
	if action == null:
		errors.append("%s auxiliary removal has no action" % label)
		return
	if action.effects.size() != expected.action_effect_count:
		errors.append("%s action effect shape drifted" % label)
	var effect_index := int(expected.apply_effect_index)
	if effect_index < 0 or effect_index >= action.effects.size():
		errors.append("%s auxiliary removal effect is missing" % label)
		return
	var apply_effect := action.effects[effect_index] as Effect_ApplyCondition
	if apply_effect == null:
		errors.append("%s auxiliary removal is not ApplyCondition" % label)
		return
	if apply_effect.target_type != expected.apply_target_type:
		errors.append("%s auxiliary apply target drifted" % label)
	var removal_condition := apply_effect.condition
	if removal_condition == null:
		errors.append("%s auxiliary removal condition is null" % label)
		return
	if removal_condition.condition_name != expected.condition_name:
		errors.append("%s auxiliary condition name drifted" % label)
	if removal_condition.is_passive != expected.is_passive:
		errors.append("%s auxiliary passive shape drifted" % label)
	if not _array_values_equal(removal_condition.remove_on_triggers, expected.remove_on_triggers):
		errors.append("%s auxiliary removal timing drifted" % label)
	if removal_condition.triggers.size() != 1:
		errors.append("%s auxiliary removal expected one trigger" % label)
		return
	var trigger := removal_condition.triggers[0] as Trigger
	if trigger == null or trigger.trigger_type != expected.trigger_type:
		errors.append("%s auxiliary trigger type drifted" % label)
		return
	if trigger.effects_to_run.size() != 1:
		errors.append("%s auxiliary removal expected one effect" % label)
		return
	var remove_effect := trigger.effects_to_run[0] as Effect_RemoveCondition
	if remove_effect == null:
		errors.append("%s auxiliary effect is not RemoveCondition" % label)
		return
	var remove_script := remove_effect.get_script() as Script
	var remove_script_path := remove_script.resource_path if remove_script != null else ""
	if remove_script_path != expected.effect_script:
		errors.append("%s auxiliary effect script drifted" % label)
	if remove_effect.target_type != expected.effect_target_type:
		errors.append("%s auxiliary effect target drifted" % label)
	if remove_effect.condition_name != expected.removed_condition_name:
		errors.append("%s auxiliary removed condition drifted" % label)


func _count_action_condition_references(action: Action, condition_path: String) -> int:
	var count := 0
	for effect: ActionEffect in action.effects:
		if effect is Effect_ApplyCondition:
			var condition := (effect as Effect_ApplyCondition).condition
			if condition != null and condition.resource_path == condition_path:
				count += 1
	return count


func _array_values_equal(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in actual.size():
		if actual[index] != expected[index]:
			return false
	return true


func _values_equal(actual: Variant, expected: Variant) -> bool:
	if actual is float or expected is float:
		return is_equal_approx(float(actual), float(expected))
	return actual == expected


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
