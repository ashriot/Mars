# CTB Recovery and Scrollable Right Queue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build deterministic signed-CT turn simulation, exact action recovery percentages, migrated self-acceleration content, and a scrollable right-side fixed-band portrait queue.

**Architecture:** A new pure `CTBSimulator` projects future turns from copied actor records and deterministic priority. `BattleManager` owns active-turn display composition, action preview adjustments, and snapshotted recovery; actors aggregate condition and equipment multipliers. A right-side queue keeps a larger active card fixed above a clipped, scrollable future-turn rail and renders cumulative ticks through a focused custom perimeter-gauge control.

**Tech Stack:** Godot 4.6.3, GDScript, Godot text resources/scenes, GUT 9.6.1.

## Global Constraints

- Use Godot 4.6.3; do not change the engine version, dependencies, or vendored plugins.
- Use `HOME=/tmp/mars-godot-home` for every automated Godot run.
- Preserve unrelated dirty files and commit only each task's listed files plus required Godot sidecars.
- Signed direct CT remains unbounded; effective action CT is clamped to `10-200%`.
- Effective Speed is consistently clamped to at least `1`.
- Equal ticks resolve by higher Speed, heroes before enemies, then immutable battle priority.
- The active actor is projection entry zero until its turn ends.
- Fixed gauge bands represent cumulative ticks from now: `0-20`, `21-40`, `41-60`, saturated at `60+`.
- Gold is reserved for the current turn; projected heroes use cyan and enemies use magenta.
- The queue publishes one active entry plus `20` future turns; at least `8` future cards are fully visible at `1920x1080`.
- The larger active card is fixed above the future-turn viewport; right stick, mouse wheel, and touch drag scroll only future turns.
- Preview refreshes preserve and clamp scroll position; an actual active-actor change resets it to the top.
- Do not rewrite general action tooltip prose or add free-action behavior.

## File Structure

- Create `src/battle/ctb_simulator.gd` — pure future-turn projection and deterministic tie priority.
- Create `test/unit/test_ctb_simulator.gd` — signed CT, Speed clamp, tie, and repeatability tests.
- Modify `src/battle/battle_manager.gd` — spawn priorities, active projection composition, preview deltas, recovery lifecycle, and selected CT display.
- Modify `src/battle/actor_card.gd` — immutable battle priority and action CT modifier aggregation.
- Modify `src/scripts/data/action.gd` — authored `ct_cost_percent`; remove unused CT APIs.
- Modify `src/scripts/conditions/condition.gd` — condition action-CT multiplier.
- Modify `src/scripts/equipment/trait.gd` — equipment-trait action-CT multiplier hook.
- Modify `src/scripts/action_effects/effect_modify_ct.gd` — signed neutral `ct_change_percent` terminology.
- Modify CT-bearing `.tres` files under `data/` — self-boost migration and direct-effect property rename.
- Create `src/battle/ctb_gauge.gd` — rounded-rectangle perimeter geometry and fixed tick-band rendering.
- Modify `src/battle/actor_queue.gd` and `src/battle/actor_queue.tscn` — role-icon/enemy-abbreviation portrait entry.
- Modify `src/battle/turn_queue.gd` and `src/battle/turn_queue.tscn` — fixed active slot, scrollable vertical future rail, occurrence-aware layout, overflow affordance, and current-only animation ownership.
- Modify `src/battle/battle_scene.tscn` — reserved right rail, selected-action CT label, and non-overlapping combat layout.
- Create `test/unit/test_ctb_gauge.gd` — fixed bands and perimeter geometry tests.
- Create `test/unit/test_actor_queue.gd` — enemy abbreviation and temporary content tests.
- Modify `test/integration/test_battle_controller_navigation.gd` — real preview/recovery and selected CT display coverage.
- Create `test/integration/test_turn_queue.gd` — active entry, repeated occurrence, colors, and stale-tween coverage.
- Create `docs/testing/ctb-combat-checklist.md` and modify `docs/README.md` — manual visual and lifecycle acceptance.

---

### Task 1: Deterministic Signed-CT Simulator and Projection Contract

**Files:**
- Create: `src/battle/ctb_simulator.gd`
- Modify: `src/battle/actor_card.gd:48-60`
- Modify: `src/battle/battle_manager.gd:58-246`
- Create: `test/unit/test_ctb_simulator.gd`

**Interfaces:**
- Produces: `CTBSimulator.project(actors: Array, target_ct: int, num_turns: int = 10, ct_adjustments: Dictionary = {}) -> Array`
- Produces: `ActorCard.battle_priority: int`
- Produces: `BattleManager._display_projection(ct_adjustments: Dictionary = {}, count: int = 10) -> Array`
- Consumes: `ActorCard.current_ct`, `ActorCard.get_speed()`, and hero/enemy runtime types.

- [ ] **Step 1: Add failing simulator tests**

Create `test/unit/test_ctb_simulator.gd` with real lightweight cards and public-boundary assertions:

