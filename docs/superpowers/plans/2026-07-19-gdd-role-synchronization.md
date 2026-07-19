# GDD Role Synchronization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Synchronize all nine hero roles, actions, Shift actions, and passives with the approved GDD while making ordinary combat healing non-reviving.

**Architecture:** Keep kits authored in Godot resources. Add only reusable primitives for Focus refunds, enemy-breach observation, condition-caster targeting, capped Guard scaling, capped Inversion hits, and source-PSY power contributions. Operative and Telepath get deliberately temporary action-first progression without stat nodes.

**Tech Stack:** Godot 4.6.3, GDScript, `.tres` resources, JSON progression, GUT.

## Global Constraints

- Use Godot 4.6.3 and the isolated test HOME `/private/tmp/mars-godot-home`.
- The behavior in `docs/superpowers/specs/2026-07-19-gdd-role-synchronization-design.md` is authoritative.
- Preserve internal role ID `dom`; display it as `Telepath`.
- Internal paths `rejuvenate.tres`, `kinetic_wall.tres`, and `telepathy.tres` may remain, but obsolete player-facing names must not.
- Ordinary combat healing must not revive. A future explicit effect may opt in with `is_revive = true`.
- Do not add role perks, character perks, save migrations, compatibility layers, or permanent stat-node design.
- Operative and Telepath progression is temporary: two rank-1 actions, actions at ranks 2 and 3, Shift at rank 4, passive at rank 5, no stat nodes.
- Preserve unrelated dirty work. Merge the user's existing edits in Sands's Booster Shots, Checkmate, Fianchetto action, and Fianchetto condition; retain the cleanup name `Fianchetto`.

---

### Task 1: Make Ordinary Healing Non-Reviving

**Files:**
- Modify: `src/scripts/action_effects/effect_healing.gd`
- Test: `test/unit/test_battle_condition_targets.gd`

**Interfaces:**
- Produces: `Effect_Healing.is_revive: bool = false`; explicit `true` remains supported.

- [ ] **Step 1: Write failing tests**

```gdscript
func test_healing_defaults_to_non_reviving() -> void:
	var effect := Effect_Healing.new()
	assert_false(effect.is_revive)
	var action := Action.new()
	action.effects = [effect]
	assert_false(action.can_revive_targets)


func test_explicit_revive_remains_opt_in() -> void:
	var effect := Effect_Healing.new()
	effect.is_revive = true
	var action := Action.new()
	action.effects = [effect]
	assert_true(action.can_revive_targets)
```

Extend the existing target fixture to assert single-target and group ordinary heals skip a defeated hero, while an explicit revive includes one. Add triggered and recurring-heal fixtures that call `Effect_Healing.execute()` against a defeated hero and assert HP stays at zero; retain the existing lifedrain assertion that `take_healing()` without `is_revive` cannot revive.

- [ ] **Step 2: Run the test and see the default assertion fail**

```bash
env HOME=/private/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test/unit/test_battle_condition_targets.gd -gexit
```

- [ ] **Step 3: Change the default**

```gdscript
@export var is_revive: bool = false
```

Do not change post-combat revival or injury handling.

- [ ] **Step 4: Re-run Step 2 and require all assertions to pass**

- [ ] **Step 5: Commit**

```bash
git add src/scripts/action_effects/effect_healing.gd test/unit/test_battle_condition_targets.gd
git commit -m "fix: prevent ordinary healing from reviving"
```

---

### Task 2: Add Focus Refunds, Breach Observation, and Caster-Aligned Triggers

**Files:**
- Modify: `src/scripts/conditions/trigger.gd`
- Modify: `src/scripts/conditions/condition.gd`
- Modify: `src/scripts/conditions/hit_trigger.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`
- Modify: `src/battle/actor_card.gd`
- Modify: `src/battle/hero_card.gd`
- Modify: `src/battle/battle_manager.gd`
- Test: `test/unit/test_battle_condition_targets.gd`
- Test: `test/unit/test_ctb_simulator.gd`
- Test: `test/unit/test_damage_effect_execution.gd`

**Interfaces:**
- Produces: `Trigger.TriggerType.ON_ENEMY_BREACHED`.
- Produces: `Condition.refund_focus_cost_on_spend: bool`.
- Produces: `HeroCard.modify_focus(amount: int, context: Dictionary = {})`.
- Produces: `ActorCard.actor_breached(actor)` with a real actor argument.
- Produces: `HitTrigger.HitCondition.IF_TARGET_IS_VULNERABLE_OR_BREACHED`.
- Triggered non-`SELF` effects resolve allegiance from `condition.attacker`, falling back to the holder.

- [ ] **Step 1: Write failing behavior tests**

```gdscript
func test_focus_refund_restores_paid_cost_and_consumes_condition() -> void:
	var hero := _hero_with_focus(5)
	var refund := Condition.new()
	refund.condition_name = "Coordinate"
	refund.refund_focus_cost_on_spend = true
	refund.remove_on_triggers = [Trigger.TriggerType.ON_SPENDING_FOCUS]
	hero.active_conditions = [refund]
	await hero.modify_focus(-3, {"paid_focus_cost": 3})
	assert_eq(hero.current_focus, 5)
	assert_false(hero.active_conditions.has(refund))


func test_breach_signal_supplies_actor() -> void:
	var actor := _actor_card()
	var received: Array[ActorCard] = []
	actor.actor_breached.connect(func(value: ActorCard) -> void: received.append(value))
	await actor.breach()
	assert_eq(received, [actor])
```

