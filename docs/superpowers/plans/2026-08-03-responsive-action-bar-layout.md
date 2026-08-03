# Responsive Action Bar Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the battle action bar's hand-positioned controls with responsive top and bottom rows while preserving the user's 270x100 action-button design and every existing controller mapping.

**Architecture:** `ActionBar` owns a `TopRow` for Passive and Shift Action bookends and a `BottomRow` for left shift, an ordered four-button `Actions` HBox, and right shift. `ActionBar.actions_ui` continues to expose exactly four direct `ActionButton` children, while explicit scene references replace incidental string paths. The action-button scene reports its complete glyph-plus-panel footprint to containers.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` UI scenes, GUT 9.6.1.

## Global Constraints

- Preserve the user's uncommitted enemy data, theme, font, hero-card, action-button, action-bar, and battle-lab work; modify only task-owned portions of `action_button.tscn` and `action_bar.tscn`.
- Keep the action buttons in `D`, `R`, `L`, `U` order, mapped to `action_1`, `action_2`, `action_3`, and `action_4`.
- Keep each action-button component `270x100`, with its glyph and lower `270x70` action panel contained inside its bounds.
- Keep role-shift controls `220x70` and Passive/Shift Action panels `270x70`.
- Preserve all existing `ActionBar` public signals and methods.
- Use Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot` and an isolated `HOME` for every automated run.

---

### Task 1: Protect the Complete Action-Button Footprint

**Files:**
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `src/battle/action_button.gd`
- Modify: `src/battle/action_button.tscn`

**Interfaces:**
- Consumes: `ActionButton.apply_display_profile(profile: int) -> void` and the real packed `action_button.tscn`.
- Produces: a container-safe `ActionButton` whose runtime minimum is `Vector2(270, 100)` and whose `Button`, `Mask`, `Title`, `FocusPips`, and `DynamicGlyph` rectangles stay inside its local `270x100` bounds.

- [ ] **Step 1: Write the failing packed-component test**

Add this test near the existing real action-button glyph tests:

```gdscript
func test_action_button_reports_its_complete_container_safe_footprint() -> void:
	var action_button := ActionButtonScene.instantiate() as ActionButton
	add_child_autofree(action_button)
	await get_tree().process_frame

	assert_eq(action_button.custom_minimum_size, Vector2(270.0, 100.0))
	var bounds := Rect2(Vector2.ZERO, Vector2(270.0, 100.0))
	for path in ["Button", "Mask", "Title", "FocusPips", "DynamicGlyph"]:
		var control := action_button.get_node(path) as Control
		assert_true(bounds.encloses(control.get_rect()), "%s stays inside the component" % path)
```

This catches a runtime profile override that shrinks the component or any child offset that leaks beyond its reported bounds.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
env HOME=/private/tmp/mars-action-bar-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
```

Expected: FAIL because `ActionButton.apply_display_profile` changes the minimum height to `86` and the lower Button/Mask end at local `y = 103`.

- [ ] **Step 3: Make the action-button runtime match the packed design**

In `action_button.gd`, replace the profile constants with:

```gdscript
const CONTROL_HEIGHT_DESKTOP := 100.0
const CONTROL_HEIGHT_COMPACT := 100.0
const PRIMARY_FONT_SIZE_DESKTOP := 24
const PRIMARY_FONT_SIZE_COMPACT := 24
```

In `action_button.tscn`, keep the user's `270x100` root and change the lower panel bounds to remain inside it:

```text
Button: offset_top = -70.0, offset_bottom = 0.0
Mask:   offset_top = -70.0, offset_bottom = 0.0
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the command from Step 2. Expected: PASS with every asserted child rectangle enclosed by `270x100`.

- [ ] **Step 5: Commit the component boundary**

```bash
git add src/battle/action_button.gd src/battle/action_button.tscn test/integration/test_battle_controller_navigation.gd
git commit -m "fix: bound battle action button layout"
```

### Task 2: Build the Responsive Two-Row Action Bar

**Files:**
- Modify: `test/integration/test_battle_responsive_layout.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `src/battle/action_bar.tscn`
- Modify: `src/battle/action_bar.gd`

**Interfaces:**
- Consumes: the container-safe `ActionButton` from Task 1 and existing `ActionBar` public signals/methods.
- Produces: `TopRow`, `TopRow/Passive`, `TopRow/Spacer`, `TopRow/ShiftAction`, `BottomRow`, `BottomRow/LeftShift`, `BottomRow/Actions`, and `BottomRow/RightShift`; `ActionBar.actions_ui` resolves `BottomRow/Actions` with four direct buttons in slot order.

- [ ] **Step 1: Write the failing packed action-bar hierarchy test**

Add to `test_battle_responsive_layout.gd`:

```gdscript
func test_packed_action_bar_uses_ordered_top_and_bottom_containers() -> void:
	var battle := await _battle_in_viewport(Vector2i(1920, 1080))
	var action_bar := battle.get_node("UI/ActionBar") as ActionBar
	var top_row := action_bar.get_node_or_null("TopRow") as HBoxContainer
	var bottom_row := action_bar.get_node_or_null("BottomRow") as HBoxContainer
	assert_not_null(top_row)
	assert_not_null(bottom_row)
	if top_row == null or bottom_row == null:
		return
	assert_same(action_bar.passive_panel.get_parent(), top_row)
	assert_same(action_bar.shift_action_panel.get_parent(), top_row)
	assert_same(action_bar.left_shift_ui.get_parent(), bottom_row)
	assert_same(action_bar.right_shift_ui.get_parent(), bottom_row)
	assert_same(action_bar.actions_ui.get_parent(), bottom_row)
	assert_eq(
		action_bar.actions_ui.get_children().map(func(child): return child.name),
		[&"ActionButtonD", &"ActionButtonR", &"ActionButtonL", &"ActionButtonU"],
	)
	for index in 4:
		assert_eq(
			(action_bar.actions_ui.get_child(index) as ActionButton).glyph_action,
			StringName("action_%d" % (index + 1)),
		)
	assert_eq(
		(action_bar.right_shift_ui.get_node("DynamicGlyph") as DynamicGlyph).action,
		&"shift_right",
	)
