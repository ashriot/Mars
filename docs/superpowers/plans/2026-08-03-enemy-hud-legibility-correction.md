# Enemy HUD Legibility Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the projected enemy HUD proportionate and readable by using a full-width HP bar, separated foreground guard pips, larger type, and inspection details above the persistent HUD.

**Architecture:** Keep `EnemyWorldHUD` as the editable owner of compact and inspection geometry and keep `EnemyGuardStack` as the reusable owner of guard layering. Preserve the 220-pixel compact width and all combat/presentation signals; change only scene-authored geometry, draw order, typography, and the small positioning calculation for the fixed upper detail block.

**Tech Stack:** Godot 4.7.1 scenes and GDScript, GUT 9.7.1 tests.

## Global Constraints

- Use Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot`.
- Keep the compact enemy HUD exactly 220 pixels wide; do not retune formation transforms.
- Keep the HP feedback colors, 5-pixel downward guard-layer step, targeting behavior, combat rules, and condition behavior unchanged.
- Guard pips are 21 pixels wide on 22-pixel centers, producing a 1-pixel horizontal gap.
- Inspection details appear above the persistent HUD without moving the compact stack.
- Preserve all unrelated user-owned working-tree changes.

---

### Task 1: Separate and foreground the guard strip

**Files:**
- Modify: `src/battle/presentation/enemy_guard_stack.tscn`
- Modify: `test/unit/test_enemy_guard_stack.gd`

**Interfaces:**
- Consumes: `EnemyGuardStack.render(guard: int, is_in_danger: bool, is_breached: bool) -> void` and the existing three-layer, ten-column structure.
- Produces: a 220-pixel guard component whose ten 21-pixel pips occupy X positions `0, 22, …, 198`; existing `layers`, `guard_value`, `status_label`, and `get_visual_layer_count()` remain unchanged.

- [ ] **Step 1: Update the guard geometry test so it fails against the overlapping strip**

Change the authored-geometry constants and assertions in `test_scene_authored_guard_visuals_fit_the_compact_width_at_full_depth`:

```gdscript
const GUARD_WIDTH := 220.0
const PIP_WIDTH := 21.0
const PIP_STEP := 22.0

assert_eq(
	 pip.position.x - _pip(stack, layer_index, pip_index - 1).position.x,
	 PIP_STEP,
	 "adjacent guard pips retain a one-pixel gap",
)
assert_eq(
	 pip.position.x - _pip(stack, layer_index, pip_index - 1).get_rect().end.x,
	 1.0,
	 "adjacent guard visuals do not merge",
)
```

Also assert `GuardValue` is at least 16-pixel type and remains centered over the current pip, and `StatusLabel` is at least 16-pixel type across the full 220-pixel component.

- [ ] **Step 2: Run the focused guard test and confirm the intended failure**

Run:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_guard_stack.gd -gexit
```

Expected: failure because the scene still authors a 202-pixel component, 22-pixel pips, 20-pixel centers, and 13-pixel labels.

- [ ] **Step 3: Author the separated 220-pixel guard component**

In `enemy_guard_stack.tscn`:

- set the root, all three layers, and `StatusLabel` to 220 pixels wide;
- set every pip to 21 pixels wide and place columns at `column * 22`;
- retain the 22-pixel pip height and layer Y positions `0`, `5`, and `10`;
- set `GuardValue` to a 21-pixel-wide cell with 16-pixel type;
- set `StatusLabel` to 16-pixel type;
- keep mouse filters, textures, colors, and the scene hierarchy unchanged.

The final column must occupy `Rect2(198, 0, 21, 22)`, leaving one pixel inside the 220-pixel component.

- [ ] **Step 4: Run the guard tests and confirm they pass**

Run the Step 2 command.

Expected: all `test_enemy_guard_stack.gd` tests pass.

- [ ] **Step 5: Commit the guard component**

```bash
git add src/battle/presentation/enemy_guard_stack.tscn test/unit/test_enemy_guard_stack.gd
git commit -m "fix: separate enemy guard pips"
```

---

### Task 2: Rebalance the enemy HUD and move inspection above it

**Files:**
- Modify: `src/battle/presentation/enemy_world_hud.tscn`
- Modify: `src/battle/presentation/enemy_world_hud.gd`
- Modify: `test/unit/test_enemy_world_hud.gd`
- Modify: `test/integration/test_enemy_hud_formation_projection.gd`
- Modify: `docs/testing/ctb-combat-checklist.md`

**Interfaces:**
- Consumes: the 220-pixel `EnemyGuardStack` from Task 1 and `EnemyWorldHUD.set_details_visible(value: bool)`, `get_desired_compact_rect() -> Rect2`, `get_visible_layout_rect() -> Rect2`.
- Produces: a full-width 220-pixel HP region, guard draw order above HP, and a fixed 58-pixel inspection block whose bottom is four pixels above the compact stack; all public HUD signals and methods remain unchanged.

