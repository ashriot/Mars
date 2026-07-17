# Battle Damage Final Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore damage-trigger target compatibility and make runtime, multihit presentation, enemy intent, incomplete-context presentation, and breakdown metadata agree with the approved damage architecture.

**Architecture:** Keep `DamageCalculator` and `DamageResult` single-hit and pure. Add a presentation-only sequential preview value that builds the existing fixed hit plan, clones only mutable target combat state, and returns ordered per-hit results without mutating live actors; route complete target collections and battle context into action presentation, while incomplete contexts render authored potency × ATK/PSY relationships. Derive modifier totals from source-labeled typed contributions and retain authored base potency in every request.

**Tech Stack:** Godot 4.6.3, typed GDScript, GUT 9.6.1.

## Global Constraints

- Use exactly `HOME=/tmp/mars-godot-home` for every automated Godot invocation.
- Preserve current lethal/event ordering, exact-target UI lifecycle, approved damage arithmetic, and the Rejuvenate/manual-acceptance deferrals.
- Preview code must not mutate actors, consume live conditions, dispatch events, or run application animations/audio.
- Preserve and do not stage unrelated weapon, dungeon-map, or cursor work.
- Use strict RED/GREEN for every behavior before implementation.

---

### Task 1: Restore PARENT damage-event routing with production Reverberate coverage

**Files:**
- Modify: `test/unit/test_damage_effect_execution.gd`
- Modify: `src/battle/actor_card.gd`

**Interfaces:**
- Consumes: `ActorCard._fire_condition_event(event_type, context)` and `BattleManager.get_targets(PARENT, ..., parent_targets, ...)`.
- Produces: every nonlethal singular damage event context contains both `target` and `targets: [target]`, plus the existing result/source facts.

- [ ] **Step 1: Write the failing production-topology test**

Load `res://data/heroes/echo/actions/reverberate.tres` and `res://data/heroes/echo/conditions/reverberate.tres`, assign the duplicated condition's attacker, and apply a real Kinetic `DamageResult` through the existing scene-backed application fixture. Assert that the nested production Energy effect removes Reverberate, removes 60 additional HP from a 40-PSY source at 1.5 potency, and publishes Energy/source-action/source-effect facts.

```gdscript
func test_production_reverberate_routes_parent_target_and_removes_after_energy_hit() -> void:
	var action := load("res://data/heroes/echo/actions/reverberate.tres") as Action
	var fixture := _application_fixture(200, 200)
	fixture.attacker.current_stats.attack = 5
	fixture.attacker.current_stats.psyche = 40
	var condition := (load(
		"res://data/heroes/echo/conditions/reverberate.tres"
	) as Condition).duplicate(true) as Condition
	condition.attacker = fixture.attacker
	var nested := condition.triggers[0].effects_to_run[0] as Effect_Damage
	fixture.target.active_conditions = [condition, _recording_condition(
		fixture.target, fixture.attacker, Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE,
	)]
	var result := DamageResult.with_hit_facts(
		DamageCalculator.calculate(_request_for_final_damage(10)),
		false, false, action.effects[0], action,
	)
	await fixture.target.take_one_hit(
		result, action.effects[0], fixture.attacker, Action.DamageType.KINETIC,
	)
	assert_eq(fixture.target.current_hp, 130)
	assert_false(fixture.target.has_condition("Reverberate"))
	assert_same(fixture.target.last_damage_context.source_effect, nested)
	assert_same(fixture.target.last_damage_context.source_action, action)
	assert_eq(fixture.target.last_damage_context.resolved_damage_type, Action.DamageType.ENERGY)
```

- [ ] **Step 2: Run RED**

