# Battle Combatant Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate authoritative combat state from the current hero and enemy `Control` nodes while preserving the complete playable 2D battle and every existing combat rule.

**Architecture:** Introduce non-visual `BattleCombatant`, `HeroCombatant`, and `EnemyCombatant` nodes. Current `HeroCard` and `EnemyCard` scenes become presentations bound through a typed `CombatantPresentation` adapter; battle systems address combatants and use a registry only when they need screen-space presentation. This plan intentionally ends before importing or rendering any 3D asset.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6.1, existing data-driven action/condition/AI systems.

## Global Constraints

- Use Godot 4.6.3; Godot 4.7 remains deferred.
- Use vendored GUT 9.6.1 and the isolated test `HOME=/tmp/mars-godot-home` for every automated Godot run.
- Add no dependencies, plugins, save migrations, formation mechanics, combat-rule changes, or controller-binding changes.
- Preserve the current four face-button skills, left/right trigger shifts, directional target navigation, confirm/cancel semantics, mouse handoff, AI decisions, damage arithmetic, conditions, CTB order, and revival behavior.
- Keep the current hero and enemy card scenes visually and behaviorally unchanged throughout this phase.
- Do not import the Quaternius packs or create placeholder production models in this phase.
- Preserve the user's existing uncommitted `src/dev/endgame_battle_lab.tscn` change and any other unrelated work.
- Commit required `.uid` sidecars created by Godot for new GDScript files; never commit `.godot/`.

---

## Phase Boundary and Follow-up Plans

This specification spans three independently testable implementation efforts:

1. **This plan:** extract combatants, bind the current cards as presentations, and migrate gameplay identity away from visual nodes.
2. **3D vertical slice plan:** import selected Quaternius assets, create `BattleWorld`, `EnemyUnit3D`, projected HUDs, W/M formation anchors, the fixed camera, and one complete production encounter.
3. **Effects and migration plan:** first-person hero effects, enemy-to-panel attacks, shake settings, remaining enemy/environment migration, UI polish, and removal of obsolete card assets.

After this plan passes its full verification gate, pause and ask the user for local paths to the extracted Modular Sci-Fi MegaKit and Sci-Fi Essentials Kit. Do not request those files earlier.

## File Structure

### New combatant files

- `src/battle/combatants/battle_combatant.gd` — shared authoritative state, conditions, traits, damage modifiers, CT timing, HP/Guard/breach/defeat lifecycle, and semantic state signals.
- `src/battle/combatants/hero_combatant.gd` — hero data, battle roles, focus, shifting state, equipment traits, injury/boon initialization, and hero revival rules.
- `src/battle/combatants/enemy_combatant.gd` — enemy data/scaling, AI runtime state, locked intent, target revalidation, cooldown completion, and enemy recovery rules.
- `src/battle/presentation/combatant_presentation.gd` — typed non-visual presentation contract used by battle orchestration and targeting.
- `src/battle/presentation/card_combatant_presentation.gd` — adapter from the contract to the existing `ActorCard` controls.

### New tests

- `test/unit/test_battle_combatant.gd` — presentation-free shared combat rules and semantic signals.
- `test/unit/test_hero_combatant.gd` — role, focus, trait, boon, injury, and revival behavior without a `Control`.
- `test/unit/test_enemy_combatant.gd` — enemy setup, scaling, intent locking, revalidation, cooldowns, and recovery without a card.
- `test/integration/test_card_combatant_binding.gd` — current card scenes mirror combatant state and forward pointer events without owning gameplay state.

### Existing files changed by responsibility

- `src/battle/actor_card.gd` — presentation only; bind one combatant, render its signals, animate bars/conditions/target states, and expose no authoritative duplicate state.
- `src/battle/hero_card.gd` — hero-specific presentation and input only.
- `src/battle/enemy_card.gd` — temporary enemy-card presentation for this phase; intent rendering remains here but reads `EnemyCombatant`.
- `src/battle/battle_manager.gd` — create combatants and presentations separately; store combatants in `actor_list`; maintain the presentation registry.
- `src/battle/battle_scene.gd` — select `BattleCombatant` identities and obtain screen geometry through `CombatantPresentation`.
- `src/battle/battle_scene.tscn` — add an explicit non-visual `Combatants` owner and wire it into `BattleManager`.
- `src/battle/action_bar.gd`, `src/battle/action_button.gd` — consume `HeroCombatant` rather than `HeroCard` while preserving direct input behavior.
- `src/battle/ctb_simulator.gd`, `src/battle/turn_queue.gd`, `src/battle/actor_queue.gd` — project and render combatant identities; request presentation metadata only through combatant data or the registry.
- `src/battle/damage/*.gd` — replace `ActorCard`/`HeroCard` parameters and preview clones with combatants.
- `src/scripts/action_effects/*.gd` — execute against combatants.
- `src/scripts/conditions/*.gd`, `src/scripts/equipment/trait.gd` — store and query combatants rather than visual cards.
- `src/scripts/data/action.gd` — build presentation contexts and effect targets from combatants.
- `src/scripts/enemies/*.gd` — reason about `EnemyCombatant` and `HeroCombatant`.
- Existing battle, damage, AI, condition, targeting, CTB, and revival tests — construct or unwrap combatants at domain boundaries while retaining scene-level assertions on cards.

---

### Task 1: Introduce the shared combatant identity and immutable initialization boundary

**Files:**
- Create: `src/battle/combatants/battle_combatant.gd`
- Create: `test/unit/test_battle_combatant.gd`

**Interfaces:**
- Produces: `BattleCombatant.Faction`, `setup_base(stats: ActorStats, faction: Faction, manager: BattleManager = null) -> void`, `is_hero() -> bool`, `is_enemy() -> bool`, `get_speed() -> int`, `get_ct_speed() -> int`, and `get_action_ct_percent(action: Action) -> int`.
- Produces signals: `hp_changed(combatant: BattleCombatant, current_hp: int, max_hp: int)`, `guard_changed(combatant: BattleCombatant, current_guard: int)`, `conditions_changed(combatant: BattleCombatant)`, `breached(combatant: BattleCombatant)`, `defeated(combatant: BattleCombatant)`, `revived(combatant: BattleCombatant)`, `danger_changed(combatant: BattleCombatant, is_in_danger: bool)`, and `presentation_event(combatant: BattleCombatant, event: StringName, payload: Dictionary)`.

- [ ] **Step 1: Write failing presentation-free initialization and timing tests**

```gdscript
extends GutTest


func test_setup_owns_state_without_control_or_scene_nodes() -> void:
	var stats := ActorStats.new()
	stats.actor_name = "Test Unit"
	stats.max_hp = 120
	stats.starting_guard = 4
	stats.speed = 25
	var combatant := BattleCombatant.new()
	add_child_autofree(combatant)

	combatant.setup_base(stats, BattleCombatant.Faction.ENEMY)

	assert_eq(combatant.actor_name, "Test Unit")
	assert_eq(combatant.current_hp, 120)
	assert_eq(combatant.current_guard, 4)
	assert_true(combatant.is_enemy())
	assert_false(combatant is CanvasItem)


func test_speed_and_action_recovery_include_conditions_and_traits() -> void:
	var combatant := _combatant_with_stats(20, 3)
	var condition := Condition.new()
	condition.speed_scalar = 0.5
	condition.action_ct_multiplier = 0.8
	combatant.active_conditions.append(condition)
	var action := Action.new()
	action.ct_cost_percent = 75

	assert_eq(combatant.get_speed(), 30)
	assert_eq(combatant.get_action_ct_percent(action), 60)


func _combatant_with_stats(speed: int, guard: int) -> BattleCombatant:
	var stats := ActorStats.new()
	stats.actor_name = "Fixture"
	stats.max_hp = 100
	stats.starting_guard = guard
	stats.speed = speed
	var combatant := BattleCombatant.new()
	add_child_autofree(combatant)
	combatant.setup_base(stats, BattleCombatant.Faction.HERO)
	return combatant
```

