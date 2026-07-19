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


class SandsRuntimeBattleManager extends BattleManager:
	var turn_order_refreshes := 0
	var rolled_chances: Array[int] = []

	func _ready() -> void:
		return

	func wait(_duration: float = 0.01) -> void:
		return

	func update_turn_order() -> void:
		turn_order_refreshes += 1

	func combat_roll_percent(chance: int) -> bool:
		rolled_chances.append(chance)
		return false


class SandsRuntimeHero extends HeroCard:
	var guard_events: Array[int] = []
	var healing_events: Array[int] = []
	var focus_events: Array[int] = []
	var damage_results: Array[DamageResult] = []

	func _update_conditions_ui() -> void:
		return

	func modify_guard(amount: int, _is_recovering: bool = false) -> void:
		if is_defeated:
			return
		guard_events.append(amount)
		current_guard = clampi(current_guard + amount, 0, MAX_GUARD)

	func take_healing(amount: int, is_revive: bool = false) -> void:
		if (is_defeated and not is_revive) or amount <= 0:
			return
		healing_events.append(amount)
		current_hp = mini(current_hp + amount, current_stats.max_hp)

	func modify_focus(amount: int, _context: Dictionary = {}) -> void:
		focus_events.append(amount)
		current_focus = clampi(current_focus + amount, 0, 10)

	func take_one_hit(
		result: DamageResult,
		_damage_effect: Effect_Damage,
		_attacker: ActorCard,
		_resolved_damage_type: Action.DamageType,
	) -> int:
		damage_results.append(result)
		var actual := mini(current_hp, result.final_damage)
		current_hp -= actual
		return actual

	func shake_panel(_intensity: float = 0.5) -> void:
		return

	func set_target_presentation(_state: TargetPresentation) -> void:
		return

	func sync_visual_health() -> Tween:
		return null

	func update_current_role() -> void:
		return

	func on_turn_started() -> void:
		shifted_this_turn = false
		await _fire_condition_event(Trigger.TriggerType.ON_TURN_START)


class SandsRuntimeEnemy extends EnemyCard:
	var damage_results: Array[DamageResult] = []
	var guard_events: Array[int] = []

	func _update_conditions_ui() -> void:
		return

	func take_one_hit(
		result: DamageResult,
		_damage_effect: Effect_Damage,
		_attacker: ActorCard,
		_resolved_damage_type: Action.DamageType,
	) -> int:
		damage_results.append(result)
		var actual := mini(current_hp, result.final_damage)
		current_hp -= actual
		return actual

	func modify_guard(amount: int, _is_recovering: bool = false) -> void:
		guard_events.append(amount)
		current_guard = clampi(current_guard + amount, 0, MAX_GUARD)

	func shake_panel(_intensity: float = 0.5) -> void:
		return

	func set_target_presentation(_state: TargetPresentation) -> void:
		return

	func sync_visual_health() -> Tween:
		return null