Run:

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect damage_effect_execution -gexit
```

Expected: the new Reverberate test fails because the nested `PARENT` effect receives no target.

- [ ] **Step 3: Restore the compatible target array**

Add the legacy plural field without removing any enriched singular/source data:

```gdscript
var event_context := {
	"attacker": attacker,
	"target": self,
	"targets": [self],
	# existing immutable damage/source facts remain unchanged
}
```

- [ ] **Step 4: Run GREEN and commit**

Re-run the selector and require all tests to pass, then commit only the two task files:

```sh
git add src/battle/actor_card.gd test/unit/test_damage_effect_execution.gd
git commit -m "fix: restore parent targets for damage reactions"
```

### Task 2: Add non-mutating sequential fixed-plan preview

**Files:**
- Modify: `test/unit/test_damage_preview.gd`
- Modify: `src/battle/damage/damage_preview.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`

**Interfaces:**
- Produces: `DamagePreview.Sequence` with defensive `results`, `is_complete`, `is_ordered`, `planned_hit_count`, and `distribution_count` getters.
- Produces: `DamagePreview.for_plan(effect, attacker, targets, action, critical, battle_manager, pre_hit_context)`.
- Preserves: `DamagePreview.for_effect(...)` for an exact single synthetic hit; a null target returns no exact result.

- [ ] **Step 1: Write Guard/Breach and one-use conversion RED tests**

Add exact single-target two-hit fixtures. The Guard fixture starts at one Guard with Kinetic Defense and OVR, and asserts ordered results transition from ordinary to Breached without changing the live Guard/Breach/HP. The Targeting Laser fixture asserts first-hit Piercing and second-hit intrinsic Kinetic, with the live condition retained.

```gdscript
var sequence := DamagePreview.for_plan(effect, attacker, [target], action, false)
assert_eq(sequence.results.size(), 2)
assert_eq(sequence.results[0].request.damage_type, Action.DamageType.PIERCING)
assert_eq(sequence.results[1].request.damage_type, Action.DamageType.KINETIC)
assert_eq(target.active_conditions, [targeting_laser])
assert_eq(target.current_guard, original_guard)
assert_false(target.is_breached)
```

- [ ] **Step 2: Run RED**

Run the `damage_preview` selector and require failure because `Sequence`/`for_plan` do not exist.

- [ ] **Step 3: Implement the sequence value and copied-state simulation**

Inside `DamagePreview`, add the focused value and build the existing `DamageHitPlan`. Clone each target once, preserving stats/traits and duplicating its active-condition array. For each fixed candidate: resolve conversion against the clone, erase only the cloned consumable condition, apply Guard/Breach to the clone, capture current-hit context from the cloned state with stable battlefield counts, resolve the canonical request/result, then subtract preview HP on the clone. Never call `remove_condition()`, `take_one_hit()`, or any event hook.

```gdscript
class Sequence extends RefCounted:
	var _results: Array[DamageResult]
	var _is_complete: bool
	var _is_ordered: bool
	var _planned_hit_count: int
	var _distribution_count: int

	var results: Array[DamageResult]:
		get: return _results.duplicate()
```

For random plans, simulate each candidate as a possible repeated sequence using the same fixed divisor and mark the output unordered; do not invent one random allocation.

- [ ] **Step 4: Render uniform, ordered, and unordered sequence output**

In `Effect_Damage.get_presentation()`, use `xN` only when every result has the same amount and resolved type. Render ordered amount/type segments when a fixed sequence changes, and render a same-type min–max `per target` range for unordered/group results.

- [ ] **Step 5: Run GREEN and commit**

Require the `damage_preview` selector to pass, then commit the three task files:

```sh
git add src/battle/damage/damage_preview.gd src/scripts/action_effects/effect_damage.gd test/unit/test_damage_preview.gd
git commit -m "fix: preview mutable multihit state sequentially"
```

### Task 3: Route complete group context and truthful incomplete relationships

**Files:**
- Modify: `test/unit/test_damage_preview.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `test/integration/test_damage_content.gd`
- Modify: `src/scripts/action_effects/effect_presentation_context.gd`
- Modify: `src/scripts/data/action.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/battle/enemy_card.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`

**Interfaces:**
- Extends: `EffectPresentationContext` with defensive `targets`, `battle_manager`, and `is_complete` presentation inputs.
- Extends: `Action.get_rich_description(user, target, targets, battle_manager)` with optional explicit group context.
- Consumes: `DamagePreview.Sequence` from Task 2 for both effect presentation and enemy intent.

- [ ] **Step 1: Replace the false-exact group fixture and add incomplete-context RED tests**

Replace the current `100 total` group assertion with an incomplete authored relationship assertion such as `100% ATK total split across all targets`. Add a complete group fixture with two different Defense values and a real fixed divisor; assert a min–max per-target range and no average. Add target-HP and living-count rules with unavailable context; assert the rendered text contains the authored relationship/contextual-scaling statement and no fabricated final damage.

- [ ] **Step 2: Add navigation/intent RED coverage**

Assert the group current-action surface receives real targets and a fixed divisor, exact-target lifecycle resets to the authored neutral relationship, and enemy intent uses the same sequential result formatting for Guard/Breach and type-changing hits.

- [ ] **Step 3: Run RED**

Run `damage_preview` and `battle_controller_navigation`; require failures from fabricated neutral totals/group divisor one and the old intent aggregation.

- [ ] **Step 4: Implement completeness and context routing**

`Action` builds an `EffectPresentationContext` from `[target]` for exact selection or the explicit group collection. `BattleManager` passes `get_targets()` plus itself for group presentation. `EnemyCard` passes `intended_targets` and `battle_manager` to both intent segments and its tooltip. Empty target context is incomplete and does not call an exact preview.

- [ ] **Step 5: Update the generic production validator**

Teach `test_damage_content.gd` to validate the incomplete relationship bindings rather than compare a fabricated null-target result. Keep exact runtime/presentation comparison in explicit complete-context fixtures.