```gdscript
extends GutTest

func _actor(hero: bool, speed: int, ct: int, priority: int) -> ActorCard:
	var actor: ActorCard = HeroCard.new() if hero else EnemyCard.new()
	var stats := ActorStats.new()
	stats.speed = speed
	actor.current_stats = stats
	actor.current_ct = ct
	actor.battle_priority = priority
	return actor

func test_negative_ct_requires_extra_ticks() -> void:
	var actor := _actor(true, 100, -1000, 0)
	var queue := CTBSimulator.project([actor], 5000, 1)
	assert_eq(queue[0].ticks_needed, 60)
	actor.free()

func test_zero_or_negative_speed_uses_one_consistently() -> void:
	var actor := _actor(true, 0, 0, 0)
	var queue := CTBSimulator.project([actor], 5000, 1)
	assert_eq(queue[0].ticks_needed, 5000)
	actor.free()

func test_exact_ties_use_speed_then_faction_then_priority() -> void:
	var fast_enemy := _actor(false, 200, 0, 3)
	var slow_hero := _actor(true, 100, 2500, 2)
	var first_hero := _actor(true, 100, 2500, 0)
	var second_hero := _actor(true, 100, 2500, 1)
	var queue := CTBSimulator.project(
		[second_hero, slow_hero, fast_enemy, first_hero], 5000, 4
	)
	assert_same(queue[0].actor, fast_enemy, "higher Speed wins an equal arrival tick")
	assert_same(queue[1].actor, first_hero, "heroes then use immutable lower priority")
	for actor in [fast_enemy, slow_hero, first_hero, second_hero]:
		actor.free()

func test_repeated_projection_is_identical() -> void:
	var first := _actor(false, 100, 0, 0)
	var second := _actor(false, 100, 0, 1)
	var first_projection := CTBSimulator.project([first, second], 5000, 10)
	var second_projection := CTBSimulator.project([first, second], 5000, 10)
	assert_eq(
		first_projection.map(func(entry): return entry.actor),
		second_projection.map(func(entry): return entry.actor)
	)
	first.free()
	second.free()

func test_adjustments_do_not_mutate_live_ct() -> void:
	var actor := _actor(true, 100, 0, 0)
	var queue := CTBSimulator.project([actor], 5000, 1, {actor: -500})
	assert_eq(queue[0].ticks_needed, 55)
	assert_eq(actor.current_ct, 0)
	actor.free()
```

- [ ] **Step 2: Run the new test and confirm the missing class/property failures**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_simulator -gexit
```

Expected: nonzero exit with parser failures for missing `CTBSimulator` and `battle_priority`.

- [ ] **Step 3: Implement the pure simulator**

Create `src/battle/ctb_simulator.gd`:

```gdscript
extends RefCounted
class_name CTBSimulator

static func project(
	actors: Array,
	target_ct: int,
	num_turns: int = 10,
	ct_adjustments: Dictionary = {}
) -> Array:
	var projection: Array = []
	var sim_data: Array[Dictionary] = []
	for actor: ActorCard in actors:
		if not is_instance_valid(actor) or actor.is_defeated:
			continue
		sim_data.append({
			"actor": actor,
			"ct": actor.current_ct + int(ct_adjustments.get(actor, 0)),
			"speed": maxi(actor.get_speed(), 1),
		})

	var elapsed_ticks := 0
	while projection.size() < num_turns and not sim_data.is_empty():
		var winner: Dictionary = {}
		var winner_ticks := 0
		for candidate: Dictionary in sim_data:
			var ticks := maxi(ceili(float(target_ct - candidate.ct) / candidate.speed), 0)
			if winner.is_empty() \
				or ticks < winner_ticks \
				or (ticks == winner_ticks and _comes_first(candidate, winner)):
				winner = candidate
				winner_ticks = ticks
		elapsed_ticks += winner_ticks
		projection.append({"actor": winner.actor, "ticks_needed": elapsed_ticks})
		for candidate: Dictionary in sim_data:
			candidate.ct += candidate.speed * winner_ticks
		winner.ct = 0
	return projection

static func _comes_first(candidate: Dictionary, incumbent: Dictionary) -> bool:
	if candidate.speed != incumbent.speed:
		return candidate.speed > incumbent.speed
	var candidate_is_hero := candidate.actor is HeroCard
	var incumbent_is_hero := incumbent.actor is HeroCard
	if candidate_is_hero != incumbent_is_hero:
		return candidate_is_hero
	return candidate.actor.battle_priority < incumbent.actor.battle_priority
```

Add `var battle_priority: int = 0` beside `current_ct` in `ActorCard`.

- [ ] **Step 4: Route BattleManager through the simulator and assign stable priorities**

Replace `_run_ct_simulation()` with delegation and add active composition:

```gdscript
func _run_ct_simulation(num_turns := 10, ct_adjustments: Dictionary = {}) -> Array:
	return CTBSimulator.project(actor_list, TARGET_CT, num_turns, ct_adjustments)

func _display_projection(ct_adjustments: Dictionary = {}, count: int = 10) -> Array:
	var future_count := count - 1 if is_instance_valid(current_actor) else count
	var projection := _run_ct_simulation(future_count, ct_adjustments)
	if is_instance_valid(current_actor):
		projection.insert(0, {"actor": current_actor, "ticks_needed": 0})
	return projection

func update_turn_order() -> void:
	turn_order_updated.emit(_display_projection(), false)
```

Assign increasing `battle_priority` values in `spawn_encounter()` immediately before each actor is appended. In `find_and_start_next_turn()`, use the future-only simulation to select and advance the winner, set `current_actor = winner`, then emit a newly built display projection from the advanced live state. Remove `sort_actors_by_ct()` and all `randf()` tie behavior.

- [ ] **Step 5: Add active-projection regression coverage**

Extend `test/unit/test_ctb_simulator.gd` with a minimal `BattleManager` test asserting `_display_projection()[0]` remains `current_actor` after `update_turn_order()` and that the actor's later projected occurrence remains in the list.

- [ ] **Step 6: Run focused simulator tests**

Run the same `-gselect ctb_simulator` command.

Expected: all simulator tests pass; no parser errors. The documented macOS CA warning and shutdown leak diagnostics are acceptable only with exit code zero.

- [ ] **Step 7: Commit the deterministic core**

```bash
git add src/battle/ctb_simulator.gd src/battle/actor_card.gd src/battle/battle_manager.gd test/unit/test_ctb_simulator.gd
git commit -m "fix: make CTB projections deterministic"
```

---

### Task 2: Action Recovery, Modifier Aggregation, and Preview Parity

**Files:**
- Modify: `src/scripts/data/action.gd:20-145`
- Modify: `src/scripts/conditions/condition.gd:15-28`
- Modify: `src/scripts/equipment/trait.gd:15-30`
- Modify: `src/battle/actor_card.gd:552-590`
- Modify: `src/scripts/action_effects/effect_modify_ct.gd`
- Modify: `src/battle/battle_manager.gd:318-388,633-680`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Create: `test/unit/test_action_ct_recovery.gd`

**Interfaces:**
- Consumes: `CTBSimulator.project(...)` and `BattleManager._display_projection(...)` from Task 1.
- Produces: `Action.ct_cost_percent: int`
- Produces: `Condition.action_ct_multiplier: float`
- Produces: `Trait.get_action_ct_multiplier(action: Action) -> float`
- Produces: `ActorCard.get_action_ct_percent(action: Action) -> int`
- Produces: `BattleManager.get_action_recovery_adjustment(actor: ActorCard, action: Action) -> int`
- Produces: `Effect_ModifyCT.ct_change_percent: float`

- [ ] **Step 1: Write failing action-recovery tests**

Create `test/unit/test_action_ct_recovery.gd`:

```gdscript
extends GutTest