Using existing doubles, also assert an enemy breach sends `ON_ENEMY_BREACHED` only to living opposing observers, and an Echo-authored `ALL_ALLIES` condition on an enemy targets living heroes.

Add a hit-trigger test with one `is_in_danger` target, one `is_breached` target, and one normal target; the new condition fires for the first two only.

- [ ] **Step 2: Run focused tests and require failures**

```bash
env HOME=/private/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test/unit/test_battle_condition_targets.gd,test/unit/test_ctb_simulator.gd,test/unit/test_damage_effect_execution.gd -gexit
```

- [ ] **Step 3: Implement exact Focus refunds**

Add:

```gdscript
@export_group("Resource Modifiers")
@export var refund_focus_cost_on_spend: bool = false
```

Replace `HeroCard.modify_focus` with:

```gdscript
func modify_focus(amount: int, context: Dictionary = {}) -> void:
	var paid_focus_cost := maxi(0, int(context.get("paid_focus_cost", -amount)))
	var should_refund := amount < 0 and active_conditions.any(
		func(condition: Condition) -> bool:
			return condition != null and condition.refund_focus_cost_on_spend
	)
	current_focus = clampi(current_focus + amount, 0, 10)
	update_focus_bar()
	focus_updated.emit()
	if amount < 0:
		var spend_context := context.duplicate(true)
		spend_context["paid_focus_cost"] = paid_focus_cost
		await _fire_condition_event(Trigger.TriggerType.ON_SPENDING_FOCUS, spend_context)
	if should_refund and paid_focus_cost > 0:
		await modify_focus(paid_focus_cost)
```

Pay action costs with:

```gdscript
await (actor as HeroCard).modify_focus(
	-paid_focus_cost,
	{"paid_focus_cost": paid_focus_cost, "action": action},
)
```

Update overridden test-double signatures to accept the optional context.

- [ ] **Step 4: Forward breached actors**

Append the new trigger so existing enum values remain stable:

```gdscript
	AFTER_SHIFT_ACTION,
	ON_ENEMY_BREACHED,
```

Emit:

```gdscript
actor_breached.emit(self)
```

Replace the manager callback:

```gdscript
func _on_actor_breached(breached_actor: ActorCard) -> void:
	print("\n Actor was Breached -> New Queue: ")
	update_turn_order()
	for observer: ActorCard in actor_list:
		if not is_instance_valid(observer) or observer.is_defeated:
			continue
		if observer is HeroCard == breached_actor is HeroCard:
			continue
		await observer._fire_condition_event(
			Trigger.TriggerType.ON_ENEMY_BREACHED,
			{"target": breached_actor, "targets": [breached_actor]},
		)
```

- [ ] **Step 5: Resolve triggered allegiance from the condition caster**

Keep `SELF` on the holder. For non-self effects use:

```gdscript
var effect_source := condition.attacker \
	if is_instance_valid(condition.attacker) else self
targets = battle_manager.get_targets(
	effect.target_type,
	effect_source is HeroCard,
	targets,
	contextual_attacker,
)
```

Append the new hit condition after existing values:

```gdscript
	IF_ATTACKER_HAS_BUFF,
	IF_TARGET_IS_VULNERABLE_OR_BREACHED,
```

Handle it in `Effect_Damage._process_on_hit_triggers()`:

```gdscript
HitTrigger.HitCondition.IF_TARGET_IS_VULNERABLE_OR_BREACHED:
	condition_met = target.is_in_danger or target.is_breached
```

- [ ] **Step 6: Re-run Step 2 and require all selected tests to pass without signal errors**

- [ ] **Step 7: Commit**

```bash
git add src/scripts/conditions/trigger.gd src/scripts/conditions/condition.gd src/scripts/conditions/hit_trigger.gd src/scripts/action_effects/effect_damage.gd src/battle/actor_card.gd src/battle/hero_card.gd src/battle/battle_manager.gd test/unit/test_battle_condition_targets.gd test/unit/test_ctb_simulator.gd test/unit/test_damage_effect_execution.gd
git commit -m "feat: support role trigger interactions"
```

---

### Task 3: Add Capped Guard Effects and Source-PSY Power

**Files:**
- Modify: `src/scripts/action_effects/effect_modify_guard.gd`
- Modify: `src/scripts/action_effects/effect_damage_inversion.gd`
- Modify: `src/scripts/conditions/condition.gd`
- Create: `src/scripts/conditions/condition_source_power_bonus.gd`
- Include when generated: `src/scripts/conditions/condition_source_power_bonus.gd.uid`
- Modify: `src/battle/actor_card.gd`
- Test: `test/unit/test_damage_scaling_rules.gd`
- Test: `test/unit/test_damage_effect_execution.gd`

