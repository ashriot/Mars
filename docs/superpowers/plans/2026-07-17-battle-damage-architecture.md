# Battle Damage Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the duplicated battle-damage formulas with one extensible resolver/calculator pipeline, migrate runtime and presentation to it, correct audited content, and protect the complete behavior with deterministic tests.

**Architecture:** `Effect_Damage` remains the asynchronous template-method executor. Read-only damage contexts and composable scaling-rule resources resolve battlefield-dependent inputs, while a side-effect-free `DamageCalculator` owns the universal arithmetic and returns a typed breakdown consumed by execution and presentation. Narrow subclass hooks remain available for custom hit planning; ordinary numeric scaling uses composition.

**Tech Stack:** Godot 4.6.3, typed GDScript, Godot resources (`.tres`), GUT 9.6.1, headless Godot verification with an isolated `HOME`.

## Global Constraints

- Follow the approved design in `docs/superpowers/specs/2026-07-17-battle-damage-architecture-design.md`.
- Use Godot 4.6.3; do not change Godot, GUT, or other dependency versions.
- Preserve unrelated dirty-worktree changes and commit only files named by the active task.
- Preserve and commit `.uid` and `.import` sidecars generated for task files; never commit `.godot/`.
- Pay Focus before resolving remaining-Focus scaling.
- Kinetic and Energy always shred Guard; intrinsic and converted Piercing never shred Guard or cause Breach.
- The hit that causes Breach receives OVR, and OVR applies universally to ATK- and PSY-powered damage from every source.
- PRE is flat critical power; AIM is clamped to 0 through 100 at the roll boundary.
- KIN/NRG Defense is literal percentage reduction clamped to 0 through 90; Piercing ignores Defense.
- Add modifiers within outgoing/incoming categories, multiply the categories, floor once, and give positive damage a minimum of one.
- Split potency is a fixed budget with a divisor locked from the initial hit plan.
- Do not add a speculative Guard-policy Boolean or enum. If a concrete future exception appears, add an explicit typed policy in a separately reviewed change.
- Automated Godot commands must use `HOME=/tmp/mars-godot-home`.

## File Structure

Create the focused calculation domain under `src/battle/damage/`:

- `damage_contribution.gd` — immutable labeled contextual contribution.
- `damage_request.gd` — immutable resolved calculator input.
- `damage_result.gd` — immutable arithmetic breakdown.
- `damage_calculator.gd` — universal side-effect-free arithmetic.
- `combatant_snapshot.gd` — read-only combatant facts captured from an `ActorCard`.
- `damage_context.gd` — read-only effect/hit battlefield snapshot.
- `damage_scaling_rule.gd` — base resource for composable scaling.
- `damage_scaling_flat_per_resource.gd` — flat potency per remaining Focus/current Guard.
- `damage_scaling_base_per_resource.gd` — base-potency percentage per resource point.
- `damage_resolver.gd` — resolves scaling rules and constructs calculator requests.
- `damage_hit_plan.gd` — fixed target/hit/distribution plan.
- `damage_preview.gd` — shared description and intent presentation.
- `effect_presentation.gd` — immutable generic effect-owned clause and bindings.
- `effect_presentation_context.gd` — read-only presentation inputs for automatic and target-aware descriptions.

Keep battle orchestration in `src/scripts/action_effects/effect_damage.gd`, HP/event application in `src/battle/actor_card.gd`, action prose binding in `src/scripts/data/action.gd`, and intent presentation in `src/battle/enemy_card.gd`.

Add focused tests:

- `test/unit/test_damage_calculator.gd`
- `test/unit/test_damage_scaling_rules.gd`
- `test/unit/test_damage_hit_plan.gd`
- `test/unit/test_damage_effect_execution.gd`
- `test/unit/test_damage_preview.gd`
- `test/integration/test_damage_content.gd`

---

### Task 1: Pure Damage Request, Result, and Calculator

**Files:**
- Create: `src/battle/damage/damage_contribution.gd`
- Create: `src/battle/damage/damage_request.gd`
- Create: `src/battle/damage/damage_result.gd`
- Create: `src/battle/damage/damage_calculator.gd`
- Test: `test/unit/test_damage_calculator.gd`
- Generate: matching `.gd.uid` sidecars for every new source script

**Interfaces:**
- Consumes: `Action.DamageType` from `src/scripts/data/action.gd`.
- Produces: `DamageRequest.new(...)`, `DamageCalculator.calculate(request) -> DamageResult`, and getter-only `DamageResult` breakdown properties used by every later task.

- [ ] **Step 1: Write the failing calculator matrix**

Create `test/unit/test_damage_calculator.gd` with table-driven cases for the approved order of operations:

