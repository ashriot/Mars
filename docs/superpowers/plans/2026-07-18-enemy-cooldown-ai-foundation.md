# Enemy Cooldown AI Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace sequence/random enemy turns with validated cooldown abilities, reactive priority rules, deterministic target selection, and per-card runtime state while preserving the existing `Action` and intent-presentation pipeline.

**Architecture:** Immutable `EnemyAbility` resources wrap ordinary actions with cooldown and rule data. A pure `EnemyDecisionEngine` evaluates typed conditions and selectors against an `EnemyAIContext`; `EnemyCard` owns only runtime cooldown/use state and the selected intent. Current actors are migrated after the engine is covered, then legacy deck and override fields are removed.

**Tech Stack:** Godot 4.6.3, typed GDScript, Godot Resources, CTB simulator, GUT 9.6.1.

## Global Constraints

- Use Godot 4.6.3; Godot 4.7 remains deferred.
- Every automated Godot command uses isolated `HOME=/tmp/mars-godot-home`.
- Preserve unrelated dirty-worktree changes and stage only task files plus required Godot `.uid` sidecars.
- Do not create a Git worktree unless the user explicitly requests one.
- Keep `Action`, `ActionEffect`, `Condition`, `Trigger`, damage execution, and intent presentation authoritative.
- Do not author the Officer, Psyker, Gang Enforcer, Defense Drone, Siege Drone, or their new actions in this plan.
- New filenames use lowercase snake_case.

---

## File Structure

- `src/scripts/enemies/enemy_decision_condition.gd` — typed, validated rule predicates.
- `src/scripts/enemies/enemy_target_selector.gd` — typed target policies with Taunt/untargetable filtering and stable seeded ties.
- `src/scripts/enemies/enemy_decision_rule.gd` — priority, conditions, selector, and diagnostic reason.
- `src/scripts/enemies/enemy_ability.gd` — immutable action wrapper with cooldown metadata and rules.
- `src/scripts/enemies/enemy_kit_validator.gd` — kit-level identity, fallback, and cross-field validation.
- `src/scripts/enemies/enemy_ai_runtime_state.gd` — per-card cooldown, one-time-use, and turn state.
- `src/scripts/enemies/enemy_ai_context.gd` — read-only living actors, CT distance, and seed context.
- `src/scripts/enemies/enemy_decision.gd` — selected ability/action/rule/targets value object.
- `src/scripts/enemies/enemy_decision_engine.gd` — pure candidate evaluation and deterministic selection.
- `src/scripts/data/enemy_data.gd` — owns `Array[EnemyAbility]` instead of legacy deck fields.
- `src/battle/enemy_card.gd` — binds runtime state and decision results to visible intents.
- `src/battle/battle_manager.gd` — builds decision context and completes enemy AI turns.
- `src/singletons/encounter_database.gd` — rejects encounters containing invalid enemy kits.
- `data/enemies/actors/*.tres` — migrate the six current actors to ability subresources without rewriting action resources.
- `test/unit/test_enemy_ability_definitions.gd` — authored-data and validator contract.
- `test/unit/test_enemy_ai_runtime_state.gd` — cooldown semantics.
- `test/unit/test_enemy_decision_engine.gd` — predicates, selectors, priorities, targeting, and deterministic choices.
- `test/unit/test_enemy_taunt_targeting.gd` — migrate Taunt coverage to the new selector path.
- `test/integration/test_enemy_ai_intents.gd` — visible intent refresh and turn-completion integration.
- `test/integration/test_damage_content.gd` — production enemy-kit validation.

---

### Task 1: Immutable Ability Data and Kit Validation

**Files:**
- Create: `src/scripts/enemies/enemy_decision_condition.gd`
- Create: `src/scripts/enemies/enemy_target_selector.gd`
- Create: `src/scripts/enemies/enemy_decision_rule.gd`
- Create: `src/scripts/enemies/enemy_ability.gd`
- Create: `src/scripts/enemies/enemy_kit_validator.gd`
- Modify: `src/scripts/data/enemy_data.gd`
- Create: `test/unit/test_enemy_ability_definitions.gd`

**Interfaces:**
- Produces: `EnemyAbility.validate(source: String) -> PackedStringArray`
- Produces: `EnemyDecisionRule.validate(source: String) -> PackedStringArray`
- Produces: `EnemyDecisionCondition.validate(source: String) -> PackedStringArray`
- Produces: `EnemyTargetSelector.validate(source: String) -> PackedStringArray`
- Produces: `EnemyKitValidator.validate(enemy: EnemyData, source: String = "") -> PackedStringArray`
- Produces: `EnemyData.abilities: Array[EnemyAbility]`

- [ ] **Step 1: Write failing definition and validation tests**

Create `test/unit/test_enemy_ability_definitions.gd` with explicit valid/failure cases:

```gdscript
extends GutTest


func _free_ability(id: StringName = &"basic") -> EnemyAbility:
	var selector := EnemyTargetSelector.new()
	selector.type = EnemyTargetSelector.Type.SEEDED_HERO
	var rule := EnemyDecisionRule.new()
	rule.priority = 0
	rule.selector = selector
	var ability := EnemyAbility.new()
	ability.ability_id = id
	ability.action = Action.new()
	ability.cooldown_turns = 0
	ability.initial_cooldown = 0
	ability.rules = [rule]
	return ability


func test_valid_kit_requires_one_unconditional_free_action() -> void:
	var enemy := EnemyData.new()
	enemy.enemy_id = "valid"
	enemy.abilities = [_free_ability()]
	assert_true(EnemyKitValidator.validate(enemy).is_empty())


func test_kit_rejects_duplicate_ids_and_missing_fallback() -> void:
	var first := _free_ability(&"same")
	first.cooldown_turns = 1
	first.initial_cooldown = 1
	var second := _free_ability(&"same")
	second.cooldown_turns = 2
	second.initial_cooldown = 1
	var enemy := EnemyData.new()
	enemy.enemy_id = "invalid"
	enemy.abilities = [first, second]
	var errors := EnemyKitValidator.validate(enemy, "res://invalid.tres")
	assert_true(errors.any(func(value: String): return "Duplicate ability ID 'same'" in value))
	assert_true(errors.any(func(value: String): return "unconditional free action" in value))


func test_ability_rejects_invalid_cooldowns_null_action_and_missing_rules() -> void:
	var ability := EnemyAbility.new()
	ability.ability_id = &"broken"
	ability.cooldown_turns = 2
	ability.initial_cooldown = 3
	var errors := ability.validate("enemy")
	assert_true(errors.any(func(value: String): return "action" in value))
	assert_true(errors.any(func(value: String): return "initial_cooldown" in value))
	assert_true(errors.any(func(value: String): return "rules" in value))


func test_one_time_free_action_is_not_a_valid_fallback() -> void:
	var ability := _free_ability()
	ability.one_time_use = true
	var enemy := EnemyData.new()
	enemy.abilities = [ability]
	var errors := EnemyKitValidator.validate(enemy)
	assert_true(errors.any(func(value: String): return "unconditional free action" in value))

func test_random_hit_action_requires_the_complete_valid_candidate_pool() -> void:
	var ability := _free_ability()
	ability.action.target_type = Action.TargetType.RANDOM_ENEMY
	var errors := ability.validate("enemy")
	assert_true(errors.any(func(value: String): return "VALID_HERO_CANDIDATES" in value))
	ability.rules[0].selector.type = EnemyTargetSelector.Type.VALID_HERO_CANDIDATES
	assert_true(ability.validate("enemy").is_empty())
```