- [ ] **Step 2: Run the new test and verify the class is missing**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_combatant -gexit
```

Expected: nonzero exit with `BattleCombatant` unresolved or the new test failing to parse.

- [ ] **Step 3: Implement the base node and state boundary**

```gdscript
extends Node
class_name BattleCombatant

enum Faction { HERO, ENEMY }

signal hp_changed(combatant: BattleCombatant, current_hp: int, max_hp: int)
signal guard_changed(combatant: BattleCombatant, current_guard: int)
signal conditions_changed(combatant: BattleCombatant)
signal breached(combatant: BattleCombatant)
signal defeated(combatant: BattleCombatant)
signal revived(combatant: BattleCombatant)
signal danger_changed(combatant: BattleCombatant, is_in_danger: bool)
signal presentation_event(
	combatant: BattleCombatant,
	event: StringName,
	payload: Dictionary,
)

const MAX_GUARD := 10

var battle_manager: BattleManager
var faction := Faction.HERO
var actor_name := ""
var current_stats: ActorStats
var current_hp := 0
var current_guard := 0
var current_ct := 0
var ct_speed_scale := 1.0
var battle_priority := 0
var is_valid_target := false
var is_breached := false
var is_in_danger := false
var is_defeated := false
var active_conditions: Array[Condition] = []
var active_traits: Array[Trait] = []


func setup_base(
	stats: ActorStats,
	combatant_faction: Faction,
	manager: BattleManager = null,
) -> void:
	assert(stats != null, "BattleCombatant requires ActorStats.")
	current_stats = stats
	faction = combatant_faction
	battle_manager = manager
	actor_name = stats.actor_name
	current_hp = stats.max_hp
	current_guard = stats.starting_guard
	current_ct = 0
	is_breached = false
	is_in_danger = false
	is_defeated = false


func is_hero() -> bool:
	return faction == Faction.HERO


func is_enemy() -> bool:
	return faction == Faction.ENEMY
```

Move `get_attack`, `get_psyche`, `get_speed`, `get_ct_speed`, `get_action_ct_percent`, `get_aim`, `get_incoming_aim_mods`, and `get_crit_damage_bonus` from `ActorCard` without changing their formulas. Keep them free of presentation calls.

- [ ] **Step 4: Generate the required UID and run the focused test**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_combatant -gexit
```

Expected: import exits zero; the new test passes with no parser error.

- [ ] **Step 5: Commit the identity boundary**

```bash
git add src/battle/combatants/battle_combatant.gd src/battle/combatants/battle_combatant.gd.uid test/unit/test_battle_combatant.gd test/unit/test_battle_combatant.gd.uid
git commit -m "refactor: add nonvisual battle combatant"
```

---

### Task 2: Move condition, trait, and damage-modifier rules into `BattleCombatant`

**Files:**
- Modify: `src/battle/combatants/battle_combatant.gd`
- Modify: `src/battle/actor_card.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/scripts/conditions/condition.gd`
- Modify: `src/scripts/conditions/condition_scale_with_debuffs.gd`
- Modify: `src/scripts/conditions/condition_source_power_bonus.gd`
- Modify: `src/scripts/equipment/trait.gd`
- Modify: `src/scripts/action_effects/pre_hit_effect.gd`
- Modify: `src/scripts/action_effects/pre_hit_effect_modify_attacker_stats.gd`
- Modify: `test/unit/test_battle_combatant.gd`
- Modify: `test/unit/test_damage_scaling_rules.gd`
- Modify: `test/unit/test_battle_condition_targets.gd`

**Interfaces:**
- Consumes: `BattleCombatant` state and faction from Task 1.
- Produces: `add_condition`, `has_condition`, `remove_condition`, `remove_debuffs`, `count_debuffs`, `_fire_condition_event`, `is_taunting`, `is_untargetable`, `get_damage_dealt_contributions`, `get_damage_taken_contributions`, and `_add_trait` on `BattleCombatant`.
- Changes: `Condition.attacker`, condition modifier hooks, trait modifier hooks, and pre-hit hooks temporarily accept `Node`, allowing the current cards and new combatants to coexist until Task 6 completes the domain migration.

- [ ] **Step 1: Add failing tests for presentation-free condition mutation and modifier composition**

```gdscript
func test_condition_add_remove_and_debuff_count_publish_semantic_changes() -> void:
	var combatant := _combatant_with_stats(20, 3)
	var changed_count := 0
	combatant.conditions_changed.connect(
		func(_actor: BattleCombatant): changed_count += 1
	)
	var debuff := Condition.new()
	debuff.condition_name = "Marked"
	debuff.condition_type = Condition.ConditionType.DEBUFF

	await combatant.add_condition(debuff)
	assert_true(combatant.has_condition("Marked"))
	assert_eq(combatant.count_debuffs(), 1)
	assert_eq(changed_count, 1)
	assert_true(await combatant.remove_condition("Marked"))
	assert_eq(changed_count, 2)


func test_damage_contributions_require_only_combatants() -> void:
	var attacker := _combatant_with_stats(20, 3)
	var target := _combatant_with_stats(20, 3)
	var condition := Condition.new()
	condition.condition_name = "Amplify"
	condition.damage_dealt_modifier = 0.25
	attacker.active_conditions.append(condition)

	assert_almost_eq(attacker.get_damage_dealt_modifier(target), 0.25, 0.0001)
```

- [ ] **Step 2: Run the combatant and scaling tests to verify missing methods and old card types fail**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_combatant -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_scaling_rules -gexit
```

Expected: nonzero exit caused by missing combatant methods or `ActorCard` parameter mismatches.

- [ ] **Step 3: Move shared condition and modifier logic without UI calls**

Copy the existing implementations from `ActorCard` into `BattleCombatant` for the produced methods listed above. Keep the card implementations intact until Task 4 can replace them with delegates in the same change that binds a model. Replace visual refresh calls in the combatant copy with semantic signals:

```gdscript
func _flush_condition_removal_notification() -> void:
	if _condition_removal_batch_depth > 0 or not _condition_removal_batch_dirty:
		return
	_condition_removal_batch_dirty = false
	conditions_changed.emit(self)


func _add_trait(trait_resource: Trait, tier: int) -> void:
	var trait_copy := trait_resource.duplicate()
	trait_copy.current_tier = tier
	active_traits.append(trait_copy)
```

In `_execute_condition_triggers`, replace every faction test based on view classes:

```gdscript
var source_is_hero := effect_source.is_hero() \
	if effect_source is BattleCombatant else effect_source is HeroCard
targets = battle_manager.get_targets(
	effect.target_type,
	source_is_hero,
	targets,
	contextual_attacker,
)
```

This compatibility branch exists only while cards and combatants coexist. Task 6 removes the `HeroCard` branch after all effect sources are combatants.

Emit `presentation_event.emit(self, &"passive_fired", {})` for the current passive-start cue rather than calling a hero-card signal.

- [ ] **Step 4: Retype condition and trait extension seams**

Use these transitional signatures throughout the listed condition, trait, and pre-hit files so the current card implementation remains parseable until its binding is complete:

```gdscript
var attacker: Node

func get_damage_dealt_power_bonus(
	_attacker: Node,
	_target: Node,
) -> float:
	return 0.0

func get_damage_taken_modifier(
	_attacker: Node,
	_target: Node,
) -> float:
	return 0.0

func on_trigger(
	_trigger_type: Trigger.TriggerType,
	_context: Dictionary,
	_owner: Node,
	_rank: int,
) -> void:
	pass
```

Update overrides to match exactly. The implementations may read the established combatant properties shared by both nodes during this transition. Replace tests that instantiate `ActorCard` only for arithmetic with `BattleCombatant` initialized through the shared fixture helper. Task 6 narrows every transitional `Node` signature to `BattleCombatant` after current cards are bound.

- [ ] **Step 5: Run focused condition and damage-rule coverage**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_combatant -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_scaling_rules -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_condition_targets -gexit
```

Expected: all selected tests pass. Card-scene presentation tests are not changed in this task.

- [ ] **Step 6: Commit shared rule ownership**