```gdscript
extends GutTest


func test_plain_defended_and_critical_power() -> void:
	var normal := DamageCalculator.calculate(_request(200, 0, 0, 0.5, 1, Action.DamageType.KINETIC, 50))
	var critical := DamageCalculator.calculate(_request(200, 0, 400, 0.5, 1, Action.DamageType.KINETIC, 50))
	assert_eq(normal.final_damage, 50)
	assert_eq(critical.final_damage, 150)
	assert_eq(critical.effective_power, 600)


func test_ovr_is_universal_for_attack_psyche_and_piercing() -> void:
	for damage_type in [Action.DamageType.KINETIC, Action.DamageType.ENERGY, Action.DamageType.PIERCING]:
		var result := DamageCalculator.calculate(_request(100, 75, 0, 1.0, 1, damage_type, 0))
		assert_eq(result.effective_power, 175)
		assert_eq(result.final_damage, 175)


func test_defense_clamps_and_piercing_bypasses() -> void:
	assert_eq(DamageCalculator.calculate(_request(100, 0, 0, 1.0, 1, Action.DamageType.KINETIC, -20)).final_damage, 100)
	assert_eq(DamageCalculator.calculate(_request(100, 0, 0, 1.0, 1, Action.DamageType.KINETIC, 90)).final_damage, 10)
	assert_eq(DamageCalculator.calculate(_request(100, 0, 0, 1.0, 1, Action.DamageType.KINETIC, 180)).final_damage, 10)
	assert_eq(DamageCalculator.calculate(_request(100, 0, 0, 1.0, 1, Action.DamageType.PIERCING, 90)).final_damage, 100)


func test_modifiers_split_floor_and_positive_minimum() -> void:
	var stacked := DamageCalculator.calculate(_request(100, 0, 0, 1.0, 1, Action.DamageType.PIERCING, 0, 0.5, 0.2))
	var split := DamageCalculator.calculate(_request(100, 0, 0, 1.0, 3, Action.DamageType.PIERCING, 0))
	var minimum := DamageCalculator.calculate(_request(1, 0, 0, 0.2, 1, Action.DamageType.KINETIC, 90))
	var zero := DamageCalculator.calculate(_request(100, 0, 0, 0.0, 1, Action.DamageType.PIERCING, 0))
	assert_eq(stacked.final_damage, 180)
	assert_eq(split.final_damage, 33)
	assert_eq(minimum.final_damage, 1)
	assert_eq(zero.final_damage, 0)


func _request(
	base_power: int,
	overload_power: int,
	precision_power: int,
	potency: float,
	distribution_count: int,
	damage_type: Action.DamageType,
	defense: int,
	outgoing_modifier: float = 0.0,
	incoming_modifier: float = 0.0,
) -> DamageRequest:
	return DamageRequest.new(
		base_power, overload_power, precision_power, potency,
		distribution_count, damage_type, defense,
		outgoing_modifier, incoming_modifier, [],
	)
```

- [ ] **Step 2: Run the focused test and verify the missing types fail**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect damage_calculator -gexit
```

Expected: parser failures naming missing `DamageRequest` or `DamageCalculator`; no unrelated script parser failure.

- [ ] **Step 3: Implement getter-only request/result values and universal arithmetic**

Use the repository's existing getter-only `RefCounted` pattern. `DamageRequest` must expose:

```gdscript
class_name DamageRequest
extends RefCounted

var _base_power: int
var _overload_power: int
var _precision_power: int
var _potency: float
var _distribution_count: int
var _damage_type: Action.DamageType
var _defense: int
var _outgoing_modifier: float
var _incoming_modifier: float
var _contributions: Array[DamageContribution]

var base_power: int: get: return _base_power
var overload_power: int: get: return _overload_power
var precision_power: int: get: return _precision_power
var potency: float: get: return _potency
var distribution_count: int: get: return _distribution_count
var damage_type: Action.DamageType: get: return _damage_type
var defense: int: get: return _defense
var outgoing_modifier: float: get: return _outgoing_modifier
var incoming_modifier: float: get: return _incoming_modifier
var contributions: Array[DamageContribution]: get: return _contributions.duplicate()


func _init(
	request_base_power: int,
	request_overload_power: int,
	request_precision_power: int,
	request_potency: float,
	request_distribution_count: int,
	request_damage_type: Action.DamageType,
	request_defense: int,
	request_outgoing_modifier: float = 0.0,
	request_incoming_modifier: float = 0.0,
	request_contributions: Array[DamageContribution] = [],
) -> void:
	_base_power = request_base_power
	_overload_power = request_overload_power
	_precision_power = request_precision_power
	_potency = request_potency
	_distribution_count = request_distribution_count
	_damage_type = request_damage_type
	_defense = request_defense
	_outgoing_modifier = request_outgoing_modifier
	_incoming_modifier = request_incoming_modifier
	_contributions = request_contributions.duplicate()
```

`DamageCalculator.calculate()` must contain the only universal formula:

```gdscript
class_name DamageCalculator
extends RefCounted


static func calculate(request: DamageRequest) -> DamageResult:
	var effective_power := maxi(0, request.base_power + request.overload_power + request.precision_power)
	var clamped_defense := 0
	if request.damage_type in [Action.DamageType.KINETIC, Action.DamageType.ENERGY]:
		clamped_defense = clampi(request.defense, 0, 90)
	var defense_multiplier := 1.0 - float(clamped_defense) / 100.0
	var outgoing_multiplier := maxf(0.0, 1.0 + request.outgoing_modifier)
	var incoming_multiplier := maxf(0.0, 1.0 + request.incoming_modifier)
	var divisor := maxi(1, request.distribution_count)
	var raw_damage := (
		float(effective_power) * maxf(0.0, request.potency) / float(divisor)
		* defense_multiplier * outgoing_multiplier * incoming_multiplier
	)
	var final_damage := 0 if raw_damage <= 0.0 else maxi(1, floori(raw_damage))
	return DamageResult.new(
		request, effective_power, clamped_defense, defense_multiplier,
		outgoing_multiplier, incoming_multiplier, raw_damage, final_damage,
	)
