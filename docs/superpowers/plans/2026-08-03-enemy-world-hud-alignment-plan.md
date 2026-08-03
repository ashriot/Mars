# Enemy World HUD Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a compact, scene-editable enemy HUD with a rounded HP bar, layered guard pips, predictable inspection details, direct model anchoring, and continuously looping Eye Drone idle motion.

**Architecture:** Enemy guard capacity is a combatant rule: the base/hero cap remains 10 and `EnemyCombatant` overrides it to 30. A reusable `EnemyGuardStack` scene owns all thirty pre-authored shield visuals and exposes a small render API to `EnemyWorldHUD`; `EnemyWorldHUD` owns every visible position relative to one projected head anchor. `BattleWorld3D` only clamps each HUD to the viewport safe rectangle. Inspection focus remains distinct from multi-target availability. `EnemyDronePresentation` configures only the imported ambient Idle animation to loop.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` resources, GUT 9.6.1.

## Global Constraints

- Preserve the user's Exo 2 replacements in `archivo.tres`, `suse_mono_bold.tres`, and their new font assets; do not add a HUD-specific font.
- Preserve unrelated edits in actor data, action-bar/button scenes, hero-card scenes, battle scenes, and lighting scenes.
- Keep the visible enemy HUD 160 pixels wide with a 108-pixel rounded HP bar.
- Place shield layers at the same ten X positions with Y offsets `0`, `5`, and `10` only.
- Keep target hit geometry based on projected 3D model bounds.
- Use `VULNERABLE` at zero guard while `is_in_danger`; use `BREACHED` after the vulnerable enemy is hit and `is_breached` becomes true.
- Details always open below their owning compact HUD. They never trigger inter-HUD collision resolution.
- Idle loops; Attack, Hit, and other action animations remain one-shot clips.
- Run all automated Godot commands with isolated `HOME=/tmp/mars-godot-home`.
- Before every commit, inspect the staged diff. If a named file already contains unrelated hunks, stage only the task's hunks rather than staging the whole file.

---

### Task 1: Give Enemies a 30-Guard Cap Without Changing Heroes

**Files:**
- Modify: `src/battle/combatants/battle_combatant.gd`
- Modify: `src/battle/combatants/enemy_combatant.gd`
- Test: `test/unit/test_battle_combatant.gd`
- Test: `test/unit/test_enemy_combatant.gd`
- Test: `test/unit/test_hero_combatant.gd`

**Interfaces:**
- Consumes: the existing `BattleCombatant.MAX_GUARD := 10` default and `BattleCombatant.modify_guard(amount: int, is_recovering: bool = false) -> void`.
- Produces: `BattleCombatant.get_guard_cap() -> int` and `EnemyCombatant.MAX_ENEMY_GUARD := 30`.

- [ ] **Step 1: Write failing cap tests**

Add tests proving:

```gdscript
await hero.modify_guard(99)
assert_eq(hero.current_guard, 10)
assert_eq(hero.get_guard_cap(), 10)

await enemy.modify_guard(99)
assert_eq(enemy.current_guard, 30)
assert_eq(enemy.get_guard_cap(), 30)
```

Also assert that large negative changes still clamp both combatant types to zero and enter the existing vulnerable state.

- [ ] **Step 2: Run the focused cap tests and verify RED**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_battle_combatant.gd,res://test/unit/test_enemy_combatant.gd,res://test/unit/test_hero_combatant.gd -gexit
```

Expected: the enemy still clamps at 10 or the new cap interface is missing.

- [ ] **Step 3: Implement the polymorphic guard cap**

Keep `BattleCombatant.MAX_GUARD` as 10 for existing hero/content references. Route `modify_guard()` through `get_guard_cap()`, and override only the enemy implementation. Do not change focus caps, starting-guard authoring, recovery semantics, or breach rules.