**Interfaces:**
- Produces: `Effect_ModifyGuard.max_abs_change: int = 0` and `resolve_guard_delta(current_guard: int) -> int`.
- Produces: `Effect_Damage_Inversion.max_guard_points: int = 0`.
- Produces: `Condition.get_damage_dealt_power_bonus(attacker, target) -> float`.
- Produces: `ConditionSourcePowerBonus.power_type` and `power_scalar`, sourced from `Condition.attacker`.

- [ ] **Step 1: Write failing tests**

```gdscript
func test_percent_guard_removal_rounds_up_and_caps() -> void:
	var effect := Effect_ModifyGuard.new()
	effect.percent_change = -0.5
	effect.max_abs_change = 5
	assert_eq(effect.resolve_guard_delta(3), -2)
	assert_eq(effect.resolve_guard_delta(20), -5)


func test_inversion_caps_guard_points() -> void:
	var effect := Effect_Damage_Inversion.new()
	effect.max_guard_points = 10
	assert_eq(effect._resolve_hit_count(null, {"guard_gained": 4}), 4)
	assert_eq(effect._resolve_hit_count(null, {"guard_gained": 14}), 10)


func test_source_power_bonus_reads_condition_creator_psy() -> void:
	var condition := ConditionSourcePowerBonus.new()
	condition.power_type = Action.PowerType.PSYCHE
	condition.power_scalar = 1.0
	condition.attacker = _actor_with_power(Action.PowerType.PSYCHE, 40)
	assert_eq(condition.get_damage_dealt_power_bonus(null, null), 40.0)
```

Also assert the resulting `POWER` contribution is divided by `DamageRequest.distribution_count`.

- [ ] **Step 2: Run and require failures**

```bash
env HOME=/private/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test/unit/test_damage_scaling_rules.gd,test/unit/test_damage_effect_execution.gd -gexit
```

- [ ] **Step 3: Implement Guard capping**

```gdscript
@export var guard_amount: int = 1
@export var percent_change: float = 0.0
@export_range(0, 99, 1) var max_abs_change: int = 0


func resolve_guard_delta(current_guard: int) -> int:
	var delta := floori(float(current_guard) * percent_change) \
		if not is_zero_approx(percent_change) else guard_amount
	if max_abs_change > 0:
		delta = clampi(delta, -max_abs_change, max_abs_change)
	return delta
```

Call `resolve_guard_delta(target_actor.current_guard)` in `execute()`.

- [ ] **Step 4: Implement Inversion capping**

```gdscript
@export_range(0, 99, 1) var max_guard_points: int = 0


func _resolve_hit_count(_attacker: ActorCard, context: Dictionary = {}) -> int:
	if not context.has("guard_gained"):
		push_error("Inversion effect triggered without 'guard_gained' context!")
		return 0
	var guard_gained := maxi(0, int(context["guard_gained"]))
	return mini(guard_gained, max_guard_points) if max_guard_points > 0 else guard_gained
```

Remove the unused `remove_guard_gained` export.

- [ ] **Step 5: Implement source-power contributions**

Base condition:

```gdscript
func get_damage_dealt_power_bonus(_attacker: ActorCard, _target: ActorCard) -> float:
	return 0.0
```

New file:

```gdscript
class_name ConditionSourcePowerBonus
extends Condition

@export var power_type: Action.PowerType = Action.PowerType.PSYCHE
@export var power_scalar: float = 1.0


func get_damage_dealt_power_bonus(_attacker: ActorCard, _target: ActorCard) -> float:
	if not is_instance_valid(attacker):
		return 0.0
	return float(attacker.get_power(power_type)) * power_scalar
```

Inside `ActorCard.get_damage_dealt_contributions()`, before the outgoing contribution:

```gdscript
var power_bonus := condition.get_damage_dealt_power_bonus(self, target)
if not is_zero_approx(power_bonus):
	contributions.append(DamageContribution.new(
		_damage_modifier_source("condition", condition.condition_name, condition.resource_path),
		DamageContribution.Stage.POWER,
		power_bonus,
	))
```

- [ ] **Step 6: Re-run Step 2; require all assertions to pass and include the generated `.gd.uid`**

- [ ] **Step 7: Commit**

```bash
git add src/scripts/action_effects/effect_modify_guard.gd src/scripts/action_effects/effect_damage_inversion.gd src/scripts/conditions/condition.gd src/scripts/conditions/condition_source_power_bonus.gd src/scripts/conditions/condition_source_power_bonus.gd.uid src/battle/actor_card.gd test/unit/test_damage_scaling_rules.gd test/unit/test_damage_effect_execution.gd
git commit -m "feat: add capped and source-scaled role effects"
```

---

### Task 4: Synchronize Asher