```bash
git add src/battle/combatants src/scripts/conditions src/scripts/equipment/trait.gd src/scripts/action_effects/pre_hit_effect.gd src/scripts/action_effects/pre_hit_effect_modify_attacker_stats.gd test/unit/test_battle_combatant.gd test/unit/test_damage_scaling_rules.gd test/unit/test_battle_condition_targets.gd
git commit -m "refactor: move shared combat rules into combatants"
```

---

### Task 3: Move HP, Guard, breach, healing, defeat, and revival state transitions

**Files:**
- Modify: `src/battle/combatants/battle_combatant.gd`
- Modify: `test/unit/test_battle_combatant.gd`
- Modify: `test/unit/test_damage_effect_execution.gd`
- Modify: `test/integration/test_battle_revival.gd`

**Interfaces:**
- Consumes: combatant conditions and semantic signals from Tasks 1–2.
- Produces: `take_one_hit`, `take_healing`, `modify_guard`, `breach`, `recover_breach`, `in_danger`, `defeat`, and `revive` as presentation-free combatant transitions.
- Produces presentation events: `damage_received`, `healing_received`, `guard_changed`, `danger_started`, `danger_ended`, `breach_started`, and `defeat_started`.

- [ ] **Step 1: Add failing state-transition tests with no `Control` tree**

```gdscript
func test_damage_and_healing_mutate_state_before_publishing_presentation() -> void:
	var combatant := _combatant_with_stats(20, 2)
	var events: Array[StringName] = []
	combatant.presentation_event.connect(
		func(_actor: BattleCombatant, event: StringName, _payload: Dictionary):
			events.append(event)
	)
	var request := DamageRequest.new(
		35, 0, 0, 1.0, 1, Action.DamageType.KINETIC, 0,
	)
	var result := DamageResult.new(
		request, 35.0, 0, 1.0, 1.0, 1.0, 35.0, 35,
	)
	var damage_effect := Effect_Damage.new()

	assert_eq(await combatant.take_one_hit(
		result, damage_effect, combatant, Action.DamageType.KINETIC,
	), 35)
	assert_eq(combatant.current_hp, 65)
	assert_has(events, &"damage_received")
	await combatant.take_healing(10)
	assert_eq(combatant.current_hp, 75)
	assert_has(events, &"healing_received")


func test_zero_guard_enters_danger_and_breach_resets_ct() -> void:
	var combatant := _combatant_with_stats(20, 2)
	combatant.current_ct = 123
	await combatant.modify_guard(-2)
	assert_true(combatant.is_in_danger)
	await combatant.breach()
	assert_true(combatant.is_breached)
	assert_false(combatant.is_in_danger)
	assert_eq(combatant.current_ct, 0)
```

- [ ] **Step 2: Run the test and verify lifecycle methods are missing**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_combatant -gexit
```

Expected: new lifecycle tests fail on missing methods.

- [ ] **Step 3: Move state mutation and replace direct visuals with payloads**

Copy the existing damage order and trigger order from `ActorCard.take_one_hit` into the combatant, preserving the live card implementation until Task 4 installs delegation. Preserve actual-damage clamping and lethal-reaction depth. Publish presentation after the authoritative value is assigned:

```gdscript
current_hp -= actual_damage
hp_changed.emit(self, current_hp, current_stats.max_hp)
presentation_event.emit(self, &"damage_received", {
	"result": result,
	"damage_type": resolved_damage_type,
	"actual_damage": actual_damage,
})
```

Use one idempotent defeat boundary:

```gdscript
func defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	current_ct = 0
	defeated.emit(self)
	presentation_event.emit(self, &"defeat_started", {})
```

Hero-only revival behavior is implemented in `HeroCombatant` in Task 5. Base healing never revives unless `is_revive` is true and the subclass accepts it.

- [ ] **Step 4: Adapt focused execution tests to call combatants**

Update test fixtures so `Effect_Damage` targets a `BattleCombatant`, then assert public state and semantic events. Keep separate scene-level revival coverage for the card binding task; do not delete it.

- [ ] **Step 5: Run damage, condition, and revival coverage**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_combatant -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_effect_execution -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_revival -gexit
```

Expected: all selected tests pass; no parser errors.

- [ ] **Step 6: Commit lifecycle extraction**

```bash
git add src/battle/combatants/battle_combatant.gd test/unit/test_battle_combatant.gd test/unit/test_damage_effect_execution.gd test/integration/test_battle_revival.gd
git commit -m "refactor: move combatant lifecycle out of cards"
```

---

### Task 4: Bind the existing cards through a presentation contract

**Files:**
- Create: `src/battle/presentation/combatant_presentation.gd`
- Create: `src/battle/presentation/card_combatant_presentation.gd`
- Modify: `src/battle/actor_card.gd`
- Modify: `src/battle/hero_card.gd`
- Modify: `src/battle/enemy_card.gd`
- Modify: `src/battle/hero_card.tscn`
- Modify: `src/battle/enemy_card.tscn`
- Create: `test/integration/test_card_combatant_binding.gd`
- Modify: `test/unit/test_actor_card_target_presentation.gd`

**Interfaces:**
- Consumes: `BattleCombatant` signals and state from Tasks 1–3.
- Produces: `CombatantPresentation.TargetState`, `bind(combatant: BattleCombatant)`, `get_target_screen_position() -> Vector2`, `is_target_visible() -> bool`, `set_target_presentation(state: TargetState) -> void`, `set_acting(active: bool) -> void`, `show_action(action_name: String) -> void`, `hide_action() -> void`, and `sync_visual_health() -> Tween`.
- Produces presentation input signals: `target_hovered(combatant: BattleCombatant)`, `target_unhovered(combatant: BattleCombatant)`, and `target_pressed(combatant: BattleCombatant)`.
- Produces: `ActorCard.bind_combatant(value: BattleCombatant) -> void`, a read-only `combatant` property, and temporary gameplay-property proxies that preserve parseability until Tasks 7–8.

- [ ] **Step 1: Write failing binding tests**

```gdscript
extends GutTest

const HeroCardScene := preload("res://src/battle/hero_card.tscn")


func test_card_mirrors_combatant_without_owning_duplicate_hp() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	var combatant := BattleCombatant.new()
	add_child_autofree(combatant)
	var stats := ActorStats.new()
	stats.actor_name = "Sands"
	stats.max_hp = 100
	combatant.setup_base(stats, BattleCombatant.Faction.HERO)

	card.bind_combatant(combatant)
	combatant.current_hp = 40
	combatant.hp_changed.emit(combatant, 40, 100)
	await get_tree().process_frame

	assert_same(card.combatant, combatant)
	assert_eq(card.hp_bar_actual.value, 40.0)
	assert_eq(card.current_hp, 40)
	card.current_hp = 55
	assert_eq(combatant.current_hp, 55)


func test_card_adapter_reports_live_screen_geometry() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	add_child_autofree(card)
	card.position = Vector2(90, 40)
	card.size = Vector2(200, 100)
	await get_tree().process_frame

	assert_eq(
		card.presentation.get_target_screen_position(),
		card.get_global_rect().get_center(),
	)
```

- [ ] **Step 2: Run binding and target-presentation tests to verify the contract is missing**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect card_combatant_binding -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_card_target_presentation -gexit
```

Expected: new binding tests fail because `bind_combatant` and `presentation` do not exist.

- [ ] **Step 3: Define the typed presentation contract**

```gdscript
extends Node
class_name CombatantPresentation

enum TargetState { NORMAL, AVAILABLE, SELECTED }

signal target_hovered(combatant: BattleCombatant)
signal target_unhovered(combatant: BattleCombatant)
signal target_pressed(combatant: BattleCombatant)

var combatant: BattleCombatant


func bind(value: BattleCombatant) -> void:
	combatant = value


func get_target_screen_position() -> Vector2:
	return Vector2.ZERO


func is_target_visible() -> bool:
	return false


func set_target_presentation(_state: TargetState) -> void:
	pass


func set_acting(_active: bool) -> void:
	pass


func show_action(_action_name: String) -> void:
	pass


func hide_action() -> void:
	pass