- [ ] **Step 6: Run GREEN and commit**

Require preview, navigation, and damage-content selectors to pass, then commit only the files in this task:

```sh
git add src/scripts/action_effects/effect_presentation_context.gd src/scripts/data/action.gd src/battle/battle_manager.gd src/battle/enemy_card.gd src/scripts/action_effects/effect_damage.gd test/unit/test_damage_preview.gd test/integration/test_battle_controller_navigation.gd test/integration/test_damage_content.gd
git commit -m "fix: distinguish complete damage presentation context"
```

### Task 4: Preserve authored base potency and labeled modifier contributions

**Files:**
- Modify: `test/unit/test_damage_scaling_rules.gd`
- Modify: `test/unit/test_damage_preview.gd`
- Modify: `src/battle/actor_card.gd`
- Modify: `src/battle/damage/damage_request.gd`
- Modify: `src/battle/damage/damage_resolver.gd`

**Interfaces:**
- Produces: immutable `DamageRequest.base_potency`.
- Produces: `ActorCard.get_damage_dealt_contributions(target)` and `get_damage_taken_contributions(attacker)`.
- Preserves: existing scalar modifier getters by summing the typed contribution arrays.

- [ ] **Step 1: Write breakdown RED tests**

Create named condition and trait modifiers on attacker/target plus a scaling-rule modifier. Assert request base potency equals the authored effect potency, every modifier appears exactly once with `OUTGOING`/`INCOMING` stage and a stable source label, and request totals equal the contribution sums.

- [ ] **Step 2: Run RED**

Run `damage_scaling_rules` and `damage_preview`; require failures for missing base potency and unlabeled actor modifiers.

- [ ] **Step 3: Implement typed actor modifier contribution collection**

Build source names from condition/trait identities, omit zero contributions, and make existing scalar getters sum the arrays. In `DamageResolver`, combine scaling, condition, and trait contributions once; derive outgoing/incoming totals from that array and pass authored base potency into `DamageRequest`.

- [ ] **Step 4: Run GREEN and commit**

Require both selectors to pass, then commit:

```sh
git add src/battle/actor_card.gd src/battle/damage/damage_request.gd src/battle/damage/damage_resolver.gd test/unit/test_damage_scaling_rules.gd test/unit/test_damage_preview.gd
git commit -m "fix: retain labeled damage breakdown inputs"
```

### Task 5: Protect asymmetric PSY runtime/preview selection

**Files:**
- Modify: `test/unit/test_damage_effect_execution.gd`

**Interfaces:**
- Consumes: existing `Effect_Damage.power_type`, OVR/PRE logic, sequential preview, and runtime resolver.
- Produces: regression coverage with ATK different from PSY and nonzero OVR/PRE.

- [ ] **Step 1: Write the asymmetric PSY test**

Use ATK 10, PSY 100, OVR 20, PRE 30, a Breached target, guaranteed critical, and a PSY effect. Assert runtime and preview both select base power 100, effective power 150, and the same final damage.

- [ ] **Step 2: Run the test as a mutation-proving RED**

Temporarily set the test effect to ATK and run `damage_effect_execution`; require the assertions to fail by selecting 10. Restore PSY before implementation verification.

- [ ] **Step 3: Run GREEN and commit**

Run `damage_effect_execution`, require all tests to pass with PSY, and commit the test:

```sh
git add test/unit/test_damage_effect_execution.gd
git commit -m "test: protect asymmetric psyche damage power"
```

### Task 6: Final verification, report, and scoped handoff

**Files:**
- Modify (ignored): `.superpowers/sdd/final-fixes-report.md`

**Interfaces:**
- Consumes: every completed task and the approved architecture.
- Produces: exact final verification evidence and a clean scoped commit history.

- [ ] **Step 1: Run fresh import**

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
```

- [ ] **Step 2: Run focused selectors**

Run `damage_`, `damage_effect_execution`, `damage_preview`, `battle_condition_targets`, `battle_controller_navigation`, `action_`, `condition_`, `actor_card_target_presentation`, and `controller_playable_loop` with the exact isolated HOME.

- [ ] **Step 3: Run the complete suite**

```sh
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Require no task regression; separately record the protected dungeon-map/cursor failures if they remain.

- [ ] **Step 4: Review and audit**

Run `git diff --check`, inspect every scoped diff/commit, verify protected files are unstaged, and request a final read-only Critical/Important review.

- [ ] **Step 5: Append the final-fixes report**

Record each new RED/GREEN cycle, final selector/full-suite totals, commits, read-only review result, preserved dirty work, manual acceptance deferral, and Rejuvenate deferral in `.superpowers/sdd/final-fixes-report.md`. Keep the ignored report out of every commit.