```

`DamageResult` must retain the request and expose every intermediate value shown in the approved spec. `DamageContribution` must expose getter-only `source: StringName`, `stage`, and `amount: float` fields; define typed stages `POTENCY`, `POWER`, `OUTGOING`, and `INCOMING` for later breakdowns.

- [ ] **Step 4: Import scripts and run the focused test green**

Run the documented editor import, then the focused command from Step 2.

Expected: `test_damage_calculator.gd` passes every test; generated `.gd.uid` sidecars exist beside the four new source scripts.

- [ ] **Step 5: Commit the pure calculator seam**

```bash
git add src/battle/damage/damage_contribution.gd src/battle/damage/damage_contribution.gd.uid src/battle/damage/damage_request.gd src/battle/damage/damage_request.gd.uid src/battle/damage/damage_result.gd src/battle/damage/damage_result.gd.uid src/battle/damage/damage_calculator.gd src/battle/damage/damage_calculator.gd.uid test/unit/test_damage_calculator.gd test/unit/test_damage_calculator.gd.uid
git commit -m "feat: add deterministic damage calculator"
```

### Task 2: Read-Only Context and Composable Scaling Rules

**Files:**
- Create: `src/battle/damage/combatant_snapshot.gd`
- Create: `src/battle/damage/damage_context.gd`
- Create: `src/battle/damage/damage_scaling_rule.gd`
- Create: `src/battle/damage/damage_scaling_flat_per_resource.gd`
- Create: `src/battle/damage/damage_scaling_base_per_resource.gd`
- Create: `src/battle/damage/damage_resolver.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`
- Modify: `data/heroes/echo/actions/focused_bolt.tres`
- Modify: `data/heroes/echo/actions/mind_storm.tres`
- Modify: `data/heroes/echo/actions/shatter.tres`
- Test: `test/unit/test_damage_scaling_rules.gd`
- Generate: matching `.gd.uid` sidecars for new scripts and tests

**Interfaces:**
- Consumes: `DamageContribution`, `DamageRequest`, and `DamageCalculator` from Task 1.
- Produces: `CombatantSnapshot.capture(actor)`, `DamageContext.capture(...)`, `DamageScalingRule.resolve(base_potency, context)`, `DamageResolver.resolve_potency(...)`, and `Effect_Damage.scaling_rules`.

- [ ] **Step 1: Write failing tests for Focus, Guard, base-scalar, and extension rules**

Create a test with a custom swarm rule proving that future battlefield state does not require calculator fields:

```gdscript
extends GutTest

class SwarmRule extends DamageScalingRule:
	func resolve(_base_potency: float, context: DamageContext) -> DamageContribution:
		return DamageContribution.new(&"swarm", DamageContribution.Stage.POTENCY, context.other_living_allies * 0.1)


func test_flat_remaining_focus_and_guard_rules() -> void:
	var context := _context(5, 4, 2)
	var focus_rule := DamageScalingFlatPerResource.new()
	focus_rule.resource = DamageScalingFlatPerResource.ResourceType.FOCUS
	focus_rule.potency_per_point = 0.2
	var guard_rule := DamageScalingFlatPerResource.new()
	guard_rule.resource = DamageScalingFlatPerResource.ResourceType.GUARD
	guard_rule.potency_per_point = 0.25
	assert_eq(focus_rule.resolve(0.2, context).amount, 1.0)
	assert_eq(guard_rule.resolve(0.0, context).amount, 1.0)


func test_base_scalar_and_swarm_extension() -> void:
	var context := _context(5, 0, 3)
	var rule := DamageScalingBasePerResource.new()
	rule.resource = DamageScalingBasePerResource.ResourceType.FOCUS
	rule.base_scalar_per_point = 0.2
	assert_eq(rule.resolve(4.0, context).amount, 4.0)
	assert_eq(SwarmRule.new().resolve(1.0, context).amount, 0.3)


func test_resolver_retains_labeled_breakdown() -> void:
	var rule := DamageScalingFlatPerResource.new()
	rule.resource = DamageScalingFlatPerResource.ResourceType.FOCUS
	rule.potency_per_point = 0.2
	var resolved := DamageResolver.resolve_potency(0.2, [rule], _context(5, 0, 0))
	assert_eq(resolved.potency, 1.2)
	assert_eq(resolved.contributions[0].source, &"remaining_focus")
```

The `_context()` fixture constructs getter-only combatant/context snapshots directly; do not require a scene tree.

- [ ] **Step 2: Run the scaling test red**

Run GUT with `-gselect damage_scaling_rules`.

Expected: missing context/rule/resolver types fail parsing.

- [ ] **Step 3: Implement snapshots, rule resources, and potency resolution**

`CombatantSnapshot` captures scalar facts and defensively copied condition names. `DamageContext` contains attacker and target snapshots, `other_living_allies`, `other_living_enemies`, source action/effect identity, and a defensively copied trigger context.

The base rule contract is:

```gdscript
class_name DamageScalingRule
extends Resource


func resolve(_base_potency: float, _context: DamageContext) -> DamageContribution:
	return DamageContribution.new(&"unused", DamageContribution.Stage.POTENCY, 0.0)
```

`DamageResolver.resolve_potency()` must return a getter-only `ResolvedPotency` inner value or dedicated type containing base potency, final potency, and contributions:

```gdscript
static func resolve_potency(base_potency: float, rules: Array[DamageScalingRule], context: DamageContext) -> ResolvedPotency:
	var contributions: Array[DamageContribution] = []
	var final_potency := base_potency
	for rule in rules:
		if rule == null:
			continue
		var contribution := rule.resolve(base_potency, context)
		contributions.append(contribution)
		final_potency += contribution.amount
	return ResolvedPotency.new(base_potency, maxf(0.0, final_potency), contributions)