func sync_visual_health() -> Tween:
	return null
```

Implement the card adapter explicitly; the shared contract itself must not expose an `ActorCard` type:

```gdscript
extends CombatantPresentation
class_name CardCombatantPresentation

var card: ActorCard


func bind(value: BattleCombatant) -> void:
	super.bind(value)
	card.target_hovered.connect(
		func(_card: ActorCard): target_hovered.emit(combatant)
	)
	card.target_unhovered.connect(
		func(_card: ActorCard): target_unhovered.emit(combatant)
	)
	if card is HeroCard:
		(card as HeroCard).hero_clicked.connect(
			func(_card: HeroCard): target_pressed.emit(combatant)
		)
	elif card is EnemyCard:
		(card as EnemyCard).enemy_clicked.connect(
			func(_card: EnemyCard): target_pressed.emit(combatant)
		)


func get_target_screen_position() -> Vector2:
	return card.get_global_rect().get_center() if is_instance_valid(card) else Vector2.ZERO


func is_target_visible() -> bool:
	return is_instance_valid(card) and card.is_visible_in_tree()


func set_target_presentation(state: TargetState) -> void:
	if not is_instance_valid(card):
		return
	match state:
		TargetState.NORMAL:
			card.set_target_presentation(ActorCard.TargetPresentation.NORMAL)
		TargetState.AVAILABLE:
			card.set_target_presentation(ActorCard.TargetPresentation.AVAILABLE)
		TargetState.SELECTED:
			card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)


func set_acting(active: bool) -> void:
	card.highlight(active)


func show_action(action_name: String) -> void:
	card.show_action(action_name)


func hide_action() -> void:
	card.hide_action()


func sync_visual_health() -> Tween:
	return card.sync_visual_health()
```

- [ ] **Step 4: Reduce `ActorCard` to visual state and signal rendering**

Add a child adapter to both card scenes and bind it through:

```gdscript
@onready var presentation := $CombatantPresentation as CardCombatantPresentation
var combatant: BattleCombatant


func bind_combatant(value: BattleCombatant) -> void:
	assert(value != null, "ActorCard requires a BattleCombatant.")
	_ensure_battle_manager()
	combatant = value
	presentation.card = self
	presentation.bind(value)
	value.hp_changed.connect(_on_combatant_hp_changed)
	value.guard_changed.connect(_on_combatant_guard_changed)
	value.conditions_changed.connect(_on_combatant_conditions_changed)
	value.danger_changed.connect(_on_combatant_danger_changed)
	value.breached.connect(_on_combatant_breached)
	value.defeated.connect(_on_combatant_defeated)
	value.revived.connect(_on_combatant_revived)
	value.presentation_event.connect(_on_combatant_presentation_event)
	_render_full_state()


func _ensure_battle_manager() -> void:
	if battle_manager == null:
		battle_manager = get_parent().get_node_or_null("%BattleManager") as BattleManager
```

Remove the backing ownership for HP, Guard, CT, stats, conditions, traits, breach, danger, and defeat from `ActorCard` after every visual read uses `combatant`. Keep temporary proxy properties so code migrated in Tasks 6–7 continues to parse. Each proxy must read and write the bound combatant rather than retain a second value; for example:

```gdscript
var current_hp: int:
	get: return combatant.current_hp
	set(value): combatant.current_hp = value

var active_conditions: Array[Condition]:
	get: return combatant.active_conditions
```

Apply the same proxy pattern to `actor_name`, `current_stats`, `current_guard`, `current_ct`, `is_breached`, `is_in_danger`, `is_defeated`, `active_traits`, `battle_priority`, `ct_speed_scale`, and `is_valid_target`. Add `_require_combatant()` assertions to setup and mutation paths so an unbound card fails immediately. Task 8 deletes these proxies once the manager and domain files no longer call them.

Until Task 7 retypes `BattleManager`, card handlers also re-emit the current card-facing signals with their existing signatures:

```gdscript
func _on_combatant_hp_changed(
	_actor: BattleCombatant,
	value: int,
	max_value: int,
) -> void:
	hp_bar_actual.value = value
	hp_value.text = Utils.commafy(value)
	hp_changed.emit(value, max_value)


func _on_combatant_guard_changed(_actor: BattleCombatant, value: int) -> void:
	update_guard_bar()
	armor_changed.emit(value)


func _on_combatant_conditions_changed(_actor: BattleCombatant) -> void:
	_update_conditions_ui()
	actor_conditions_changed.emit()


func _on_combatant_breached(_actor: BattleCombatant) -> void:
	actor_breached.emit(self)


func _on_combatant_defeated(_actor: BattleCombatant) -> void:
	actor_defeated.emit(self)


func _on_combatant_revived(_actor: BattleCombatant) -> void:
	actor_revived.emit(self)
```

Task 7 connects the manager directly to combatant signals; Task 8 removes these compatibility emissions while preserving pointer and presentation-only card signals.

Refactor `update_guard_bar` to render only; remove its current `armor_changed.emit(...)` so the compatibility handler above emits exactly once per combatant change.

Keep the live game operational before specialized combatants exist. In this task, `HeroCard.setup(data)` and `EnemyCard.setup(...)` each create a child `BattleCombatant` with the correct faction, bind it, and then initialize the unchanged card visuals:

```gdscript
# HeroCard, after HeroData has calculated its stats.
_ensure_battle_manager()
var model := BattleCombatant.new()
add_child(model)
model.setup_base(hero_data.stats, BattleCombatant.Faction.HERO, battle_manager)
bind_combatant(model)
await _setup_card_visuals()
```

Use the equivalent enemy flow after enemy scaling, with `Faction.ENEMY`. Rename the visual portion of `ActorCard.setup_base(stats)` to `_setup_card_visuals()`; it reads the already-bound combatant and initializes bars, labels, panels, and target presentation without creating gameplay state.

Until Tasks 6–7 migrate callers, retain thin card compatibility methods for shared gameplay. Methods such as `take_one_hit`, `take_healing`, `modify_guard`, `breach`, `recover_breach`, `add_condition`, condition queries, stat queries, and condition-trigger dispatch immediately delegate to `combatant`; they must not mutate card-owned backing fields. Hero-specific role/focus code and enemy-specific AI code remain on their cards only until Task 5.

Map semantic events explicitly:

```gdscript
func _on_combatant_presentation_event(
	_actor: BattleCombatant,
	event: StringName,
	payload: Dictionary,
) -> void:
	match event:
		&"damage_received":
			_spawn_damage_popup(
				payload.result.final_damage,
				payload.damage_type,
				payload.result.is_critical,
			)
			spawn_particles.emit(get_global_rect().get_center(), "gunshot")
			shake_panel(1.0)
		&"passive_fired":
			if self is HeroCard:
				(self as HeroCard).passive_fired.emit()
```

- [ ] **Step 5: Preserve current card visual tests**

Update card tests to bind a combatant before asserting bars, focus, conditions, acting gold, and target states. Keep the current scene nodes and visual expectations unchanged.

- [ ] **Step 6: Run card binding, target-presentation, and revival tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect card_combatant_binding -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_card_target_presentation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_revival -gexit
```

Expected: all selected tests pass; cards display model state and retain their existing visuals.

- [ ] **Step 7: Commit the card adapter**

```bash
git add src/battle/presentation src/battle/actor_card.gd src/battle/hero_card.gd src/battle/enemy_card.gd src/battle/hero_card.tscn src/battle/enemy_card.tscn test/integration/test_card_combatant_binding.gd test/unit/test_actor_card_target_presentation.gd test/integration/test_battle_revival.gd
git commit -m "refactor: bind actor cards to combatants"
```

---

### Task 5: Extract hero and enemy specializations