**Files:**
- Modify: `data/heroes/asher/actions/fusion_ammo.tres`
- Modify: `data/heroes/asher/actions/siphon_shots.tres`
- Modify: `data/heroes/asher/actions/charged_shot.tres`
- Modify: `data/heroes/asher/actions/mark_target.tres`
- Modify: `data/heroes/asher/actions/aimed_shot.tres`
- Modify: `data/heroes/asher/actions/concussive_shot.tres`
- Modify: `data/heroes/asher/actions/dismantle.tres`
- Modify: `data/heroes/asher/actions/teamwork.tres`
- Modify: `data/heroes/asher/actions/coordinate.tres`
- Modify: `data/heroes/asher/actions/decoy.tres`
- Modify: `data/heroes/asher/actions/debilitate.tres`
- Modify: `data/heroes/asher/actions/ensnare.tres`
- Modify: `data/heroes/asher/conditions/fusion_ammo.tres`
- Modify: `data/heroes/asher/conditions/coordinate.tres`
- Modify: `data/heroes/asher/roles/opr.tres`
- Test: `test/integration/test_damage_content.gd`
- Test: `test/integration/test_progression_content.gd`

**Interfaces:**
- Consumes: Tasks 2-3.
- Produces: GDD Gunner, Sniper, and complete Operative resources.

- [ ] **Step 1: Add failing content assertions**

```gdscript
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
```

Assert Operative order `[Coordinate, Decoy, Debilitate, Ensnare]`, Shift `Dismantle`, passive `Teamwork`; Teamwork observes `ON_ENEMY_BREACHED` and grants all heroes 1 Focus.

- [ ] **Step 2: Run and require drift failures**

```bash
env HOME=/private/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test/integration/test_damage_content.gd,test/integration/test_progression_content.gd -gexit
```

- [ ] **Step 3: Update Gunner and Sniper**

```gdscript
# Fusion Ammo: CT 75%; extra 50% PSY Energy hit until Shift or Breached.
# Remove the undocumented +25% outgoing damage.
# Siphon Shots
potency = 0.75
hit_count = 3
lifedrain_scalar = 0.5
# Charged Shot grants 2 Focus for Vulnerable OR Breached.
# Mark Target
ct_cost_percent = 50
# Aimed Shot / Concussive Shot
potency = 2.0
potency = 5.5
```

Keep Suppressive Fire, Bullet Time, Double Tap, Bullet Storm, Exploit Weakness, and Targeting Laser mechanically unchanged.

- [ ] **Step 4: Complete Operative**

```gdscript
# Dismantle
percent_change = -0.5
max_abs_change = 5
# Coordinate
refund_focus_cost_on_spend = true
remove_on_triggers = Array[int]([Trigger.TriggerType.ON_SPENDING_FOCUS])
# Decoy
focus_cost = 1
guard_amount = 1
is_untargetable = true
remove_on_triggers = Array[int]([Trigger.TriggerType.ON_TURN_START])
# Debilitate
focus_cost = 2
damage_dealt_scalar = -0.35
# Ensnare
focus_cost = 2
potency = 1.5
speed_scalar = -0.25
```

Remove Decoy's unrelated `Effect_RemoveCondition("Return Fire")`; its effects are only Guard and untargetability. Ensnare's slow ends when its target gains Guard. Teamwork is a passive condition on Asher with an `ON_ENEMY_BREACHED` trigger, `Effect_ModifyFocus.focus_amount = 1`, and `target_type = ALL_ALLIES`; the passive condition removes on Asher's next `ON_SHIFT`.

Wire `opr.tres` to the four real action paths, Dismantle, and Teamwork; use role description: `OPERATIVE[p][i]A tactical support specialist who controls enemy momentum and enables the team.`

- [ ] **Step 5: Re-run Step 2; Asher assertions must pass**

- [ ] **Step 6: Commit**

```bash
git add data/heroes/asher test/integration/test_damage_content.gd test/integration/test_progression_content.gd
git commit -m "feat: synchronize Asher roles with GDD"
```

---

### Task 5: Synchronize Echo

**Files:**
- Modify: `data/heroes/echo/actions/shatter.tres`
- Modify: `data/heroes/echo/actions/focused_bolt.tres`
- Modify: `data/heroes/echo/actions/energy_barrier.tres`
- Modify: `data/heroes/echo/actions/reverberate.tres`
- Modify: `data/heroes/echo/actions/mind_storm.tres`
- Modify: `data/heroes/echo/actions/kinetic_wall.tres`
- Modify: `data/heroes/echo/actions/telepathy.tres`
- Modify: `data/heroes/echo/actions/telekinesis.tres`
- Modify: `data/heroes/echo/actions/rejuvenate.tres`
- Modify: `data/heroes/echo/actions/pain_transfer.tres`
- Modify: `data/heroes/echo/actions/energize.tres`
- Modify: `data/heroes/echo/actions/force_field.tres`
- Modify: `data/heroes/echo/actions/displace.tres`
- Modify: `data/heroes/echo/actions/feedback.tres`
- Modify: `data/heroes/echo/actions/static_charge.tres`
- Modify: `data/heroes/echo/actions/inversion.tres`
- Modify: `data/heroes/echo/conditions/psionic_pulse_cond.tres`
- Modify: `data/heroes/echo/conditions/energy_barrier.tres`
- Modify: `data/heroes/echo/conditions/reverberate.tres`
- Modify: `data/heroes/echo/conditions/telepathy.tres`
- Modify: `data/heroes/echo/conditions/pain_transfer.tres`
- Modify: `data/heroes/echo/conditions/feedback.tres`
- Modify: `data/heroes/echo/conditions/static_charge.tres`
- Modify: `data/heroes/echo/conditions/inversion.tres`
- Modify: `data/heroes/echo/roles/kin.tres`
- Modify: `data/heroes/echo/roles/dom.tres`
- Create: `data/heroes/echo/actions/precognition.tres`
- Include when generated: `data/heroes/echo/actions/precognition.tres.uid`
- Test: `test/integration/test_damage_content.gd`
- Test: `test/unit/test_damage_effect_execution.gd`