```

- [ ] **Step 4: Replace bespoke dynamic-potency fields with composed rules**

In `Effect_Damage`, replace `potency_per_guard` and `potency_scalar_per_focus` with:

```gdscript
@export var scaling_rules: Array[DamageScalingRule] = []
```

Migrate the three production resources:

- Focused Bolt: base `potency = 0.2`, flat remaining-Focus rule at `0.2` per point.
- Mind Storm: base `potency = 4.0`, base-scalar remaining-Focus rule at `0.2` per point.
- Shatter: base `potency = 0.0`, flat current-Guard rule at `0.25` per point.

Keep `_get_dynamic_potency()` temporarily as the compatibility-free entry point used by current execution, but implement it solely by capturing a context and calling `DamageResolver.resolve_potency()`; do not retain the removed fields.

- [ ] **Step 5: Import and run scaling plus production-load tests**

Run the editor import, `-gselect damage_scaling_rules`, and `-gselect progression_content`.

Expected: all focused scaling tests and all production progression-content tests pass; no removed-property load warning appears.

- [ ] **Step 6: Commit contextual scaling**

Stage only the new damage-context/rule scripts and sidecars, `effect_damage.gd`, the three migrated `.tres` files, and the focused test. Commit:

```bash
git commit -m "refactor: compose contextual damage scaling"
```

### Task 3: Canonical Runtime Resolution, Guard Rules, and Critical Seam

**Files:**
- Create: `src/battle/damage/damage_hit_plan.gd`
- Modify: `src/battle/damage/damage_resolver.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`
- Modify: `src/scripts/action_effects/effect_damage_inversion.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/battle/actor_card.gd`
- Modify: `src/scripts/conditions/condition.gd`
- Modify: `src/scripts/conditions/condition_scale_with_debuffs.gd`
- Modify: `src/scripts/equipment/trait.gd`
- Modify: `data/enemies/conditions/bleed.tres`
- Modify: `data/heroes/echo/conditions/psionic_pulse_cond.tres`
- Modify: `data/heroes/echo/conditions/static_charge.tres`
- Modify: `data/heroes/sands/conditions/return_fire.tres`
- Test: `test/unit/test_damage_hit_plan.gd`
- Test: `test/unit/test_damage_effect_execution.gd`
- Generate: matching `.gd.uid` sidecars for new scripts/tests

**Interfaces:**
- Consumes: context, scaling, request, result, resolver, and calculator types from Tasks 1-2.
- Produces: overridable `Effect_Damage` hooks `_build_hit_plan()`, `_roll_percent()`, `_pick_random_target()`, `_resolve_forced_damage_type()`, `_resolve_potency()`, `_modify_damage_request()`, `_play_hit_audio()`, and `_apply_calculated_hit()`; `DamageHitPlan`; canonical runtime calls to `DamageResolver.resolve_hit()`.

- [ ] **Step 1: Write failing pure hit-plan tests**

Cover fixed divisors independently from battle animation:

```gdscript
func test_all_target_split_locks_recipient_count() -> void:
	var plan := DamageHitPlan.all_targets([Node.new(), Node.new(), Node.new()], true)
	assert_eq(plan.planned_hit_count, 3)
	assert_eq(plan.distribution_count, 3)


func test_random_split_uses_authored_hit_count_not_candidate_count() -> void:
	var plan := DamageHitPlan.random_targets([Node.new(), Node.new()], 3, true)
	assert_eq(plan.planned_hit_count, 3)
	assert_eq(plan.distribution_count, 3)


func test_unsplit_multihit_keeps_divisor_one() -> void:
	var plan := DamageHitPlan.single_target(Node.new(), 4, false)
	assert_eq(plan.planned_hit_count, 4)
	assert_eq(plan.distribution_count, 1)
```

- [ ] **Step 2: Write failing execution-contract tests with deterministic hooks**

Define test-only `Effect_Damage` and `ActorCard` subclasses. Override audio/wait/popup hooks, `_roll_percent()`, and `_pick_random_target()` rather than seeding global RNG. Protect:

```gdscript
func test_energy_causes_breach_before_damage_and_same_hit_gets_ovr() -> void:
	var outcome := await _execute_recorded_hit(Action.DamageType.ENERGY, 0, false, Action.DamageType.NONE, 100, 75, 0, 100)
	assert_eq(outcome.breach_calls, 1)
	assert_true(outcome.breached_when_request_built)
	assert_eq(outcome.result.request.overload_power, 75)
	assert_eq(outcome.result.effective_power, 175)


func test_intrinsic_and_converted_piercing_never_touch_guard() -> void:
	var intrinsic := await _execute_recorded_hit(Action.DamageType.PIERCING, 2, false, Action.DamageType.NONE, 100, 0, 0, 100)
	var converted := await _execute_recorded_hit(Action.DamageType.KINETIC, 2, false, Action.DamageType.PIERCING, 100, 0, 0, 100)
	assert_eq(intrinsic.guard_changes, [])
	assert_eq(converted.guard_changes, [])
	assert_eq(intrinsic.breach_calls, 0)
	assert_eq(converted.breach_calls, 0)


func test_kinetic_and_energy_always_shred_guard() -> void:
	for damage_type in [Action.DamageType.KINETIC, Action.DamageType.ENERGY]:
		var outcome := await _execute_recorded_hit(damage_type, 2, false, Action.DamageType.NONE, 100, 0, 0, 100)
		assert_eq(outcome.guard_changes, [-1])
		assert_eq(outcome.remaining_guard, 1)


func test_aim_is_clamped_at_roll_boundary() -> void:
	var below := await _execute_recorded_hit(Action.DamageType.PIERCING, 0, false, Action.DamageType.NONE, 100, 0, -50, 1)
	var above := await _execute_recorded_hit(Action.DamageType.PIERCING, 0, false, Action.DamageType.NONE, 100, 0, 150, 100)
	assert_eq(below.result.request.precision_power, 0)
	assert_gt(above.result.request.precision_power, 0)
```

Define `_execute_recorded_hit()` in the same test with test-only `RecordingDamageEffect`, `RecordingActor`, and `RecordingBattleManager` inner classes. `RecordingDamageEffect` overrides `_roll_percent()`, `_resolve_forced_damage_type()`, `_play_hit_audio()`, and `_apply_calculated_hit()`; `RecordingActor` records `modify_guard()` and `breach()` calls; the returned `RecordedHitOutcome` exposes every property asserted above. These helpers execute the real base `Effect_Damage` loop and never duplicate Guard or calculator arithmetic.

- [ ] **Step 3: Run the two focused scripts red**

Run GUT with `-gselect damage_hit_plan`, then `-gselect damage_effect_execution`.

Expected: missing `DamageHitPlan` and missing override hooks fail; existing unrelated tests are not selected.

- [ ] **Step 4: Implement hit plans and refactor `Effect_Damage` as a template executor**

Create `DamageHitPlan` with getter-only candidates, planned-hit count, fixed distribution count, and random/all/single mode. Refactor `execute()` into named phases without changing animation timing:

```gdscript
func execute(attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, action: Action = null, context: Dictionary = {}) -> void:
	var plan := _build_hit_plan(parent_targets, action)
	var effect_context := DamageContext.capture(attacker, null, battle_manager, action, self, context)
	var resolved_potency := _resolve_potency(effect_context)
	for hit_index in plan.planned_hit_count:
		var target := _resolve_planned_target(plan, hit_index)
		if not _can_continue_hit(attacker, target, battle_manager):
			continue
		await _execute_one_hit(attacker, target, battle_manager, action, context, plan, resolved_potency)