**Files:**
- Modify: `src/battle/combatants/battle_combatant.gd`
- Create: `src/battle/combatants/hero_combatant.gd`
- Create: `src/battle/combatants/enemy_combatant.gd`
- Modify: `src/battle/hero_card.gd`
- Modify: `src/battle/enemy_card.gd`
- Modify: `src/battle/enemy_card.tscn`
- Modify: `src/scripts/data/enemy_data.gd`
- Modify: `src/scripts/enemies/enemy_ai_context.gd`
- Modify: `src/scripts/enemies/enemy_decision.gd`
- Modify: `src/scripts/enemies/enemy_decision_condition.gd`
- Modify: `src/scripts/enemies/enemy_decision_engine.gd`
- Modify: `src/scripts/enemies/enemy_target_selector.gd`
- Create: `test/unit/test_hero_combatant.gd`
- Create: `test/unit/test_enemy_combatant.gd`
- Modify: `test/unit/test_enemy_decision_engine.gd`
- Modify: `test/unit/test_enemy_taunt_targeting.gd`
- Modify: `test/integration/test_enemy_ai_intents.gd`

**Interfaces:**
- Consumes: `BattleCombatant` and card binding from Tasks 1–4.
- Produces: `HeroCombatant.setup(data: HeroData, manager: BattleManager = null)`, role getters, `shift_role`, `modify_focus`, `get_scaled_focus_cost`, and hero revival.
- Produces: `EnemyCombatant.setup(data: EnemyData, fight_level: int, is_elite: bool, is_boss: bool, hp_multiplier: float, manager: BattleManager = null)`, `initialize_ai`, `decide_intent`, `revalidate_intent_targets`, `complete_ai_turn`, and `clear_intent`.
- Changes AI context and decisions to arrays of combatants.

- [ ] **Step 1: Write failing hero-model tests**

```gdscript
func _hero_data_with_three_roles() -> HeroData:
	var data := HeroData.new()
	data.hero_name = "Test Hero"
	data.derived_state_is_prebuilt = true
	data.stats = ActorStats.new()
	data.stats.actor_name = data.hero_name
	data.stats.max_hp = 100
	data.stats.starting_focus = 5
	for role_id: String in ["a", "b", "c"]:
		var definition := RoleDefinition.new()
		definition.role_id = role_id
		definition.role_name = role_id.to_upper()
		var role := RoleData.new()
		role.source_definition = definition
		data.role_definitions.append(definition)
		data.unlocked_role_ids.append(role_id)
		data.battle_roles[role_id] = role
	return data


func test_focus_and_role_shift_work_without_hero_card() -> void:
	var hero := HeroCombatant.new()
	add_child_autofree(hero)
	var data := _hero_data_with_three_roles()
	hero.setup(data)
	var original := hero.get_current_role()

	await hero.modify_focus(-2, {"paid_focus_cost": 2})
	await hero.shift_role("right")

	assert_eq(hero.current_focus, data.stats.starting_focus - 2)
	assert_ne(hero.get_current_role(), original)
	assert_true(hero.shifted_this_turn)
```

- [ ] **Step 2: Write failing enemy-model intent tests**

Copy the exact `_hero_data_with_three_roles()` fixture above into `test_enemy_combatant.gd` so the test has no dependency on another test script.

```gdscript
func test_enemy_locks_intent_against_hero_combatants() -> void:
	var hero := HeroCombatant.new()
	add_child_autofree(hero)
	var hero_data := _hero_data_with_three_roles()
	hero.setup(hero_data)
	var enemy := EnemyCombatant.new()
	add_child_autofree(enemy)
	var enemy_data := preload("res://data/enemies/actors/attack_drone.tres").duplicate(true) as EnemyData
	enemy.setup(enemy_data, 1, false, false, 1.0)
	var context := EnemyAIContext.new(
		[hero], [enemy], {hero: 0, enemy: 0}, 77,
	)

	enemy.initialize_ai(77)
	enemy.decide_intent(context)

	assert_not_null(enemy.intended_action)
	assert_eq(enemy.intended_targets, [hero])
```

- [ ] **Step 3: Run focused hero and enemy tests to verify classes and AI typing are incomplete**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect hero_combatant -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_combatant -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_decision_engine -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_taunt_targeting -gexit
```

Expected: nonzero exit from missing specialization behavior and old AI card types.

- [ ] **Step 4: Move hero gameplay out of `HeroCard`**

Move hero data, loaded roles, focus, role index, shift state, trait setup, boon/injury setup, focus spending/refund, role selection, and revival rules into `HeroCombatant`. Publish `focus_changed(hero: HeroCombatant)` and semantic presentation events for `role_changed`, `focus_changed`, `revived`, and `defeated`.

`HeroCard` keeps only role/focus rendering, slide animation, recoloring, and GUI input. Preserve the current data-taking entry point temporarily so the battle manager remains runnable before Task 7, and add the final model-taking entry point beside it:

```gdscript
func setup(data: HeroData) -> void:
	_ensure_battle_manager()
	var model := HeroCombatant.new()
	add_child(model)
	model.setup(data, battle_manager)
	setup_from_combatant(model)


func setup_from_combatant(model: HeroCombatant) -> void:
	_ensure_battle_manager()
	bind_combatant(model)
	model.focus_changed.connect(_on_focus_changed)
	model.presentation_event.connect(_on_hero_presentation_event)
	_render_hero_state()


```

The child-owned model is only a migration bridge. Task 7 changes the manager to create and own the model under `BattleScene/Combatants`; Task 8 removes `setup(data)` and leaves `setup_from_combatant` as the sole card setup path.

Keep temporary hero-card compatibility getters for `hero_data`, `loaded_roles`, `current_role_index`, `current_focus`, and `shifted_this_turn`, plus delegates for role getters, `modify_focus`, `shift_role`, and `get_scaled_focus_cost`. Each reads or calls `combatant as HeroCombatant`; none stores a second value. `_on_focus_changed` refreshes the bar and re-emits the existing zero-argument `focus_updated` signal exactly once. These bridges keep the current action bar and manager green until Task 7 retypes them.

- [ ] **Step 5: Move enemy gameplay and AI state out of `EnemyCard`**

Move enemy data duplication/scaling, AI runtime state, locked decisions, intended action/targets, target revalidation, cooldown completion, recovery intent, and intent clearing into `EnemyCombatant`.

Move the shared recovery action out of the card scene and into enemy gameplay data:

```gdscript
# EnemyData
@export var recover_action: Action = preload(
	"res://data/enemies/actions/recover_breach.tres"
)
```

`EnemyCombatant.setup` reads `enemy_data.recover_action`. Remove the `recover_action` export assignment and now-unused resource entry from `enemy_card.tscn`; individual enemy resources may override the data field later without coupling recovery rules to a presentation.

Use combatant targets throughout:

```gdscript
var intended_targets: Array[BattleCombatant] = []

func decide_intent(context: EnemyAIContext) -> void:
	var next := EnemyDecisionEngine.choose(self, enemy_data.abilities, ai_state, context)
	var intent_changed := intended_action != next.action \
		or not _targets_match(next.targets)
	intended_decision = next
	intended_action = next.action
	intended_targets.assign(next.targets)
	presentation_event.emit(self, &"intent_changed", {
		"changed": intent_changed,
	})
```

`EnemyCard` retains intent text/tooltip rendering, defense gauges, flash animation, defeat fade, portrait, and click input. It reads `EnemyCombatant` and never owns AI state. As with the hero card, keep the current data-taking `setup(...)` as a temporary bridge that calls `_ensure_battle_manager()`, creates a child `EnemyCombatant` with that manager, then delegates to `setup_from_combatant(model: EnemyCombatant)`. The model-taking path also calls `_ensure_battle_manager()` before binding. Task 7 switches the manager to the model-taking path and Task 8 deletes the bridge.

Until Task 7, expose `enemy_data`, `ai_state`, `intended_decision`, `intended_action`, `intended_targets`, and `encounter_seed` as read-only model proxies. Keep `initialize_ai`, `decide_intent`, `revalidate_intent_targets`, `complete_ai_turn`, and `clear_intent` as delegates to `EnemyCombatant`; the card's only implementation work after delegation is refreshing intent visuals when the model publishes `intent_changed`.

- [ ] **Step 6: Retype the AI domain behind the temporary neutral bridge**

Add the phase's only migration helper to `BattleCombatant`; it names no presentation class:

```gdscript
static func resolve_model(value: Node) -> BattleCombatant:
	if value is BattleCombatant:
		return value
	var candidate: Variant = value.get("combatant") if value != null else null
	assert(candidate is BattleCombatant, "Expected a combatant or bound presentation.")
	return candidate as BattleCombatant