**Interfaces:**
- Consumes: Tasks 2-3.
- Produces: GDD Psion, Kineticist, and player-facing Telepath while retaining internal `dom`.

- [ ] **Step 1: Add failing Echo assertions**

```gdscript
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
```

Assert player names `Force Field`, `Acuity`, `Reconstruct`, `Telepath`, `Suppress`, and `Precognition`; reject obsolete player names.

- [ ] **Step 2: Run and require drift failures**

```bash
env HOME=/private/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test/integration/test_damage_content.gd,test/unit/test_damage_effect_execution.gd -gexit
```

- [ ] **Step 3: Update Psion**

```gdscript
# Shatter
potency_per_point = 0.5
split_damage = true
# Psionic Pulse
potency = 0.35
power_type = Action.PowerType.PSYCHE
# Focused Bolt
potency_per_point = 0.25
# Energy Barrier
guard_amount = 2
potency = 1.5
# Reverberate
focus_cost = 3
potency = 2.0 # both initial and triggered hit
# Mind Storm
potency = 5.0
potency_per_point = 0.2 # Focus remaining after payment
```

Preserve Shatter's Guard clear and Reverberate's next-Kinetic-hit trigger.

- [ ] **Step 4: Update Kineticist**

```gdscript
# kinetic_wall.tres
action_name = "Force Field"
guard_amount = 1
# telepathy.tres and condition
action_name = "Acuity"
condition_name = "Acuity"
focus_amount = 2
remove_on_triggers = Array[int]([Trigger.TriggerType.ON_SHIFT])
# Telekinesis
potency = 0.75
focus_amount = 1
# rejuvenate.tres
action_name = "Reconstruct"
focus_cost = 2
potency = 0.5
focus_scalar = 0.5
# Pain Transfer
focus_cost = 2
potency = 2.0
# Enemy-held trigger
potency = 0.5
target_type = Action.TargetType.ALL_ALLIES
# Energize
focus_cost = 4
ct_cost_percent = 50
focus_amount = 4
```

Set `kin.tres` description to a healer/support identity.

- [ ] **Step 5: Update Telepath**

```gdscript
# Reuse force_field.tres as internal Shift path
action_name = "Suppress"
is_shift_action = true
damage_dealt_scalar = -0.25
remove_on_triggers = Array[int]([Trigger.TriggerType.ON_SHIFT])
# Precognition passive
action_name = "Precognition"
guard_amount = 1
target_type = Action.TargetType.ALL_ALLIES
remove_on_triggers = Array[int]([Trigger.TriggerType.ON_SHIFT])
# Displace
guard_amount = 1
# retain one-debuff removal
# Feedback ON_BEING_HIT effects, per hit of next attack
guard_amount = -1
potency = 0.5
damage_type = Action.DamageType.PIERCING
# Static Charge
ct_change_percent = -0.25
speed_scalar = -0.25
potency = 1.0
damage_type = Action.DamageType.PIERCING
# Inversion
focus_cost = 3
potency = 0.5
damage_type = Action.DamageType.PIERCING
max_guard_points = 10
```

Suppress applies the `-0.25` debuff to one enemy and a `Suppress Cleanup` marker to Echo. The marker's `ON_SHIFT` trigger runs `Effect_RemoveCondition(condition_name = "Suppress", target_type = ALL_ENEMIES)`, then removes itself; this ties cleanup to Echo's Shift rather than the enemy's turn or Shift. Static Charge's slow ends on the target's next turn, when its delayed hit fires. Remove serialized `remove_guard_gained`. Wire `dom.tres` as role ID `dom`, name `Telepath`, actions `[Displace, Feedback, Static Charge, Inversion]`, Shift `Suppress`, passive `Precognition`.

- [ ] **Step 6: Re-run Step 2 and require all Echo assertions to pass**

- [ ] **Step 7: Commit**

```bash
git add data/heroes/echo test/integration/test_damage_content.gd test/unit/test_damage_effect_execution.gd
git commit -m "feat: synchronize Echo roles with GDD"
```

---

### Task 6: Synchronize Sands

**Files:**
- Modify: `data/heroes/sands/actions/draw_fire.tres`
- Modify: `data/heroes/sands/actions/focus_fire.tres`
- Modify: `data/heroes/sands/actions/phalanx.tres`
- Modify: `data/heroes/sands/actions/triage.tres`
- Modify: `data/heroes/sands/actions/first_aid.tres`
- Modify: `data/heroes/sands/actions/booster_shots.tres`
- Modify: `data/heroes/sands/actions/auto_shields.tres`
- Modify: `data/heroes/sands/actions/advantage.tres`
- Modify: `data/heroes/sands/actions/checkmate.tres`
- Modify: `data/heroes/sands/conditions/painkillers.tres`
- Preserve and verify: `data/heroes/sands/actions/fianchetto.tres`
- Preserve and verify: `data/heroes/sands/conditions/fianchetto.tres`
- Modify: `data/heroes/sands/roles/van.tres`
- Modify: `data/heroes/sands/roles/med.tres`
- Modify: `data/heroes/sands/roles/stg.tres`
- Test: `test/integration/test_damage_content.gd`
- Test: `test/unit/test_damage_scaling_rules.gd`