class RecoveryTrait extends Trait:
	var multiplier := 1.0
	func get_action_ct_multiplier(_action: Action) -> float:
		return multiplier

func _actor() -> HeroCard:
	var actor := HeroCard.new()
	actor.current_stats = ActorStats.new()
	actor.current_stats.speed = 100
	return actor

func test_action_ct_modifiers_multiply_round_and_clamp() -> void:
	var actor := _actor()
	var action := Action.new()
	action.ct_cost_percent = 80
	var condition := Condition.new()
	condition.action_ct_multiplier = 0.9
	actor.active_conditions = [condition]
	var trait := RecoveryTrait.new()
	trait.multiplier = 0.8
	actor.active_traits = [trait]
	assert_eq(actor.get_action_ct_percent(action), 58)
	action.ct_cost_percent = 10
	condition.action_ct_multiplier = 0.1
	assert_eq(actor.get_action_ct_percent(action), 10)
	action.ct_cost_percent = 200
	condition.action_ct_multiplier = 2.0
	trait.multiplier = 2.0
	assert_eq(actor.get_action_ct_percent(action), 200)
	actor.free()

func test_recovery_adjustment_uses_signed_ct() -> void:
	var manager := BattleManager.new()
	var actor := _actor()
	var action := Action.new()
	action.ct_cost_percent = 75
	assert_eq(manager.get_action_recovery_adjustment(actor, action), 1250)
	action.ct_cost_percent = 125
	assert_eq(manager.get_action_recovery_adjustment(actor, action), -1250)
	manager.free()
	actor.free()
```

- [ ] **Step 2: Run the new test and verify missing APIs fail**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect action_ct_recovery -gexit
```

Expected: nonzero exit naming the missing action, condition, trait, actor, and manager APIs.

- [ ] **Step 3: Implement authored percentages and modifier aggregation**

In `Action`, replace the unused `update_turn_order` export with:

```gdscript
@export_range(10, 200, 1) var ct_cost_percent: int = 100
```

Remove the unused `get_ct_modification_for_actor()`, `_effect_targets_actor()`, and `has_self_ct_modification()` methods. Keep `get_ct_description()` only for remaining direct CT effects, updated to read `ct_change_percent`.

In `Condition`, add:

```gdscript
@export_range(0.01, 4.0, 0.01) var action_ct_multiplier: float = 1.0
```

In `Trait`, add:

```gdscript
func get_action_ct_multiplier(_action: Action) -> float:
	return 1.0
```

In `ActorCard`, add:

```gdscript
func get_action_ct_percent(action: Action) -> int:
	if action == null:
		return 100
	var result := float(action.ct_cost_percent)
	for condition: Condition in active_conditions:
		result *= condition.action_ct_multiplier
	for active_trait: Trait in active_traits:
		result *= active_trait.get_action_ct_multiplier(action)
	return clampi(roundi(result), 10, 200)
```

- [ ] **Step 4: Rename direct signed CT and centralize recovery math**

In `Effect_ModifyCT`, rename the export and keep signed addition:

```gdscript
@export var ct_change_percent: float = 0.5

func execute(_attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	for target: ActorCard in parent_targets:
		var ct_change := int(battle_manager.TARGET_CT * ct_change_percent)
		target.current_ct += ct_change
	battle_manager.update_turn_order()
	await battle_manager.wait()
```

Add to `BattleManager`:

```gdscript
func get_action_recovery_adjustment(actor: ActorCard, action: Action) -> int:
	var percent := actor.get_action_ct_percent(action)
	return int(TARGET_CT * (100 - percent) / 100.0)
```

- [ ] **Step 5: Snapshot and apply recovery only for turn-ending actions**

Add manager fields:

```gdscript
var executing_action_ct_percent := 100
var executing_action_ends_turn := false
```

Extend `execute_action()` with `ends_turn: bool = false`. Set `executing_action = action`; when `ends_turn` is true, snapshot `actor.get_action_ct_percent(action)`. Hero target confirmations and `execute_enemy_turn()` pass `true`; starting passives and shift actions retain `false`.

Add:

```gdscript
func _apply_executing_action_recovery(actor: ActorCard) -> void:
	if not executing_action_ends_turn:
		return
	actor.current_ct += int(TARGET_CT * (100 - executing_action_ct_percent) / 100.0)
	executing_action_ends_turn = false
	update_turn_order()
```

Call it after action effects resolve and before `actor.on_turn_ended()` for both heroes and enemies. Clear the snapshot when a battle ends or execution is abandoned.

- [ ] **Step 6: Make preview use additive simulated adjustments**

Replace live CT mutation in `preview_action_turn_order()` with a dictionary:

```gdscript
func preview_action_turn_order(actor: ActorCard, action: Action, selected_target: ActorCard = null) -> void:
	var adjustments: Dictionary = {
		actor: get_action_recovery_adjustment(actor, action),
	}
	var primary_targets: Array = []
	if is_instance_valid(selected_target):
		primary_targets.append(selected_target)
	elif is_group_target_action(action):
		primary_targets = get_targets(action.target_type, actor is HeroCard, [], actor)

	for effect: ActionEffect in action.effects:
		if not effect is Effect_ModifyCT:
			continue
		if effect.target_type == Action.TargetType.PARENT and primary_targets.is_empty():
			continue
		for target: ActorCard in get_targets(effect.target_type, actor is HeroCard, primary_targets, actor):
			adjustments[target] = int(adjustments.get(target, 0)) \
				+ int(TARGET_CT * effect.ct_change_percent)
	turn_order_updated.emit(_display_projection(adjustments), true)
```