```gdscript
# battle_combatant.gd
func get_guard_cap() -> int:
	return MAX_GUARD

# Replace only the existing clamp line inside modify_guard():
current_guard = clampi(current_guard + amount, 0, get_guard_cap())

# enemy_combatant.gd
const MAX_ENEMY_GUARD := 30

func get_guard_cap() -> int:
	return MAX_ENEMY_GUARD
```

- [ ] **Step 4: Run the cap tests and verify GREEN**

Run the command from Step 2. Expected: all selected scripts pass.

- [ ] **Step 5: Commit the combat rule**

```bash
git add src/battle/combatants/battle_combatant.gd src/battle/combatants/enemy_combatant.gd test/unit/test_battle_combatant.gd test/unit/test_enemy_combatant.gd test/unit/test_hero_combatant.gd
git commit -m "feat: allow enemies to hold thirty guard"
```

### Task 2: Build the Scene-Editable Layered Guard Stack

**Files:**
- Create: `src/battle/presentation/enemy_guard_stack.tscn`
- Create: `src/battle/presentation/enemy_guard_stack.gd`
- Preserve Godot sidecar: `src/battle/presentation/enemy_guard_stack.gd.uid`
- Create: `test/unit/test_enemy_guard_stack.gd`
- Preserve Godot sidecar: `test/unit/test_enemy_guard_stack.gd.uid`

**Interfaces:**
- Consumes: `res://assets/graphics/icons/textures/shield.png` and the current bold theme font resource.
- Produces: `EnemyGuardStack.render(guard: int, is_in_danger: bool, is_breached: bool) -> void` and `EnemyGuardStack.get_visual_layer_count() -> int`.

**Scene contract:**
- Three scene-authored layer controls at local Y positions `0`, `5`, and `10`, each containing ten shield `TextureRect` children at the same X positions.
- One `GuardValue` label overlays the newest visible shield.
- One `StatusLabel` occupies the same minimum one-layer slot and renders `VULNERABLE` or `BREACHED` at zero guard.
- Public method: `render(guard: int, is_in_danger: bool, is_breached: bool) -> void`.
- Public method: `get_visual_layer_count() -> int`, returning 1, 2, or 3; zero guard retains one layer of layout height.

- [ ] **Step 1: Write failing guard-stack tests**

Instantiate the new scene and cover representative states:

- `0 / danger`: no shields, `VULNERABLE` visible, one-layer height.
- `0 / breached`: no shields, `BREACHED` visible, one-layer height.
- `7`: seven white pips in layer 1; value `7` inside column 7; one-layer height.
- `10`: ten white pips; value `10` inside column 10.
- `13`: ten medium-gray pips in layer 1, three white pips in layer 2, value `13` inside layer-2 column 3; two-layer height.
- `23`: ten dark-gray pips in layer 1, ten medium-gray pips in layer 2, three white pips in layer 3, value `23` inside layer-3 column 3; three-layer height.
- `30`: all three layers visible with value `30` inside layer-3 column 10.
- Inputs above 30 render as 30 defensively without changing combatant state.

Assert that corresponding pips in each layer have identical X positions and exact `5`-pixel Y differences.

- [ ] **Step 2: Run the guard-stack test and verify RED**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_guard_stack.gd -gexit
```

Expected: the new scene/script does not exist.

- [ ] **Step 3: Author the reusable guard scene**

Create all shield nodes in `enemy_guard_stack.tscn` so their size, spacing, colors, and texture remain editable in the Godot inspector. Use the existing shield texture. The script should only select visibility/modulation, move the integer label over the newest shield, choose the status text, and update its minimum height to `base_height + 5 * (layer_count - 1)`.

Layer rendering rules:

- current/top partial layer: white;
- one completed layer below the current layer: medium gray;
- two completed layers below the current layer: bottom dark gray, middle medium gray;
- unfilled pips in the current layer: hidden.

Do not create pips dynamically at runtime and do not offset later layers horizontally.

Use this rendering structure:

```gdscript
extends Control
class_name EnemyGuardStack