```

The `EnemyAIContext` constructor temporarily accepts untyped input arrays from the card-authoritative manager, then stores only combatants. Normalize CTB projection keys through the same helper:

```gdscript
for value: Node in living_heroes:
	heroes.append(BattleCombatant.resolve_model(value) as HeroCombatant)
for value: Node in living_enemies:
	enemies.append(BattleCombatant.resolve_model(value) as EnemyCombatant)
for value: Node in turn_ticks:
	ticks_by_actor[BattleCombatant.resolve_model(value)] = turn_ticks[value]
```

Use `Array[HeroCombatant]`, `Array[EnemyCombatant]`, and `Array[BattleCombatant]` inside AI contexts, decisions, selectors, and conditions. Replace class-based allegiance checks with `is_hero()` and `is_enemy()`. Keep seeded tie-breaking, taunt, untargetable, cooldown, and locked-intent algorithms unchanged. Task 7 narrows the constructor inputs and deletes the resolver when the manager owns combatants.

- [ ] **Step 7: Run hero, enemy, AI, intent, and condition tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect hero_combatant -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_combatant -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_decision_engine -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_taunt_targeting -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_ai_intents -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_condition_targets -gexit
```

Expected: all selected tests pass with no `HeroCard` or `EnemyCard` types in `src/scripts/enemies/`.

- [ ] **Step 8: Commit specializations**

```bash
git add src/battle/combatants src/battle/hero_card.gd src/battle/enemy_card.gd src/battle/enemy_card.tscn src/scripts/data/enemy_data.gd src/scripts/enemies test/unit/test_hero_combatant.gd test/unit/test_enemy_combatant.gd test/unit/test_enemy_decision_engine.gd test/unit/test_enemy_taunt_targeting.gd test/integration/test_enemy_ai_intents.gd
git commit -m "refactor: separate hero and enemy combatants"
```

---

### Task 6: Decouple action and damage internals from card classes through a temporary model bridge

**Files:**
- Modify: `src/battle/combatants/battle_combatant.gd`
- Modify: `src/scripts/data/action.gd`
- Modify: `src/scripts/conditions/condition.gd`
- Modify: `src/scripts/conditions/condition_scale_with_debuffs.gd`
- Modify: `src/scripts/conditions/condition_source_power_bonus.gd`
- Modify: `src/scripts/equipment/trait.gd`
- Modify: `src/scripts/action_effects/action_effect.gd`
- Modify: `src/scripts/action_effects/effect_apply_condition.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`
- Modify: `src/scripts/action_effects/effect_damage_inversion.gd`
- Modify: `src/scripts/action_effects/effect_healing.gd`
- Modify: `src/scripts/action_effects/effect_modify_ct.gd`
- Modify: `src/scripts/action_effects/effect_modify_focus.gd`
- Modify: `src/scripts/action_effects/effect_modify_guard.gd`
- Modify: `src/scripts/action_effects/effect_modify_stat.gd`
- Modify: `src/scripts/action_effects/effect_presentation_context.gd`
- Modify: `src/scripts/action_effects/effect_recover_breach.gd`
- Modify: `src/scripts/action_effects/effect_remove_condition.gd`
- Modify: `src/scripts/action_effects/effect_remove_debuffs.gd`
- Modify: `src/scripts/action_effects/effect_swap_resources.gd`
- Modify: `src/scripts/action_effects/pre_hit_effect.gd`
- Modify: `src/scripts/action_effects/pre_hit_effect_modify_attacker_stats.gd`
- Modify: `src/battle/damage/combatant_snapshot.gd`
- Modify: `src/battle/damage/damage_context.gd`
- Modify: `src/battle/damage/damage_preview.gd`
- Modify: `src/battle/damage/damage_resolver.gd`
- Modify: `test/unit/test_damage_effect_execution.gd`
- Modify: `test/unit/test_damage_preview.gd`
- Modify: `test/integration/test_damage_content.gd`
- Modify: `test/unit/test_action_ct_recovery.gd`
- Modify: `test/unit/test_ctb_action_content.gd`

**Interfaces:**
- Consumes: `BattleCombatant`, `HeroCombatant`, and `EnemyCombatant` from Tasks 1–5.
- Consumes: the temporary `BattleCombatant.resolve_model(value: Node) -> BattleCombatant` migration boundary introduced in Task 5.
- Produces: action/effect/damage internals containing no visual-card type checks.
- Changes: public seams called by the still-card-authoritative manager temporarily accept `Node`, immediately resolve it to a combatant, and use combatants thereafter. Task 7 narrows those public seams to `BattleCombatant` in the same change that migrates the manager.
- Changes: `EffectPresentationContext.actor`, `target`, and `targets` are combatants even though presentation rendering remains in card adapters.

- [ ] **Step 1: Convert focused tests to presentation-free combatants and confirm they fail against old signatures**

Replace arithmetic-only construction such as:

```gdscript
var attacker := ActorCard.new()
var target := EnemyCard.new()
```

with:

```gdscript
var attacker := HeroCombatant.new()
var target := EnemyCombatant.new()
add_child_autofree(attacker)
add_child_autofree(target)
var attacker_stats := ActorStats.new()
attacker_stats.actor_name = "Attacker"
attacker_stats.max_hp = 100
var target_stats := ActorStats.new()
target_stats.actor_name = "Target"
target_stats.max_hp = 100
attacker.setup_base(attacker_stats, BattleCombatant.Faction.HERO)
target.setup_base(target_stats, BattleCombatant.Faction.ENEMY)
```

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_effect_execution -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_preview -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_content -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect action_ct_recovery -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_action_content -gexit
```

Expected: nonzero exit from old card-typed APIs.

- [ ] **Step 2: Extend coverage for the temporary neutral model resolver**

Use the migration bridge introduced with AI:

```gdscript
static func resolve_model(value: Node) -> BattleCombatant:
	if value is BattleCombatant:
		return value
	var candidate: Variant = value.get("combatant") if value != null else null
	assert(candidate is BattleCombatant, "Expected a combatant or bound presentation.")
	return candidate as BattleCombatant
```

Add a focused test that a combatant resolves to itself and that a bound `HeroCard` resolves to its model. Task 7 deletes this function after the manager migration proves no caller needs it.

- [ ] **Step 3: Remove card types from action and effect internals**

Use this transitional base signature on entry points still invoked by `BattleManager`:

```gdscript
func execute(
	attacker_node: Node,
	parent_targets: Array,
	battle_manager: BattleManager,
	action: Action = null,
	context: Dictionary = {},
) -> void:
	var attacker := BattleCombatant.resolve_model(attacker_node)
	var targets: Array[BattleCombatant] = []
	for value: Node in parent_targets:
		targets.append(BattleCombatant.resolve_model(value))
	await _execute_for_combatants(attacker, targets, battle_manager, action, context)