- [ ] **Step 2: Run the test and verify missing-type failures**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_ability_definitions -gexit
```

Expected: nonzero exit with parse errors for undefined `EnemyAbility`, `EnemyDecisionRule`, `EnemyDecisionCondition`, `EnemyTargetSelector`, and `EnemyKitValidator`.

- [ ] **Step 3: Implement the immutable resource shapes**

Implement the exported fields and validation contracts exactly:

```gdscript
# src/scripts/enemies/enemy_decision_condition.gd
extends Resource
class_name EnemyDecisionCondition

enum Type {
	ALWAYS,
	FIRST_TURN,
	SELF_HP_AT_MOST,
	ANY_ALLY_HP_AT_MOST,
	ANY_HERO_FOCUS_AT_LEAST,
	ANY_HERO_GUARD_AT_LEAST,
	ANY_HERO_GUARD_AT_MOST,
	ANY_HERO_BREACHED,
	SELF_MISSING_GUARD,
	ANY_ALLY_MISSING_GUARD,
	HAS_NAMED_CONDITION,
	LACKS_NAMED_CONDITION,
	LIVING_HERO_COUNT_AT_LEAST,
	LIVING_ALLY_COUNT_AT_LEAST,
	HERO_TURN_WITHIN,
}
enum Subject { SELF, ANY_ALLY, ANY_HERO }

@export var type: Type = Type.ALWAYS
@export var subject: Subject = Subject.SELF
@export var threshold: float = 0.0
@export var count: int = 1
@export var condition_name: String = ""