```

Every subclass uses the base loop and narrow hooks. Update `Effect_Damage_Inversion._get_dynamic_hit_count()` to the new `_build_hit_plan()` or `_resolve_hit_count()` hook without copying `execute()`.

- [ ] **Step 5: Derive Guard behavior solely from resolved damage type**

Resolve pre-hit conversion first. Then:

```gdscript
func _resolved_type_shreds_guard(resolved_type: Action.DamageType) -> bool:
	return resolved_type in [Action.DamageType.KINETIC, Action.DamageType.ENERGY]
```

Await `target.breach()` on the Vulnerable-to-Breached transition before capturing the hit context. Remove the `shreds_guard` export and every authored `shreds_guard` property. Do not add a replacement Boolean.

- [ ] **Step 6: Build and calculate one canonical request per hit**

Rename misleading scalar helpers so they return additive modifiers:

```gdscript
func get_damage_dealt_modifier(target: ActorCard) -> float:
	var modifier := 0.0
	for condition in active_conditions:
		modifier += condition.get_damage_dealt_modifier(self, target)
	for trait_item in active_traits:
		modifier += trait_item.get_damage_dealt_modifier(target)
	return modifier
```

Provide equivalent incoming-modifier and renamed condition/trait hooks. `DamageResolver.resolve_hit()` chooses ATK/PSY, adds OVR only from the post-Guard target snapshot, adds PRE only after a clamped deterministic crit roll, selects Defense by resolved type, constructs `DamageRequest`, calls `DamageCalculator`, and returns its `DamageResult`.

- [ ] **Step 7: Make actual Focus payment match the displayed scaled cost**

In `BattleManager.execute_action()`, calculate the effective cost once, validate it, pay it before any effect, and include it in action context:

```gdscript
var paid_focus_cost := action.focus_cost
if actor is HeroCard:
	paid_focus_cost = (actor as HeroCard).get_scaled_focus_cost(action.focus_cost)
	if (actor as HeroCard).current_focus < paid_focus_cost:
		return
	await (actor as HeroCard).modify_focus(-paid_focus_cost)
var action_context := {"paid_focus_cost": paid_focus_cost}
```

Pass `action_context` to each effect. Remove the unused local `focus_cost` from `Effect_Damage`.

- [ ] **Step 8: Import and run calculator, scaling, plan, and execution tests**

Run editor import and the four focused GUT selectors.

Expected: all four scripts pass; no parser error, floating coroutine warning, removed `shreds_guard` property warning, or unexpected global RNG dependency.

- [ ] **Step 9: Commit canonical runtime resolution**

Stage only Task 3 source, data-property removals, tests, and required sidecars. Commit:

```bash
git commit -m "refactor: route battle hits through damage resolver"
```

### Task 4: Damage Application, Resolved Events, and Lifedrain

**Files:**
- Modify: `src/battle/actor_card.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`
- Test: `test/unit/test_damage_effect_execution.gd`

**Interfaces:**
- Consumes: `DamageResult` from Task 1 and the per-hit runtime path from Task 3.
- Produces: `ActorCard.take_one_hit(result, effect, attacker, resolved_type) -> int`, returning actual HP removed; complete event contexts consumed by existing conditions.

- [ ] **Step 1: Add failing application tests**

Add complete fixture tests asserting:

```gdscript
func test_take_one_hit_returns_actual_hp_removed_and_lifedrain_excludes_overkill() -> void:
	var fixture := _application_fixture(30, 200)
	var result := DamageCalculator.calculate(_request_for_final_damage(100))
	var actual := await fixture.target.take_one_hit(result, fixture.effect, fixture.attacker, Action.DamageType.PIERCING)
	var healing := Effect_Damage.lifedrain_amount(actual, 0.5)
	assert_eq(result.final_damage, 100)
	assert_eq(actual, 30)
	assert_eq(healing, 15)


func test_converted_damage_dispatches_only_resolved_type_event() -> void:
	var fixture := _application_fixture(200, 200)
	var result := DamageCalculator.calculate(_request_for_final_damage(20))
	await fixture.target.take_one_hit(result, fixture.effect, fixture.attacker, Action.DamageType.PIERCING)
	assert_false(Trigger.TriggerType.ON_TAKING_KINETIC_DAMAGE in fixture.target.recorded_events)
	assert_false(Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE in fixture.target.recorded_events)
	assert_eq(fixture.target.last_damage_context.resolved_damage_type, Action.DamageType.PIERCING)


func test_existing_lethal_hit_reaction_order_is_preserved() -> void:
	var fixture := _application_fixture(10, 200)
	var result := DamageCalculator.calculate(_request_for_final_damage(20))
	await fixture.target.take_one_hit(result, fixture.effect, fixture.attacker, Action.DamageType.KINETIC)
	assert_eq(fixture.target.recorded_events, [])