const MAX_GUARD := 30
const PIPS_PER_LAYER := 10
const LAYER_STEP := 5.0
const WHITE := Color.WHITE
const MEDIUM_GRAY := Color(0.62, 0.65, 0.7, 1.0)
const DARK_GRAY := Color(0.34, 0.37, 0.42, 1.0)

@onready var layers: Array[Control] = [%Layer1, %Layer2, %Layer3]
@onready var guard_value: Label = %GuardValue
@onready var status_label: Label = %StatusLabel
var _guard := 0

func render(guard: int, is_in_danger: bool, is_breached: bool) -> void:
	var value := clampi(guard, 0, MAX_GUARD)
	_guard = value
	var layer_count := get_visual_layer_count()
	status_label.text = "BREACHED" if is_breached \
		else ("VULNERABLE" if is_in_danger else "")
	status_label.visible = value == 0 and not status_label.text.is_empty()
	guard_value.visible = value > 0
	for layer_index: int in layers.size():
		var visible_count := clampi(value - layer_index * PIPS_PER_LAYER, 0, PIPS_PER_LAYER)
		for pip_index: int in PIPS_PER_LAYER:
			var pip := layers[layer_index].get_child(pip_index) as TextureRect
			pip.visible = pip_index < visible_count
			pip.modulate = _layer_color(layer_index, layer_count)
	if value > 0:
		var current_layer := floori(float(value - 1) / PIPS_PER_LAYER)
		var current_column := (value - 1) % PIPS_PER_LAYER
		var current_pip := layers[current_layer].get_child(current_column) as TextureRect
		guard_value.text = str(value)
		guard_value.position = layers[current_layer].position + current_pip.position
	custom_minimum_size.y = %Layer1.size.y + LAYER_STEP * float(layer_count - 1)

func get_visual_layer_count() -> int:
	return clampi(ceili(float(maxi(_guard, 1)) / PIPS_PER_LAYER), 1, 3)

func _layer_color(layer_index: int, layer_count: int) -> Color:
	if layer_index == layer_count - 1:
		return WHITE
	if layer_count == 3 and layer_index == 0:
		return DARK_GRAY
	return MEDIUM_GRAY
```

- [ ] **Step 4: Run the guard-stack test and verify GREEN**

Run the command from Step 2. Expected: all states, positions, colors, and labels pass.

- [ ] **Step 5: Commit the guard component**

```bash
git add src/battle/presentation/enemy_guard_stack.tscn src/battle/presentation/enemy_guard_stack.gd src/battle/presentation/enemy_guard_stack.gd.uid test/unit/test_enemy_guard_stack.gd test/unit/test_enemy_guard_stack.gd.uid
git commit -m "feat: add layered enemy guard display"
```

### Task 3: Rebuild the Compact HUD Around Rounded HP and Guard States

**Files:**
- Modify: `src/battle/presentation/enemy_world_hud.tscn`
- Modify: `src/battle/presentation/enemy_world_hud.gd`
- Test: `test/unit/test_enemy_world_hud.gd`

**Scene contract:**
- Compact width: 160 pixels.
- Intent row first.
- Rounded `ProgressBar` HP: 108 pixels wide, no percentage text, six-pixel corner radius on background and fill.
- `EnemyGuardStack` overlaps the HP bar's lower edge slightly.
- Conditions are five pixels below the guard/status slot and therefore move downward only 5 pixels at guard 11 and another 5 pixels at guard 21.
- Details are centered below the current compact-stack height with a four-pixel gap.

**Interfaces:**
- Consumes: `EnemyGuardStack.render(guard: int, is_in_danger: bool, is_breached: bool) -> void`.
- Produces: `EnemyWorldHUD.is_hovered() -> bool` and a compact rect whose width is fixed while its height follows the guard layer count.

- [ ] **Step 1: Write failing HUD composition tests**

Extend `test_enemy_world_hud.gd` to assert:

- the compact and intent widths are 160;
- HP is a `ProgressBar`, width 108, `show_percentage == false`;
- HP background/fill are `StyleBoxFlat` resources with all four corner radii equal to 6;
- the guard scene is instantiated beneath HP and overlaps it by the authored amount;
- condition Y is five pixels below the guard component at guard 0, 7, 13, and 23;
- changing from 7 to 13 to 23 moves conditions and details by exactly 5 pixels per threshold, never by a full row;
- binding and signals render `VULNERABLE` from `danger_changed` and `BREACHED` from `breached`;
- `GuardValue` is inside the current shield through the guard component;
- the scene continues to resolve its existing bold font resource, allowing the user's Exo 2 replacement to flow through automatically.

- [ ] **Step 2: Run the HUD test and verify RED**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_world_hud.gd -gexit
```