func validate(source: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if type in [Type.SELF_HP_AT_MOST, Type.ANY_ALLY_HP_AT_MOST] \
	and (threshold < 0.0 or threshold > 1.0):
		errors.append("%s condition HP threshold must be between 0 and 1." % source)
	if type in [Type.ANY_HERO_FOCUS_AT_LEAST, Type.ANY_HERO_GUARD_AT_LEAST,
		Type.ANY_HERO_GUARD_AT_MOST, Type.HERO_TURN_WITHIN] and threshold < 0.0:
		errors.append("%s condition threshold must be non-negative." % source)
	if type in [Type.LIVING_HERO_COUNT_AT_LEAST, Type.LIVING_ALLY_COUNT_AT_LEAST] and count < 1:
		errors.append("%s condition count must be at least 1." % source)
	if type in [Type.HAS_NAMED_CONDITION, Type.LACKS_NAMED_CONDITION] and condition_name.is_empty():
		errors.append("%s named-condition predicate requires condition_name." % source)
	return errors
```

```gdscript
# src/scripts/enemies/enemy_target_selector.gd
extends Resource
class_name EnemyTargetSelector

enum Type {
	SELF,
	ALL_HEROES,
	ALL_ALLIES,
	SEEDED_HERO,
	VALID_HERO_CANDIDATES,
	PREFERRED_CONDITION_HERO,
	HIGHEST_FOCUS_HERO,
	HIGHEST_GUARD_HERO,
	LOWEST_GUARD_HERO,
	HERO_CLOSEST_TO_ACTING,
	LOWEST_HP_PERCENT_ALLY,
	LEAST_GUARD_ALLY,
	ALLY_FURTHEST_FROM_ACTING,
}

@export var type: Type = Type.SEEDED_HERO
@export var condition_name: String = ""
@export var exclude_self := false

func validate(source: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if type == Type.PREFERRED_CONDITION_HERO and condition_name.is_empty():
		errors.append("%s preferred-condition selector requires condition_name." % source)
	return errors
```

```gdscript
# src/scripts/enemies/enemy_decision_rule.gd
extends Resource
class_name EnemyDecisionRule

@export var priority: int = 0
@export var conditions: Array[EnemyDecisionCondition] = []
@export var selector: EnemyTargetSelector
@export var reason: String = ""

func is_unconditional() -> bool:
	return conditions.is_empty() or conditions.all(func(value: EnemyDecisionCondition):
		return value != null and value.type == EnemyDecisionCondition.Type.ALWAYS
	)

func validate(source: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if selector == null:
		errors.append("%s rule requires a target selector." % source)
	else:
		errors.append_array(selector.validate(source))
	for index in conditions.size():
		if conditions[index] == null:
			errors.append("%s condition %d is null." % [source, index])
		else:
			errors.append_array(conditions[index].validate("%s condition %d" % [source, index]))
	return errors
```

```gdscript
# src/scripts/enemies/enemy_ability.gd
extends Resource
class_name EnemyAbility

@export var ability_id: StringName
@export var action: Action
@export_range(0, 99, 1) var cooldown_turns := 0
@export_range(0, 99, 1) var initial_cooldown := 0
@export var one_time_use := false
@export var rules: Array[EnemyDecisionRule] = []

func validate(source: String) -> PackedStringArray:
	var label := "%s ability '%s'" % [source, ability_id]
	var errors := PackedStringArray()
	if ability_id.is_empty(): errors.append("%s ability_id must not be empty." % source)
	if action == null: errors.append("%s action must not be null." % label)
	if initial_cooldown < 0 or initial_cooldown > cooldown_turns:
		errors.append("%s initial_cooldown must be between 0 and cooldown_turns." % label)
	if rules.is_empty(): errors.append("%s rules must not be empty." % label)
	for index in rules.size():
		if rules[index] == null:
			errors.append("%s rule %d is null." % [label, index])
		else:
			errors.append_array(rules[index].validate("%s rule %d" % [label, index]))
			var selector := rules[index].selector
			if action != null and selector != null:
				var uses_candidate_pool := selector.type == EnemyTargetSelector.Type.VALID_HERO_CANDIDATES
				if action.target_type == Action.TargetType.RANDOM_ENEMY and not uses_candidate_pool:
					errors.append("%s RANDOM_ENEMY rules require VALID_HERO_CANDIDATES." % label)
				elif action.target_type != Action.TargetType.RANDOM_ENEMY and uses_candidate_pool:
					errors.append("%s may use VALID_HERO_CANDIDATES only with RANDOM_ENEMY." % label)
	return errors
```

```gdscript
# src/scripts/enemies/enemy_kit_validator.gd
extends RefCounted
class_name EnemyKitValidator

static func validate(enemy: EnemyData, source: String = "") -> PackedStringArray:
	var label := source if not source.is_empty() else "enemy '%s'" % (enemy.enemy_id if enemy else "<null>")
	var errors := PackedStringArray()
	if enemy == null:
		errors.append("%s is null." % label)
		return errors
	var ids := {}
	var has_fallback := false
	for ability in enemy.abilities:
		if ability == null:
			errors.append("%s contains a null ability." % label)
			continue
		errors.append_array(ability.validate(label))
		if ids.has(ability.ability_id):
			errors.append("%s has Duplicate ability ID '%s'." % [label, ability.ability_id])
		ids[ability.ability_id] = true
		if ability.cooldown_turns == 0 and not ability.one_time_use \
		and ability.rules.any(func(rule: EnemyDecisionRule): return rule != null and rule.is_unconditional()):
			has_fallback = true
	if not has_fallback:
		errors.append("%s requires an unconditional free action." % label)
	return errors
```

Add this export to `EnemyData` alongside the legacy fields:

```gdscript
@export var abilities: Array[EnemyAbility] = []
```

Do not remove legacy fields until Task 5 because current production resources must continue parsing during Tasks 1–4.

- [ ] **Step 4: Run focused definition tests**

Run the Step 2 command.

Expected: all `test_enemy_ability_definitions` tests pass with zero failures.

- [ ] **Step 5: Import and commit generated sidecars with the task**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
git diff --check
```

Expected: both commands exit zero; new `.gd.uid` files exist for new scripts.

Commit:

```sh
git add src/scripts/enemies/enemy_decision_condition.gd src/scripts/enemies/enemy_decision_condition.gd.uid src/scripts/enemies/enemy_target_selector.gd src/scripts/enemies/enemy_target_selector.gd.uid src/scripts/enemies/enemy_decision_rule.gd src/scripts/enemies/enemy_decision_rule.gd.uid src/scripts/enemies/enemy_ability.gd src/scripts/enemies/enemy_ability.gd.uid src/scripts/enemies/enemy_kit_validator.gd src/scripts/enemies/enemy_kit_validator.gd.uid src/scripts/data/enemy_data.gd test/unit/test_enemy_ability_definitions.gd test/unit/test_enemy_ability_definitions.gd.uid
git commit -m "feat: define validated enemy cooldown abilities"
```

---

### Task 2: Per-Card Cooldown State

**Files:**
- Create: `src/scripts/enemies/enemy_ai_runtime_state.gd`
- Create: `test/unit/test_enemy_ai_runtime_state.gd`

**Interfaces:**
- Consumes: `Array[EnemyAbility]`
- Produces: `EnemyAIRuntimeState.initialize(abilities: Array[EnemyAbility]) -> void`
- Produces: `EnemyAIRuntimeState.is_ready(ability: EnemyAbility) -> bool`
- Produces: `EnemyAIRuntimeState.complete_turn(used_ability_id: StringName = &"") -> void`
- Produces: defensive read-only helpers `remaining(ability_id)` and `has_been_used(ability_id)`

- [ ] **Step 1: Write failing cooldown tests**

Create tests proving exact cooldown semantics and resource immutability:

```gdscript
extends GutTest

func _ability(id: StringName, cooldown: int, initial: int = 0, one_time := false) -> EnemyAbility:
	var value := EnemyAbility.new()
	value.ability_id = id
	value.action = Action.new()
	value.cooldown_turns = cooldown
	value.initial_cooldown = initial
	value.one_time_use = one_time
	return value

func test_initial_cooldown_and_three_skipped_turns() -> void:
	var basic := _ability(&"basic", 0)
	var major := _ability(&"major", 3)
	var state := EnemyAIRuntimeState.new()
	state.initialize([basic, major])
	assert_true(state.is_ready(major))
	state.complete_turn(&"major")
	assert_eq(state.remaining(&"major"), 3)
	for expected in [2, 1, 0]:
		state.complete_turn(&"basic")
		assert_eq(state.remaining(&"major"), expected)
	assert_true(state.is_ready(major))
	assert_eq(state.completed_turns, 4)

func test_recovery_turn_ticks_without_starting_an_ability() -> void:
	var major := _ability(&"major", 3, 2)
	var state := EnemyAIRuntimeState.new()
	state.initialize([major])
	state.complete_turn()
	assert_eq(state.remaining(&"major"), 1)

func test_one_time_use_and_duplicate_cards_are_independent() -> void:
	var once := _ability(&"once", 0, 0, true)
	var left := EnemyAIRuntimeState.new()
	var right := EnemyAIRuntimeState.new()
	left.initialize([once]); right.initialize([once])
	left.complete_turn(&"once")
	assert_false(left.is_ready(once))
	assert_true(right.is_ready(once))
	assert_false(once.one_time_use == false, "authored resource was not mutated")
```

- [ ] **Step 2: Run and verify the missing-state failure**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_ai_runtime_state -gexit
```

Expected: nonzero exit because `EnemyAIRuntimeState` is undefined.

- [ ] **Step 3: Implement cooldown state without storing mutable state on resources**

```gdscript
extends RefCounted
class_name EnemyAIRuntimeState

var completed_turns := 0
var _remaining: Dictionary[StringName, int] = {}
var _used_once: Dictionary[StringName, bool] = {}
var _abilities: Dictionary[StringName, EnemyAbility] = {}

func initialize(abilities: Array[EnemyAbility]) -> void:
	completed_turns = 0
	_remaining.clear(); _used_once.clear(); _abilities.clear()
	for ability in abilities:
		if ability == null: continue
		_abilities[ability.ability_id] = ability
		_remaining[ability.ability_id] = ability.initial_cooldown

func remaining(ability_id: StringName) -> int:
	return int(_remaining.get(ability_id, 0))

func has_been_used(ability_id: StringName) -> bool:
	return bool(_used_once.get(ability_id, false))

func is_ready(ability: EnemyAbility) -> bool:
	return ability != null and remaining(ability.ability_id) == 0 \
		and not (ability.one_time_use and has_been_used(ability.ability_id))

func complete_turn(used_ability_id: StringName = &"") -> void:
	for ability_id in _remaining.keys():
		_remaining[ability_id] = maxi(0, int(_remaining[ability_id]) - 1)
	if not used_ability_id.is_empty() and _abilities.has(used_ability_id):
		var ability: EnemyAbility = _abilities[used_ability_id]
		_remaining[used_ability_id] = ability.cooldown_turns
		if ability.one_time_use: _used_once[used_ability_id] = true
	completed_turns += 1
```

- [ ] **Step 4: Run the focused tests and commit**

Run the Step 2 command, then the isolated import command from Task 1.

Expected: tests and import exit zero.

Commit the script, generated `.uid`, and test files with:

```sh
git add src/scripts/enemies/enemy_ai_runtime_state.gd src/scripts/enemies/enemy_ai_runtime_state.gd.uid test/unit/test_enemy_ai_runtime_state.gd test/unit/test_enemy_ai_runtime_state.gd.uid
git commit -m "feat: track enemy ability cooldowns per card"
```

---

### Task 3: Conditions, Selectors, and Pure Decisions

**Files:**
- Create: `src/scripts/enemies/enemy_ai_context.gd`
- Create: `src/scripts/enemies/enemy_decision.gd`
- Create: `src/scripts/enemies/enemy_decision_engine.gd`
- Modify: `src/scripts/enemies/enemy_decision_condition.gd`
- Modify: `src/scripts/enemies/enemy_target_selector.gd`
- Create: `test/unit/test_enemy_decision_engine.gd`
- Modify: `test/unit/test_enemy_taunt_targeting.gd`

**Interfaces:**
- Produces: `EnemyAIContext.new(heroes, enemies, ticks_by_actor, encounter_seed)`
- Produces: `EnemyDecisionEngine.choose(enemy, abilities, state, context) -> EnemyDecision`
- Produces: `EnemyDecision.is_valid() -> bool`
- Produces: `EnemyDecisionCondition.matches(enemy, state, context) -> bool`
- Produces: `EnemyTargetSelector.select(enemy, state, context, salt) -> Array[ActorCard]`

- [ ] **Step 1: Write failing decision tests**

Cover high-priority free moves, urgent support, Taunt, stable ties, and target selectors:

```gdscript
extends GutTest

func test_high_focus_free_rule_beats_lower_priority_cooldown() -> void:
	var fixture := _fixture()
	fixture.echo.current_focus = 6
	var spike := _ability(&"spike", 0, 80, EnemyDecisionCondition.Type.ANY_HERO_FOCUS_AT_LEAST,
		EnemyTargetSelector.Type.HIGHEST_FOCUS_HERO, 5.0)
	var wave := _ability(&"wave", 4, 50, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.ALL_HEROES)
	var decision := EnemyDecisionEngine.choose(fixture.enemy, [spike, wave], fixture.state, fixture.context)
	assert_eq(decision.ability.ability_id, &"spike")
	assert_eq(decision.targets, [fixture.echo])
	_free_fixture(fixture)

func test_equal_priority_prefers_longer_cooldown_then_stable_seeded_target() -> void:
	var fixture := _fixture()
	var short := _ability(&"short", 2, 40, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.SEEDED_HERO)
	var long := _ability(&"long", 4, 40, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.SEEDED_HERO)
	var first := EnemyDecisionEngine.choose(fixture.enemy, [short, long], fixture.state, fixture.context)
	var second := EnemyDecisionEngine.choose(fixture.enemy, [short, long], fixture.state, fixture.context)
	assert_eq(first.ability.ability_id, &"long")
	assert_same(first.targets[0], second.targets[0])
	assert_eq(fixture.state.completed_turns, 0)
	_free_fixture(fixture)

func test_taunt_overrides_highest_focus_but_not_all_heroes() -> void:
	var fixture := _fixture()
	fixture.echo.current_focus = 10
	fixture.sands.active_conditions = [_taunt()]
	var single := _ability(&"single", 0, 0, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.HIGHEST_FOCUS_HERO)
	assert_eq(EnemyDecisionEngine.choose(fixture.enemy, [single], fixture.state, fixture.context).targets,
		[fixture.sands])
	var group := _ability(&"group", 0, 0, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.ALL_HEROES)
	assert_eq(EnemyDecisionEngine.choose(fixture.enemy, [group], fixture.state, fixture.context).targets,
		[fixture.sands, fixture.echo])
	_free_fixture(fixture)

func test_low_hp_percentage_selector_and_urgent_heal() -> void:
	var fixture := _fixture()
	fixture.ally.current_stats.max_hp = 1000; fixture.ally.current_hp = 400
	fixture.enemy.current_stats.max_hp = 100; fixture.enemy.current_hp = 60
	var heal := _ability(&"heal", 4, 100, EnemyDecisionCondition.Type.ANY_ALLY_HP_AT_MOST,
		EnemyTargetSelector.Type.LOWEST_HP_PERCENT_ALLY, 0.5)
	var attack := _ability(&"attack", 5, 90, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.SEEDED_HERO)
	var decision := EnemyDecisionEngine.choose(fixture.enemy, [heal, attack], fixture.state, fixture.context)
	assert_eq(decision.ability.ability_id, &"heal")
	assert_eq(decision.targets, [fixture.ally])
	_free_fixture(fixture)
```

In the same file, define `_fixture`, `_ability`, `_taunt`, and `_free_fixture` so every actor has `current_stats`, HP, Guard, battle priority, and a context with fixed ticks `{sands: 8, echo: 3, enemy: 6, ally: 12}` and seed `1234`.

- [ ] **Step 2: Run and verify missing decision types**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_decision_engine -gexit
```

Expected: nonzero exit because context, decision, and engine types are undefined and conditions/selectors have no runtime methods.

- [ ] **Step 3: Implement the read-only context and decision value**

```gdscript
# src/scripts/enemies/enemy_ai_context.gd
extends RefCounted
class_name EnemyAIContext

var heroes: Array[HeroCard] = []
var enemies: Array[EnemyCard] = []
var ticks_by_actor: Dictionary = {}
var encounter_seed := 0

func _init(living_heroes: Array[HeroCard], living_enemies: Array[EnemyCard],
	turn_ticks: Dictionary, seed_value: int) -> void:
	heroes.assign(living_heroes); enemies.assign(living_enemies)
	ticks_by_actor = turn_ticks.duplicate(); encounter_seed = seed_value

func ticks_until(actor: ActorCard) -> int:
	return int(ticks_by_actor.get(actor, 1 << 30))
```

```gdscript
# src/scripts/enemies/enemy_decision.gd
extends RefCounted
class_name EnemyDecision

var ability: EnemyAbility
var action: Action
var rule: EnemyDecisionRule
var targets: Array[ActorCard] = []
var reason: String = ""
var is_recovery := false

func is_valid() -> bool:
	return action != null and not targets.is_empty()
```

- [ ] **Step 4: Implement condition evaluation and target selection**

Add `matches()` to `EnemyDecisionCondition` with these semantics. Ally checks include the acting enemy because `context.enemies` is the complete living enemy team; “missing Guard” means zero Guard.

```gdscript
func matches(enemy: EnemyCard, state: EnemyAIRuntimeState, context: EnemyAIContext) -> bool:
	match type:
		Type.ALWAYS: return true
		Type.FIRST_TURN: return state.completed_turns == 0
		Type.SELF_HP_AT_MOST: return _hp_percent(enemy) <= threshold
		Type.ANY_ALLY_HP_AT_MOST: return context.enemies.any(func(ally: EnemyCard):
			return _hp_percent(ally) <= threshold)
		Type.ANY_HERO_FOCUS_AT_LEAST: return context.heroes.any(func(hero: HeroCard):
			return hero.current_focus >= threshold)
		Type.ANY_HERO_GUARD_AT_LEAST: return context.heroes.any(func(hero: HeroCard):
			return hero.current_guard >= threshold)
		Type.ANY_HERO_GUARD_AT_MOST: return context.heroes.any(func(hero: HeroCard):
			return hero.current_guard <= threshold)
		Type.ANY_HERO_BREACHED: return context.heroes.any(func(hero: HeroCard): return hero.is_breached)
		Type.SELF_MISSING_GUARD: return enemy.current_guard <= 0
		Type.ANY_ALLY_MISSING_GUARD: return context.enemies.any(func(ally: EnemyCard):
			return ally.current_guard <= 0)
		Type.HAS_NAMED_CONDITION: return _subjects(enemy, context).any(func(actor: ActorCard):
			return actor.has_condition(condition_name))
		Type.LACKS_NAMED_CONDITION: return _subjects(enemy, context).any(func(actor: ActorCard):
			return not actor.has_condition(condition_name))
		Type.LIVING_HERO_COUNT_AT_LEAST: return context.heroes.size() >= count
		Type.LIVING_ALLY_COUNT_AT_LEAST: return context.enemies.size() >= count
		Type.HERO_TURN_WITHIN: return context.heroes.any(func(hero: HeroCard):
			return context.ticks_until(hero) <= int(threshold))
	return false

func _subjects(enemy: EnemyCard, context: EnemyAIContext) -> Array[ActorCard]:
	match subject:
		Subject.SELF: return [enemy]
		Subject.ANY_ALLY: return _as_actor_cards(context.enemies)
		Subject.ANY_HERO: return _as_actor_cards(context.heroes)
	return []

func _hp_percent(actor: ActorCard) -> float:
	return float(actor.current_hp) / maxf(actor.current_stats.max_hp, 1.0)
```

Add an explicit typed-copy helper in this class as well; do not rely on typed-array covariance:

```gdscript
func _as_actor_cards(values: Array) -> Array[ActorCard]:
	var actors: Array[ActorCard] = []
	for value in values:
		if value is ActorCard: actors.append(value)
	return actors
```

Add `select()` to `EnemyTargetSelector` with these exact rules:

```gdscript
func select(enemy: EnemyCard, state: EnemyAIRuntimeState, context: EnemyAIContext,
	salt: String) -> Array[ActorCard]:
	var heroes: Array[HeroCard] = context.heroes.filter(func(hero: HeroCard):
		return is_instance_valid(hero) and not hero.is_defeated and not hero.is_untargetable()
	)
	var taunts: Array[HeroCard] = heroes.filter(func(hero: HeroCard): return hero.is_taunting())
	var hostile := type in [Type.SEEDED_HERO, Type.VALID_HERO_CANDIDATES,
		Type.PREFERRED_CONDITION_HERO,
		Type.HIGHEST_FOCUS_HERO, Type.HIGHEST_GUARD_HERO, Type.LOWEST_GUARD_HERO,
		Type.HERO_CLOSEST_TO_ACTING]
	if hostile and not taunts.is_empty(): heroes = taunts
	var allies: Array[EnemyCard] = context.enemies.filter(func(ally: EnemyCard):
		return is_instance_valid(ally) and not ally.is_defeated and (not exclude_self or ally != enemy)
	)
	match type:
		Type.SELF: return [enemy]
		Type.ALL_HEROES: return _as_actor_cards(heroes)
		Type.ALL_ALLIES: return _as_actor_cards(allies)
		Type.VALID_HERO_CANDIDATES: return _as_actor_cards(heroes)
		Type.PREFERRED_CONDITION_HERO:
			var preferred := heroes.filter(func(hero: HeroCard): return hero.has_condition(condition_name))
			return _seeded_one(preferred if not preferred.is_empty() else heroes,
				enemy, state, context, salt)
		Type.HIGHEST_FOCUS_HERO: return _extreme_one(heroes, func(hero: HeroCard): return hero.current_focus, true, enemy, state, context, salt)
		Type.HIGHEST_GUARD_HERO: return _extreme_one(heroes, func(hero: HeroCard): return hero.current_guard, true, enemy, state, context, salt)
		Type.LOWEST_GUARD_HERO: return _extreme_one(heroes, func(hero: HeroCard): return hero.current_guard, false, enemy, state, context, salt)
		Type.HERO_CLOSEST_TO_ACTING: return _extreme_one(heroes, func(hero: HeroCard): return context.ticks_until(hero), false, enemy, state, context, salt)
		Type.LOWEST_HP_PERCENT_ALLY: return _extreme_one(allies, func(ally: EnemyCard): return float(ally.current_hp) / maxf(ally.current_stats.max_hp, 1), false, enemy, state, context, salt)
		Type.LEAST_GUARD_ALLY: return _extreme_one(allies, func(ally: EnemyCard): return ally.current_guard, false, enemy, state, context, salt)
		Type.ALLY_FURTHEST_FROM_ACTING: return _extreme_one(allies, func(ally: EnemyCard): return context.ticks_until(ally), true, enemy, state, context, salt)
		_: return _seeded_one(heroes, enemy, state, context, salt)
```

Implement `_as_actor_cards` using the same explicit typed-copy body above. Implement `_seeded_one` and `_extreme_one` with `EnemyAIRuntimeState` as an argument, sort ties by `battle_priority`, then select `posmod(hash("%d:%d:%d:%s" % [context.encounter_seed, enemy.battle_priority, state.completed_turns, salt]), tied.size())`. They must not read `enemy.ai_state`, call `randf`/`randi`, or mutate an RNG; all decision inputs remain explicit.

- [ ] **Step 5: Implement pure decision evaluation**

```gdscript
extends RefCounted
class_name EnemyDecisionEngine

static func choose(enemy: EnemyCard, abilities: Array[EnemyAbility], state: EnemyAIRuntimeState,
	context: EnemyAIContext) -> EnemyDecision:
	var candidates: Array[Dictionary] = []
	for ability in abilities:
		if ability == null or not state.is_ready(ability): continue
		for index in ability.rules.size():
			var rule := ability.rules[index]
			if rule == null or not rule.conditions.all(func(condition: EnemyDecisionCondition):
				return condition != null and condition.matches(enemy, state, context)):
				continue
			var salt := "%s:%d" % [ability.ability_id, index]
			var targets := rule.selector.select(enemy, state, context, salt) if rule.selector else []
			if targets.is_empty(): continue
			candidates.append({"ability": ability, "rule": rule, "targets": targets, "salt": salt})
	if candidates.is_empty(): return EnemyDecision.new()
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left.rule.priority != right.rule.priority: return left.rule.priority > right.rule.priority
		if left.ability.cooldown_turns != right.ability.cooldown_turns: return left.ability.cooldown_turns > right.ability.cooldown_turns
		return _stable_key(enemy, state, context, left.salt) < _stable_key(enemy, state, context, right.salt)
	)
	var winner := candidates[0]
	var decision := EnemyDecision.new()
	decision.ability = winner.ability; decision.action = winner.ability.action
	decision.rule = winner.rule; decision.targets.assign(winner.targets)
	decision.reason = winner.rule.reason
	return decision

static func _stable_key(enemy: EnemyCard, state: EnemyAIRuntimeState,
	context: EnemyAIContext, salt: String) -> int:
	return hash("%d:%d:%d:%s" % [context.encounter_seed, enemy.battle_priority, state.completed_turns, salt])
```

- [ ] **Step 6: Migrate Taunt unit coverage to selectors**

Replace `base_turn_action`/`get_a_target()` setup in `test_enemy_taunt_targeting.gd` with `EnemyTargetSelector.select()`. Retain the established assertions: direct single target is restricted to Sands, `VALID_HERO_CANDIDATES` returns only Sands while Taunt is active, and `ALL_HEROES` remains the complete eligible living party rather than being narrowed by Taunt. Add one untargetable-hero assertion for both single-target and group selectors.

- [ ] **Step 7: Run decision and Taunt tests, import, and commit**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "enemy_decision_engine|enemy_taunt_targeting" -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
git diff --check
```

Expected: all selected tests pass and both commands exit zero.

Commit only the files from this task and their generated `.uid` files:

```sh
git add src/scripts/enemies/enemy_ai_context.gd src/scripts/enemies/enemy_ai_context.gd.uid src/scripts/enemies/enemy_decision.gd src/scripts/enemies/enemy_decision.gd.uid src/scripts/enemies/enemy_decision_engine.gd src/scripts/enemies/enemy_decision_engine.gd.uid src/scripts/enemies/enemy_decision_condition.gd src/scripts/enemies/enemy_target_selector.gd test/unit/test_enemy_decision_engine.gd test/unit/test_enemy_decision_engine.gd.uid test/unit/test_enemy_taunt_targeting.gd
git commit -m "feat: choose enemy actions from reactive priorities"
```

---

### Task 4: Battle Intent and Turn Integration

**Files:**
- Modify: `src/battle/enemy_card.gd`
- Modify: `src/battle/battle_manager.gd`
- Create: `test/integration/test_enemy_ai_intents.gd`

**Interfaces:**
- Consumes: `EnemyDecisionEngine.choose(enemy, abilities, state, context)`
- Produces: `EnemyCard.initialize_ai(encounter_seed: int) -> void`
- Produces: `EnemyCard.decide_intent(context: EnemyAIContext) -> void`
- Produces: `EnemyCard.complete_ai_turn(used_ability_id: StringName = &"") -> void`
- Produces: `BattleManager._enemy_ai_context() -> EnemyAIContext`

- [ ] **Step 1: Write failing integration coverage**

Create a fixture manager with two heroes and one quiet enemy. Protect these behaviors in `test_enemy_ai_intents.gd`:

```gdscript
func test_refresh_changes_reactive_intent_without_ticking_cooldowns() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 0
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"focus_attack")
	assert_eq(fixture.enemy.ai_state.completed_turns, 0)
	assert_eq(fixture.enemy.ai_state.remaining(&"focus_attack"), 0)
	_free_fixture(fixture)

func test_completed_turn_sets_only_used_cooldown_and_plans_next_intent() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	var used_id := fixture.enemy.intended_decision.ability.ability_id
	fixture.enemy.complete_ai_turn(used_id)
	assert_eq(fixture.enemy.ai_state.completed_turns, 1)
	assert_gt(fixture.enemy.ai_state.remaining(used_id), 0)
	fixture.manager._update_all_enemy_intents()
	assert_ne(fixture.enemy.intended_decision.ability.ability_id, used_id)
	_free_fixture(fixture)

func test_breached_enemy_intends_recovery_and_ticks_a_recovery_turn() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.enemy.is_breached = true
	fixture.manager._update_all_enemy_intents()
	assert_true(fixture.enemy.intended_decision.is_recovery)
	fixture.enemy.complete_ai_turn()
	assert_eq(fixture.enemy.ai_state.completed_turns, 1)
	_free_fixture(fixture)
```

The fixture supplies a free basic and a cooldown Focus attack whose high-Focus rule has the winning priority, assigns `recover_action`, and overrides intent UI animation and manager waits.

- [ ] **Step 2: Run and confirm missing integration APIs**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_ai_intents -gexit
```

Expected: nonzero exit for missing `initialize_ai`, `intended_decision`, and `complete_ai_turn`.

- [ ] **Step 3: Replace EnemyCard deck state with decision state**

Remove `base_turn_action`, `ai_index`, `used_overrides`, and sequence preparation. Add:

```gdscript
var ai_state := EnemyAIRuntimeState.new()
var intended_decision := EnemyDecision.new()
var encounter_seed := 0

func initialize_ai(seed_value: int) -> void:
	encounter_seed = seed_value
	ai_state.initialize(enemy_data.abilities)

func decide_intent(context: EnemyAIContext) -> void:
	var next := EnemyDecision.new()
	if is_breached and recover_action != null:
		next.action = recover_action; next.targets = [self]; next.reason = "recover_breach"
		next.is_recovery = true
	else:
		next = EnemyDecisionEngine.choose(self, enemy_data.abilities, ai_state, context)
	if not next.is_valid():
		push_error("Enemy '%s' could not produce a valid intent on AI turn %d." % [actor_name, ai_state.completed_turns])
		clear_intent(); return
	intended_decision = next
	intended_action = next.action
	intended_targets.assign(next.targets)
	_update_intent_ui()

func complete_ai_turn(used_ability_id: StringName = &"") -> void:
	ai_state.complete_turn(used_ability_id)

func clear_intent() -> void:
	intended_decision = EnemyDecision.new()
	intended_action = null; intended_targets = []
	_update_intent_ui()
```

Delete `_check_ai_overrides`, `_get_fallback_action`, and old action selection. Retain intent formatting and defense display.

- [ ] **Step 4: Build one immutable context per intent refresh**

In `BattleManager`, add:

```gdscript
var encounter_seed := 0

func _enemy_ai_context() -> EnemyAIContext:
	var ticks := {}
	for actor: ActorCard in actor_list:
		if not is_instance_valid(actor) or actor.is_defeated: continue
		ticks[actor] = maxi(ceili(float(TARGET_CT - actor.current_ct) / maxi(actor.get_ct_speed(), 1)), 0)
	return EnemyAIContext.new(get_living_heroes(), get_living_enemies(), ticks, encounter_seed)

func _update_all_enemy_intents() -> void:
	var context := _enemy_ai_context()
	for enemy: EnemyCard in get_living_enemies():
		if enemy != current_actor: enemy.decide_intent(context)
```

During spawn, assign battle priority first, then call `enemy_card.initialize_ai(encounter_seed)`. Remove `prepare_turn_base_action()` calls.

At the end of `execute_enemy_turn`, capture the decision before clearing it:

```gdscript
var used_ability_id := enemy.intended_decision.ability.ability_id \
	if enemy.intended_decision.ability != null else &""
await execute_action(enemy, action, targets, true, true)
if current_state == State.BATTLE_OVER: return
await wait(0.15)
enemy.clear_intent()
enemy.complete_ai_turn(used_ability_id)
```

Retain the existing post-turn manager flow that sets `current_actor = null` and then calls `_update_all_enemy_intents()`. That refresh computes the acting enemy's next visible intent from its newly completed cooldown state exactly once; the acting enemy remains excluded from refreshes while its action is still resolving.

Before executing, if the cached decision is no longer valid, recalculate once from `_enemy_ai_context()`. If it remains invalid, log the contextual error, call `complete_ai_turn()` with no ability, clear the executing-action recovery state, and proceed to the next actor safely.

- [ ] **Step 5: Run focused battle AI tests and established targeting tests**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "enemy_ai_intents|enemy_decision_engine|enemy_taunt_targeting|ctb_simulator" -gexit
```

Expected: all selected suites pass with zero failures.

- [ ] **Step 6: Commit battle integration**

```sh
git add src/battle/enemy_card.gd src/battle/battle_manager.gd test/integration/test_enemy_ai_intents.gd test/integration/test_enemy_ai_intents.gd.uid
git commit -m "feat: drive enemy intents from cooldown decisions"
```

---

### Task 5: Production Kit Migration and Legacy Removal

**Files:**
- Modify: `data/enemies/actors/attack_drone.tres`
- Modify: `data/enemies/actors/defense_drone.tres`
- Modify: `data/enemies/actors/guardian.tres`
- Modify: `data/enemies/actors/riot_drone.tres`
- Modify: `data/enemies/actors/scout_drone.tres`
- Modify: `data/enemies/actors/trooper.tres`
- Modify: `src/scripts/data/enemy_data.gd`
- Delete: `src/scripts/enemies/ai_override.gd`
- Delete: `src/scripts/enemies/ai_override.gd.uid`
- Modify: `src/singletons/encounter_database.gd`
- Modify: `test/integration/test_damage_content.gd`

**Interfaces:**
- Consumes: validated `EnemyData.abilities`
- Produces: every production enemy has a valid cooldown kit.
- Removes: legacy deck, pattern, index, and override APIs.

- [ ] **Step 1: Audit overlapping user changes before touching actor resources**

Run:

```sh
git status --short -- data/enemies/actors src/scripts/data/enemy_data.gd src/scripts/enemies/ai_override.gd
git diff -- data/enemies/actors/attack_drone.tres data/enemies/actors/defense_drone.tres data/enemies/actors/guardian.tres data/enemies/actors/riot_drone.tres data/enemies/actors/scout_drone.tres data/enemies/actors/trooper.tres
```

Expected: inspect every reported change. If a migration target contains pre-existing user edits, preserve them and do not stage unrelated hunks. If the migration cannot be separated safely, pause this task and ask the user to resolve or authorize the overlap.

- [ ] **Step 2: Add a failing production-content assertion**

In `test/integration/test_damage_content.gd`, scan `data/enemies/actors`, load every `.tres`, assert it is `EnemyData`, and assert `EnemyKitValidator.validate(resource, path).is_empty()`. Also assert no current actor has an empty ability list.

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_content -gexit
```

Expected: FAIL listing all six actors without cooldown abilities.

- [ ] **Step 3: Author exact migration metadata without changing action resources**

Use unconditional `SEEDED_HERO` rules for attacks, `LEAST_GUARD_ALLY` for Fortify, and the following matrix. Priorities are intentionally simple early-game identities, not final balance:

| Actor | Ability ID | Existing action | CD | Initial | Priority | Selector |
|---|---|---|---:|---:|---:|---|
| Attack Drone | `attack.basic` | Gunshot | 0 | 0 | 0 | Seeded hero |
| Attack Drone | `attack.double_shot` | Double Shot | 2 | 1 | 20 | Seeded hero |
| Attack Drone | `attack.mow_down` | Mow Down | 4 | 3 | 40 | All heroes |
| Attack Drone | `attack.rapid_fire` | Rapid Fire | 3 | 2 | 30 | Valid hero candidates used by the action |
| Defense Drone | `defense.fortify` | Fortify | 0 | 0 | 10 | Least-Guard ally |
| Defense Drone | `defense.gunshot` | Gunshot | 2 | 1 | 20 | Seeded hero |
| Guardian | `guardian.fortify` | Fortify | 0 | 0 | 10 | Least-Guard ally |
| Riot Drone | `riot.potshot` | Potshot | 0 | 0 | 0 | Seeded hero |
| Riot Drone | `riot.stun_baton` | Stun Baton | 2 | 1 | 20 | Hero closest to acting |
| Scout Drone | `scout.gunshot` | Gunshot | 0 | 0 | 0 | Seeded hero |
| Scout Drone | `scout.potshot` | Potshot | 2 | 1 | 10 | Seeded hero |
| Scout Drone | `scout.double_shot` | Double Shot | 3 | 2 | 20 | Seeded hero |
| Scout Drone | `scout.mow_down` | Mow Down | 4 | 3 | 30 | All heroes |
| Trooper | `trooper.gunshot` | Gunshot | 0 | 0 | 0 | Seeded hero |
| Trooper | `trooper.double_shot` | Double Shot | 2 | 1 | 20 | Seeded hero |
| Trooper | `trooper.shrapnel` | Shrapnel | 3 | 2 | 30 | Lowest-Guard hero |
| Trooper | `trooper.rapid_fire` | Rapid Fire | 4 | 3 | 40 | Valid hero candidates used by the action |

For `RANDOM_ENEMY` actions, use `VALID_HERO_CANDIDATES` so the selector returns the Taunt-filtered eligible candidate pool rather than one exact hero and the existing hit-plan distribution remains authoritative.

Use embedded `EnemyDecisionCondition`, `EnemyTargetSelector`, `EnemyDecisionRule`, and `EnemyAbility` subresources inside each actor `.tres`; reuse existing external action resources.

- [ ] **Step 4: Reject invalid encountered kits during database scan**

Before registering an encounter ID, validate every `EnemyData` in its `enemies` array. If any error exists, push each contextual error and do not add that encounter to `_id_map`. Register valid encounters in `_register_encounter` so normal/elite/boss arrays remain synchronized.

- [ ] **Step 5: Remove legacy AI fields and scripts**

Delete `AIPattern`, `ai_script_indices`, `ai_pattern`, `action_deck`, and `ai_overrides` from `EnemyData`. Delete `ai_override.gd` and its `.uid`. Confirm no references remain:

```sh
rg -n "action_deck|ai_pattern|ai_script_indices|ai_overrides|AIOverride|prepare_turn_base_action|base_turn_action" src data test
```

Expected: no matches.

- [ ] **Step 6: Run production content, battle, and full-loop focused tests**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "damage_content|enemy_ai|enemy_taunt_targeting|controller_playable_loop|game_manager_interactions" -gexit
git diff --check
```

Expected: import and tests exit zero, all production kits validate, and no parser errors occur.

- [ ] **Step 7: Commit only migration changes**

Stage the six actor files, `EnemyData`, database, content test, legacy-script deletions, and required generated sidecars. Review `git diff --cached` to ensure unrelated user changes are absent, then commit:

```sh
git commit -m "feat: migrate enemies to cooldown AI kits"
```

---

### Task 6: AI Foundation Verification

**Files:**
- Modify: `docs/testing/ctb-combat-checklist.md`

**Interfaces:**
- Verifies the complete cooldown-AI foundation before combat extensions or benchmark content.

- [ ] **Step 1: Add focused manual checks**

Add checklist items that require observing a current multi-action enemy across at least four own turns and confirming:

- its opening intent is identical after restarting with the same seed;
- cooldown abilities do not repeat before their authored gap;
- changing Taunt or Breach updates intent without advancing a cooldown;
- duplicate enemies keep independent cooldowns; and
- visible intent damage still matches the executed action.

- [ ] **Step 2: Run import, focused suites, and the complete isolated suite**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "enemy_ability_definitions|enemy_ai_runtime_state|enemy_decision_engine|enemy_ai_intents|enemy_taunt_targeting|damage_content" -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: all commands exit zero. Record exact test and assertion totals from the full suite; certificate and documented shutdown diagnostics are acceptable only with a zero exit.

- [ ] **Step 3: Commit checklist and any verification-only corrections**

```sh
git add docs/testing/ctb-combat-checklist.md
git commit -m "docs: add cooldown AI combat checks"
```

Do not mark interactive checklist items complete unless they were actually performed.