```

Define `_application_fixture()` using an instantiated actor-card scene so HP bars and popup hooks exist, plus a test-only recording condition effect that appends every dispatched trigger and context. The current lethal path calls `defeated()` and returns before target damage events, so preserve the exact empty target-event array above; the approved design does not authorize reaction reordering.

Define `_request_for_final_damage(amount)` as a Piercing `DamageRequest` with `base_power = amount`, `potency = 1.0`, divisor one, zero Defense, and zero modifiers. The fixture's recording target must expose `recorded_events` and `last_damage_context` exactly as asserted.

- [ ] **Step 2: Run execution tests red for missing result/application behavior**

Run `-gselect damage_effect_execution`.

Expected: failures show lifedrain using attempted float damage and authored-type dispatch.

- [ ] **Step 3: Apply `DamageResult`, return actual damage, and enrich context**

Change the signature to:

```gdscript
func take_one_hit(
	result: DamageResult,
	damage_effect: Effect_Damage,
	attacker: ActorCard,
	resolved_damage_type: Action.DamageType,
) -> int:
```

Compute `actual_damage := mini(result.final_damage, current_hp)` before HP mutation. Use `result.final_damage` for the popup and attempted-damage reporting, subtract `actual_damage`, dispatch type events from `resolved_damage_type`, and include:

```gdscript
var event_context := {
	"attacker": attacker,
	"target": self,
	"damage_result": result,
	"attempted_damage": result.final_damage,
	"actual_damage": actual_damage,
	"resolved_damage_type": resolved_damage_type,
	"is_critical": result.request.precision_power > 0,
	"was_breached": result.request.overload_power > 0,
}
```

Return `actual_damage` on every path, including lethal damage after preserving characterized trigger order.

- [ ] **Step 4: Base lifedrain on actual damage**

In `Effect_Damage`, capture the returned amount and use:

```gdscript
static func lifedrain_amount(actual_damage: int, scalar: float) -> int:
	return maxi(0, floori(float(actual_damage) * maxf(0.0, scalar)))


var actual_damage := await target.take_one_hit(result, self, attacker, resolved_damage_type)
if lifedrain_scalar > 0.0:
	attacker.take_healing(lifedrain_amount(actual_damage, lifedrain_scalar))
```

Pass the same result and amounts to on-hit/attacker events. Remove all remaining use of pre-rounded `final_dmg_float`.

- [ ] **Step 5: Run focused tests and commit**

Run `-gselect damage_effect_execution` and `-gselect battle_condition_targets`; both must pass. Commit only the Task 4 files:

```bash
git commit -m "fix: apply resolved damage events and lifedrain"
```

### Task 5: Shared Damage Preview for Descriptions and Enemy Intent

**Files:**
- Create: `src/battle/damage/damage_preview.gd`
- Create: `src/scripts/action_effects/effect_presentation.gd`
- Create: `src/scripts/action_effects/effect_presentation_context.gd`
- Modify: `src/scripts/action_effects/action_effect.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`
- Modify: `src/scripts/data/action.gd`
- Modify: `src/battle/action_button.gd`
- Modify: `src/battle/enemy_card.gd`
- Test: `test/unit/test_damage_preview.gd`
- Generate: matching `.gd.uid` sidecars

**Interfaces:**
- Consumes: `DamageResolver`, `DamageCalculator`, and runtime effect/context types from Tasks 1-4.
- Produces: `EffectPresentation`, `EffectPresentationContext`, `ActionEffect.get_presentation(context)`, `DamagePreview.for_effect(effect, attacker, target, action, distribution_count, critical) -> DamageResult`, and generic `{effect:N}` action-description bindings.

- [ ] **Step 1: Write failing preview parity tests**

Cover Focus payment, target Defense/Breach, crit variants, fixed split count, and multi-effect binding:

```gdscript
func test_focused_bolt_preview_uses_post_cost_remaining_focus_curve() -> void:
	var attacker := _hero(100, 5)
	var action := load("res://data/heroes/echo/actions/focused_bolt.tres") as Action
	var effect := action.effects[0] as Effect_Damage
	var result := DamagePreview.for_effect(effect, attacker, null, Action.new(), 1, false)
	assert_eq(result.request.potency, 1.2)
	assert_eq(result.final_damage, 120)
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


func test_effect_tokens_bind_by_action_effect_index() -> void:
	var action := Action.new()
	action.description = "First {effect:1}; second {effect:2}"
	action.effects = [_damage_effect(0.5), _damage_effect(1.0)]
	var text := action.get_rich_description(_attacker(), _target())
	assert_false(text.contains("{effect:"))
	assert_string_contains(text, "First ")
	assert_string_contains(text, "; second ")


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
```

Define `_hero()`, `_target()`, `_attacker()`, and `_damage_effect()` as explicit test-local constructors that assign `ActorStats`, Focus, Breach, and defenses without adding nodes to the scene tree.

- [ ] **Step 2: Run preview tests red**

Run `-gselect damage_preview`.

Expected: missing presentation/preview types and unsupported `{effect:N}` binding failures.

- [ ] **Step 3: Implement preview construction without RNG or duplicated math**

`DamagePreview.for_effect()` captures the same post-cost resource state as execution, resolves contextual scaling, chooses an explicit `critical` Boolean without rolling, and calls `DamageResolver.resolve_hit()`. It may omit audiovisual and event state but must not reproduce arithmetic.

For no target, use an explicit neutral target snapshot: not Breached, zero Defense, zero incoming modifier. For an exact target, include its current Breach, Defense, and incoming modifiers. For multiple targets, return per-target results or a min-max display; never average different target defenses silently.

- [ ] **Step 4: Establish the generic effect-presentation contract**

Create getter-only `EffectPresentation` fields `clause_template: String`, `bindings: Dictionary`, and `details: Array[String]`. Its `render()` method defensively copies bindings and replaces named placeholders in the clause. Create `EffectPresentationContext` with actor, optional target, action, effect index, fixed distribution count, critical-preview mode, and optional damage context.

Add the base extension seam:

```gdscript
func get_presentation(_context: EffectPresentationContext) -> EffectPresentation:
	return null