const CONTENT_ROOTS: Array[String] = [
	"res://data/heroes",
	"res://data/enemies",
]
const SUPPORTED_DAMAGE_SCALING_RULE_SCRIPTS: Array[String] = [
	"res://src/battle/damage/damage_scaling_flat_per_resource.gd",
	"res://src/battle/damage/damage_scaling_base_per_resource.gd",
]
const ASHER_GDD := {
	"fusion_ammo": {"cost": 1, "ct": 75, "extra_potency": 0.5, "outgoing": 0.0},
	"siphon_shots": {"cost": 3, "potency": 0.75, "hits": 3, "lifedrain": 0.5},
	"charged_shot": {"focus_if_vulnerable_or_breached": 2},
	"mark_target": {"ct": 50},
	"aimed_shot": {"potency": 2.0},
	"concussive_shot": {"potency": 5.5},
	"dismantle": {"percent_guard": -0.5, "cap": 5},
	"coordinate": {"refund_focus_cost_on_spend": true},
	"decoy": {"cost": 1, "guard": 1, "untargetable": true},
	"debilitate": {"cost": 2, "outgoing": -0.35},
	"ensnare": {"cost": 2, "potency": 1.5, "speed": -0.25},
}
const ECHO_GDD := {
	"shatter": {"per_guard": 0.5, "split": true, "clears_guard": true},
	"psionic_pulse": {"potency": 0.35, "power": Action.PowerType.PSYCHE},
	"focused_bolt": {"per_focus": 0.25},
	"energy_barrier": {"cost": 2, "guard": 2, "retaliation": 1.5},
	"reverberate": {"cost": 3, "initial": 2.0, "triggered": 2.0},
	"mind_storm": {"cost": 5, "base": 5.0, "remaining_focus": 0.2},
	"telekinesis": {"potency": 0.75, "party_focus": 1},
	"reconstruct": {"cost": 2, "heal": 0.5, "per_target_focus": 0.5},
	"pain_transfer": {"cost": 2, "damage": 2.0, "team_heal": 0.5},
	"energize": {"cost": 4, "ct": 50, "focus": 4},
	"feedback": {"guard_per_hit": -1, "piercing": 0.5},
	"static_charge": {"delay": -0.25, "speed": -0.25, "piercing": 1.0},
	"inversion": {"cost": 3, "piercing_per_guard": 0.5, "cap": 10},
}
const SANDS_GDD := {
	"draw_fire": {"focus": 1},
	"crossfire": {
		"cost": 2,
		"potency": 2.5,
		"split": true,
		"focus_per_breached": 1,
	},
	"phalanx": {
		"cost": 4,
		"potency": 0.35,
		"hits": 4,
		"guard_per_breached": 1,
	},
	"triage": {"heal": 0.5, "missing_hp": true},
	"painkillers": {"reduction": -0.10},
	"first_aid": {"heal": 0.75, "missing_hp": false},
	"covering_fire": {"cost": 1, "potency": 0.5, "hits": 2},
	"auto_shield": {"cost": 2, "guard": 1, "heal": 0.5},
	"advantage": {"cost": 3, "ct_boost": 0.5, "source_psy": 1.0},
	"checkmate": {"potency": 3.0, "ct_change": -0.5},
}
const APPROVED_DESCRIPTION_FORMULAS: Dictionary = {
	"res://data/enemies/actions/shrapnel.tres": ["{atk*1.0}"],
	"res://data/enemies/conditions/bleed.tres": ["{atk*1.0}"],
	"res://data/heroes/asher/actions/fusion_ammo.tres": ["{psy*0.5}"],
	"res://data/heroes/asher/conditions/fusion_ammo.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/energy_barrier.tres": ["{psy*1.5}"],
	"res://data/heroes/echo/actions/feedback.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/inversion.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/pain_transfer.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/psionic_pulse.tres": ["{psy*0.35}"],
	"res://data/heroes/echo/actions/rejuvenate.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/actions/reverberate.tres": ["{psy*2.0}"],
	"res://data/heroes/echo/actions/static_charge.tres": ["{psy*1.0}"],
	"res://data/heroes/echo/conditions/energy_barrier.tres": ["{psy*1.5}"],
	"res://data/heroes/echo/conditions/feedback.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/conditions/inversion.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/conditions/pain_transfer.tres": ["{psy*0.5}"],
	"res://data/heroes/echo/conditions/psionic_pulse_cond.tres": ["{psy*0.35}"],
	"res://data/heroes/echo/conditions/reverberate.tres": ["{psy*2.0}"],
	"res://data/heroes/echo/conditions/static_charge.tres": ["{psy*1.0}"],
	"res://data/heroes/sands/actions/first_aid.tres": ["{psy*0.75}"],
	"res://data/heroes/sands/conditions/return_fire.tres": ["{atk*0.5}", "{atk*0.5}"],
}
const DEFERRED_DIRECT_HEALING_FORMULAS: Dictionary = {
	"res://data/heroes/echo/actions/rejuvenate.tres": ["{psy*0.5}"],
	"res://data/heroes/sands/actions/first_aid.tres": ["{psy*0.75}"],
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
			"boosts asher's next turn by 25%",
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
		"formula": "{psy*1.5}",
		"icon": "{nrg}",
		"shreds_guard": true,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.ATTACKER,
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
		"id": "feedback",
		"action": "res://data/heroes/echo/actions/feedback.tres",
		"condition": "res://data/heroes/echo/conditions/feedback.tres",
		"condition_type": Condition.ConditionType.DEBUFF,
		"trigger_type": Trigger.TriggerType.ON_HIT,
		"remove_on_triggers": [Trigger.TriggerType.AFTER_ATTACKING],
		"required_action_prose": [
			"applies debuff", "each hit of this enemy's next attack", "lose",
		],
		"required_condition_prose": [
			"each hit of this enemy's next attack", "loses",
		],
		"formula": "{psy*0.5}",
		"icon": "{prc}",
		"shreds_guard": false,
		"allows_guard_loss_prose": true,
		"effects": [
			{
				"script": "res://src/scripts/action_effects/effect_modify_guard.gd",
				"target_type": Action.TargetType.SELF,
				"kind": "guard",
				"guard_amount": -1,
			},
			{
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
		],
	},
	{
		"id": "inversion",
		"action": "res://data/heroes/echo/actions/inversion.tres",
		"condition": "res://data/heroes/echo/conditions/inversion.tres",
		"condition_type": Condition.ConditionType.DEBUFF,
		"trigger_type": Trigger.TriggerType.ON_GAINING_GUARD,
		"remove_on_triggers": [Trigger.TriggerType.ON_GAINING_GUARD],
		"required_action_prose": [
			"applies debuff", "next time this enemy attempts to gain", "capped at 10",
		],
		"required_condition_prose": [
			"next time this enemy attempts to gain guard", "capped at 10",
		],
		"formula": "{psy*0.5}",
		"icon": "{prc}",
		"shreds_guard": false,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage_inversion.gd",
			"target_type": Action.TargetType.PARENT,
			"kind": "damage",
			"power": Action.PowerType.PSYCHE,
			"potency": 0.5,
			"damage_type": Action.DamageType.PIERCING,
			"hit_count": 1,
			"split_damage": false,
			"is_indirect": false,
			"requires_inversion": true,
			"max_guard_points": 10,
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
			"applies debuff", "each hit on this enemy", "living party",
			"lasts until echo's next turn",
		],
		"required_condition_prose": [
			"each hit on this enemy", "living party", "until echo's next turn",
		],
		"formula": "{psy*0.5}",
		"effect": {
			"script": "res://src/scripts/action_effects/effect_healing.gd",
			"target_type": Action.TargetType.ALL_ALLIES,
			"kind": "healing",
			"power": Action.PowerType.PSYCHE,
			"potency": 0.5,
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
		"formula": "{psy*0.35}",
		"icon": "{nrg}",
		"shreds_guard": true,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.ALL_ENEMIES,
			"kind": "damage",
			"power": Action.PowerType.PSYCHE,
			"potency": 0.35,
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
		"formula": "{psy*2.0}",
		"icon": "{nrg}",
		"shreds_guard": true,
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.PARENT,
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
		"formula": "{psy*1.0}",
		"icon": "{prc}",
		"shreds_guard": false,
		"condition_fields": {"speed_scalar": -0.25},
		"effect": {
			"script": "res://src/scripts/action_effects/effect_damage.gd",
			"target_type": Action.TargetType.SELF,
			"kind": "damage",
			"power": Action.PowerType.PSYCHE,
			"potency": 1.0,
			"damage_type": Action.DamageType.PIERCING,
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


func test_nested_cases_cover_every_authorized_formula_except_direct_healing_actions() -> void:
	var paths: Array[String] = []
	for root: String in CONTENT_ROOTS:
		_collect_resource_paths(root, paths)
	paths.sort()
	var formula_paths: Array[String] = []
	for path: String in paths:
		if DEFERRED_DIRECT_HEALING_FORMULAS.has(path):
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
	(healing_drift.triggers[0].effects_to_run[0] as Effect_Healing).potency = 0.75
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
				if not expected.get("allows_guard_loss_prose", false):
					assert_false(
						"lose" in normalized_guard_prose and "guard" in normalized_guard_prose,
						"%s Piercing does not claim intrinsic Guard loss" % expected.condition,
					)


func test_direct_healing_formulas_are_allowlisted_but_mechanic_parity_is_deferred() -> void:
	for path: String in DEFERRED_DIRECT_HEALING_FORMULAS:
		assert_eq(
			APPROVED_DESCRIPTION_FORMULAS[path],
			DEFERRED_DIRECT_HEALING_FORMULAS[path],
		)
		assert_false(NESTED_COMPATIBILITY_CASES.any(func(expected: Dictionary):
			return expected.get("action", "") == path
		), "%s remains outside nested/healing mechanic-parity claims" % path)


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
	assert_almost_eq(rule.potency_per_point, ECHO_GDD.focused_bolt.per_focus, 0.0001)
	assert_string_contains(action.description, "{effect:1}")
	assert_string_contains(action.description, "20% ATK plus 25% per remaining Focus after paying the cost")


func test_charged_shot_remains_one_hundred_fifty_percent_attack() -> void:
	var action := load("res://data/heroes/asher/actions/charged_shot.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	assert_almost_eq(effect.potency, 1.5, 0.0001)
	assert_eq(effect.power_type, Action.PowerType.ATTACK)
	assert_string_contains(action.description, "{effect:1}")
	assert_false("{atk*1.25}" in action.description)


func test_asher_gunner_actions_match_gdd() -> void:
	var fusion := load("res://data/heroes/asher/actions/fusion_ammo.tres") as Action
	var fusion_condition := load(
		"res://data/heroes/asher/conditions/fusion_ammo.tres"
	) as Condition
	var extra_hit := fusion_condition.triggers[0].effects_to_run[0] as Effect_Damage
	assert_eq(fusion.focus_cost, ASHER_GDD.fusion_ammo.cost)
	assert_eq(fusion.ct_cost_percent, ASHER_GDD.fusion_ammo.ct)
	assert_almost_eq(
		extra_hit.potency, ASHER_GDD.fusion_ammo.extra_potency, 0.0001,
	)
	assert_eq(extra_hit.power_type, Action.PowerType.PSYCHE)
	assert_eq(extra_hit.damage_type, Action.DamageType.ENERGY)
	assert_eq(fusion_condition.damage_dealt_scalar, ASHER_GDD.fusion_ammo.outgoing)
	assert_eq(
		fusion_condition.remove_on_triggers,
		[Trigger.TriggerType.ON_BREACHED, Trigger.TriggerType.ON_SHIFT],
	)
	assert_string_contains(fusion.description, "Boosts Asher's next turn by 25%")

	var siphon := load("res://data/heroes/asher/actions/siphon_shots.tres") as Action
	var siphon_damage := siphon.effects[0] as Effect_Damage
	assert_eq(siphon.focus_cost, ASHER_GDD.siphon_shots.cost)
	assert_almost_eq(siphon_damage.potency, ASHER_GDD.siphon_shots.potency, 0.0001)
	assert_eq(siphon_damage.hit_count, ASHER_GDD.siphon_shots.hits)
	assert_almost_eq(
		siphon_damage.lifedrain_scalar, ASHER_GDD.siphon_shots.lifedrain, 0.0001,
	)


func test_asher_sniper_actions_match_gdd() -> void:
	var charged := load("res://data/heroes/asher/actions/charged_shot.tres") as Action
	var charged_damage := charged.effects[0] as Effect_Damage
	assert_eq(charged_damage.on_hit_triggers.size(), 1)
	var focus_trigger := charged_damage.on_hit_triggers[0]
	assert_eq(
		focus_trigger.condition,
		HitTrigger.HitCondition.IF_TARGET_IS_VULNERABLE_OR_BREACHED,
	)
	assert_eq(focus_trigger.effects_to_run.size(), 1)
	var focus_effect := focus_trigger.effects_to_run[0] as Effect_ModifyFocus
	assert_eq(
		focus_effect.focus_amount,
		ASHER_GDD.charged_shot.focus_if_vulnerable_or_breached,
	)
	assert_eq(focus_effect.target_type, Action.TargetType.SELF)
	assert_string_contains(charged.description, "VULNERABLE or BREACHED")

	var mark := load("res://data/heroes/asher/actions/mark_target.tres") as Action
	assert_eq(mark.ct_cost_percent, ASHER_GDD.mark_target.ct)
	assert_string_contains(mark.description, "Boosts Asher's next turn by 50%")

	var aimed := load("res://data/heroes/asher/actions/aimed_shot.tres") as Action
	var aimed_damage := aimed.effects[0] as Effect_Damage
	assert_almost_eq(aimed_damage.potency, ASHER_GDD.aimed_shot.potency, 0.0001)

	var concussive := load(
		"res://data/heroes/asher/actions/concussive_shot.tres"
	) as Action
	var concussive_damage := concussive.effects[0] as Effect_Damage
	assert_almost_eq(
		concussive_damage.potency, ASHER_GDD.concussive_shot.potency, 0.0001,
	)


func test_aimed_shot_receives_exactly_twenty_five_aim_from_production_marked() -> void:
	var fixture := _sands_runtime_fixture()
	var asher := fixture.sands as SandsRuntimeHero
	var enemy := fixture.enemy as SandsRuntimeEnemy
	var manager := fixture.manager as SandsRuntimeBattleManager
	asher.actor_name = "Asher"
	asher.current_stats.aim = 10
	var mark_target := load(
		"res://data/heroes/asher/actions/mark_target.tres"
	) as Action
	var aimed_shot := load(
		"res://data/heroes/asher/actions/aimed_shot.tres"
	) as Action

	await manager.execute_action(asher, mark_target, [enemy], false)
	assert_true(enemy.has_condition("Marked"))
	assert_eq(enemy.get_incoming_aim_mods(), 25)

	await manager.execute_action(asher, aimed_shot, [enemy], false)

	assert_eq(manager.rolled_chances, [35])
	assert_true(enemy.has_condition("Marked"))
	_free_sands_runtime_fixture(fixture)


func test_concussive_shot_consumes_production_marked_and_delays_target() -> void:
	var fixture := _sands_runtime_fixture()
	var asher := fixture.sands as SandsRuntimeHero
	var enemy := fixture.enemy as SandsRuntimeEnemy
	var manager := fixture.manager as SandsRuntimeBattleManager
	asher.actor_name = "Asher"
	enemy.current_ct = 3000
	var mark_target := load(
		"res://data/heroes/asher/actions/mark_target.tres"
	) as Action
	var concussive_shot := load(
		"res://data/heroes/asher/actions/concussive_shot.tres"
	) as Action

	await manager.execute_action(asher, mark_target, [enemy], false)
	assert_true(enemy.has_condition("Marked"))
	await manager.execute_action(asher, concussive_shot, [enemy], false)

	assert_false(enemy.has_condition("Marked"))
	assert_eq(enemy.current_ct, 1000)
	assert_eq(manager.turn_order_refreshes, 1)
	_free_sands_runtime_fixture(fixture)


func test_asher_operative_actions_match_gdd() -> void:
	var dismantle := load("res://data/heroes/asher/actions/dismantle.tres") as Action
	var guard_effect := dismantle.effects[0] as Effect_ModifyGuard
	assert_almost_eq(
		guard_effect.percent_change, ASHER_GDD.dismantle.percent_guard, 0.0001,
	)
	assert_eq(guard_effect.max_abs_change, ASHER_GDD.dismantle.cap)

	var coordinate := load("res://data/heroes/asher/actions/coordinate.tres") as Action
	var coordinate_apply := coordinate.effects[0] as Effect_ApplyCondition
	assert_eq(
		coordinate_apply.condition.refund_focus_cost_on_spend,
		ASHER_GDD.coordinate.refund_focus_cost_on_spend,
	)
	assert_eq(coordinate_apply.condition.focus_cost_reduction, 0.0)
	assert_eq(
		coordinate_apply.condition.remove_on_triggers,
		[Trigger.TriggerType.ON_SPENDING_FOCUS],
	)
	assert_string_contains(coordinate.description.to_lower(), "cost is refunded")

	var decoy := load("res://data/heroes/asher/actions/decoy.tres") as Action
	assert_eq(decoy.focus_cost, ASHER_GDD.decoy.cost)
	assert_eq(decoy.effects.size(), 2)
	var decoy_guard := decoy.effects[0] as Effect_ModifyGuard
	var decoy_apply := decoy.effects[1] as Effect_ApplyCondition
	assert_eq(decoy_guard.guard_amount, ASHER_GDD.decoy.guard)
	assert_eq(decoy_apply.condition.is_untargetable, ASHER_GDD.decoy.untargetable)
	assert_eq(
		decoy_apply.condition.remove_on_triggers,
		[Trigger.TriggerType.ON_TURN_START],
	)
	assert_false(decoy.effects.any(func(effect): return effect is Effect_RemoveCondition))

	var debilitate := load("res://data/heroes/asher/actions/debilitate.tres") as Action
	var debilitate_apply := debilitate.effects[0] as Effect_ApplyCondition
	assert_eq(debilitate.focus_cost, ASHER_GDD.debilitate.cost)
	assert_almost_eq(
		debilitate_apply.condition.damage_dealt_scalar,
		ASHER_GDD.debilitate.outgoing,
		0.0001,
	)
	assert_eq(
		debilitate_apply.condition.remove_on_triggers,
		[Trigger.TriggerType.AFTER_ATTACKING],
	)

	var ensnare := load("res://data/heroes/asher/actions/ensnare.tres") as Action
	var ensnare_damage := ensnare.effects[0] as Effect_Damage
	var ensnare_apply := ensnare.effects[1] as Effect_ApplyCondition
	assert_eq(ensnare.focus_cost, ASHER_GDD.ensnare.cost)
	assert_almost_eq(ensnare_damage.potency, ASHER_GDD.ensnare.potency, 0.0001)
	assert_almost_eq(
		ensnare_apply.condition.speed_scalar, ASHER_GDD.ensnare.speed, 0.0001,
	)
	assert_eq(
		ensnare_apply.condition.remove_on_triggers,
		[Trigger.TriggerType.ON_GAINING_GUARD],
	)


func test_echo_psion_actions_match_gdd() -> void:
	var shatter := load("res://data/heroes/echo/actions/shatter.tres") as Action
	var shatter_damage := shatter.effects[0] as Effect_Damage
	var shatter_rule := shatter_damage.scaling_rules[0] as DamageScalingFlatPerResource
	var shatter_clear := shatter.effects[1] as Effect_ModifyGuard
	assert_almost_eq(
		shatter_rule.potency_per_point, ECHO_GDD.shatter.per_guard, 0.0001,
	)
	assert_eq(shatter_rule.resource, DamageScalingFlatPerResource.ResourceType.GUARD)
	assert_eq(shatter_damage.split_damage, ECHO_GDD.shatter.split)
	assert_eq(
		shatter_clear.guard_amount <= -ActorCard.MAX_GUARD,
		ECHO_GDD.shatter.clears_guard,
	)
	assert_eq(shatter_clear.target_type, Action.TargetType.SELF)

	var pulse := load(
		"res://data/heroes/echo/conditions/psionic_pulse_cond.tres"
	) as Condition
	var pulse_damage := pulse.triggers[0].effects_to_run[0] as Effect_Damage
	assert_almost_eq(pulse_damage.potency, ECHO_GDD.psionic_pulse.potency, 0.0001)
	assert_eq(pulse_damage.power_type, ECHO_GDD.psionic_pulse.power)
	assert_eq(pulse_damage.damage_type, Action.DamageType.ENERGY)

	var focused := load("res://data/heroes/echo/actions/focused_bolt.tres") as Action
	var focused_damage := focused.effects[0] as Effect_Damage
	var focused_rule := focused_damage.scaling_rules[0] as DamageScalingFlatPerResource
	assert_almost_eq(
		focused_rule.potency_per_point, ECHO_GDD.focused_bolt.per_focus, 0.0001,
	)

	var barrier := load("res://data/heroes/echo/actions/energy_barrier.tres") as Action
	var barrier_guard := barrier.effects[0] as Effect_ModifyGuard
	var retaliation := _first_condition_damage(load(
		"res://data/heroes/echo/conditions/energy_barrier.tres"
	) as Condition)
	assert_eq(barrier.focus_cost, ECHO_GDD.energy_barrier.cost)
	assert_eq(barrier_guard.guard_amount, ECHO_GDD.energy_barrier.guard)
	assert_almost_eq(retaliation.potency, ECHO_GDD.energy_barrier.retaliation, 0.0001)

	var reverberate := load("res://data/heroes/echo/actions/reverberate.tres") as Action
	var initial := reverberate.effects[0] as Effect_Damage
	var triggered := _first_condition_damage(load(
		"res://data/heroes/echo/conditions/reverberate.tres"
	) as Condition)
	assert_eq(reverberate.focus_cost, ECHO_GDD.reverberate.cost)
	assert_almost_eq(initial.potency, ECHO_GDD.reverberate.initial, 0.0001)
	assert_eq(initial.power_type, Action.PowerType.ATTACK)
	assert_eq(initial.damage_type, Action.DamageType.ENERGY)
	assert_almost_eq(triggered.potency, ECHO_GDD.reverberate.triggered, 0.0001)
	assert_eq(triggered.power_type, Action.PowerType.PSYCHE)
	assert_eq(triggered.damage_type, Action.DamageType.ENERGY)

	var storm := load("res://data/heroes/echo/actions/mind_storm.tres") as Action
	var storm_damage := storm.effects[0] as Effect_Damage
	var storm_rule := storm_damage.scaling_rules[0] as DamageScalingBasePerResource
	assert_eq(storm.focus_cost, ECHO_GDD.mind_storm.cost)
	assert_almost_eq(storm_damage.potency, ECHO_GDD.mind_storm.base, 0.0001)
	assert_almost_eq(
		storm_rule.base_scalar_per_point, ECHO_GDD.mind_storm.remaining_focus, 0.0001,
	)
	assert_eq(storm_rule.resource, DamageScalingBasePerResource.ResourceType.FOCUS)
	assert_string_contains(storm.description, "remaining Focus after paying the cost")


func test_echo_kineticist_actions_match_gdd() -> void:
	var role := load("res://data/heroes/echo/roles/kin.tres") as RoleDefinition
	assert_string_contains(role.description.to_lower(), "heal")
	assert_string_contains(role.description.to_lower(), "support")

	var force_field := load(
		"res://data/heroes/echo/actions/kinetic_wall.tres"
	) as Action
	assert_eq(force_field.action_name, "Force Field")
	assert_true(force_field.is_shift_action)
	assert_eq((force_field.effects[0] as Effect_ModifyGuard).guard_amount, 1)

	var acuity := load("res://data/heroes/echo/actions/telepathy.tres") as Action
	var acuity_condition := (acuity.effects[0] as Effect_ApplyCondition).condition
	var acuity_focus := acuity_condition.triggers[0].effects_to_run[0] as Effect_ModifyFocus
	assert_eq(acuity.action_name, "Acuity")
	assert_eq(acuity_condition.condition_name, "Acuity")
	assert_eq(acuity_focus.focus_amount, 2)
	assert_eq(acuity_condition.remove_on_triggers, [Trigger.TriggerType.ON_SHIFT])

	var telekinesis := load("res://data/heroes/echo/actions/telekinesis.tres") as Action
	var telekinesis_damage := telekinesis.effects[0] as Effect_Damage
	var party_focus := telekinesis.effects[1] as Effect_ModifyFocus
	assert_almost_eq(
		telekinesis_damage.potency, ECHO_GDD.telekinesis.potency, 0.0001,
	)
	assert_eq(telekinesis_damage.power_type, Action.PowerType.ATTACK)
	assert_eq(telekinesis_damage.damage_type, Action.DamageType.KINETIC)
	assert_eq(party_focus.focus_amount, ECHO_GDD.telekinesis.party_focus)
	assert_eq(party_focus.target_type, Action.TargetType.ALLIES_ONLY)

	var reconstruct := load("res://data/heroes/echo/actions/rejuvenate.tres") as Action
	var healing := reconstruct.effects[0] as Effect_Healing
	assert_eq(reconstruct.action_name, "Reconstruct")
	assert_eq(reconstruct.focus_cost, ECHO_GDD.reconstruct.cost)
	assert_almost_eq(healing.potency, ECHO_GDD.reconstruct.heal, 0.0001)
	assert_almost_eq(
		healing.focus_scalar, ECHO_GDD.reconstruct.per_target_focus, 0.0001,
	)
	assert_false(healing.is_revive)

	var pain := load("res://data/heroes/echo/actions/pain_transfer.tres") as Action
	var pain_damage := pain.effects[0] as Effect_Damage
	var pain_condition := load(
		"res://data/heroes/echo/conditions/pain_transfer.tres"
	) as Condition
	var team_heal := pain_condition.triggers[0].effects_to_run[0] as Effect_Healing
	assert_eq(pain.focus_cost, ECHO_GDD.pain_transfer.cost)
	assert_almost_eq(pain_damage.potency, ECHO_GDD.pain_transfer.damage, 0.0001)
	assert_eq(pain_damage.power_type, Action.PowerType.PSYCHE)
	assert_eq(pain_damage.damage_type, Action.DamageType.KINETIC)
	assert_almost_eq(team_heal.potency, ECHO_GDD.pain_transfer.team_heal, 0.0001)
	assert_eq(team_heal.target_type, Action.TargetType.ALL_ALLIES)
	assert_false(team_heal.is_revive)

	var energize := load("res://data/heroes/echo/actions/energize.tres") as Action
	var energize_focus := energize.effects[0] as Effect_ModifyFocus
	assert_eq(energize.focus_cost, ECHO_GDD.energize.cost)
	assert_eq(energize.ct_cost_percent, ECHO_GDD.energize.ct)
	assert_eq(energize_focus.focus_amount, ECHO_GDD.energize.focus)


func test_force_field_uses_exact_all_allies_scope_through_real_execution() -> void:
	var fixture := _sands_runtime_fixture()
	var echo := fixture.sands as SandsRuntimeHero
	var first_ally := fixture.first_ally as SandsRuntimeHero
	var second_ally := fixture.second_ally as SandsRuntimeHero
	var manager := fixture.manager as SandsRuntimeBattleManager
	echo.actor_name = "Echo"
	var force_field := load(
		"res://data/heroes/echo/actions/kinetic_wall.tres"
	) as Action
	var guard_effect := force_field.effects[0] as Effect_ModifyGuard

	assert_eq(force_field.target_type, Action.TargetType.ALL_ALLIES)
	assert_eq(guard_effect.target_type, Action.TargetType.ALL_ALLIES)
	var targets := manager.get_targets(
		force_field.target_type, true, [], echo, force_field.can_revive_targets,
	)
	assert_eq(targets, [echo, first_ally, second_ally])
	await guard_effect.execute(echo, targets, manager, force_field)

	for hero: SandsRuntimeHero in [echo, first_ally, second_ally]:
		assert_eq(hero.guard_events, [1])
	_free_sands_runtime_fixture(fixture)


func test_acuity_fires_on_echo_turn_start_and_expires_on_echo_shift() -> void:
	var fixture := _sands_runtime_fixture()
	var echo := fixture.sands as SandsRuntimeHero
	var ally := fixture.first_ally as SandsRuntimeHero
	var manager := fixture.manager as SandsRuntimeBattleManager
	echo.actor_name = "Echo"
	echo.current_focus = 3
	var acuity := load("res://data/heroes/echo/actions/telepathy.tres") as Action

	await manager.execute_action(echo, acuity, [echo], false)
	assert_true(echo.has_condition("Acuity"))
	assert_false(ally.has_condition("Acuity"))
	var applied := echo.active_conditions.filter(
		func(condition: Condition) -> bool: return condition.condition_name == "Acuity"
	)[0] as Condition
	assert_same(applied.attacker, echo)
	assert_true(applied.is_passive)
	assert_eq(applied.triggers[0].trigger_type, Trigger.TriggerType.ON_TURN_START)
	assert_eq(applied.remove_on_triggers, [Trigger.TriggerType.ON_SHIFT])
	assert_eq(echo.current_focus, 3)

	await ally.on_turn_started()
	assert_eq(echo.current_focus, 3)
	await echo.on_turn_started()
	assert_eq(echo.current_focus, 5)
	assert_true(echo.has_condition("Acuity"))
	await echo.shift_role("right")
	assert_false(echo.has_condition("Acuity"))
	_free_sands_runtime_fixture(fixture)


func test_echo_telepath_actions_match_gdd() -> void:
	var role := load("res://data/heroes/echo/roles/dom.tres") as RoleDefinition
	assert_eq(role.role_id, "dom")
	assert_eq(role.role_name, "Telepath")
	assert_eq(
		role.actions.map(func(action: Action) -> String: return action.action_name),
		["Displace", "Feedback", "Static Charge", "Inversion"],
	)
	if not assert_not_null(role.shift_action, "Telepath has a Shift action"):
		return
	if not assert_not_null(role.passive, "Telepath has a passive"):
		return
	assert_eq(role.shift_action.action_name, "Suppress")
	assert_eq(role.passive.action_name, "Precognition")

	var suppress := role.shift_action
	assert_true(suppress.is_shift_action)
	assert_eq(suppress.effects.size(), 2)
	var suppress_apply := suppress.effects[0] as Effect_ApplyCondition
	var cleanup_apply := suppress.effects[1] as Effect_ApplyCondition
	assert_eq(suppress_apply.condition.condition_name, "Suppress")
	assert_eq(suppress_apply.condition.condition_type, Condition.ConditionType.DEBUFF)
	assert_almost_eq(suppress_apply.condition.damage_dealt_scalar, -0.25, 0.0001)
	assert_eq(suppress_apply.condition.remove_on_triggers, [])
	assert_eq(cleanup_apply.target_type, Action.TargetType.SELF)
	assert_eq(cleanup_apply.condition.condition_name, "Suppress Cleanup")
	assert_true(cleanup_apply.condition.is_passive)
	assert_eq(cleanup_apply.condition.remove_on_triggers, [Trigger.TriggerType.ON_SHIFT])
	assert_eq(cleanup_apply.condition.triggers.size(), 1)
	var cleanup_trigger := cleanup_apply.condition.triggers[0]
	assert_eq(cleanup_trigger.trigger_type, Trigger.TriggerType.ON_SHIFT)
	assert_eq(cleanup_trigger.effects_to_run.size(), 1)
	var cleanup_effect := cleanup_trigger.effects_to_run[0] as Effect_RemoveCondition
	assert_eq(cleanup_effect.condition_name, "Suppress")
	assert_eq(cleanup_effect.target_type, Action.TargetType.ALL_ENEMIES)

	var precognition := role.passive
	var precognition_condition := (
		precognition.effects[0] as Effect_ApplyCondition
	).condition
	var precognition_guard := (
		precognition_condition.triggers[0].effects_to_run[0] as Effect_ModifyGuard
	)
	assert_eq(precognition_guard.guard_amount, 1)
	assert_eq(precognition_guard.target_type, Action.TargetType.ALL_ALLIES)
	assert_eq(precognition_condition.remove_on_triggers, [Trigger.TriggerType.ON_SHIFT])

	var displace := load("res://data/heroes/echo/actions/displace.tres") as Action
	assert_eq((displace.effects[0] as Effect_ModifyGuard).guard_amount, 1)
	assert_eq((displace.effects[1] as Effect_RemoveDebuffs).quantity, 1)

	var feedback := load("res://data/heroes/echo/conditions/feedback.tres") as Condition
	assert_eq(feedback.triggers[0].trigger_type, Trigger.TriggerType.ON_HIT)
	assert_eq(feedback.remove_on_triggers, [Trigger.TriggerType.AFTER_ATTACKING])
	assert_eq(feedback.triggers[0].effects_to_run.size(), 2)
	assert_eq(
		(feedback.triggers[0].effects_to_run[0] as Effect_ModifyGuard).guard_amount,
		ECHO_GDD.feedback.guard_per_hit,
	)
	var feedback_damage := feedback.triggers[0].effects_to_run[1] as Effect_Damage
	assert_almost_eq(feedback_damage.potency, ECHO_GDD.feedback.piercing, 0.0001)
	assert_eq(feedback_damage.power_type, Action.PowerType.PSYCHE)
	assert_eq(feedback_damage.damage_type, Action.DamageType.PIERCING)

	var static_action := load(
		"res://data/heroes/echo/actions/static_charge.tres"
	) as Action
	var delay := static_action.effects[0] as Effect_ModifyCT
	var static_condition := load(
		"res://data/heroes/echo/conditions/static_charge.tres"
	) as Condition
	var static_damage := _first_condition_damage(static_condition)
	assert_almost_eq(delay.ct_change_percent, ECHO_GDD.static_charge.delay, 0.0001)
	assert_almost_eq(static_condition.speed_scalar, ECHO_GDD.static_charge.speed, 0.0001)
	assert_almost_eq(static_damage.potency, ECHO_GDD.static_charge.piercing, 0.0001)
	assert_eq(static_damage.power_type, Action.PowerType.PSYCHE)
	assert_eq(static_damage.damage_type, Action.DamageType.PIERCING)
	assert_eq(static_condition.remove_on_triggers, [Trigger.TriggerType.ON_TURN_START])

	var inversion := load("res://data/heroes/echo/actions/inversion.tres") as Action
	var inversion_condition := load(
		"res://data/heroes/echo/conditions/inversion.tres"
	) as Condition
	var inversion_damage := (
		inversion_condition.triggers[0].effects_to_run[0] as Effect_Damage_Inversion
	)
	assert_eq(inversion.focus_cost, ECHO_GDD.inversion.cost)
	assert_almost_eq(
		inversion_damage.potency, ECHO_GDD.inversion.piercing_per_guard, 0.0001,
	)
	assert_eq(inversion_damage.damage_type, Action.DamageType.PIERCING)
	assert_eq(inversion_damage.max_guard_points, ECHO_GDD.inversion.cap)
	assert_false(FileAccess.get_file_as_string(
		"res://data/heroes/echo/conditions/inversion.tres"
	).contains("remove_guard_gained"))


func test_precognition_fires_for_party_on_echo_turn_start_until_echo_shifts() -> void:
	var fixture := _sands_runtime_fixture()
	var echo := fixture.sands as SandsRuntimeHero
	var first_ally := fixture.first_ally as SandsRuntimeHero
	var second_ally := fixture.second_ally as SandsRuntimeHero
	var manager := fixture.manager as SandsRuntimeBattleManager
	echo.actor_name = "Echo"
	var precognition := load(
		"res://data/heroes/echo/actions/precognition.tres"
	) as Action

	await manager.execute_action(echo, precognition, [echo], false)
	assert_true(echo.has_condition("Precognition"))
	assert_false(first_ally.has_condition("Precognition"))
	assert_false(second_ally.has_condition("Precognition"))
	var applied := echo.active_conditions.filter(
		func(condition: Condition) -> bool:
			return condition.condition_name == "Precognition"
	)[0] as Condition
	assert_same(applied.attacker, echo)
	assert_true(applied.is_passive)
	assert_eq(applied.triggers[0].trigger_type, Trigger.TriggerType.ON_TURN_START)
	assert_eq(applied.remove_on_triggers, [Trigger.TriggerType.ON_SHIFT])
	for hero: SandsRuntimeHero in [echo, first_ally, second_ally]:
		assert_eq(hero.guard_events, [])

	await first_ally.on_turn_started()
	for hero: SandsRuntimeHero in [echo, first_ally, second_ally]:
		assert_eq(hero.guard_events, [])
	await echo.on_turn_started()
	for hero: SandsRuntimeHero in [echo, first_ally, second_ally]:
		assert_eq(hero.guard_events, [1])
	assert_true(echo.has_condition("Precognition"))

	await echo.shift_role("right")
	assert_false(echo.has_condition("Precognition"))
	await echo.on_turn_started()
	for hero: SandsRuntimeHero in [echo, first_ally, second_ally]:
		assert_eq(hero.guard_events, [1])
	_free_sands_runtime_fixture(fixture)


func test_echo_player_names_reject_obsolete_identity() -> void:
	var psion := load("res://data/heroes/echo/roles/psi.tres") as RoleDefinition
	var kineticist := load("res://data/heroes/echo/roles/kin.tres") as RoleDefinition
	var telepath := load("res://data/heroes/echo/roles/dom.tres") as RoleDefinition
	var player_names: Array[String] = [psion.role_name, kineticist.role_name, telepath.role_name]
	for role: RoleDefinition in [psion, kineticist, telepath]:
		if role.shift_action != null:
			player_names.append(role.shift_action.action_name)
		if role.passive != null:
			player_names.append(role.passive.action_name)
		player_names.append_array(role.actions.map(
			func(action: Action) -> String: return action.action_name
		))
	for required_name: String in [
		"Force Field", "Acuity", "Reconstruct", "Telepath", "Suppress", "Precognition",
	]:
		assert_has(player_names, required_name)
	for obsolete_name: String in ["Kinetic Wall", "Telepathy", "Rejuvenate", "Dominator"]:
		assert_does_not_have(player_names, obsolete_name)


func test_sands_vanguard_actions_match_gdd() -> void:
	var role := load("res://data/heroes/sands/roles/van.tres") as RoleDefinition
	assert_string_contains(role.description.to_lower(), "protect")
	assert_string_contains(role.description.to_lower(), "counterattack")

	var draw_fire := load("res://data/heroes/sands/actions/draw_fire.tres") as Action
	assert_eq(draw_fire.effects.size(), 2)
	if draw_fire.effects.size() != 2:
		return
	var draw_focus := draw_fire.effects[1] as Effect_ModifyFocus
	assert_not_null(draw_focus)
	if draw_focus != null:
		assert_eq(draw_focus.focus_amount, SANDS_GDD.draw_fire.focus)
		assert_eq(draw_focus.target_type, Action.TargetType.SELF)

	var crossfire := load("res://data/heroes/sands/actions/focus_fire.tres") as Action
	var crossfire_damage := crossfire.effects[0] as Effect_Damage
	assert_eq(crossfire.action_name, "Crossfire")
	assert_eq(crossfire.focus_cost, SANDS_GDD.crossfire.cost)
	assert_almost_eq(crossfire_damage.potency, SANDS_GDD.crossfire.potency, 0.0001)
	assert_eq(crossfire_damage.power_type, Action.PowerType.ATTACK)
	assert_eq(crossfire_damage.damage_type, Action.DamageType.KINETIC)
	assert_eq(crossfire_damage.split_damage, SANDS_GDD.crossfire.split)
	assert_eq(crossfire_damage.on_hit_triggers.size(), 1)
	var crossfire_trigger := crossfire_damage.on_hit_triggers[0]
	assert_eq(crossfire_trigger.condition, HitTrigger.HitCondition.IF_TARGET_IS_BREACHED)
	var crossfire_focus := crossfire_trigger.effects_to_run[0] as Effect_ModifyFocus
	assert_eq(crossfire_focus.focus_amount, SANDS_GDD.crossfire.focus_per_breached)
	assert_eq(crossfire_focus.target_type, Action.TargetType.SELF)

	var phalanx := load("res://data/heroes/sands/actions/phalanx.tres") as Action
	var phalanx_damage := phalanx.effects[0] as Effect_Damage
	assert_eq(phalanx.focus_cost, SANDS_GDD.phalanx.cost)
	assert_almost_eq(phalanx_damage.potency, SANDS_GDD.phalanx.potency, 0.0001)
	assert_eq(phalanx_damage.hit_count, SANDS_GDD.phalanx.hits)
	assert_eq(phalanx_damage.power_type, Action.PowerType.ATTACK)
	assert_eq(phalanx_damage.damage_type, Action.DamageType.KINETIC)
	assert_eq(phalanx_damage.on_hit_triggers.size(), 1)
	var phalanx_trigger := phalanx_damage.on_hit_triggers[0]
	assert_eq(phalanx_trigger.condition, HitTrigger.HitCondition.IF_TARGET_IS_BREACHED)
	var phalanx_guard := phalanx_trigger.effects_to_run[0] as Effect_ModifyGuard
	assert_eq(phalanx_guard.guard_amount, SANDS_GDD.phalanx.guard_per_breached)
	assert_eq(phalanx_guard.target_type, Action.TargetType.LEAST_GUARD_ALLY)


func test_phalanx_retargets_the_current_least_guard_teammate_per_breached_hit() -> void:
	var fixture := _sands_runtime_fixture()
	var sands := fixture.sands as SandsRuntimeHero
	var first_ally := fixture.first_ally as SandsRuntimeHero
	var second_ally := fixture.second_ally as SandsRuntimeHero
	var enemy := fixture.enemy as SandsRuntimeEnemy
	sands.current_guard = 5
	first_ally.current_guard = 0
	second_ally.current_guard = 0
	enemy.is_breached = true
	var phalanx := load("res://data/heroes/sands/actions/phalanx.tres") as Action
	var damage := phalanx.effects[0] as Effect_Damage

	await damage._process_on_hit_triggers(sands, enemy, fixture.manager, {})
	await damage._process_on_hit_triggers(sands, enemy, fixture.manager, {})

	assert_eq(first_ally.guard_events, [1])
	assert_eq(second_ally.guard_events, [1])
	_free_sands_runtime_fixture(fixture)


func test_sands_medic_actions_match_gdd() -> void:
	var role := load("res://data/heroes/sands/roles/med.tres") as RoleDefinition
	assert_string_contains(role.description.to_lower(), "heal")
	assert_string_contains(role.description.to_lower(), "guard")

	var triage := load("res://data/heroes/sands/actions/triage.tres") as Action
	var triage_heal := triage.effects[0] as Effect_Healing
	assert_almost_eq(triage_heal.potency, SANDS_GDD.triage.heal, 0.0001)
	assert_eq(triage_heal.scales_with_missing_hp, SANDS_GDD.triage.missing_hp)
	assert_eq(triage_heal.target_type, Action.TargetType.ALL_ALLIES)
	assert_false(triage_heal.is_revive)

	var painkillers := load("res://data/heroes/sands/conditions/painkillers.tres") as Condition
	assert_almost_eq(
		painkillers.damage_taken_scalar, SANDS_GDD.painkillers.reduction, 0.0001,
	)
	assert_string_contains(painkillers.description, "10%")

	var first_aid := load("res://data/heroes/sands/actions/first_aid.tres") as Action
	var first_aid_heal := first_aid.effects[0] as Effect_Healing
	assert_almost_eq(first_aid_heal.potency, SANDS_GDD.first_aid.heal, 0.0001)
	assert_eq(first_aid_heal.scales_with_missing_hp, SANDS_GDD.first_aid.missing_hp)
	assert_false(first_aid_heal.is_revive)
	assert_false("missing" in first_aid.description.to_lower())

	var covering_fire := load(
		"res://data/heroes/sands/actions/booster_shots.tres"
	) as Action
	var covering_damage := covering_fire.effects[0] as Effect_Damage
	assert_eq(covering_fire.action_name, "Covering Fire")
	assert_eq(covering_fire.focus_cost, SANDS_GDD.covering_fire.cost)
	assert_almost_eq(
		covering_damage.potency, SANDS_GDD.covering_fire.potency, 0.0001,
	)
	assert_eq(covering_damage.hit_count, SANDS_GDD.covering_fire.hits)
	assert_eq(covering_damage.power_type, Action.PowerType.ATTACK)
	assert_eq(covering_damage.damage_type, Action.DamageType.KINETIC)
	var covering_passive := (
		covering_fire.effects[1] as Effect_ApplyCondition
	).condition
	assert_eq(covering_passive.remove_on_triggers, [Trigger.TriggerType.ON_SHIFT])
	assert_eq(covering_passive.triggers[0].trigger_type, Trigger.TriggerType.ON_SHIFT)
	var covering_remove := (
		covering_passive.triggers[0].effects_to_run[0] as Effect_RemoveCondition
	)
	var covering_boost := (covering_fire.effects[2] as Effect_ApplyCondition).condition
	assert_eq(covering_remove.condition_name, covering_boost.condition_name)
	assert_almost_eq(
		covering_boost.damage_taken_scalar, SANDS_GDD.painkillers.reduction, 0.0001,
	)

	var auto_shield := load("res://data/heroes/sands/actions/auto_shields.tres") as Action
	assert_eq(auto_shield.action_name, "Auto-Shield")
	assert_eq(auto_shield.focus_cost, SANDS_GDD.auto_shield.cost)
	assert_eq(auto_shield.target_type, Action.TargetType.ALLY_ONLY)
	assert_eq(auto_shield.effects.size(), 3)
	if auto_shield.effects.size() != 3:
		return
	var immediate_guard := auto_shield.effects[0] as Effect_ModifyGuard
	var immediate_heal := auto_shield.effects[1] as Effect_Healing
	var auto_condition := (auto_shield.effects[2] as Effect_ApplyCondition).condition
	assert_eq(immediate_guard.guard_amount, SANDS_GDD.auto_shield.guard)
	assert_eq(immediate_guard.target_type, Action.TargetType.PARENT)
	assert_almost_eq(immediate_heal.potency, SANDS_GDD.auto_shield.heal, 0.0001)
	assert_eq(immediate_heal.target_type, Action.TargetType.PARENT)
	assert_false(immediate_heal.is_revive)
	assert_eq(auto_condition.condition_name, "Auto-Shield")
	assert_eq(auto_condition.remove_on_triggers, [Trigger.TriggerType.ON_SHIFT])
	assert_eq(auto_condition.triggers.size(), 1)
	assert_eq(auto_condition.triggers[0].trigger_type, Trigger.TriggerType.ON_TURN_START)
	var recurring_guard := auto_condition.triggers[0].effects_to_run[0] as Effect_ModifyGuard
	var recurring_heal := auto_condition.triggers[0].effects_to_run[1] as Effect_Healing
	assert_eq(recurring_guard.guard_amount, SANDS_GDD.auto_shield.guard)
	assert_eq(recurring_guard.target_type, Action.TargetType.SELF)
	assert_almost_eq(recurring_heal.potency, SANDS_GDD.auto_shield.heal, 0.0001)
	assert_eq(recurring_heal.target_type, Action.TargetType.SELF)
	assert_false(recurring_heal.is_revive)

	var bastion := load("res://data/heroes/sands/actions/bastion.tres") as Action
	assert_eq(bastion.focus_cost, 4)
	assert_eq((bastion.effects[0] as Effect_ModifyGuard).guard_amount, 3)
	assert_eq(bastion.effects[0].target_type, Action.TargetType.ALL_ALLIES)


func test_covering_fire_runs_full_action_scope_stack_and_sands_shift_lifecycle() -> void:
	var fixture := _sands_runtime_fixture()
	var sands := fixture.sands as SandsRuntimeHero
	var first_ally := fixture.first_ally as SandsRuntimeHero
	var second_ally := fixture.second_ally as SandsRuntimeHero
	var enemy := fixture.enemy as SandsRuntimeEnemy
	var manager := fixture.manager as SandsRuntimeBattleManager
	var party: Array[SandsRuntimeHero] = [sands, first_ally, second_ally]
	var painkillers := load(
		"res://data/heroes/sands/actions/apply_painkillers.tres"
	) as Action
	var action := load("res://data/heroes/sands/actions/booster_shots.tres") as Action

	await manager.execute_action(sands, painkillers, [sands], false)
	for hero: SandsRuntimeHero in party:
		assert_eq(_condition_count(hero, "Painkillers"), 1)
		assert_almost_eq(hero.get_damage_taken_modifier(enemy), -0.1, 0.0001)

	var selected_targets := manager.get_targets(
		action.target_type, true, [], sands, action.can_revive_targets,
	)
	assert_eq(selected_targets, [enemy])
	await manager.execute_action(sands, action, selected_targets, false)

	assert_eq(enemy.damage_results.size(), 2)
	for result: DamageResult in enemy.damage_results:
		assert_almost_eq(result.request.base_potency, 0.5, 0.0001)
		assert_almost_eq(result.raw_damage, 50.0, 0.0001)
	for hero: SandsRuntimeHero in party:
		assert_eq(_condition_count(hero, "Painkillers"), 1)
		assert_eq(_condition_count(hero, "Covering Fire"), 1)
		assert_almost_eq(hero.get_damage_taken_modifier(enemy), -0.2, 0.0001)
		var boost := hero.active_conditions.filter(
			func(condition: Condition) -> bool:
				return condition.condition_name == "Covering Fire"
		)[0] as Condition
		assert_same(boost.attacker, sands)
	assert_eq(_condition_count(sands, "Covering Fire Passive"), 1)
	assert_eq(_condition_count(first_ally, "Covering Fire Passive"), 0)
	assert_eq(_condition_count(second_ally, "Covering Fire Passive"), 0)

	await manager.execute_action(sands, action, selected_targets, false)
	assert_eq(enemy.damage_results.size(), 4)
	for hero: SandsRuntimeHero in party:
		assert_eq(_condition_count(hero, "Covering Fire"), 1)
		assert_almost_eq(hero.get_damage_taken_modifier(enemy), -0.2, 0.0001)
	assert_eq(_condition_count(sands, "Covering Fire Passive"), 1)

	await first_ally.shift_role("right")
	for hero: SandsRuntimeHero in party:
		assert_true(hero.has_condition("Painkillers"))
		assert_true(hero.has_condition("Covering Fire"))
	assert_true(sands.has_condition("Painkillers Passive"))
	assert_true(sands.has_condition("Covering Fire Passive"))

	await sands.shift_role("right")
	for hero: SandsRuntimeHero in party:
		assert_false(hero.has_condition("Painkillers"))
		assert_false(hero.has_condition("Covering Fire"))
	assert_false(sands.has_condition("Painkillers Passive"))
	assert_false(sands.has_condition("Covering Fire Passive"))
	_free_sands_runtime_fixture(fixture)


func test_auto_shield_uses_manager_eligibility_and_public_turn_start_lifecycle() -> void:
	var fixture := _sands_runtime_fixture()
	var sands := fixture.sands as SandsRuntimeHero
	var target := fixture.first_ally as SandsRuntimeHero
	var defeated := fixture.second_ally as SandsRuntimeHero
	var manager := fixture.manager as SandsRuntimeBattleManager
	target.current_stats.max_hp = 200
	target.current_hp = 20
	target.current_guard = 4
	defeated.current_hp = 0
	defeated.current_guard = 0
	defeated.is_defeated = true
	var action := load("res://data/heroes/sands/actions/auto_shields.tres") as Action
	var eligible_targets := manager.get_targets(
		action.target_type, true, [], sands, action.can_revive_targets,
	)

	assert_eq(eligible_targets, [target])
	assert_false(eligible_targets.has(sands))
	assert_false(eligible_targets.has(defeated))
	await manager.execute_action(sands, action, eligible_targets, false)

	assert_eq(target.guard_events, [1])
	assert_eq(target.healing_events, [50])
	assert_eq(target.current_hp, 70)
	assert_true(target.has_condition("Auto-Shield"))
	assert_eq(defeated.guard_events, [])
	assert_eq(defeated.healing_events, [])
	assert_false(defeated.has_condition("Auto-Shield"))
	var matching_conditions := target.active_conditions.filter(
		func(condition: Condition) -> bool: return condition.condition_name == "Auto-Shield"
	)
	if matching_conditions.is_empty():
		_free_sands_runtime_fixture(fixture)
		return
	var applied := matching_conditions[0] as Condition
	assert_same(applied.attacker, sands)

	await target.on_turn_started()
	assert_eq(target.guard_events, [1, 1])
	assert_eq(target.healing_events, [50, 50])
	assert_eq(target.current_hp, 120)

	target.is_defeated = true
	target.current_hp = 0
	await target.on_turn_started()
	assert_true(target.is_defeated)
	assert_eq(target.current_hp, 0)
	assert_eq(target.guard_events, [1, 1])
	assert_eq(target.healing_events, [50, 50])

	await target.shift_role("right")
	assert_false(target.has_condition("Auto-Shield"))
	_free_sands_runtime_fixture(fixture)


func test_sands_strategist_actions_match_gdd() -> void:
	var role := load("res://data/heroes/sands/roles/stg.tres") as RoleDefinition
	assert_string_contains(role.description.to_lower(), "turn")
	assert_string_contains(role.description.to_lower(), "attack")

	var advantage := load("res://data/heroes/sands/actions/advantage.tres") as Action
	var advantage_ct := advantage.effects[0] as Effect_ModifyCT
	var advantage_apply := advantage.effects[1] as Effect_ApplyCondition
	var advantage_condition := advantage_apply.condition
	assert_eq(advantage.focus_cost, SANDS_GDD.advantage.cost)
	assert_almost_eq(advantage_ct.ct_change_percent, SANDS_GDD.advantage.ct_boost, 0.0001)
	assert_true(advantage_condition is ConditionSourcePowerBonus)
	if advantage_condition is ConditionSourcePowerBonus:
		var source_bonus := advantage_condition as ConditionSourcePowerBonus
		assert_eq(source_bonus.power_type, Action.PowerType.PSYCHE)
		assert_almost_eq(source_bonus.power_scalar, SANDS_GDD.advantage.source_psy, 0.0001)
	assert_almost_eq(advantage_condition.damage_dealt_scalar, 0.0, 0.0001)
	assert_eq(
		advantage_condition.remove_on_triggers,
		[Trigger.TriggerType.AFTER_ATTACKING],
	)

	var checkmate := load("res://data/heroes/sands/actions/checkmate.tres") as Action
	var checkmate_damage := checkmate.effects[0] as Effect_Damage
	var checkmate_ct := checkmate.effects[1] as Effect_ModifyCT
	assert_almost_eq(checkmate_damage.potency, SANDS_GDD.checkmate.potency, 0.0001)
	assert_eq(checkmate_damage.power_type, Action.PowerType.PSYCHE)
	assert_eq(checkmate_damage.damage_type, Action.DamageType.ENERGY)
	assert_almost_eq(checkmate_ct.ct_change_percent, SANDS_GDD.checkmate.ct_change, 0.0001)


func test_advantage_executes_direct_ct_and_source_power_through_next_attack() -> void:
	var fixture := _sands_runtime_fixture()
	var sands := fixture.sands as SandsRuntimeHero
	var ally := fixture.first_ally as SandsRuntimeHero
	var enemy := fixture.enemy as SandsRuntimeEnemy
	var manager := fixture.manager as SandsRuntimeBattleManager
	sands.current_stats.psyche = 50
	sands.current_ct = 100
	ally.current_stats.attack = 100
	ally.current_ct = 250
	enemy.current_hp = 2000
	enemy.current_guard = 10
	var advantage := load("res://data/heroes/sands/actions/advantage.tres") as Action
	var ally_targets := manager.get_targets(
		advantage.target_type, true, [], sands, advantage.can_revive_targets,
	)
	assert_has(ally_targets, ally)

	await manager.execute_action(sands, advantage, [ally], false)

	assert_eq(ally.current_ct, 2250)
	assert_eq(sands.current_ct, 100)
	assert_eq(advantage.ct_cost_percent, 100)
	assert_eq(manager.turn_order_refreshes, 1)
	assert_true(ally.has_condition("Advantage"))
	var applied := ally.active_conditions.filter(
		func(condition: Condition) -> bool: return condition.condition_name == "Advantage"
	)[0] as Condition
	assert_same(applied.attacker, sands)

	manager.current_actor = ally
	var double_tap := load("res://data/heroes/asher/actions/double_tap.tres") as Action
	await manager.execute_action(ally, double_tap, [enemy], false)

	assert_eq(enemy.damage_results.size(), 2)
	for result: DamageResult in enemy.damage_results:
		assert_almost_eq(result.request.power_bonus, 50.0, 0.0001)
		assert_almost_eq(result.request.outgoing_modifier, 0.0, 0.0001)
		assert_almost_eq(result.effective_power, 150.0, 0.0001)
		assert_almost_eq(result.raw_damage, 75.0, 0.0001)
	assert_false(ally.has_condition("Advantage"))

	await manager.execute_action(ally, double_tap, [enemy], false)
	assert_eq(enemy.damage_results.size(), 4)
	for index in range(2, 4):
		var result := enemy.damage_results[index]
		assert_almost_eq(result.request.power_bonus, 0.0, 0.0001)
		assert_almost_eq(result.effective_power, 100.0, 0.0001)
		assert_almost_eq(result.raw_damage, 50.0, 0.0001)
	_free_sands_runtime_fixture(fixture)


func test_fianchetto_grants_ten_percent_speed_and_cleans_party_on_sands_shift() -> void:
	var fixture := _sands_runtime_fixture()
	var sands := fixture.sands as SandsRuntimeHero
	var first_ally := fixture.first_ally as SandsRuntimeHero
	var second_ally := fixture.second_ally as SandsRuntimeHero
	var action := load("res://data/heroes/sands/actions/fianchetto.tres") as Action
	var source_text := FileAccess.get_file_as_string(action.resource_path)
	source_text += FileAccess.get_file_as_string(
		"res://data/heroes/sands/conditions/fianchetto.tres"
	)
	assert_false("Tactician" in source_text)

	await action.effects[0].execute(sands, [sands], fixture.manager, action)

	for hero: SandsRuntimeHero in [sands, first_ally, second_ally]:
		assert_true(hero.has_condition("Fianchetto"))
		assert_eq(hero.get_speed(), 110)
	await sands._fire_condition_event(Trigger.TriggerType.ON_SHIFT)
	for hero: SandsRuntimeHero in [sands, first_ally, second_ally]:
		assert_false(hero.has_condition("Fianchetto"))
		assert_eq(hero.get_speed(), 100)
	_free_sands_runtime_fixture(fixture)


func test_shatter_splits_its_guard_scaled_damage() -> void:
	var action := load("res://data/heroes/echo/actions/shatter.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	assert_true(effect.split_damage)
	assert_string_contains(action.description, "{effect:1}")
	assert_string_contains(action.description, "current Guard")


func test_telekinesis_deals_kinetic_damage() -> void:
	var action := load("res://data/heroes/echo/actions/telekinesis.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	assert_eq(effect.damage_type, Action.DamageType.KINETIC)
	assert_string_contains(action.description, "{effect:1}")


func test_reverberate_uses_attack_directly_and_psyche_when_triggered() -> void:
	var action := load("res://data/heroes/echo/actions/reverberate.tres") as Action
	var direct := action.effects[0] as Effect_Damage
	var nested := _first_condition_damage(load(
		"res://data/heroes/echo/conditions/reverberate.tres"
	) as Condition)
	assert_eq(direct.power_type, Action.PowerType.ATTACK)
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


func test_psionic_pulse_shreds_guard_but_static_charge_is_piercing() -> void:
	var pulse_path := "res://data/heroes/echo/conditions/psionic_pulse_cond.tres"
	var pulse := _first_condition_damage(load(pulse_path) as Condition)
	assert_eq(pulse.damage_type, Action.DamageType.ENERGY, pulse_path)
	assert_true(pulse._resolved_type_shreds_guard(pulse.damage_type), pulse_path)

	var static_path := "res://data/heroes/echo/conditions/static_charge.tres"
	var static_damage := _first_condition_damage(load(static_path) as Condition)
	assert_eq(static_damage.damage_type, Action.DamageType.PIERCING, static_path)
	assert_false(
		static_damage._resolved_type_shreds_guard(static_damage.damage_type), static_path,
	)
	for effect: Effect_Damage in [pulse, static_damage]:
		assert_false(effect.get_property_list().any(func(property):
			return property.name == "shreds_guard"
		), "damage resources have no obsolete Guard override")


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


func test_all_production_enemies_have_valid_nonempty_cooldown_kits() -> void:
	var paths: Array[String] = []
	_collect_resource_paths("res://data/enemies/actors", paths)
	paths.sort()
	assert_gt(paths.size(), 0, "production enemy scan found actors")
	for path: String in paths:
		var resource := ResourceLoader.load(path)
		assert_true(resource is EnemyData, "%s is EnemyData" % path)
		if not resource is EnemyData:
			continue
		var enemy := resource as EnemyData
		assert_false(enemy.abilities.is_empty(), "%s has a nonempty cooldown kit" % path)
		assert_eq(
			EnemyKitValidator.validate(enemy, path),
			PackedStringArray(),
			"%s has a valid cooldown kit" % path,
		)


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


func _sands_runtime_fixture() -> Dictionary:
	var manager := SandsRuntimeBattleManager.new()
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.current_action_panel = PanelContainer.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	manager.add_child(manager.current_action_panel)
	var sands := _sands_runtime_hero("Sands")
	var first_ally := _sands_runtime_hero("Asher")
	var second_ally := _sands_runtime_hero("Echo")
	var enemy := SandsRuntimeEnemy.new()
	enemy.actor_name = "Target"
	enemy.current_stats = ActorStats.new()
	enemy.current_stats.max_hp = 2000
	enemy.current_hp = 2000
	enemy.current_guard = 10
	for hero: SandsRuntimeHero in [sands, first_ally, second_ally]:
		hero.battle_manager = manager
		manager.hero_area.add_child(hero)
	enemy.battle_manager = manager
	manager.enemy_area.add_child(enemy)
	manager.current_actor = sands
	manager.actor_list = [sands, first_ally, second_ally, enemy]
	return {
		"manager": manager,
		"sands": sands,
		"first_ally": first_ally,
		"second_ally": second_ally,
		"enemy": enemy,
	}


func _sands_runtime_hero(actor_name: String) -> SandsRuntimeHero:
	var hero := SandsRuntimeHero.new()
	hero.actor_name = actor_name
	hero.current_stats = ActorStats.new()
	hero.current_stats.attack = 100
	hero.current_stats.psyche = 100
	hero.current_stats.speed = 100
	hero.current_stats.max_hp = 100
	hero.current_hp = 100
	hero.current_focus = 10
	hero.hero_data = HeroData.new()
	hero.hero_data.unlocked_role_ids = ["first", "second"]
	return hero


func _free_sands_runtime_fixture(fixture: Dictionary) -> void:
	(fixture.manager as BattleManager).free()


func _condition_count(actor: ActorCard, condition_name: String) -> int:
	return actor.active_conditions.filter(
		func(condition: Condition) -> bool:
			return condition.condition_name == condition_name
	).size()


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
	if expected.has("effects"):
		var expected_effects := expected.effects as Array
		if trigger.effects_to_run.size() != expected_effects.size():
			errors.append("%s triggered effect count drifted" % condition_path)
		else:
			for effect_index in expected_effects.size():
				_append_effect_spec_errors(
					errors,
					trigger.effects_to_run[effect_index] as ActionEffect,
					expected_effects[effect_index],
					"%s effect %d" % [condition_path, effect_index + 1],
				)
	else:
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
			if expected.get("requires_inversion", false) \
				and not damage is Effect_Damage_Inversion:
				errors.append("%s lost its specialized Inversion shape" % label)
			if expected.has("max_guard_points"):
				if not damage is Effect_Damage_Inversion \
				or (damage as Effect_Damage_Inversion).max_guard_points \
				!= int(expected.max_guard_points):
					errors.append("%s Inversion cap drifted" % label)
			_append_on_hit_spec_errors(errors, damage, expected.get("on_hit", null), label)
		"guard":
			if not effect is Effect_ModifyGuard:
				errors.append("%s is not Guard modification" % label)
				return
			if (effect as Effect_ModifyGuard).guard_amount != int(expected.guard_amount):
				errors.append("%s Guard amount drifted" % label)
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