Expected: old 220-pixel geometry, `TextureProgressBar`, single shield, missing danger/breach bindings, or old detail placement fails.

- [ ] **Step 3: Make the scene own its compact geometry**

In `enemy_world_hud.tscn`:

- replace the current horizontal single-shield/HP row with a centered vertical vitals group;
- replace `TextureProgressBar` with `ProgressBar` and scene-authored rounded background/fill `StyleBoxFlat` resources;
- instance `enemy_guard_stack.tscn` under HP with a small negative vertical separation so shields/status overlap HP;
- keep `ConditionsRow` in normal container flow five pixels below the actual guard component;
- set `Details` below the compact stack rather than above it;
- keep the current theme font resource and reduce only intent size if necessary for the 160-pixel width.

In `enemy_world_hud.gd`:

- type HP as `ProgressBar` and guard as `EnemyGuardStack`;
- connect/disconnect `danger_changed` and `breached` in addition to existing guard/condition signals;
- route `_render_guard()` through the guard component using `current_guard`, `is_in_danger`, and `is_breached`;
- reposition details from the current compact-stack height after guard depth changes;
- expose `is_hovered() -> bool` for the later inspection task.

Remove the old direct `GuardIcon`/`GuardValue` rendering only after the new component is in place. Preserve node unique IDs wherever the same semantic node remains.

Use these runtime seams:

```gdscript
@onready var guard_stack: EnemyGuardStack = %GuardStack
@onready var hp_bar: ProgressBar = %HP

func _render_guard() -> void:
	guard_stack.render(
		combatant.current_guard,
		combatant.is_in_danger,
		combatant.is_breached,
	)
	call_deferred(&"_sync_details_position")

func _sync_details_position() -> void:
	details.position = Vector2(0.0, compact_stack.size.y + DETAILS_GAP)

func is_hovered() -> bool:
	return _hovered
```

- [ ] **Step 4: Run the HUD test and verify GREEN**

Run the command from Step 2. Expected: all HUD geometry and state tests pass.

- [ ] **Step 5: Commit the compact HUD rebuild**

```bash
git add src/battle/presentation/enemy_world_hud.tscn src/battle/presentation/enemy_world_hud.gd test/unit/test_enemy_world_hud.gd
git commit -m "feat: rebuild compact enemy HUD"
```

### Task 4: Anchor HUDs Directly to Models and Standardize Inspection

**Files:**
- Modify: `src/battle/presentation/battle_world_3d.gd`
- Modify: `src/battle/presentation/combatant_presentation.gd`
- Modify: `src/battle/presentation/enemy_drone_presentation.gd`
- Modify: `src/battle/presentation/enemy_world_hud.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/battle/battle_scene.gd`
- Test: `test/unit/test_enemy_world_hud.gd`
- Test: `test/integration/test_battle_world_3d.gd`
- Test: `test/integration/test_enemy_drone_presentation.gd`
- Test: `test/integration/test_battle_controller_navigation.gd`

**Interfaces:**
- Consumes: the existing projected head/model bounds and `BattleManager.presentation_for(combatant: BattleCombatant) -> CombatantPresentation`.
- Produces: `EnemyWorldHUD.get_desired_compact_rect() -> Rect2` centered over the projected head and `CombatantPresentation.set_inspection_focused(focused: bool) -> void` distinct from broad `AVAILABLE`/`SELECTED` visuals.