```

Implement `Effect_Damage.get_presentation()` as the first full adopter. It must obtain damage values from `DamagePreview`, create bindings for amount, selected power, damage type, hit count, split behavior, and contextual-scaling text, and return a clause without inspecting tooltip controls.

- [ ] **Step 5: Replace handwritten damage evaluation with generic effect composition**

Change the public signature compatibly:

```gdscript
func get_rich_description(user: ActorCard, target: ActorCard = null) -> String:
```

Resolve one-based `{effect:N}` against the actual `Action.effects` index and call that child's `get_presentation()`. When an action description is empty, join every non-null child presentation in effect order. Existing non-damage prose and its general expression parser remain compatible until a follow-up migrates other effect types. Delete unused `_get_damage_string()` and do not introduce a damage-only token language.

- [ ] **Step 6: Route enemy intent through `DamagePreview`**

Replace `power * potency` and the hardcoded `/= 3` in `_update_intent_ui()`. Build the fixed plan and resolve each intended target through `DamagePreview`; append existing hit-count and RANDOM/EVERYONE presentation without calculating damage independently.

- [ ] **Step 7: Import, run preview and CTB content tests, then commit**

Run editor import, `-gselect damage_preview`, and `-gselect ctb_action_content`.

Expected: all pass and no action tooltip contains an unresolved structured damage token in test fixtures.

Commit:

```bash
git commit -m "refactor: share damage previews with runtime"
```

### Task 6: Migrate and Validate Production Damage Content

**Files:**
- Modify: `data/enemies/actions/double_shot.tres`
- Modify: `data/enemies/actions/gunshot.tres`
- Modify: `data/enemies/actions/mow_down.tres`
- Modify: `data/enemies/actions/potshot.tres`
- Modify: `data/enemies/actions/rapid_fire.tres`
- Modify: `data/enemies/actions/shrapnel.tres`
- Modify: `data/enemies/actions/stun_baton.tres`
- Modify: `data/enemies/conditions/bleed.tres`
- Modify: `data/heroes/asher/actions/aimed_shot.tres`
- Modify: `data/heroes/asher/actions/bullet_storm.tres`
- Modify: `data/heroes/asher/actions/charged_shot.tres`
- Modify: `data/heroes/asher/actions/concussive_shot.tres`
- Modify: `data/heroes/asher/actions/double_tap.tres`
- Modify: `data/heroes/asher/actions/ensnare.tres`
- Modify: `data/heroes/asher/actions/fusion_ammo.tres`
- Modify: `data/heroes/asher/actions/siphon_shots.tres`
- Modify: `data/heroes/asher/conditions/fusion_ammo.tres`
- Modify: `data/heroes/echo/actions/energy_barrier.tres`
- Modify: `data/heroes/echo/actions/feedback.tres`
- Modify: `data/heroes/echo/actions/focused_bolt.tres`
- Modify: `data/heroes/echo/actions/inversion.tres`
- Modify: `data/heroes/echo/actions/mind_storm.tres`
- Modify: `data/heroes/echo/actions/pain_transfer.tres`
- Modify: `data/heroes/echo/actions/psionic_pulse.tres`
- Modify: `data/heroes/echo/actions/rejuvenate.tres`
- Modify: `data/heroes/echo/actions/reverberate.tres`
- Modify: `data/heroes/echo/actions/shatter.tres`
- Modify: `data/heroes/echo/actions/static_charge.tres`
- Modify: `data/heroes/echo/actions/telekinesis.tres`
- Modify: `data/heroes/echo/conditions/energy_barrier.tres`
- Modify: `data/heroes/echo/conditions/feedback.tres`
- Modify: `data/heroes/echo/conditions/inversion.tres`
- Modify: `data/heroes/echo/conditions/psionic_pulse_cond.tres`
- Modify: `data/heroes/echo/conditions/reverberate.tres`
- Modify: `data/heroes/echo/conditions/static_charge.tres`
- Modify: `data/heroes/sands/actions/booster_shots.tres`
- Modify: `data/heroes/sands/actions/checkmate.tres`
- Modify: `data/heroes/sands/actions/focus_fire.tres`
- Modify: `data/heroes/sands/actions/opening_salvo.tres`
- Modify: `data/heroes/sands/actions/overwatch.tres`
- Modify: `data/heroes/sands/actions/phalanx.tres`
- Modify: `data/heroes/sands/conditions/return_fire.tres`
- Modify: `src/scripts/equipment/equipment.gd`
- Modify: `src/scripts/data/enemy_data.gd`
- Modify: `src/scripts/action_effects/pre_hit_effect_modify_attacker_stats.gd`
- Delete: `src/scripts/data/action_upgrade.gd`
- Delete: `src/scripts/data/action_upgrade.gd.uid`
- Test: `test/integration/test_damage_content.gd`
- Generate: `test/integration/test_damage_content.gd.uid`

**Interfaces:**
- Consumes: structured `{effect:N}` binding and typed effect/rule configuration from Tasks 2 and 5.
- Produces: production content with no duplicated damage formula authority and a recursive validation test preventing renewed drift.

- [ ] **Step 1: Write the failing recursive production validator**

Recursively enumerate `.tres` files below `res://data/heroes` and `res://data/enemies`, load each resource, inspect `Action.effects`, `Condition.triggers`, hit-trigger effects, and nested damage effects. Assert:

```gdscript
func _validate_damage_effect(effect: Effect_Damage, path: String, effect_index: int) -> void:
	assert_true(effect.potency >= 0.0, "%s effect %d nonnegative potency" % [path, effect_index])
	assert_true(effect.hit_count >= 1, "%s effect %d positive hit count" % [path, effect_index])
	assert_true(effect.damage_type != Action.DamageType.NONE, "%s effect %d concrete damage type" % [path, effect_index])
	assert_false(effect.get_property_list().any(func(property): return property.name == "shreds_guard"), "%s effect %d has no obsolete Guard override" % [path, effect_index])
```

For every `Action`, assert that each `{effect:N}` index exists and references an effect with a non-null presentation, every direct child `Effect_Damage` intended for numeric presentation has exactly one binding, and no `{dmgN}` remains. Existing prose for damage nested behind `Effect_ApplyCondition` remains compatible in this effort because condition presentation is deferred; add explicit assertions that its authored power, potency, type, and Guard wording match the referenced nested damage resource.

- [ ] **Step 2: Add explicit failing regression assertions for audited mismatches**