Do not write to or restore `actor.current_ct` inside preview.

- [ ] **Step 7: Extend integration tests for snapshot, accumulation, and hover stability**

Add real-manager tests to `test_battle_controller_navigation.gd` that:

- set an actor to `-500`, apply a `75%` action recovery, and assert final CT is `750`;
- snapshot `75%`, change/remove its condition during execution, and assert the applied adjustment remains the snapshotted value;
- call the same non-CT target preview twice and assert actor/tick arrays are identical;
- assert preview and subsequent recovery publish the same next future actor.

- [ ] **Step 8: Run focused recovery and battle tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect action_ct_recovery -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
```

Expected: both scripts pass with no parser failures or unexpected errors.

- [ ] **Step 9: Commit action recovery**

```bash
git add src/scripts/data/action.gd src/scripts/conditions/condition.gd src/scripts/equipment/trait.gd src/battle/actor_card.gd src/scripts/action_effects/effect_modify_ct.gd src/battle/battle_manager.gd test/unit/test_action_ct_recovery.gd test/integration/test_battle_controller_navigation.gd
git commit -m "feat: add action CT recovery"
```

---

### Task 3: Migrate Self-Acceleration Content and Display Final CT

**Files:**
- Modify: `data/enemies/actions/brace.tres`
- Modify: `data/heroes/asher/actions/fusion_ammo.tres`
- Modify: `data/heroes/asher/actions/mark_target.tres`
- Modify: `data/heroes/asher/actions/targeting_laser.tres`
- Modify: `data/heroes/echo/actions/energize.tres`
- Modify: `data/enemies/actions/stun_baton.tres`
- Modify: `data/heroes/asher/actions/concussive_shot.tres`
- Modify: `data/heroes/asher/actions/suppressive_fire.tres`
- Modify: `data/heroes/echo/actions/static_charge.tres`
- Modify: `data/heroes/sands/actions/advantage.tres`
- Modify: `data/heroes/sands/actions/checkmate.tres`
- Modify: `data/heroes/sands/actions/tempo.tres`
- Modify: `data/heroes/asher/actions/bullet_time.tres`
- Modify: `data/heroes/sands/actions/apply_painkillers.tres`
- Modify: `data/heroes/sands/actions/draw_fire.tres`
- Modify: `data/heroes/sands/actions/focus_fire.tres`
- Modify: `data/heroes/sands/actions/immunize.tres`
- Modify: `data/heroes/sands/actions/opening_salvo.tres`
- Modify: `data/heroes/sands/actions/overwatch.tres`
- Modify: `data/heroes/sands/actions/return_fire.tres`
- Modify: `src/battle/battle_scene.tscn:118-163`
- Modify: `src/battle/battle_manager.gd:281-289`
- Create: `test/unit/test_ctb_action_content.gd`

**Interfaces:**
- Consumes: `Action.ct_cost_percent`, `ActorCard.get_action_ct_percent()`, and `Effect_ModifyCT.ct_change_percent` from Task 2.
- Produces: `BattleManager._action_ct_color(base_percent: int, final_percent: int) -> Color`.
- Produces: `UI/CurrentAction/HBoxContainer/CTPercent` label.

- [ ] **Step 1: Write failing production-content migration tests**

Create `test/unit/test_ctb_action_content.gd`:

```gdscript
extends GutTest

const MIGRATED := {
	"res://data/enemies/actions/brace.tres": 75,
	"res://data/heroes/asher/actions/fusion_ammo.tres": 85,
	"res://data/heroes/asher/actions/mark_target.tres": 25,
	"res://data/heroes/asher/actions/targeting_laser.tres": 75,
	"res://data/heroes/echo/actions/energize.tres": 50,
}

func test_self_acceleration_is_action_recovery_only() -> void:
	for path: String in MIGRATED:
		var action := load(path) as Action
		assert_eq(action.ct_cost_percent, MIGRATED[path], path)
		assert_false(action.effects.any(func(effect):
			return effect is Effect_ModifyCT and effect.target_type in [
				Action.TargetType.SELF, Action.TargetType.ATTACKER,
			]
		), "%s no longer double-applies self acceleration" % path)

func test_other_actor_and_conditional_ct_effects_remain_direct() -> void:
	for path in [
		"res://data/heroes/sands/actions/tempo.tres",
		"res://data/heroes/sands/actions/advantage.tres",
		"res://data/heroes/asher/actions/concussive_shot.tres",
	]:
		var action := load(path) as Action
		assert_eq(action.ct_cost_percent, 100)
		assert_true(_contains_ct_effect(action), path)

func _contains_ct_effect(action: Action) -> bool:
	for effect: ActionEffect in action.effects:
		if effect is Effect_ModifyCT:
			return true
		if effect is Effect_Damage:
			for trigger in effect.on_hit_triggers:
				for nested: ActionEffect in trigger.effects_to_run:
					if nested is Effect_ModifyCT:
						return true
	return false
```

- [ ] **Step 2: Run the content test and verify it fails on unmigrated resources**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_action_content -gexit
```

Expected: failures show all five self-acceleration actions still at `100%` or retaining a self CT effect.

- [ ] **Step 3: Migrate exactly the five self-acceleration actions**

For each resource in `MIGRATED`, set `ct_cost_percent` to the expected integer and remove only the direct self-resolving `Effect_ModifyCT` subresource from its effects array. Remove now-unused CT script ext-resources and adjust `load_steps` only when Godot's text resource requires it.

Preserve `Tempo` and `Advantage` because they accelerate another actor. Preserve `Stun Baton`, `Suppressive Fire`, `Static Charge`, `Checkmate`, and conditional `Concussive Shot` delays. Rename every remaining serialized `ct_boost_percent` property to `ct_change_percent`; resources relying on the `0.5` default require no serialized line. Remove the obsolete action-level `update_turn_order` line from the eight action resources listed above, while retaining the condition-level flag in `bullet_time_debuff.tres` and `bullet_time_passive.tres`.