```

The concrete implementation may remain inline instead of using `_execute_for_combatants`, but after the first normalization lines it may refer only to `BattleCombatant`, `HeroCombatant`, or `EnemyCombatant`. Replace `attacker is HeroCard` with `attacker.is_hero()` and focus-specific casts with `attacker as HeroCombatant` after checking faction.

Keep the transitional `Node` signatures introduced in Task 2 on condition, trait, and pre-hit public hooks, but resolve each argument at the top of the implementation. No gameplay implementation may name or test `ActorCard`, `HeroCard`, or `EnemyCard`.

Preserve the awaited breach-reaction order when damage begins targeting models. Add a transitional `BattleManager._on_combatant_breached(breached: BattleCombatant)` that normalizes each `actor_list` entry with `resolve_model`, updates the card-backed turn queue, refreshes enemy recovery intent on `EnemyCombatant`, and awaits opposing combatants' `ON_ENEMY_BREACHED` triggers. `BattleCombatant.breach()` awaits this method before its own `ON_BREACHED` trigger. Remove the old manager call from the `ActorCard.breach()` delegate in the same step so the reaction fires exactly once.

- [ ] **Step 4: Move damage previews and snapshots to resolved combatants**

At each damage entry point still called by the manager, accept `Node` and immediately call `BattleCombatant.resolve_model`. Internal helpers, `DamageContext`, and `CombatantSnapshot` use `BattleCombatant` exclusively. Replace preview copying with non-visual models:

```gdscript
static func _copy_target(target: BattleCombatant) -> BattleCombatant:
	var copy: BattleCombatant = HeroCombatant.new() \
		if target.is_hero() else EnemyCombatant.new()
	copy.setup_base(
		target.current_stats.duplicate(true),
		target.faction,
	)
	copy.current_hp = target.current_hp
	copy.current_guard = target.current_guard
	copy.current_ct = target.current_ct
	copy.is_breached = target.is_breached
	copy.is_defeated = target.is_defeated
	copy.active_conditions.assign(target.active_conditions.map(
		func(condition: Condition): return condition.duplicate(true)
	))
	if copy is HeroCombatant and target is HeroCombatant:
		(copy as HeroCombatant).current_focus = target.current_focus
	return copy
```

`CombatantSnapshot.capture(actor: BattleCombatant)` reads focus only from `HeroCombatant`. Existing card callers are covered by an outer preview entry point that resolves before capture.

- [ ] **Step 5: Preserve presentation descriptions while changing identity types**

`EffectPresentationContext` continues supplying the same action-description bindings, but all actor fields are combatants. Enemy-card intent rendering passes its bound `EnemyCombatant` and intended combatant targets into the existing description and preview functions.

- [ ] **Step 6: Run all damage and action-content tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_calculator -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_hit_plan -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_scaling_rules -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_effect_execution -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_preview -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_content -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect action_ct_recovery -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_action_content -gexit
```

Expected: all selected tests pass while the current card-driven manager remains playable; `rg -n '\\bActorCard\\b|\\bHeroCard\\b|\\bEnemyCard\\b' src/scripts/action_effects src/battle/damage src/scripts/data/action.gd` returns no matches.

- [ ] **Step 7: Commit the green migration bridge**

```bash
git add src/battle/combatants/battle_combatant.gd src/battle/actor_card.gd src/battle/battle_manager.gd src/scripts/data/action.gd src/scripts/action_effects src/scripts/conditions src/scripts/equipment/trait.gd src/battle/damage test/unit/test_battle_combatant.gd test/unit/test_damage_effect_execution.gd test/unit/test_damage_preview.gd test/integration/test_damage_content.gd test/unit/test_action_ct_recovery.gd test/unit/test_ctb_action_content.gd
git commit -m "refactor: decouple action domain from cards"
```

---

### Task 7: Make `BattleManager`, CTB, and targeting authoritative on combatants

**Files:**
- Modify: `src/battle/combatants/battle_combatant.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/battle/battle_scene.gd`
- Modify: `src/battle/battle_scene.tscn`
- Modify: `src/battle/action_bar.gd`
- Modify: `src/battle/action_button.gd`
- Modify: `src/battle/ctb_simulator.gd`
- Modify: `src/battle/turn_queue.gd`
- Modify: `src/battle/actor_queue.gd`
- Modify: `src/scripts/data/action.gd`
- Modify: `src/scripts/conditions/condition.gd`
- Modify: `src/scripts/conditions/condition_scale_with_debuffs.gd`
- Modify: `src/scripts/conditions/condition_source_power_bonus.gd`
- Modify: `src/scripts/equipment/trait.gd`
- Modify: `src/scripts/action_effects/action_effect.gd`
- Modify: `src/scripts/action_effects/effect_apply_condition.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`
- Modify: `src/scripts/action_effects/effect_damage_inversion.gd`
- Modify: `src/scripts/action_effects/effect_healing.gd`
- Modify: `src/scripts/action_effects/effect_modify_ct.gd`
- Modify: `src/scripts/action_effects/effect_modify_focus.gd`
- Modify: `src/scripts/action_effects/effect_modify_guard.gd`
- Modify: `src/scripts/action_effects/effect_modify_stat.gd`
- Modify: `src/scripts/action_effects/effect_presentation_context.gd`
- Modify: `src/scripts/action_effects/effect_recover_breach.gd`
- Modify: `src/scripts/action_effects/effect_remove_condition.gd`
- Modify: `src/scripts/action_effects/effect_remove_debuffs.gd`
- Modify: `src/scripts/action_effects/effect_swap_resources.gd`
- Modify: `src/scripts/action_effects/pre_hit_effect.gd`
- Modify: `src/scripts/action_effects/pre_hit_effect_modify_attacker_stats.gd`
- Modify: `src/battle/damage/combatant_snapshot.gd`
- Modify: `src/battle/damage/damage_context.gd`
- Modify: `src/battle/damage/damage_preview.gd`
- Modify: `src/battle/damage/damage_resolver.gd`
- Modify: `test/unit/test_ctb_simulator.gd`
- Modify: `test/integration/test_turn_queue.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `test/integration/test_controller_playable_loop.gd`
- Modify: `test/integration/test_battle_revival.gd`
- Modify: `test/integration/test_endgame_battle_lab.gd`
- Modify: `test/integration/test_battle_responsive_layout.gd`
- Modify: `test/integration/test_game_manager_interactions.gd`

**Interfaces:**
- Consumes: combatants, specialized models, cards, and presentation contract from Tasks 1–6.
- Produces: `BattleManager.actor_list: Array[BattleCombatant]`, `current_actor: BattleCombatant`, `get_living_heroes() -> Array[HeroCombatant]`, `get_living_enemies() -> Array[EnemyCombatant]`, `register_presentation(combatant, presentation)`, `presentation_for(combatant)`, and `unregister_presentation(combatant)`.
- Produces: `BattleScene` target memory and current target as combatant identities.
- Produces: action, condition, trait, pre-hit, damage, preview, and description entry points narrowed from the Task 6 `Node` bridge to combatants.

- [ ] **Step 1: Add failing manager/registry and target-geometry tests**

Add assertions to `test_battle_controller_navigation.gd`:

```gdscript
func test_target_selection_owns_combatant_and_reads_geometry_from_presentation() -> void:
	var fixture := await _navigation_fixture()
	var enemy := fixture.enemy.combatant
	fixture.scene._set_current_target(enemy)

	assert_same(fixture.scene._current_target, enemy)
	assert_same(
		fixture.manager.presentation_for(enemy),
		fixture.enemy.presentation,
	)
	assert_eq(
		fixture.enemy.get_target_presentation(),
		ActorCard.TargetPresentation.SELECTED,
	)
```

Add an integration assertion that `manager.actor_list.all(func(value): return value is BattleCombatant)` after spawning the real battle scene.

- [ ] **Step 2: Run manager, controller, CTB, and revival tests to verify old card identity fails**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_simulator -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_revival -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect endgame_battle_lab -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect game_manager_interactions -gexit
```

Expected: new combatant-identity assertions fail.

- [ ] **Step 3: Spawn models and cards separately**

Add `Combatants` under `BattleScene` and export it on `BattleManager` as `combatant_root: Node`. For each hero:

```gdscript
var hero := HeroCombatant.new()
combatant_root.add_child(hero)
hero.setup(hero_data, self)
var card := hero_card_scene.instantiate() as HeroCard
hero_area.add_child(card)
card.setup_from_combatant(hero)
register_presentation(hero, card.presentation)
actor_list.append(hero)
```

Use the equivalent `EnemyCombatant` setup before binding `EnemyCard` through `setup_from_combatant(enemy)`. Assign immutable `battle_priority` to combatants, and apply duplicate suffixes to combatant names before the first intent or CTB projection.

- [ ] **Step 4: Implement the presentation registry**