```

Update existing packed-node test paths to `BottomRow/Actions/ActionButtonD` and `TopRow/Passive`, and update the real shift-glyph test paths to `BottomRow/LeftShift/DynamicGlyph` and `BottomRow/RightShift/DynamicGlyph`.

- [ ] **Step 2: Run focused responsive and controller tests and verify RED**

Run:

```bash
env HOME=/private/tmp/mars-action-bar-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_responsive_layout -gexit
env HOME=/private/tmp/mars-action-bar-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
```

Expected: the packed hierarchy test and moved-node path assertions fail because the two-row hierarchy and script references do not exist yet.

- [ ] **Step 3: Rebuild `action_bar.tscn` with containers**

Preserve the user's styles, typography, icons, and sizes while producing this hierarchy:

```text
ActionBar
├── TopRow (HBoxContainer, 70 high)
│   ├── Passive (270x70)
│   ├── Spacer (horizontal Expand + Fill)
│   └── ShiftAction (270x70)
└── BottomRow (HBoxContainer, 100 high, centered)
    ├── LeftShift (220x70, vertical Shrink End)
    ├── Actions (HBoxContainer, 1152x100, separation 24)
    │   ├── ActionButtonD
    │   ├── ActionButtonR
    │   ├── ActionButtonL
    │   └── ActionButtonU
    └── RightShift (220x70, vertical Shrink End)
```

Set `BottomRow` separation to `20`, preserve the button glyph actions, and correct `BottomRow/RightShift/DynamicGlyph.action` to `&"shift_right"`.

- [ ] **Step 4: Rewrite scene references and row animation in `action_bar.gd`**

Use explicit references:

```gdscript
@onready var top_row: HBoxContainer = $TopRow
@onready var bottom_row: HBoxContainer = $BottomRow
@onready var actions_ui: Control = $BottomRow/Actions
@onready var left_shift_ui: Control = $BottomRow/LeftShift
@onready var right_shift_ui: Control = $BottomRow/RightShift
@onready var left_shift_button: Button = $BottomRow/LeftShift/Button
@onready var right_shift_button: Button = $BottomRow/RightShift/Button
@onready var passive_panel: Panel = $TopRow/Passive
@onready var shift_action_panel: Panel = $TopRow/ShiftAction
```

Replace repeated old scene paths with stored nodes or explicit new paths. Keep `actions_ui.get_child(index)` behavior unchanged because `Actions` still contains exactly four direct buttons.

Record `top_row` and `bottom_row` on-screen positions. Slide and fade those two rows as units; do not animate children owned by either HBox. Keep public signals, input actions, role updates, disabled-state synchronization, and flash behavior unchanged. Set auxiliary control heights to `70`; each `ActionButton.apply_display_profile` keeps its full `100` height.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run both commands from Step 2. Expected: all responsive-layout and controller-navigation tests pass, including packed action loading and left/right glyph-family assertions.

- [ ] **Step 6: Commit the responsive action bar**

```bash
git add src/battle/action_bar.gd src/battle/action_bar.tscn test/integration/test_battle_responsive_layout.gd test/integration/test_battle_controller_navigation.gd
git commit -m "feat: lay out battle actions in responsive rows"
```

### Task 3: Verify the Integrated Battle HUD

**Files:**
- Modify only if a failing assertion reveals a task-owned regression: `src/battle/action_bar.gd`, `src/battle/action_bar.tscn`, `src/battle/action_button.gd`, `src/battle/action_button.tscn`, `test/integration/test_battle_responsive_layout.gd`, `test/integration/test_battle_controller_navigation.gd`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: imported Godot resources and a verified battle HUD at both supported outputs.

- [ ] **Step 1: Import and parse the project**

```bash
env HOME=/private/tmp/mars-action-bar-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
```

Expected: exit `0` with no parser errors. The documented macOS certificate warning is acceptable.

- [ ] **Step 2: Run focused integration coverage together**

Run `battle_responsive_layout`, `battle_controller_navigation`, and `controller_playable_loop` as three focused GUT selectors with the isolated command above. Expected: every selected test passes.

- [ ] **Step 3: Run the complete isolated suite**

```bash
env HOME=/private/tmp/mars-action-bar-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: every test passes. Any failure caused only by the user's intentionally modified battle-lab multiplier must be reported separately rather than changing or staging `src/dev/endgame_battle_lab.tscn`.

- [ ] **Step 4: Check task-owned diffs and preserved user work**

```bash
git diff --check -- src/battle/action_bar.gd src/battle/action_bar.tscn src/battle/action_button.gd src/battle/action_button.tscn test/integration/test_battle_responsive_layout.gd test/integration/test_battle_controller_navigation.gd
git status --short
```

Expected: no whitespace errors; all unrelated user-modified files remain modified and unstaged.

- [ ] **Step 5: Perform manual visual acceptance**

Launch the endgame battle lab at `1920x1080` and a desktop `1280x800` proxy. Verify the straight action order, correct face-button glyphs, correct left/right Shift glyphs, hero/action clearance, no turn-queue overlap, mouse tooltips, action activation, role shifting, and row entry/exit animation. This manual step remains pending until observed by the user.