Run:

```bash
rg -n "ct_boost_percent|update_turn_order =" data src test --glob '*.tres' --glob '*.gd'
```

Expected: no old CT property remains; only condition-level `update_turn_order` remains where intentionally used.

- [ ] **Step 4: Add the compact selected-action CT label**

Add a `Label` named `CTPercent` to `UI/CurrentAction/HBoxContainer`, sized for text such as `75% CT`. Keep the parent neutral so semantic white/green/red colors remain accurate; move the existing role color to the icon mask or another existing accent instead of modulating the entire panel.

Add to `BattleManager`:

```gdscript
const CT_FASTER_COLOR := Color("67e88a")
const CT_SLOWER_COLOR := Color("f87171")

static func _action_ct_color(base_percent: int, final_percent: int) -> Color:
	if final_percent < base_percent:
		return CT_FASTER_COLOR
	if final_percent > base_percent:
		return CT_SLOWER_COLOR
	return Color.WHITE
```

In `set_current_action()`:

```gdscript
var final_percent := current_actor.get_action_ct_percent(current_action)
var ct_label := current_action_panel.get_node("HBoxContainer/CTPercent") as Label
ct_label.text = "%d%% CT" % final_percent
ct_label.add_theme_color_override(
	"font_color", _action_ct_color(current_action.ct_cost_percent, final_percent)
)
```

- [ ] **Step 5: Test CT text and semantic colors**

Extend `test_ctb_action_content.gd` to assert white for unchanged `65 -> 65`, green for `65 -> 52`, and red for `65 -> 80`. Add a real `battle_scene.tscn` assertion that selecting a `75%` action renders `75% CT`.

- [ ] **Step 6: Run import and focused content tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_action_content -gexit
```

Expected: import exits zero; all migration and display tests pass without missing ext-resource or parser errors.

- [ ] **Step 7: Commit content migration and CT display**

```bash
git add data/enemies/actions/brace.tres data/enemies/actions/stun_baton.tres data/heroes/asher/actions/bullet_time.tres data/heroes/asher/actions/concussive_shot.tres data/heroes/asher/actions/fusion_ammo.tres data/heroes/asher/actions/mark_target.tres data/heroes/asher/actions/suppressive_fire.tres data/heroes/asher/actions/targeting_laser.tres data/heroes/echo/actions/energize.tres data/heroes/echo/actions/static_charge.tres data/heroes/sands/actions/advantage.tres data/heroes/sands/actions/apply_painkillers.tres data/heroes/sands/actions/checkmate.tres data/heroes/sands/actions/draw_fire.tres data/heroes/sands/actions/focus_fire.tres data/heroes/sands/actions/immunize.tres data/heroes/sands/actions/opening_salvo.tres data/heroes/sands/actions/overwatch.tres data/heroes/sands/actions/return_fire.tres data/heroes/sands/actions/tempo.tres src/battle/battle_scene.tscn src/battle/battle_manager.gd test/unit/test_ctb_action_content.gd
git commit -m "feat: migrate self boosts to action CT"
```

Before committing, inspect the staged diff and unstage any resource outside the exact CT migration list.

---

### Task 4: Scrollable Right-Side Portrait Queue and Fixed Tick Gauges

**Files:**
- Create: `src/battle/ctb_gauge.gd`
- Create: `src/battle/ctb_gauge.gd.uid` if generated by Godot.
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/battle/actor_queue.gd`
- Modify: `src/battle/actor_queue.tscn`
- Modify: `src/battle/turn_queue.gd`
- Modify: `src/battle/turn_queue.tscn`
- Modify: `src/battle/battle_scene.tscn:164-217`
- Create: `test/unit/test_ctb_gauge.gd`
- Create: `test/unit/test_actor_queue.gd`
- Create: `test/integration/test_turn_queue.gd`

**Interfaces:**
- Consumes: projection entries `{actor: ActorCard, ticks_needed: int}` from Task 1.
- Produces: `CTBGauge.configure(ticks: int, faction: CTBGauge.Faction, is_current: bool) -> void`
- Produces: `CTBGauge.band_fills(ticks: int) -> Array[float]`
- Produces: `ActorQueue.setup(actor: ActorCard, ticks: int, animate: bool, is_current: bool, occurrence_index: int) -> void`
- Produces: `ActorQueue.enemy_abbreviation(actor_name: String) -> String`
- Produces: queue matching identity `(actor_ref, occurrence_index)`.
- Produces: `TurnQueue.scroll_future_by_axis(axis_value: float, delta: float) -> void`.
- Produces: one fixed active card plus `20` scrollable future cards.

- [ ] **Step 1: Write failing gauge and abbreviation tests**

Create `test/unit/test_ctb_gauge.gd`:

```gdscript
extends GutTest

func test_fixed_twenty_tick_bands_and_saturation() -> void:
	assert_eq(CTBGauge.band_fills(0), [0.0, 0.0, 0.0])
	assert_eq(CTBGauge.band_fills(10), [0.5, 0.0, 0.0])
	assert_eq(CTBGauge.band_fills(20), [1.0, 0.0, 0.0])
	assert_eq(CTBGauge.band_fills(31), [1.0, 0.55, 0.0])
	assert_eq(CTBGauge.band_fills(55), [1.0, 1.0, 0.75])
	assert_eq(CTBGauge.band_fills(70), [1.0, 1.0, 1.0])

func test_partial_perimeter_has_exact_end_interpolation() -> void:
	var square := PackedVector2Array([
		Vector2.ZERO, Vector2(10, 0), Vector2(10, 10),
		Vector2(0, 10), Vector2.ZERO,
	])
	var half := CTBGauge.partial_polyline(square, 0.5)
	assert_eq(half[-1], Vector2(10, 10))
```

Create `test/unit/test_actor_queue.gd` with:

```gdscript
extends GutTest

func test_enemy_abbreviation_preserves_duplicate_suffix() -> void:
	assert_eq(ActorQueue.enemy_abbreviation("Scout Drone A"), "SD A")
	assert_eq(ActorQueue.enemy_abbreviation("Marauder"), "MA")
```

- [ ] **Step 2: Run both tests and verify missing visual APIs fail**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_gauge -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_queue -gexit
```

Expected: nonzero exits because `CTBGauge` and the abbreviation API do not exist.

- [ ] **Step 3: Implement rounded perimeter geometry and fixed bands**

Create `ctb_gauge.gd` as a custom `Control` with `Faction { HERO, ENEMY }`, `TICKS_PER_BAND := 20`, three cyan shades, three magenta shades, a gold current color, and a neutral track.

Its public pure helpers are:

```gdscript
static func band_fills(ticks: int) -> Array[float]:
	var fills: Array[float] = []
	for band in 3:
		fills.append(clampf(float(ticks - band * TICKS_PER_BAND) / TICKS_PER_BAND, 0.0, 1.0))
	return fills

static func partial_polyline(points: PackedVector2Array, fraction: float) -> PackedVector2Array:
	if points.size() < 2 or fraction <= 0.0:
		return PackedVector2Array()
	if fraction >= 1.0:
		return points
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	var target := total * fraction
	var traversed := 0.0
	var result := PackedVector2Array([points[0]])
	for i in range(1, points.size()):
		var segment := points[i - 1].distance_to(points[i])
		if traversed + segment >= target:
			var weight := (target - traversed) / segment
			result.append(points[i - 1].lerp(points[i], weight))
			break
		result.append(points[i])
		traversed += segment
	return result
```

Generate the closed path and draw it with these concrete methods:

```gdscript
static func rounded_rect_path(rect: Rect2, radius: float, segments_per_corner: int = 8) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var centers := [
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.position.y + r),
	]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	var points := PackedVector2Array()
	for corner in 4:
		for step in segments_per_corner + 1:
			var angle: float = starts[corner] + PI * 0.5 * float(step) / segments_per_corner
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * r)
	points.append(points[0])
	return points

func configure(ticks: int, faction: Faction, is_current: bool) -> void:
	_ticks = maxi(ticks, 0)
	_faction = faction
	_is_current = is_current
	queue_redraw()

func _draw() -> void:
	var inset := GAUGE_WIDTH * 0.5
	var path := rounded_rect_path(Rect2(Vector2.ONE * inset, size - Vector2.ONE * GAUGE_WIDTH), CORNER_RADIUS)
	draw_polyline(path, TRACK_COLOR, GAUGE_WIDTH, true)
	if _is_current:
		draw_polyline(path, CURRENT_COLOR, GAUGE_WIDTH, true)
		return
	var colors := HERO_COLORS if _faction == Faction.HERO else ENEMY_COLORS
	var fills := band_fills(_ticks)
	for band in 3:
		var partial := partial_polyline(path, fills[band])
		if partial.size() >= 2:
			draw_polyline(partial, colors[band], GAUGE_WIDTH - band * 2.0, true)
```

- [ ] **Step 4: Replace ActorQueue bars with temporary portrait content**

Rebuild `actor_queue.tscn` as a resizable rounded portrait card containing:

- `CTBGauge` filling the card;
- a clipped interior `Panel` inset from the gauge;
- a centered `TextureRect` for hero role icons;
- a centered `Label` for enemy abbreviations.

Replace `actor_queue.gd` with setup that chooses `HeroCard.get_current_role().icon` or `enemy_abbreviation(actor.actor_name)`, configures cyan/magenta/current gold, stores `occurrence_index`, sizes the active card to `104x112` and future cards to `68x72`, and owns/kills its single movement tween:

```gdscript
const ACTIVE_SIZE := Vector2(104, 112)
const FUTURE_SIZE := Vector2(68, 72)

func setup(actor: ActorCard, ticks: int, animate: bool, is_current: bool, occurrence: int) -> void:
	actor_ref = actor
	occurrence_index = occurrence
	custom_minimum_size = ACTIVE_SIZE if is_current else FUTURE_SIZE
	size = custom_minimum_size
	role_icon.visible = actor is HeroCard
	enemy_label.visible = actor is EnemyCard
	if actor is HeroCard:
		var role := (actor as HeroCard).get_current_role()
		role_icon.texture = role.icon if role else null
	else:
		enemy_label.text = enemy_abbreviation(actor.actor_name)
	gauge.configure(ticks, CTBGauge.Faction.HERO if actor is HeroCard else CTBGauge.Faction.ENEMY, is_current)
	if not animate and _move_tween and _move_tween.is_valid():
		_move_tween.kill()

func animate_to(target_position: Vector2) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_move_tween.tween_property(self, "position", target_position, ANIMATION_DURATION)

func animate_exit() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_move_tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION / 3.0)
	_move_tween.tween_callback(queue_free)
```

Implement abbreviation as:

```gdscript
static func enemy_abbreviation(actor_name: String) -> String:
	var words := actor_name.strip_edges().split(" ", false)
	var suffix := ""
	if words.size() > 1 and words[-1].length() == 1:
		suffix = words.pop_back().to_upper()
	var core := ""
	if words.size() == 1:
		core = words[0].left(2).to_upper()
	else:
		for word in words.slice(0, 2):
			core += word.left(1).to_upper()
	return core if suffix.is_empty() else "%s %s" % [core, suffix]
```

- [ ] **Step 5: Build the fixed active slot and scrollable future rail**

In `battle_manager.gd`, make the display depth explicit without changing the ten-turn simulation used only to select the next actor:

```gdscript
const FUTURE_TURN_DISPLAY_COUNT := 20

func _display_projection(
	ct_adjustments: Dictionary = {},
	count: int = FUTURE_TURN_DISPLAY_COUNT + 1,
) -> Array:
	var future_count := count - 1 if is_instance_valid(current_actor) else count
	var projection := _run_ct_simulation(future_count, ct_adjustments)
	if is_instance_valid(current_actor):
		projection.insert(0, {"actor": current_actor, "ticks_needed": 0})
	return projection