**Interfaces:**
- Consumes: Tasks 2-3.
- Produces: GDD Vanguard, Medic, and Strategist.

- [ ] **Step 1: Add failing Sands assertions**

```gdscript
const SANDS_GDD := {
	"draw_fire": {"focus": 1},
	"crossfire": {"cost": 2, "potency": 2.5, "split": true, "focus_per_breached": 1},
	"phalanx": {"cost": 4, "potency": 0.35, "hits": 4, "guard_per_breached": 1},
	"triage": {"heal": 0.5, "missing_hp": true},
	"painkillers": {"reduction": -0.10},
	"first_aid": {"heal": 0.75, "missing_hp": false},
	"covering_fire": {"cost": 1, "potency": 0.5, "hits": 2},
	"auto_shield": {"cost": 2, "guard": 1, "heal": 0.5},
	"advantage": {"cost": 3, "ct_boost": 0.5, "source_psy": 1.0},
	"checkmate": {"potency": 3.0, "ct_change": -0.5},
}
```

Assert player-facing `Crossfire`, `Covering Fire`, and `Auto-Shield`. Assert Fianchetto is 10% and removes `Fianchetto`, never `Tactician`.

- [ ] **Step 2: Run and require failures**

```bash
env HOME=/private/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test/integration/test_damage_content.gd,test/unit/test_damage_scaling_rules.gd -gexit
```

- [ ] **Step 3: Update Vanguard**

```gdscript
# Draw Fire also grants Sands 1 Focus.
focus_amount = 1
# focus_fire.tres
action_name = "Crossfire"
focus_cost = 2
potency = 2.5
split_damage = true
# Preserve 1 Focus per Breached target hit.
# Phalanx
focus_cost = 4
potency = 0.35
hit_count = 4
# Preserve 1 Guard per Breached hit.
```

Keep Opening Salvo, Return Fire, and Overwatch unchanged.

- [ ] **Step 4: Update Medic**

```gdscript
# Triage
potency = 0.5
scales_with_missing_hp = true
# Painkillers
damage_taken_scalar = -0.10
# First Aid
potency = 0.75
scales_with_missing_hp = false
# booster_shots.tres
action_name = "Covering Fire"
focus_cost = 1
potency = 0.5
hit_count = 2
# Preserve/double Painkillers until Sands shifts.
# auto_shields.tres
action_name = "Auto-Shield"
focus_cost = 2
guard_amount = 1
potency = 0.5
remove_on_triggers = Array[int]([Trigger.TriggerType.ON_SHIFT])
```

Auto-Shield applies Guard/healing immediately and repeats both at the start of the target's turns until that target shifts. Bastion stays cost 4, party +3 Guard.

- [ ] **Step 5: Update Strategist**

Advantage:

```gdscript
focus_cost = 3
ct_change_percent = 0.5
# Its applied condition uses ConditionSourcePowerBonus:
condition_name = "Advantage"
power_type = Action.PowerType.PSYCHE
power_scalar = 1.0
remove_on_triggers = Array[int]([Trigger.TriggerType.AFTER_ATTACKING])
```

Remove `damage_dealt_scalar = 0.5`. The `POWER` contribution is divided by the attack's normal hit/target divisor.

Checkmate:

```gdscript
potency = 3.0
ct_change_percent = -0.5
```

Keep Opening Move, Tempo, and Gambit unchanged. Preserve the user's Fianchetto cleanup and verify 10%.

- [ ] **Step 6: Re-run Step 2 and inspect overlapping diffs**

```bash
git diff -- data/heroes/sands/actions/booster_shots.tres data/heroes/sands/actions/checkmate.tres data/heroes/sands/actions/fianchetto.tres data/heroes/sands/conditions/fianchetto.tres
```

Expected: tests pass; user-authored ext resources and Fianchetto cleanup remain.

- [ ] **Step 7: Commit only Sands task files**

```bash
git add data/heroes/sands/actions/draw_fire.tres data/heroes/sands/actions/focus_fire.tres data/heroes/sands/actions/phalanx.tres data/heroes/sands/actions/triage.tres data/heroes/sands/conditions/painkillers.tres data/heroes/sands/actions/first_aid.tres data/heroes/sands/actions/booster_shots.tres data/heroes/sands/actions/auto_shields.tres data/heroes/sands/actions/advantage.tres data/heroes/sands/actions/checkmate.tres data/heroes/sands/actions/fianchetto.tres data/heroes/sands/conditions/fianchetto.tres data/heroes/sands/roles/van.tres data/heroes/sands/roles/med.tres data/heroes/sands/roles/stg.tres test/integration/test_damage_content.gd test/unit/test_damage_scaling_rules.gd
git commit -m "feat: synchronize Sands roles with GDD"
```