- [ ] **Step 1: Write failing direct-anchor tests**

Replace collision-staircase expectations with two close projected heads. Assert both compact HUDs retain the same Y when their head anchors share a Y and that each X remains centered on its own anchor. Add safe-edge cases proving each rect clamps independently. Keep the existing projected-model target-region assertions unchanged so the visible HUD shrink cannot reduce clickability.

- [ ] **Step 2: Write failing inspection-ownership tests**

Add coverage proving:

- pointer hover reveals only its own detail block;
- moving controller focus transfers detail visibility from the previous enemy to the new enemy;
- clearing focus hides the detail block;
- group target availability/selection can outline multiple enemies without opening multiple detail blocks;
- replacing a presentation transfers inspection focus to its replacement;
- every visible details block is below its own compact stack and uses the same relative four-pixel rule.

- [ ] **Step 3: Run the focused layout/focus tests and verify RED**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_world_hud.gd,res://test/integration/test_battle_world_3d.gd,res://test/integration/test_enemy_drone_presentation.gd,res://test/integration/test_battle_controller_navigation.gd -gexit
```

Expected: old collision resolution displaces HUDs and target selection still controls details directly.

- [ ] **Step 4: Remove inter-enemy HUD collision solving**

In `battle_world_3d.gd`, replace `EnemyHUDLayout.resolve()` and `_resolve_details_rect()` with independent safe-area clamping of each HUD's desired rect. Remove detail candidate-search helpers. Do not alter projected model bounds or target regions.

```gdscript
func _layout_enemy_huds() -> void:
	if not is_instance_valid(hud_layer):
		return
	var layer_size := hud_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		layer_size = get_viewport().get_visible_rect().size
	var safe_rect := Rect2(Vector2.ZERO, layer_size).grow(-HUD_SAFE_MARGIN)
	for child: Node in hud_layer.get_children():
		if child is not EnemyWorldHUD:
			continue
		var hud := child as EnemyWorldHUD
		hud.set_safe_rect(safe_rect)
		if not hud.visible or not hud.has_valid_projection():
			continue
		var rect := hud.get_desired_compact_rect()
		rect.position.x = clampf(
			rect.position.x, safe_rect.position.x, safe_rect.end.x - rect.size.x,
		)
		rect.position.y = clampf(
			rect.position.y, safe_rect.position.y, safe_rect.end.y - rect.size.y,
		)
		hud.apply_resolved_compact_rect(rect)
```

- [ ] **Step 5: Implement explicit inspection ownership**

Add `inspection_focused` and its setter to `CombatantPresentation`. Have `BattleScene` clear the old presentation and focus exactly one new presentation whenever `_current_target` changes. Transfer that state in `BattleManager` when replacing a presentation. In `EnemyDronePresentation`, reveal details only when acting, explicitly inspection-focused, or pointer-hovered. Remove detail visibility changes from generic target-state highlighting.

```gdscript
# combatant_presentation.gd
var inspection_focused := false

func set_inspection_focused(focused: bool) -> void:
	inspection_focused = focused

# enemy_drone_presentation.gd
func set_inspection_focused(focused: bool) -> void:
	super.set_inspection_focused(focused)
	_refresh_details_visibility()

func _refresh_details_visibility() -> void:
	if is_instance_valid(hud):
		hud.set_details_visible(acting or inspection_focused or hud.is_hovered())

# battle_scene.gd
func _set_inspection_focus(target: BattleCombatant, focused: bool) -> void:
	var presentation := manager.presentation_for(target) if manager != null else null
	if presentation != null:
		presentation.set_inspection_focused(focused)