- [ ] **Step 1: Write failing unit tests for geometry, draw order, typography, and upper details**

Update `test_compact_stack_authors_layered_hp_and_overlapping_guard` and the details tests in `test_enemy_world_hud.gd` to require:

```gdscript
const HP_WIDTH := 220.0
const DETAILS_SIZE := Vector2(220.0, 58.0)
const DETAILS_GAP := 4.0

assert_eq(hud.hp_region.position, Vector2.ZERO)
assert_eq(hud.hp_region.size, Vector2(HP_WIDTH, 18.0))
assert_eq(hud.guard_stack.position, Vector2(0.0, 14.0))
assert_eq(hud.guard_stack.size.x, HP_WIDTH)
assert_gt(hud.guard_stack.z_index, hud.hp_bar_actual.z_index)
assert_gte(hud.intent_row.get_theme_font_size(&"normal_font_size"), 16)
assert_gte(hud.name_label.get_theme_font_size(&"font_size"), 22)
assert_gte(hud.kinetic_value.get_theme_font_size(&"font_size"), 17)
assert_gte(hud.energy_value.get_theme_font_size(&"font_size"), 17)
```

After `hud.set_details_visible(true)`, preserve the compact position and assert:

```gdscript
assert_eq(hud.details.size, DETAILS_SIZE)
assert_eq(hud.details.global_position.x, hud.compact_stack.global_position.x)
assert_eq(
	 hud.details.get_global_rect().end.y,
	 hud.compact_stack.global_position.y - DETAILS_GAP,
)
```

- [ ] **Step 2: Update the real-projection test for upper details and run the red tests**

In `test_enemy_hud_formation_projection.gd`, change the inspection assertion from `detail_rect.position.y == original_rect.end.y + DETAILS_GAP` to:

```gdscript
assert_eq(detail_rect.end.y, original_rect.position.y - DETAILS_GAP)
assert_true(safe_rect.encloses(detail_rect))
```

Retain the assertions that the detail block does not intersect any other compact HUD, compact HUDs remain mutually nonintersecting, and target rectangles enclose complete projected models.

Run:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_world_hud.gd -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_enemy_hud_formation_projection.gd -gexit
```

Expected: failures for the 168-pixel HP region, lower detail placement, current draw order, and current type sizes.

- [ ] **Step 3: Author the new HUD hierarchy without changing public behavior**

In `enemy_world_hud.tscn`:

- make `HPRegion`, `HPFeedback`, and `HPActual` 220 pixels wide with HPRegion at X `0`;
- place the 220-pixel `GuardStack` at X `0`, Y `14`, and give it a `z_index` above `HPActual`;
- set intent type to 16 pixels and give its row enough minimum height to avoid clipping;
- author `Details` as `Vector2(220, 58)` with name type 22 and defense type 17 or 18;
- keep conditions, tooltips, mouse filters, colors, HP height, and rounded styles unchanged.

In `enemy_world_hud.gd`, set:

```gdscript
const DETAILS_SIZE := Vector2(220.0, 58.0)

func _sync_details_position() -> void:
	details.position = Vector2(0.0, -DETAILS_SIZE.y - DETAILS_GAP)
```

Do not add a second HUD layout solver or move the compact stack when inspection visibility changes.

- [ ] **Step 4: Run focused HUD, guard, and projection verification**

Run:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_guard_stack.gd -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_enemy_world_hud.gd -gexit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gtest=res://test/integration/test_enemy_hud_formation_projection.gd -gexit
```

Expected: all three focused suites pass at W/M layouts, supported logical canvases, and camera yaw `-3`, `0`, and `+3` degrees.

- [ ] **Step 5: Update manual acceptance and run project-level verification**

In `docs/testing/ctb-combat-checklist.md`, update the pending readable-enemy-HUD checks to call out:

- full-width HP with guard pips visibly in front;
- a visible gap between adjacent shields;
- larger intent, name, defense, guard, `VULNERABLE`, and `BREACHED` type;
- inspection details above the persistent HUD without obscuring another compact HUD.

Then run:

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: import succeeds; the new focused tests pass; the full suite has no new failures beyond the two documented dirty-tree failures for the action-button DynamicGlyph footprint and battle-lab HP multiplier; `git diff --check` exits zero.

- [ ] **Step 6: Commit the HUD correction**

```bash
git add src/battle/presentation/enemy_world_hud.tscn src/battle/presentation/enemy_world_hud.gd test/unit/test_enemy_world_hud.gd test/integration/test_enemy_hud_formation_projection.gd docs/testing/ctb-combat-checklist.md
git commit -m "fix: improve enemy HUD legibility"
```