---

### Task 7: Add Temporary Operative and Telepath Progression

**Files:**
- Modify: `data/progression/asher/opr.json`
- Modify: `data/progression/echo/dom.json`
- Modify: `test/integration/test_progression_content.gd`
- Modify: `test/integration/test_endgame_battle_lab.gd`
- Modify: `test/unit/test_endgame_party_factory.gd`
- Modify: `test/integration/test_controller_playable_loop.gd`

**Interfaces:**
- Produces: each graph at revision 3 with 7 nodes, paid XP 1400, effects `action:4, shift_action:1, passive:1, stat:0`.

- [ ] **Step 1: Write failing graph assertions**

```gdscript
"opr": {"nodes": 7, "total_xp": 1400, "effects": {"action": 4, "shift_action": 1, "passive": 1, "stat": 0}},
"dom": {"nodes": 7, "total_xp": 1400, "effects": {"action": 4, "shift_action": 1, "passive": 1, "stat": 0}},
```

Also assert each node's resource, slot, rank, parent, cost, and starting ownership.

- [ ] **Step 2: Run and require placeholder failures**

```bash
env HOME=/private/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test/integration/test_progression_content.gd -gexit
```

- [ ] **Step 3: Replace `opr.json` nodes**

```json
[
  {"id":"opr.anchor","node_kind":"role_anchor","parent":null,"rank":1,"column":0},
  {"id":"opr.coordinate","node_kind":"progression","parent":"opr.anchor","rank":1,"column":-1,"xp_cost":0,"starting_owned":true,"effect":{"type":"action","resource":"res://data/heroes/asher/actions/coordinate.tres","slot":1}},
  {"id":"opr.decoy","node_kind":"progression","parent":"opr.anchor","rank":1,"column":1,"xp_cost":0,"starting_owned":true,"effect":{"type":"action","resource":"res://data/heroes/asher/actions/decoy.tres","slot":2}},
  {"id":"opr.debilitate","node_kind":"progression","parent":"opr.coordinate","rank":2,"column":-1,"xp_cost":200,"effect":{"type":"action","resource":"res://data/heroes/asher/actions/debilitate.tres","slot":3}},
  {"id":"opr.ensnare","node_kind":"progression","parent":"opr.decoy","rank":3,"column":1,"xp_cost":300,"effect":{"type":"action","resource":"res://data/heroes/asher/actions/ensnare.tres","slot":4}},
  {"id":"opr.dismantle","node_kind":"progression","parent":"opr.ensnare","rank":4,"column":0,"xp_cost":400,"effect":{"type":"shift_action","resource":"res://data/heroes/asher/actions/dismantle.tres"}},
  {"id":"opr.teamwork","node_kind":"progression","parent":"opr.dismantle","rank":5,"column":0,"xp_cost":500,"effect":{"type":"passive","resource":"res://data/heroes/asher/actions/teamwork.tres"}}
]
```

Set `content_revision: 3`; keep schema 2 and role ID `opr`.

- [ ] **Step 4: Replace `dom.json` nodes**

```json
[
  {"id":"dom.anchor","node_kind":"role_anchor","parent":null,"rank":1,"column":0},
  {"id":"dom.displace","node_kind":"progression","parent":"dom.anchor","rank":1,"column":-1,"xp_cost":0,"starting_owned":true,"effect":{"type":"action","resource":"res://data/heroes/echo/actions/displace.tres","slot":1}},
  {"id":"dom.feedback","node_kind":"progression","parent":"dom.anchor","rank":1,"column":1,"xp_cost":0,"starting_owned":true,"effect":{"type":"action","resource":"res://data/heroes/echo/actions/feedback.tres","slot":2}},
  {"id":"dom.static_charge","node_kind":"progression","parent":"dom.displace","rank":2,"column":-1,"xp_cost":200,"effect":{"type":"action","resource":"res://data/heroes/echo/actions/static_charge.tres","slot":3}},
  {"id":"dom.inversion","node_kind":"progression","parent":"dom.feedback","rank":3,"column":1,"xp_cost":300,"effect":{"type":"action","resource":"res://data/heroes/echo/actions/inversion.tres","slot":4}},
  {"id":"dom.suppress","node_kind":"progression","parent":"dom.inversion","rank":4,"column":0,"xp_cost":400,"effect":{"type":"shift_action","resource":"res://data/heroes/echo/actions/force_field.tres"}},
  {"id":"dom.precognition","node_kind":"progression","parent":"dom.suppress","rank":5,"column":0,"xp_cost":500,"effect":{"type":"passive","resource":"res://data/heroes/echo/actions/precognition.tres"}}
]
```

Set revision 3; preserve schema 2 and internal role ID `dom`. Use the new `precognition.tres` path authored in Task 5.

- [ ] **Step 5: Update dependent integration expectations**

