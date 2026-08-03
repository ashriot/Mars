# Readable Enemy HUD and Formation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task by task. Use `superpowers:test-driven-development` for every behavior change and `superpowers:verification-before-completion` before the final handoff.

**Goal:** Restore a readable 220-pixel model-anchored enemy HUD, directional damage/healing feedback, and a more pronounced W/M diorama formation without overwriting the user's current room, font, action-bar, or hero-card scene work.

**Architecture:** `BattleFormationLayout` owns stronger authored world-space rows that project into five stable screen columns. `EnemyWorldHUD` remains a scene-editable projected UI and owns its dual HP layers, guard/status composition, tooltip, and health tween. `EnemyDronePresentation` joins HUD health animation with its existing hit/defeat operations so battle sequencing waits for every relevant visual without coupling unrelated operations. A small shared health-feedback palette gives actor cards and enemy HUDs the same yellow-damage/green-healing language without editing the user's dirty card scenes.

**Tech Stack:** Godot 4.7.1, GDScript, Godot text scenes/resources, GUT 9.6.1.

## Global Constraints

- Work in the primary checkout. Do not create a worktree.
- Begin with `git diff --cached --quiet` and stop if the index is not clean. Existing unstaged changes belong to the user.
- Preserve every unrelated hunk in the dirty files listed by `git status`, especially `hero_card.tscn`, `battle_world_3d.tscn`, `enemy_drone_presentation.gd`, `test_enemy_drone_presentation.gd`, the action-bar scenes, lighting/room scenes, enemy resources, and Exo 2 font work.
- Do not edit `hero_card.tscn`, `enemy_card.tscn`, `battle_world_3d.tscn`, or either industrial-room scene for this implementation. Apply actor-card feedback color at runtime and obtain the first formation pass entirely from authored enemy transforms.
- When a task touches a dirty file, inspect `git diff -- <file>` before and after editing, then stage only the task hunks with `git add -p <file>`. Never stage a whole dirty file reflexively.
- Preserve Godot-generated `.uid` and `.import` sidecars required by new source files. Never stage `.godot/` or the ignored Quaternius local-model tree.
- Keep enemy compact HUDs centered on their projected head anchors. Do not add a collision solver, per-HUD staircase offset, detached top rail, or screen-space formation override.
- Keep projected model bounds as the pointer target. Keep valid-target outlines and inspection-detail ownership separate from compact-HUD highlighting.
- Keep enemy guard capped at 30 and hero guard capped at 10. Do not change existing guard gameplay, layer colors, vertical-only 5-pixel stacking, `VULNERABLE`, or `BREACHED` rules.
- Keep Idle looping and transient Attack/Hit/Charging clips one-shot. Do not alter animation import resources.
- Run every Godot command with `HOME=/tmp/mars-godot-home` and Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot`.
- GUT 9.6.1 selects one filename substring per run with `-gselect`. Do not use `-gtest=` or pipe-delimited selectors.
- Purely visual acceptance remains manual. Automated geometry tests protect the contract but do not establish that the composition looks good on real displays.

## Responsibility Map

- `src/battle/presentation/health_feedback_palette.gd`: shared feedback colors and safe per-control style overrides.
- `src/battle/actor_card.gd`: stages actor-card damage/healing using the shared palette; existing health tween remains authoritative.
- `src/battle/presentation/enemy_guard_stack.tscn`: inspector-editable 202-pixel shield geometry.
- `src/battle/presentation/enemy_world_hud.tscn`: inspector-editable 220-pixel compact/detail geometry and layered rounded HP bars.
- `src/battle/presentation/enemy_world_hud.gd`: HP staging, tooltip metadata, feedback tween, guard/condition layout, and existing targeting input.
- `src/battle/presentation/combatant_presentation.gd`: protected operation-join helper that waits for independent children without cancelling them.
- `src/battle/presentation/enemy_drone_presentation.gd`: owns the enemy health operation and joins it with hit/defeat presentation.
- `src/battle/presentation/battle_formation_layout.gd`: authored W/M front/back transforms only.
- Unit tests: exact scene geometry, colors, guard behavior, health staging, and authored transforms.
- Integration tests: actor-card behavior, enemy presentation-operation lifetime, projected five-HUD containment/nonintersection, and detail placement.
- `docs/testing/ctb-combat-checklist.md`: unresolved hands-on visual and physical-input acceptance.

---

### Task 1: Share Yellow-Damage and Green-Healing Feedback With Actor Cards

**Files:**

- Create: `src/battle/presentation/health_feedback_palette.gd`
- Preserve generated sidecar: `src/battle/presentation/health_feedback_palette.gd.uid`
- Modify: `src/battle/actor_card.gd`
- Test: `test/integration/test_card_combatant_binding.gd`

**Interfaces:**

- Produce `HealthFeedbackPalette.Direction { DAMAGE, HEALING }`.
- Produce `HealthFeedbackPalette.apply(bar: ProgressBar, direction: Direction) -> void`.
- Preserve `ActorCard.sync_visual_health() -> Tween` and its existing timing semantics.

- [ ] **Step 1: Add failing directional-color assertions**

Extend the existing damage and healing tests in `test_card_combatant_binding.gd`. Read the effective `fill` style from `card.hp_bar_ghost`, assert it is a `StyleBoxFlat`, and assert:

```gdscript
assert_eq(
	(card.hp_bar_ghost.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color,
	HealthFeedbackPalette.DAMAGE_YELLOW,
)
```

after `damage_received`, and `HealthFeedbackPalette.HEALING_GREEN` after `healing_received`. Also assert the feedback bar is visible while feedback is staged and both bars finish at authoritative HP after the tween.

- [ ] **Step 2: Run the card test and verify RED**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect card_combatant_binding -gexit
```

Expected: the healing case still uses the scene's yellow fill and the shared palette class does not exist.

- [ ] **Step 3: Implement a non-shared style override**

Create the helper with exact semantic colors:

```gdscript
extends RefCounted
class_name HealthFeedbackPalette

enum Direction { DAMAGE, HEALING }

const DAMAGE_YELLOW := Color(0.98, 0.76766664, 0.0, 1.0)
const HEALING_GREEN := Color(0.20, 0.90, 0.45, 1.0)


static func apply(bar: ProgressBar, direction: Direction) -> void:
	var source := bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	assert(source != null, "Health feedback requires a StyleBoxFlat fill.")
	var style := source.duplicate() as StyleBoxFlat
	var color := DAMAGE_YELLOW if direction == Direction.DAMAGE else HEALING_GREEN
	style.bg_color = color
	style.border_color = color
	bar.add_theme_stylebox_override(&"fill", style)
```

Duplicating the style is required; mutating the scene/theme resource would recolor every card sharing it. In `ActorCard._on_combatant_presentation_event()`, apply yellow before staging damage and green before staging healing, and show `hp_bar_ghost` immediately for either event. Do not change health values, tween duration, hit shake, popup behavior, or the existing `sync_visual_health()` branch logic.

- [ ] **Step 4: Import once, run the card test, and verify GREEN**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect card_combatant_binding -gexit
```

Expected: import exits zero; all card-binding tests pass; damage ends with yellow staged feedback and healing with green staged feedback.

- [ ] **Step 5: Commit only the shared feedback change**

```bash
git diff --check
git add src/battle/presentation/health_feedback_palette.gd src/battle/presentation/health_feedback_palette.gd.uid src/battle/actor_card.gd test/integration/test_card_combatant_binding.gd
git diff --cached --check
git commit -m "feat: color health feedback by direction"
```

---

### Task 2: Rebuild the Editable Enemy HUD at 220 Pixels With Dual HP Layers

**Files:**

- Modify: `src/battle/presentation/enemy_guard_stack.tscn`
- Modify: `src/battle/presentation/enemy_world_hud.tscn`
- Modify: `src/battle/presentation/enemy_world_hud.gd`
- Test: `test/unit/test_enemy_guard_stack.gd`
- Test: `test/unit/test_enemy_world_hud.gd`

**Scene contract:**

- Compact and detail width: `220` pixels.
- Intent row width: `220` pixels.
- HP region: `168 x 18`, centered at local X `26`.
- HP feedback and actual bars share the same rectangle and six-pixel rounded corners. Feedback is below; pink actual health is above with a transparent background.
- Guard scene natural width: `202` pixels, centered at local X `9`.
- Guard pips: `22 x 22` at local X positions `0, 20, 40, ..., 180`; layer Y positions stay `0`, `5`, and `10`.
- Guard/status overlaps the HP region at the existing `GUARD_TOP := 14` seam. Conditions remain five pixels below the guard/status component's real depth.
- Details stay four pixels below the compact stack and never flip.

**Runtime interface:**

- Replace the single `hp_bar` field with `hp_region: Control`, `hp_bar_feedback: ProgressBar`, and `hp_bar_actual: ProgressBar`.
- Produce `EnemyWorldHUD.sync_visual_health() -> Tween`.
- Preserve `EnemyWorldHUD.get_desired_compact_rect()`, projected-bound targeting, `is_hovered()`, detail visibility, and defeat ownership.

- [ ] **Step 1: Change geometry tests first and add health-staging tests**

In `test_enemy_guard_stack.gd`, replace the 160-pixel expectation with `GUARD_WIDTH := 202.0`; assert every layer is 202 pixels wide, each pip is 22 pixels wide, and adjacent pip X positions differ by exactly 20 pixels. Retain every current 0/7/10/13/23/30 guard, layer-color, integer-label, and vertical-offset assertion.

In `test_enemy_world_hud.gd`, change the compact width to 220 and HP width to 168. Assert the dual bars, exact centered positions, rounded styles, z-order, percentage suppression, tooltip, 202-pixel guard centered at X 9, fixed detail placement, and existing input/model-target behavior.

Add damage/healing tests using a bound enemy and presentation events:

```gdscript
# Damage: authoritative foreground drops immediately; old yellow value remains.
assert_eq(hud.hp_bar_actual.value, 60.0)
assert_eq(hud.hp_bar_feedback.value, 100.0)
assert_eq(_fill_color(hud.hp_bar_feedback), HealthFeedbackPalette.DAMAGE_YELLOW)

# Healing: green target is staged; pink actual remains old until sync.
assert_eq(hud.hp_bar_actual.value, 40.0)
assert_eq(hud.hp_bar_feedback.value, 60.0)
assert_eq(_fill_color(hud.hp_bar_feedback), HealthFeedbackPalette.HEALING_GREEN)
```

Advance the returned tween and assert both bars settle at `combatant.current_hp`. Interrupt a running tween with a second event and assert the replacement begins from displayed values and settles at the latest authoritative HP.

- [ ] **Step 2: Run both unit tests separately and verify RED**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_guard_stack -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_world_hud -gexit
```

Expected: old 160/108 geometry and the single HP bar fail the new contract.

- [ ] **Step 3: Expand the authored guard scene without changing its script rules**

In `enemy_guard_stack.tscn`, set the root and each layer to 202 pixels wide. Move all three layers' pips to the exact X sequence `0, 20, ..., 180`; each pip ends 22 pixels after its X origin. Keep the three layer Y positions, node names, unique names, shield texture, value label behavior, status label, colors, and script unchanged unless a test exposes a width constant in the script.

- [ ] **Step 4: Author the dual-bar HUD scene**

In `enemy_world_hud.tscn`:

```text
VitalsGroup
├── HPRegion (Control, 168x18 at x=26, mouse_filter=PASS)
│   ├── HPFeedback (ProgressBar, full rect, mouse_filter=IGNORE)
│   └── HPActual (ProgressBar, full rect, mouse_filter=IGNORE)
└── GuardStack (202px at x=9, y=14)
```

Give `HPFeedback` the rounded dark background and an initial yellow rounded fill. Give `HPActual` a transparent background and the current pink rounded fill. Both bars have `show_percentage = false`. Expand `EnemyWorldHUD`, `CompactStack`, `IntentRow`, `VitalsAndConditions`, `VitalsGroup`, `ConditionsRow`, and `Details` to the authored 220-pixel width. Preserve semantic node unique IDs where the semantic node survives; do not hand-normalize unrelated generated fields.

- [ ] **Step 5: Stage and animate enemy health in `EnemyWorldHUD`**

Use the same direction model as actor cards:

```gdscript
func _on_presentation_event(
	_enemy: BattleCombatant,
	event: StringName,
	_payload: Dictionary,
) -> void:
	match event:
		&"damage_received":
			HealthFeedbackPalette.apply(
				hp_bar_feedback, HealthFeedbackPalette.Direction.DAMAGE,
			)
			hp_bar_actual.value = combatant.current_hp
		&"healing_received":
			HealthFeedbackPalette.apply(
				hp_bar_feedback, HealthFeedbackPalette.Direction.HEALING,
			)
			hp_bar_feedback.value = combatant.current_hp
		&"intent_changed":
			refresh_intent()
```

`_render_full_state()` initializes both bars to authoritative HP. The ordinary `hp_changed` callback updates both maxima and the `"current / max HP"` tooltip, but must not collapse staged values before `sync_visual_health()` runs. `sync_visual_health()` mirrors `ActorCard.sync_visual_health()`: kill only the prior HUD health tween, tween pink upward for healing or feedback downward for damage over `0.5 / battle_speed`, return `null` when settled, and never write combatant state. Use battle speed `1.0` only when no valid manager is available in a unit fixture.

Connect hover/click input to `HPRegion`; its child bars ignore mouse input so events are not duplicated. Kill the health tween in `_exit_tree()` in addition to the existing details tween.

- [ ] **Step 6: Run both unit tests and verify GREEN**

Run the two commands from Step 2. Expected: both selected suites pass, including all retained guard/status, safe-edge, detail, targeting, and defeat tests.

- [ ] **Step 7: Commit the self-contained HUD component**

```bash
git diff --check
git add src/battle/presentation/enemy_guard_stack.tscn src/battle/presentation/enemy_world_hud.tscn src/battle/presentation/enemy_world_hud.gd test/unit/test_enemy_guard_stack.gd test/unit/test_enemy_world_hud.gd
git diff --cached --check
git commit -m "feat: restore readable layered enemy health hud"
```

---

### Task 3: Join Enemy Health, Hit, and Defeat Presentation Operations Safely

**Files:**

- Modify: `src/battle/presentation/combatant_presentation.gd`
- Modify carefully; already dirty: `src/battle/presentation/enemy_drone_presentation.gd`
- Modify carefully; already dirty: `test/integration/test_enemy_drone_presentation.gd`
- Test: `test/integration/test_presentation_operation_cancellation.gd`

**Interfaces:**

- Produce protected `CombatantPresentation._operation_when_all(operations: Array[PresentationOperation]) -> PresentationOperation`.
- Add one private `_health_operation: PresentationOperation` to `EnemyDronePresentation`.
- Preserve public `EnemyDronePresentation.sync_visual_health() -> PresentationOperation`.

- [ ] **Step 1: Write failing operation-lifetime tests**

Add or extend tests proving:

- damage starts a pending HUD health operation and the existing pending Hit operation;
- the operation returned by `sync_visual_health()` completes only after both children complete;
- healing waits for the HUD health tween without starting Hit;
- a second health event completes/replaces only the previous health operation and does not complete Attack, Hit, acting, or shutdown work;
- freeing, unregistering, or replacing the presentation completes the joined wait exactly once;
- an absent optional model still permits HUD health feedback and does not block on nonexistent animation clips.

Add a focused test for `_operation_when_all()` through a small test subclass: already-completed children are ignored, two pending children must both finish, and completing the joined operation does not complete its children.

- [ ] **Step 2: Run the two integration suites separately and verify RED**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_drone_presentation -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect presentation_operation_cancellation -gexit
```

Expected: enemy health is not represented by a presentation operation and the join helper is missing.

- [ ] **Step 3: Implement a non-owning operation join**

In `CombatantPresentation`, filter out null/completed children. Return `already_completed()` when none remain. Otherwise begin one tracked joined operation, subscribe once to every pending child, decrement a shared remaining counter, and complete the joined operation only when the count reaches zero. The joined operation observes children; it must never complete or cancel them.

Use a dictionary-backed counter and a bound callback so GDScript mutates shared state safely:

```gdscript
func _operation_when_all(
	operations: Array[PresentationOperation],
) -> PresentationOperation:
	var pending: Array[PresentationOperation] = []
	for operation: PresentationOperation in operations:
		if operation != null and not operation.is_completed:
			pending.append(operation)
	if pending.is_empty():
		return PresentationOperation.already_completed()
	var joined := _begin_operation()
	var remaining := {&"count": pending.size()}
	for child: PresentationOperation in pending:
		child.completed.connect(
			_on_joined_child_completed.bind(joined, remaining),
			CONNECT_ONE_SHOT,
		)
	return joined


func _on_joined_child_completed(
	joined: PresentationOperation,
	remaining: Dictionary,
) -> void:
	if joined.is_completed:
		return
	remaining[&"count"] = int(remaining[&"count"]) - 1
	if int(remaining[&"count"]) == 0:
		joined.complete()
```

- [ ] **Step 4: Integrate the HUD health tween into `EnemyDronePresentation`**

In `sync_visual_health()`:

1. Return the existing shutdown operation unchanged when defeat is active.
2. Complete only the prior `_health_operation` before replacing a running health tween.
3. Ask `hud.sync_visual_health()` for the current tween and wrap it with `_operation_for_tween()`.
4. Join the new health operation with the current `_hit_operation` using `_operation_when_all()`.
5. Return an already-completed operation when neither child is pending.

Clear `_health_operation` only when its exact operation completes. Do not change current action replacement, hit animation, shutdown fade, outline, lighting/material, idle-loop, or projection code. On cancellation/free, the inherited pending-operation registry remains the single cleanup boundary.

- [ ] **Step 5: Run both integration suites and verify GREEN**

Run the two commands from Step 2. Expected: all health/hit/defeat joins and cancellation cases pass once, with no stuck waits.

- [ ] **Step 6: Inspect and selectively commit the dirty presentation files**

```bash
git diff -- src/battle/presentation/enemy_drone_presentation.gd test/integration/test_enemy_drone_presentation.gd
git add src/battle/presentation/combatant_presentation.gd test/integration/test_presentation_operation_cancellation.gd
git add -p src/battle/presentation/enemy_drone_presentation.gd
git add -p test/integration/test_enemy_drone_presentation.gd
git diff --cached --check
git diff --cached --stat
git commit -m "feat: synchronize enemy health presentation"
```

Before committing, confirm the staged diff contains no material/lighting, outline, local-model, room, or unrelated test-fixture hunks that predated this task.

---

### Task 4: Exaggerate W/M Depth Into Five Stable Projected Columns

**Files:**

- Modify: `src/battle/presentation/battle_formation_layout.gd`
- Test: `test/unit/test_battle_formation_layout.gd`
- Create: `test/integration/test_enemy_hud_formation_projection.gd`
- Preserve generated sidecar: `test/integration/test_enemy_hud_formation_projection.gd.uid`

**Authored transform candidate:**

Use these exact first-pass slots. Positive Z is closer to the camera at Z 9.5; negative Z is farther away.

```gdscript
# W: three far/back, two near/front.
const W_BACK_LEFT := Vector3(-4.60, 0.0, -2.20)
const W_BACK_CENTER := Vector3(0.0, 0.0, -2.60)
const W_BACK_RIGHT := Vector3(4.60, 0.0, -2.20)
const W_FRONT_LEFT := Vector3(-1.55, 0.0, 1.80)
const W_FRONT_RIGHT := Vector3(1.55, 0.0, 1.80)

# M: two far/back, three near/front.
const M_BACK_LEFT := Vector3(-2.35, 0.0, -2.20)
const M_BACK_RIGHT := Vector3(2.35, 0.0, -2.20)
const M_FRONT_LEFT := Vector3(-3.05, 0.0, 1.80)
const M_FRONT_CENTER := Vector3(0.0, 0.0, 2.20)
const M_FRONT_RIGHT := Vector3(3.05, 0.0, 1.80)
```

Counts one through five retain their present row-membership rules and authored subset ordering. Boss and boss-ally transforms remain unchanged.

- [ ] **Step 1: Update formation unit expectations and add projection acceptance tests**

First update `test_battle_formation_layout.gd` with the exact slots above for every W/M count. Add assertions that every mixed-row layout has at least 4 world units of front/back Z separation and that boss transforms are untouched.

Create `test_enemy_hud_formation_projection.gd`. Instantiate the real battle world and five bound drone views for W and M at logical canvas sizes `1920x1080` and `1920x1200` (the latter represents the project's expanded 16:10 logical canvas; physical `1280x800` remains manual). After placement and projection:

- assert every compact HUD is exactly 220 pixels wide;
- assert all five compact rectangles are inside the world's 24-pixel safe rectangle;
- assert every pair of compact rectangles does not intersect;
- assert front-row projected model bounds are larger than corresponding back-row bounds;
- show details for each enemy one at a time and assert its detail rectangle stays at the fixed four-pixel-below offset and does not intersect another compact HUD;
- assert each HUD target rectangle contains the center of its own projected model bounds;
- assert selecting/availability does not move the compact rectangle.

Do not assert raw physical `1280x800` coordinates in a direct `SubViewport`; that bypasses the project's 1920x1080 `canvas_items` stretch contract.

- [ ] **Step 2: Run the formation tests and verify RED**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_formation_layout -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_hud_formation_projection -gexit
```

Expected: old transforms fail exact depth expectations; projected 220-pixel HUDs overlap under the old formation.

- [ ] **Step 3: Replace only ordinary formation transforms**

Refactor the dictionaries to use the named slot constants above so W/M membership is readable. Do not change maximum enemy count, layout enum, transform basis, view ownership, camera, room, boss center volume, or boss ally X positions.

If the integration test shows a subpixel intersection from font/guard height or projection rounding, tune only ordinary X/Z slot constants while retaining:

- W = three back and two front;
- M = two back and three front;
- at least 4 units of depth separation;
- back models visibly smaller than front models;
- all models within the existing authored room volume.

Do not solve overlap by reducing the 220-pixel HUD, shifting HUDs away from model centers, or editing the dirty world/camera scene.

- [ ] **Step 4: Run formation, world, HUD, and idle-loop regressions**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_formation_layout -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_hud_formation_projection -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_world_3d -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_drone_presentation -gexit
```

Expected: all selected suites pass; the existing Idle loop test still reports `LOOP_LINEAR` while Attack and Hit remain `LOOP_NONE`.

- [ ] **Step 5: Commit the formation and projection contract**

```bash
git diff --check
git add src/battle/presentation/battle_formation_layout.gd test/unit/test_battle_formation_layout.gd test/integration/test_enemy_hud_formation_projection.gd test/integration/test_enemy_hud_formation_projection.gd.uid
git diff --cached --check
git commit -m "feat: deepen ordinary enemy formations"
```

---

### Task 5: Record Manual Acceptance and Verify the Complete Change

**Files:**

- Modify: `docs/testing/ctb-combat-checklist.md`

- [ ] **Step 1: Add a pending readable-HUD acceptance subsection**

Under the first-person 3D battle slice, add unchecked items for both physical `1920x1080` and desktop-proxy `1280x800`:

- W and M five-enemy model/HUD attribution and visibly distinct depth rows;
- no compact HUD overlap, including long intent text, 23/30 guard, conditions, safe-edge clamping, and one open detail block;
- 168-pixel rounded HP readability without permanent exact-HP text; tooltip shows `current / max`;
- yellow delayed damage and green delayed healing on enemies and every hero/actor card;
- mouse model clicking, green valid-target outline, controller selection/inspection, and unchanged face-button skill selection;
- uninterrupted Idle motion after attacks and hits;
- no regression to room lighting, ceiling practicals, model readability, action bar, hero card height, or Exo 2 typography.

Leave every item unchecked until the user performs it. State that Steam Deck hardware acceptance is still distinct from the desktop proxy.

- [ ] **Step 2: Run import/parse and every focused task suite**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect card_combatant_binding -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_guard_stack -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_world_hud -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect presentation_operation_cancellation -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_drone_presentation -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_formation_layout -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_hud_formation_projection -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_world_3d -gexit
```

Expected: import exits zero without parser/resource errors and every selected suite passes.

- [ ] **Step 3: Run the complete automated suite**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: no new failures. If the user's already-dirty endgame battle-lab HP multiplier still causes its known single failure, report the exact total and failure separately; do not alter or stage that scene/test and do not describe the full suite as passing.

- [ ] **Step 4: Review source and staged scope**

```bash
git diff --check
git status --short
git diff --cached --check
```

Inspect the task commits and confirm no user-owned font, action-bar, hero-card scene, room/lighting, enemy-resource, or battle-lab hunk entered them. Confirm the local Quaternius tree remains ignored and untracked.

- [ ] **Step 5: Commit the pending manual checklist**

```bash
git add docs/testing/ctb-combat-checklist.md
git diff --cached --check
git commit -m "docs: add readable enemy hud acceptance"
```

- [ ] **Step 6: Stop for hands-on acceptance**

Ask the user to run the endgame battle lab in W and M at physical `1920x1080` and desktop-proxy `1280x800`. Report exact automated totals, the known unrelated baseline failure if still present, and the unchecked manual items. Do not claim the visual design is accepted until the user approves the live result.