```

- [ ] **Step 6: Run focused tests and verify GREEN**

Run the command from Step 3. Expected: all selected scripts pass, with unrelated action-button geometry failures reported separately rather than repaired in this task.

- [ ] **Step 7: Commit alignment and inspection ownership**

```bash
git add src/battle/presentation/battle_world_3d.gd src/battle/presentation/combatant_presentation.gd src/battle/presentation/enemy_drone_presentation.gd src/battle/presentation/enemy_world_hud.gd src/battle/battle_manager.gd src/battle/battle_scene.gd test/unit/test_enemy_world_hud.gd test/integration/test_battle_world_3d.gd test/integration/test_enemy_drone_presentation.gd test/integration/test_battle_controller_navigation.gd
git commit -m "fix: align enemy HUD inspection to models"
```

### Task 5: Loop Idle and Verify the Integrated Battle View

**Files:**
- Modify: `src/battle/presentation/enemy_drone_presentation.gd`
- Test: `test/integration/test_enemy_drone_presentation.gd`
- Verify: `test/integration/test_endgame_battle_lab.gd`
- Update only if behavior instructions changed: `docs/testing/endgame-battle-lab-checklist.md`

**Interfaces:**
- Consumes: the `AnimationPlayer` discovered by `EnemyDronePresentation._prepare_model(model_root: Node3D)`.
- Produces: `EnemyDronePresentation._configure_ambient_animations() -> void`, modifying only an existing `Idle` clip.

- [ ] **Step 1: Write the failing animation test**

In the animated-drone fixture, leave `Idle.loop_mode = Animation.LOOP_NONE`. After binding, assert Idle is `Animation.LOOP_LINEAR` while Attack and Hit remain `Animation.LOOP_NONE`.

- [ ] **Step 2: Run the animation test and verify RED**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_enemy_drone_presentation.gd -gunit_test_name=idle -gexit
```

Expected: imported Idle remains one-shot.

- [ ] **Step 3: Configure only Idle as an ambient loop**

After discovering the `AnimationPlayer`, set the existing Idle animation's `loop_mode` to `Animation.LOOP_LINEAR` before playback. Models without Idle retain the safe fallback. Do not modify Attack, Hit, Charging, BackFlip, or Look.

```gdscript
func _configure_ambient_animations() -> void:
	if not is_instance_valid(animation_player):
		return
	if not animation_player.has_animation(&"Idle"):
		return
	animation_player.get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
```

- [ ] **Step 4: Parse/import and run the integrated test set**

```bash
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_battle_combatant.gd,res://test/unit/test_enemy_combatant.gd,res://test/unit/test_hero_combatant.gd,res://test/unit/test_enemy_guard_stack.gd,res://test/unit/test_enemy_world_hud.gd,res://test/integration/test_enemy_drone_presentation.gd,res://test/integration/test_battle_world_3d.gd,res://test/integration/test_battle_controller_navigation.gd,res://test/integration/test_endgame_battle_lab.gd -gexit
```

Expected: parse exits 0 with no parser errors and all selected tests pass. The documented macOS CA/shutdown warning remains acceptable if the process exits successfully.

- [ ] **Step 5: Perform manual visual acceptance**

At `1920x1080` and `1280x800`, verify:

- four- and five-enemy W/M formations keep each HUD centered on its own model without a stair-step;
- HP fill/background have clean rounded corners at partial and full values;
- guard values 0, 7, 13, 23, and 30 use the approved layering, gray hierarchy, and exact-number placement;
- `VULNERABLE` changes to `BREACHED` after the next hit and both slightly overlap HP;
- conditions remain five pixels below the real guard/status depth without a large empty gap;
- hover/controller details always open below their owner and only one detail block is visible;
- group targeting outlines all affected enemies without expanding all details;
- clicking anywhere on the projected drone body still selects it;
- Idle continues beyond 3.33 seconds without freezing;
- the Exo 2 font remains active throughout the HUD.

- [ ] **Step 6: Review preservation and commit the idle fix**

Before staging, confirm no unrelated actor data, theme/font assets, action-bar/button, hero-card, battle-scene, or lighting edits are included. The Exo 2 changes stay in the user's worktree unless the user separately asks to commit them.

```bash
git add src/battle/presentation/enemy_drone_presentation.gd test/integration/test_enemy_drone_presentation.gd
git commit -m "fix: loop enemy idle animation"
```