Load and assert intended structured values for:

- Focused Bolt: approved 20% plus flat 20% per remaining Focus and matching prose.
- Charged Shot: 150% ATK, with matching prose.
- Booster Shots: three executed and described 50% ATK hits.
- Shatter: `split_damage = true`.
- Telekinesis: Energy damage.
- Reverberate: PSY power.
- Shrapnel: a 200% ATK Kinetic initial hit followed by the existing Piercing Bleed.
- Rapid Fire: three-hit fixed split.
- Psionic Pulse and Static Charge: Energy and therefore intrinsic Guard shredding, with no override.

- [ ] **Step 3: Run the content validator red and capture every resource path**

Run `-gselect damage_content`.

Expected: failures list all remaining `{dmgN}`, handwritten damage formulas, obsolete Guard overrides, and the known audited mismatches by exact resource path.

- [ ] **Step 4: Migrate production prose and correct confirmed resources**

Replace direct child damage expressions with indexed structured bindings while preserving narrative copy and icon tags. Keep nested condition-damage prose compatible, but correct and explicitly validate its copied mechanical wording. Correct all audited power type, damage type, potency, hit count, split, and scaling-rule data using the approved rules in Step 2.

Descriptions for dynamic rules must name their timing and curve. Use “remaining Focus after paying the cost” for Focus-scaled actions where needed. Do not show a fabricated exact target result when no target context exists.

- [ ] **Step 5: Correct stat-generation defects at their source and boundary**

In `Equipment.calculate_stats()`, derive AIM from `ratings[ActorStats.Stats.AIM]`, not KIN Defense. In `EnemyData.calculate_stats()`, clamp generated KIN/NRG Defense to 0 through 90. Retain the calculator boundary clamp as defense in depth.

Add focused assertions to `test_damage_content.gd` or a small adjacent unit test:

```gdscript
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
```

- [ ] **Step 6: Remove or complete dead extension surfaces based on verified usage**

Use `rg` to reconfirm the plan-creation audit: `damage_bonus` and `def_mod` have no consumer, and `ActionUpgrade` has no production caller or resource. Remove the unused pre-hit field and no-op defense branch, then delete the unused `ActionUpgrade` script and sidecar rather than preserving its invalid `action.damage_modifier` mutation.

Fix `IF_ATTACKER_HAS_BUFF` with empty context to count Buff conditions, not Debuffs, and add a focused assertion in `test_damage_effect_execution.gd`.

- [ ] **Step 7: Import and run content, calculator, preview, progression, and execution tests**

Run editor import and focused selectors for `damage_`, `progression_content`, and `ctb_action_content`.

Expected: every selected test passes; production resources load without invalid-property or unresolved-token warnings.

- [ ] **Step 8: Commit the content migration and audited corrections**

Stage only Task 6 resources, source fixes, tests, and sidecars. Commit:

```bash
git commit -m "fix: align production damage content"
```

### Task 7: Full Verification and Documentation Reconciliation

**Files:**
- Modify if implementation details changed: `docs/superpowers/specs/2026-07-17-battle-damage-architecture-design.md`
- Modify: `docs/testing/ctb-combat-checklist.md` only for new manual damage-preview/Guard checks
- Test: all new and existing test scripts

**Interfaces:**
- Consumes: the complete implemented damage architecture.
- Produces: parser-clean project, damage-focused green suite, no new full-suite failures, reconciled documentation, and a reviewable final commit series.

- [ ] **Step 1: Run final static searches**

Run:

```bash
rg -n "shreds_guard|potency_per_guard|potency_scalar_per_focus|\{dmg[0-9]+\}|damage_modifier|var def_mod" src data test docs --glob '*.{gd,tres,md}'
rg -n "final_dmg_float|power \* damage_effect\.potency|intended_dmg /= 3" src --glob '*.gd'
```

Expected: no obsolete production implementation or content matches. Historical design/plan references are acceptable only when clearly historical; the approved architecture document must describe the implemented names accurately.

- [ ] **Step 2: Run import and every damage-focused test**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect damage_ -gexit
```

Expected: import exits zero; all damage calculator, scaling, planning, execution, preview, and production-content tests pass with zero failures.

- [ ] **Step 3: Run the complete suite and compare against the pre-existing baseline**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected for a clean unrelated baseline: zero test failures. At plan creation, the dirty worktree independently causes failures in `test_approved_cursor_set_is_complete` and `test_dungeon_hud_groups_use_owned_anchors_and_fit_acceptance_outputs`; do not modify those files as part of damage work. If they remain, report the exact full-suite totals and demonstrate that damage-focused tests and all previously passing tests remain green.

- [ ] **Step 4: Perform focused manual battle acceptance**

Using the existing combat checklist, verify at minimum:

- Kinetic and Energy remove Guard and can cause Breach.
- Intrinsic and Targeting-Laser-converted Piercing bypass Defense without touching Guard.
- The breach-causing hit receives OVR.
- Critical popups reflect PRE and resolved type.
- Focused Bolt shows and executes 20% plus 20% per remaining Focus.
- Mind Storm previews remaining Focus after its cost.
- Rapid Fire damage does not change when a target dies mid-action.
- Enemy intent and action tooltip numbers match observed noncritical damage for the same target state.
- Lifedrain excludes overkill.

Record viewport, input method, and any intentionally unverified visual item in the handoff.

- [ ] **Step 5: Reconcile documentation and commit only if needed**

If implemented type or hook names differ from the approved spec, update the spec without changing its gameplay rules. Add concise manual damage checks to `docs/testing/ctb-combat-checklist.md` if they are not already represented. Run `git diff --check`, then commit documentation-only reconciliation:

```bash
git commit -m "docs: reconcile battle damage verification"
```

- [ ] **Step 6: Request final code review**

Invoke `superpowers:requesting-code-review`. The review must compare every approved gameplay rule and audit finding against implementation and tests, inspect the complete commit range, and report findings before branch completion or integration decisions.