```gdscript
var _presentations: Dictionary = {}


func register_presentation(
	combatant: BattleCombatant,
	presentation: CombatantPresentation,
) -> void:
	assert(combatant != null and presentation != null)
	_presentations[combatant] = presentation


func presentation_for(combatant: BattleCombatant) -> CombatantPresentation:
	return _presentations.get(combatant) as CombatantPresentation


func unregister_presentation(combatant: BattleCombatant) -> void:
	_presentations.erase(combatant)
```

Battle teardown and presentation-replacement paths remove registry entries before freeing combatants or presentations. Defeat does **not** unregister a presentation: the defeated view remains available for its animation and for legal revival.

- [ ] **Step 5: Retype manager, CTB, queue, and action-bar identity**

Use combatant faction rather than view classes:

```gdscript
var candidate_is_hero := candidate.actor.is_hero()
var incumbent_is_hero := incumbent.actor.is_hero()
```

`ActorQueue.setup` accepts `BattleCombatant`; it reads the role from `HeroCombatant` and enemy abbreviation from the combatant name. `ActionBar.load_actions` accepts `HeroCombatant` and reads its current role and focus.

- [ ] **Step 6: Narrow the temporary domain seams and delete the bridge**

Once `BattleManager` stores and passes combatants, change every Task 6 public `Node` argument to the narrowest correct combatant type. Condition, trait, pre-hit, general effect, damage, preview, and description contracts use `BattleCombatant`; hero-only and enemy-only APIs use `HeroCombatant` and `EnemyCombatant` after explicit faction checks. Delete `BattleCombatant.resolve_model` and its temporary bridge assertions.

Run the type audit:

```bash
rg -n 'resolve_model|attacker_node: Node|_attacker: Node|_target: Node' src/battle/combatants src/scripts/action_effects src/scripts/conditions src/scripts/equipment/trait.gd src/battle/damage
rg -n '\bActorCard\b|\bHeroCard\b|\bEnemyCard\b' src/scripts/action_effects src/scripts/conditions src/scripts/equipment/trait.gd src/battle/damage src/scripts/data/action.gd
```

Expected: both commands return no matches. Presentation adapters may still name card classes, but gameplay-domain files may not.

- [ ] **Step 7: Retype battle targeting and geometry lookup**

Store `_current_target`, `_navigation_origin`, `_last_enemy_target`, and `_last_hero_target` as combatants. Replace every direct `global_position`, `size`, and visibility read with:

```gdscript
func _target_position(combatant: BattleCombatant) -> Vector2:
	var presentation := manager.presentation_for(combatant)
	return presentation.get_target_screen_position() \
		if presentation != null else Vector2.ZERO


func _is_presentation_visible(combatant: BattleCombatant) -> bool:
	var presentation := manager.presentation_for(combatant)
	return presentation != null and presentation.is_target_visible()
```

Target state changes call `presentation.set_target_presentation(CombatantPresentation.TargetState.SELECTED)` or the corresponding semantic state. Confirmation sends the selected combatant to manager methods typed as `HeroCombatant` or `EnemyCombatant`.

- [ ] **Step 8: Preserve direct controller mappings and pointer ownership**

Do not change `project.godot` input actions. Keep `ActionBar._unhandled_input` behavior: four action slots in action state, context-sensitive confirm/cancel during targeting, trigger shifts, and no GUI focus traversal. On registration, connect `CombatantPresentation.target_hovered`, `target_unhovered`, and `target_pressed` to manager handlers typed with `BattleCombatant`; stop connecting manager input directly to hero/enemy card signals. Update only the selected actor types in tests.

- [ ] **Step 9: Run all battle identity and input tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_simulator -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_revival -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_ai_intents -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect endgame_battle_lab -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_responsive_layout -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect game_manager_interactions -gexit
```

Expected: all selected tests pass; the current 2D battle remains fully playable.

- [ ] **Step 10: Commit combatant authority**

```bash
git add src/battle/combatants/battle_combatant.gd src/battle/battle_manager.gd src/battle/battle_scene.gd src/battle/battle_scene.tscn src/battle/action_bar.gd src/battle/action_button.gd src/battle/ctb_simulator.gd src/battle/turn_queue.gd src/battle/actor_queue.gd src/scripts/data/action.gd src/scripts/action_effects src/scripts/conditions src/scripts/equipment/trait.gd src/battle/damage test/unit/test_ctb_simulator.gd test/integration/test_turn_queue.gd test/integration/test_battle_controller_navigation.gd test/integration/test_controller_playable_loop.gd test/integration/test_battle_revival.gd test/integration/test_endgame_battle_lab.gd test/integration/test_battle_responsive_layout.gd test/integration/test_game_manager_interactions.gd
git commit -m "refactor: make battle manager combatant authoritative"
```

---

### Task 8: Remove card-domain compatibility and verify the foundation

**Files:**
- Modify: `src/battle/actor_card.gd`
- Modify: `src/battle/hero_card.gd`
- Modify: `src/battle/enemy_card.gd`
- Modify: `docs/testing/ctb-combat-checklist.md`
- Test: complete automated suite

**Interfaces:**
- Consumes: the authoritative combatant and presentation registry completed in Tasks 1–7.
- Produces: a current 2D battle in which cards are replaceable presentations and no gameplay-domain file depends on a visual-card type.

- [ ] **Step 1: Run the domain-type and visual-state audits**

Run:

```bash
rg -n '\bActorCard\b|\bHeroCard\b|\bEnemyCard\b' src/scripts src/battle/damage src/battle/ctb_simulator.gd
rg -n '^var (actor_name|current_stats|current_hp|current_guard|current_ct|is_breached|is_in_danger|is_defeated|active_conditions|active_traits)' src/battle/actor_card.gd src/battle/hero_card.gd src/battle/enemy_card.gd
```

Expected before cleanup: any remaining matches are limited to presentation files or identified compatibility remnants. The duplicated-state scan must be empty after cleanup.

- [ ] **Step 2: Remove compatibility proxies and duplicate gameplay ownership**

Cards may retain only `combatant`, visual node references, tweens, presentation state, and input signals. Replace any remaining card-domain read with the bound model:

```gdscript
name_label.text = combatant.actor_name
hp_bar_actual.value = combatant.current_hp
for condition: Condition in combatant.active_conditions:
	_render_condition(condition)
```

Delete unused card methods that mutate gameplay. Do not retain wrappers named `take_one_hit`, `modify_guard`, `add_condition`, `shift_role`, or `decide_intent` on presentation classes.

- [ ] **Step 3: Add the foundation regression item to the manual checklist**

Add a focused checklist section requiring one controller-only and one mouse battle on the unchanged 2D presentation. Verify face-button actions, trigger shifts, directional targeting, hover/click, intent, conditions, damage, breach, defeat, revival, and CTB correspondence.

- [ ] **Step 4: Parse the project under the isolated Godot home**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
```

Expected: exit zero with no parser error.

- [ ] **Step 5: Run the complete automated suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: exit zero and every test passes. Record exact test and assertion totals. Documented macOS certificate and shutdown diagnostics are acceptable; parser errors, crashes, unexpected failures, and nonzero exits are not.

- [ ] **Step 6: Perform current-presentation manual acceptance**

Run one complete controller-only battle and one representative mouse battle using the current card presentation. Record the commit, OS, resolution, controller/connection, and concise observations in `docs/testing/ctb-combat-checklist.md`. Leave Steam Deck hardware items unchecked unless run on the device.

- [ ] **Step 7: Commit the completed foundation**

```bash
git add src/battle/actor_card.gd src/battle/hero_card.gd src/battle/enemy_card.gd docs/testing/ctb-combat-checklist.md
git status --short
git commit -m "refactor: complete battle combatant foundation"
```

Before committing, confirm `src/dev/endgame_battle_lab.tscn` and all unrelated user files are unstaged.

- [ ] **Step 8: Stop at the asset handoff gate**

Report the exact full-suite totals and manual results. Ask the user for local filesystem paths to the extracted Quaternius Modular Sci-Fi MegaKit and Sci-Fi Essentials Kit. Inspect those source trees read-only before writing the 3D vertical-slice plan; select only the required models, animations, textures, materials, shaders, and license files for the first encounter.