```

Rebuild `turn_queue.tscn` as a right-rail `Control` with these children:

- `ActiveSlot`, a `104x112` fixed `Control` centered at the top;
- `FutureScroll`, a vertical `ScrollContainer` below it with horizontal scrolling disabled, `scroll_deadzone = 12`, and clipping left on so native wheel and touch-drag scrolling work;
- `FutureScroll/FutureContent`, a manually positioned `Control` whose minimum height tracks all future entries;
- `OverflowFade`, a mouse-ignoring bottom gradient shown only while additional entries remain below.

In `turn_queue.gd`, use `ITEM_SPACING := 8`, `RIGHT_STICK_DEAD_ZONE := 0.25`, and `RIGHT_STICK_SCROLL_SPEED := 700.0`; card sizes come from `ActorQueue.ACTIVE_SIZE` and `ActorQueue.FUTURE_SIZE`. Keep the active card separate, then count occurrences over the complete projection so a later turn by the active actor begins at occurrence `1`:

```gdscript
func _setup_active(turn_data: Dictionary, _animate: bool) -> void:
	if active_item == null or active_item.actor_ref != turn_data.actor:
		if active_item:
			active_item.queue_free()
		active_item = actor_queue_scene.instantiate() as ActorQueue
		active_slot.add_child(active_item)
	active_item.setup(turn_data.actor, int(turn_data.ticks_needed), false, true, 0)
	active_item.position = Vector2(
		(active_slot.size.x - ActorQueue.ACTIVE_SIZE.x) * 0.5,
		0.0,
	)

func _on_turn_order_updated(projected_queue: Array, animate: bool = true) -> void:
	if projected_queue.is_empty():
		_clear_queue()
		return
	var new_active: ActorCard = projected_queue[0].actor
	var active_changed := active_actor_ref != new_active
	var saved_scroll := 0 if active_changed else future_scroll.scroll_vertical
	active_actor_ref = new_active
	_setup_active(projected_queue[0], animate)

	var occurrence_counts: Dictionary = {new_active: 1}
	var old_items := future_items.duplicate()
	future_items.clear()
	for index in range(1, projected_queue.size()):
		var turn_data: Dictionary = projected_queue[index]
		var actor: ActorCard = turn_data.actor
		var occurrence := int(occurrence_counts.get(actor, 0))
		occurrence_counts[actor] = occurrence + 1
		var item := _find_and_pop_match(actor, occurrence, old_items)
		if item == null:
			item = actor_queue_scene.instantiate() as ActorQueue
			future_content.add_child(item)
		item.setup(actor, int(turn_data.ticks_needed), animate, false, occurrence)
		var target := Vector2(
			(future_scroll.size.x - ActorQueue.FUTURE_SIZE.x) * 0.5,
			(index - 1) * (ActorQueue.FUTURE_SIZE.y + ITEM_SPACING),
		)
		if animate:
			item.animate_to(target)
		else:
			item.position = target
		future_items.append(item)

	var content_height := future_items.size() * int(ActorQueue.FUTURE_SIZE.y + ITEM_SPACING)
	if not future_items.is_empty():
		content_height -= ITEM_SPACING
	future_content.custom_minimum_size = Vector2(future_scroll.size.x, content_height)
	for unused: ActorQueue in old_items:
		unused.animate_exit()
	call_deferred("_restore_scroll", saved_scroll)
```

Match both `actor_ref` and `occurrence_index`:

```gdscript
func _find_and_pop_match(actor: ActorCard, occurrence: int, pool: Array) -> ActorQueue:
	for index in pool.size():
		var candidate := pool[index] as ActorQueue
		if candidate.actor_ref == actor and candidate.occurrence_index == occurrence:
			pool.remove_at(index)
			return candidate
	return null
```

Existing items kill their old layout tween before moving; obsolete items own only their exit fade. Remove `_calculate_ticks_per_bar()` and all projection-dependent scaling.

Implement scrolling without accepting the right-stick event, so combat selection continues to own its existing inputs:

```gdscript
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
		_right_stick_y = event.axis_value

func _process(delta: float) -> void:
	scroll_future_by_axis(_right_stick_y, delta)

func scroll_future_by_axis(axis_value: float, delta: float) -> void:
	if absf(axis_value) < RIGHT_STICK_DEAD_ZONE:
		return
	var amount := int(axis_value * RIGHT_STICK_SCROLL_SPEED * delta)
	future_scroll.scroll_vertical = clampi(
		future_scroll.scroll_vertical + amount,
		0,
		_max_future_scroll(),
	)

func _restore_scroll(value: int) -> void:
	future_scroll.scroll_vertical = clampi(value, 0, _max_future_scroll())
	_update_overflow_fade()

func _max_future_scroll() -> int:
	var bar := future_scroll.get_v_scroll_bar()
	return maxi(int(ceil(bar.max_value - bar.page)), 0)

func _update_overflow_fade(_value: float = 0.0) -> void:
	overflow_fade.visible = (
		_max_future_scroll() > 0
		and future_scroll.scroll_vertical < _max_future_scroll()
	)