In `test/integration/test_endgame_battle_lab.gd` and `test/unit/test_endgame_party_factory.gd`, expect Operative's four actions in order plus its Shift and passive. Add equivalent Telepath four-action, Shift, passive, and player-name assertions. In `test/integration/test_controller_playable_loop.gd`, replace starting IDs `opr.root` and `dom.root` with `opr.coordinate` and `dom.displace`.

- [ ] **Step 6: Run progression and dependent tests; require all to pass**

```bash
env HOME=/private/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test/integration/test_progression_content.gd,test/integration/test_endgame_battle_lab.gd,test/unit/test_endgame_party_factory.gd,test/integration/test_controller_playable_loop.gd -gexit
```

- [ ] **Step 7: Commit**

```bash
git add data/progression/asher/opr.json data/progression/echo/dom.json test/integration/test_progression_content.gd test/integration/test_endgame_battle_lab.gd test/unit/test_endgame_party_factory.gd test/integration/test_controller_playable_loop.gd
git commit -m "feat: complete operative and telepath progression"
```

---

### Task 8: Reconcile Validation and Verify the Whole Game

**Files:**
- Modify: `test/integration/test_damage_content.gd`
- Review: `docs/superpowers/specs/2026-07-19-gdd-role-synchronization-design.md`

**Interfaces:**
- Consumes: Tasks 1-7.
- Produces: formula allowlists and regression assertions matching the GDD, plus fresh full-suite evidence.

- [ ] **Step 1: Replace drifted validation fixtures**

Update `APPROVED_DESCRIPTION_FORMULAS`, `NESTED_COMPATIBILITY_CASES`, and `DEFERRED_DIRECT_HEALING_FORMULAS` to the exact manifests in Tasks 4-6. Remove entries blessing obsolete Focused Bolt, Charged Shot, Booster Shots, Shatter, Reverberate, Psionic Pulse, Static Charge, or Telekinesis values.

Add exact name checks:

```gdscript
assert_eq(_action("res://data/heroes/echo/actions/rejuvenate.tres").action_name, "Reconstruct")
assert_eq(_action("res://data/heroes/echo/actions/kinetic_wall.tres").action_name, "Force Field")
assert_eq(_action("res://data/heroes/echo/actions/telepathy.tres").action_name, "Acuity")
assert_eq(_action("res://data/heroes/sands/actions/focus_fire.tres").action_name, "Crossfire")
assert_eq(_action("res://data/heroes/sands/actions/booster_shots.tres").action_name, "Covering Fire")
assert_eq(_action("res://data/heroes/sands/actions/auto_shields.tres").action_name, "Auto-Shield")
assert_eq(_role("res://data/heroes/echo/roles/dom.tres").role_name, "Telepath")
```

- [ ] **Step 2: Run all focused files**

```bash
env HOME=/private/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect=test/unit/test_battle_condition_targets.gd,test/unit/test_ctb_simulator.gd,test/unit/test_damage_scaling_rules.gd,test/unit/test_damage_effect_execution.gd,test/integration/test_damage_content.gd,test/integration/test_progression_content.gd -gexit
```

Expected: all selected tests pass; no parser errors, crashes, or unexpected failures.

- [ ] **Step 3: Inspect scope and overlapping user edits**

```bash
git status --short
git diff --check
git diff -- data/heroes/sands/actions/booster_shots.tres data/heroes/sands/actions/checkmate.tres data/heroes/sands/actions/fianchetto.tres data/heroes/sands/conditions/fianchetto.tres
```

Expected: no whitespace errors, Fianchetto cleanup remains correct, unrelated files remain untouched/unstaged.

- [ ] **Step 4: Run the complete suite**

```bash
env HOME=/private/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: exit 0 and all tests pass. Document expected shutdown diagnostics separately; parser errors, crashes, and unexpected failures are unacceptable.

- [ ] **Step 5: Perform manual presentation and combat checks**

Launch the endgame battle lab with isolated local data. For Asher, Echo, and Sands, inspect all three role names, four action buttons, Shift label, passive label, Focus/CT costs, and dynamic tooltips. Exercise one representative loop per hero: Operative Coordinate plus an enemy Breach, Kineticist Pain Transfer plus a defeated ally, Telepath Suppress/Feedback/Static Charge/Inversion, Medic Auto-Shield through a target Shift, and Strategist Advantage with a multi-hit attack. Expected: player-facing copy matches the GDD, no defeated hero revives, timed conditions expire on the documented event, and no runtime errors appear.

- [ ] **Step 6: Audit the final content**

```bash
rg -n 'Dominator|Kinetic Wall|Telepathy|Rejuvenate|Focus Fire|Booster Shots|Auto Shields' data/heroes test
rg -n 'is_revive = true' data/heroes
```

Expected: no obsolete player-facing names and no ordinary hero heal opting into revival. Check every design-spec bullet against a concrete test assertion and confirm unchanged actions were not mechanically altered.

- [ ] **Step 7: Commit final validation adjustments**

```bash
git add test/integration/test_damage_content.gd
git commit -m "test: validate GDD role synchronization"
```

- [ ] **Step 8: Handoff**

Report exact focused/full-suite counts and exit status, manual checks not performed, the repaired `actor_breached` argument bug, temporary progression assumptions, and unrelated dirty files intentionally left uncommitted.