```

Connect the vertical scrollbar's `value_changed` signal to `_update_overflow_fade`. Native `ScrollContainer` behavior owns mouse-wheel and touch-drag scrolling.

- [ ] **Step 6: Add real queue integration tests**

Create `test/integration/test_turn_queue.gd` to instantiate the real queue scene and assert:

- `_display_projection()` publishes one active plus twenty future entries;
- entry zero is a larger gold/current card fixed outside `FutureScroll`;
- a hero future entry uses hero faction and its current role icon;
- an enemy future entry uses magenta and the generated abbreviation;
- a later projection for the active actor has occurrence `1`, distinct from the fixed active item;
- the `1920x1080` rail allocation fully exposes eight `68x72` future cards with seven `8`-pixel gaps;
- a same-active preview refresh preserves and clamps scroll position;
- changing the active actor resets the future scroll to zero;
- `scroll_future_by_axis(1.0, 0.1)` scrolls an overflowing list without changing `BattleManager.current_action` or target state;
- the overflow fade is visible above the bottom, hidden at the bottom, and hidden when all entries fit;
- publishing two rapid projections leaves each surviving item with only its newest movement tween and final vertical target.

Use real `ActorQueue` instances and real `ScrollContainer` layout frames. The scroll lifecycle regression should follow this shape:

```gdscript
func test_preview_preserves_scroll_and_new_active_resets_it() -> void:
	queue._on_turn_order_updated(_projection(hero_a, 21), false)
	await get_tree().process_frame
	queue.future_scroll.scroll_vertical = 160
	queue._on_turn_order_updated(_projection(hero_a, 21), false)
	await get_tree().process_frame
	assert_eq(queue.future_scroll.scroll_vertical, 160)
	queue._on_turn_order_updated(_projection(hero_b, 21), false)
	await get_tree().process_frame
	assert_eq(queue.future_scroll.scroll_vertical, 0)
```

- [ ] **Step 7: Place the queue and selected panel without overlap**

In `battle_scene.tscn`, anchor `TurnQueue` to the right edge with `anchor_left = 1`, `anchor_right = 1`, `anchor_bottom = 1`, `offset_left = -136`, `offset_top = 16`, `offset_right = -16`, and `offset_bottom = -300`. This yields a `120x764` rail: the `104x112` active card plus gap leaves at least `640` pixels for the future viewport, enough for eight `68x72` cards and seven `8`-pixel gaps. Set `CurrentAction.offset_right = -152` and `Enemies.offset_right = -144` so neither renders beneath the rail. Preserve hero and action-bar placement; the rail ends above the action bar.

- [ ] **Step 8: Import and run focused visual-logic tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb_gauge -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect actor_queue -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect turn_queue -gexit
```

Expected: import and all three test scripts exit zero.

- [ ] **Step 9: Commit the scrollable right queue**

```bash
git add src/battle/ctb_gauge.gd src/battle/ctb_gauge.gd.uid src/battle/battle_manager.gd src/battle/actor_queue.gd src/battle/actor_queue.tscn src/battle/turn_queue.gd src/battle/turn_queue.tscn src/battle/battle_scene.tscn test/unit/test_ctb_gauge.gd test/unit/test_actor_queue.gd test/integration/test_turn_queue.gd
git commit -m "feat: add scrollable CTB portrait rail"
```

If Godot does not generate `ctb_gauge.gd.uid`, omit that path rather than creating a sidecar manually.

---

### Task 5: Combat Acceptance, Documentation, and Full Verification

**Files:**
- Create: `docs/testing/ctb-combat-checklist.md`
- Modify: `docs/README.md`
- Modify: CTB task files only if verification exposes a directly related defect.

**Interfaces:**
- Consumes: all public behavior from Tasks 1-4.
- Produces: documented manual acceptance for the temporary icon/abbreviation queue and action recovery.

- [ ] **Step 1: Write the manual CTB checklist**

Create `docs/testing/ctb-combat-checklist.md` with explicit checks for:

- gold active portrait remains first during selection, hover, cancel, CT effects, conditions, and Speed changes;
- the larger active portrait remains fixed at the top-right while future turns scroll beneath it;
- the rail exposes at least eight complete future cards at `1920x1080` and allows inspection of all twenty projected future turns;
- right-stick scrolling does not change action selection or target selection;
- mouse wheel over the rail and direct touch drag scroll the same future list;
- hover and preview refreshes preserve the current scroll position, while the next actual turn resets it to the top;
- the bottom overflow fade appears only when additional future turns remain below;
- identical non-CT target hovers never reorder equal-tick enemies;
- cyan hero and magenta enemy fixed bands retain the same meaning as actors move;
- `20`, `40`, and `60+` tick boundaries render the expected shade layers;
- current role shifts update subsequent hero queue icons;
- duplicate enemies retain readable abbreviations and A/B/C suffixes;
- `75% CT` moves the actor earlier than `100% CT`, and `125% CT` moves it later;
- modifier colors are white/green/red relative to the authored action value;
- repeated reactive 10% delays stack below zero;
- mouse, keyboard, and controller target changes agree with the same queue preview;
- rapid hover and input-family handoffs do not leave cards between positions.

Add a one-line entry under testing documentation in `docs/README.md`.

- [ ] **Step 2: Run repository hygiene checks**

Run:

```bash
git diff --check
rg -n "ct_boost_percent|sort_actors_by_ct|_calculate_ticks_per_bar|update_turn_order =" src data test --glob '*.gd' --glob '*.tres'
git status --short
```

Expected: no whitespace errors; no obsolete CT property, random tie helper, or dynamic queue scale; only intentional CTB files plus the user's pre-existing unrelated dirty files are present.

- [ ] **Step 3: Run the focused CTB and combat suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect ctb -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
```

Expected: every command exits zero with all selected tests passing.

- [ ] **Step 4: Run the complete suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: exit zero with no failing tests, parser errors, crashes, or unexpected runtime errors. Record exact test and assertion totals. The documented CA warning and engine shutdown leak diagnostics remain acceptable.

- [ ] **Step 5: Perform manual visual acceptance**

Launch the project with the isolated HOME:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"
```

Enter combat and execute every item in `docs/testing/ctb-combat-checklist.md`. Record any unchecked item as remaining manual work; do not claim it passed without observing it.

- [ ] **Step 6: Commit documentation or final directly related corrections**

```bash
git add docs/testing/ctb-combat-checklist.md docs/README.md
git commit -m "docs: add CTB combat acceptance checks"
```

If verification required source/test corrections, stage only those CTB files, rerun their focused tests and the complete suite, and include them in a separate accurately named commit before the documentation commit.

- [ ] **Step 7: Review final branch scope**

Run:

```bash
git log --oneline --decorate -8
git diff --stat codex/terminal-ui-redesign..HEAD
git status --short
```

Expected: CTB commits contain only plan files, CTB implementation/tests/resources/docs, and required sidecars; the user's unrelated dirty files remain uncommitted.
