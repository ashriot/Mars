# Cursor Snap Continuity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Synchronize the custom cursor with the physical mouse during keyboard/controller focus navigation and keep the default pointer throughout map and combat.

**Architecture:** `InputManager` tracks input family separately from cursor movement behavior (`FREE` or `SNAPPED`) and suppresses only the synthetic mouse-motion event created by an expected warp. `NavigationCursor` positions itself from the focused target in snapped behavior, warps the hidden physical mouse to the same coordinate once, and resumes free movement from that synchronized point after genuine mouse motion. Map and combat adapters retain targeting behavior but request only the default cursor appearance.

**Tech Stack:** Godot 4.7, GDScript, Input events, GUT 9.7.1.

## Global Constraints

- Keyboard/mouse and controller remain the only input families used for glyph presentation.
- Keyboard navigation remains keyboard/mouse family and never shows controller glyphs.
- Keyboard and controller focus navigation both synchronize the physical mouse to the snapped cursor.
- Genuine mouse movement returns the cursor to free movement from the synchronized coordinate.
- Synthetic warp motion must not change input family, cursor behavior, or controller hints.
- Map and combat always use `CursorState.DEFAULT`; targeting/gameplay behavior does not change.
- Preserve the unrelated local `project.godot` modification and never stage it.

---

### Task 1: Track Free vs Snapped Cursor Intent and Suppress Synthetic Warp Motion

**Files:**
- Modify: `src/singletons/input_manager.gd`
- Modify: `test/unit/test_input_manager.gd`

**Interfaces:**
- Produces: `InputManager.CursorBehavior { FREE, SNAPPED }`.
- Produces: `InputManager.cursor_behavior_changed(behavior: CursorBehavior)`.
- Produces: `InputManager.get_cursor_behavior() -> CursorBehavior`.
- Produces: `InputManager.expect_mouse_warp(position: Vector2) -> void`.
- Keeps: `InputManager.InputMode { KEYBOARD_MOUSE, CONTROLLER }` and existing mode/type signals.

- [ ] **Step 1: Write failing cursor-behavior tests**

Add tests using real input events:

```gdscript
var nav := InputEventKey.new()
nav.keycode = KEY_UP
nav.pressed = true
manager._input(nav)
assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)

var mouse := InputEventMouseMotion.new()
mouse.position = Vector2(140, 80)
mouse.relative = Vector2(8, 0)
manager._input(mouse)
assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.FREE)
```

Cover controller button/axis input selecting `SNAPPED`, ordinary non-navigation keyboard keys leaving cursor behavior unchanged, and behavior signals emitting only on actual changes.

- [ ] **Step 2: Write failing warp-suppression tests**

```gdscript
manager._set_active_mode(manager.InputMode.CONTROLLER)
manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
manager.expect_mouse_warp(Vector2(300, 200))
var synthetic := InputEventMouseMotion.new()
synthetic.position = Vector2(300.5, 199.5)
synthetic.relative = Vector2(100, 50)
manager._input(synthetic)
assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)
```

Then send motion outside the positional tolerance and assert it switches to `KEYBOARD_MOUSE` plus `FREE`. Add an expiration test by injecting/advancing the bounded warp deadline so an old expectation cannot suppress later real input.

- [ ] **Step 3: Run focused tests and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
```

Expected: `CursorBehavior`, its signal, and warp expectation APIs are missing.

- [ ] **Step 4: Implement cursor intent independently of input family**

Add:

```gdscript
enum CursorBehavior { FREE, SNAPPED }
signal cursor_behavior_changed(behavior: CursorBehavior)

const WARP_POSITION_TOLERANCE := 2.0
const WARP_SUPPRESSION_MS := 100
const NAVIGATION_ACTIONS: Array[StringName] = [
	&"nav_left", &"nav_right", &"nav_up", &"nav_down",
	&"confirm", &"cancel", &"page_left", &"page_right",
	&"role_left", &"role_right",
]

var _cursor_behavior := CursorBehavior.FREE
var _expected_warp_position := Vector2.INF
var _expected_warp_deadline_ms := 0
```

`InputEventJoypadButton/Motion` selects controller family and `SNAPPED`. A pressed keyboard event selects keyboard/mouse family; it selects `SNAPPED` only if `event.is_action(action)` matches a semantic navigation action. Genuine meaningful mouse button/motion selects keyboard/mouse and `FREE`.

`expect_mouse_warp(position)` records position and `Time.get_ticks_msec() + WARP_SUPPRESSION_MS`. Before meaningful-event classification, mouse motion within tolerance and before the deadline clears the marker and returns without changing state. Expired or mismatched motion clears the marker and proceeds as genuine input. Expose a small clock method (`_now_ms()`) so the test subclass can deterministically advance expiration without sleeps.

- [ ] **Step 5: Run focused tests and commit**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
git diff --check
git add src/singletons/input_manager.gd test/unit/test_input_manager.gd
git commit -m "feat: track snapped cursor intent"
```

### Task 2: Synchronize Navigation Cursor and Physical Mouse

**Files:**
- Modify: `src/ui/navigation/navigation_cursor.gd`
- Modify: `test/unit/test_navigation_cursor.gd`
- Modify: `test/integration/test_navigation_ux_layer.gd`
- Modify: `test/integration/test_hub_progression.gd`

**Interfaces:**
- Consumes: `InputManager.get_cursor_behavior()` and `expect_mouse_warp(position)` from Task 1.
- Produces: `NavigationCursor.update_position_for_behavior(behavior, mouse_position, immediate := false)` for deterministic tests.
- Keeps: target/state APIs and custom cursor textures.

- [ ] **Step 1: Write failing cursor synchronization tests**

Use a test cursor subclass that records warp calls through an overridable `_warp_mouse(position)` method:

```gdscript
cursor.set_focus_target(target)
cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2(10, 10), true)
assert_eq(cursor.position, expected_target_position)
assert_eq(cursor.warped_positions, [expected_target_position])
assert_eq(manager._expected_warp_position, expected_target_position)
```

Assert both controller-selected and keyboard-selected snapped behavior use the target. Then call free behavior with the synchronized mouse coordinate plus real delta and assert the cursor follows that new physical position.

- [ ] **Step 2: Add repeated/invalid target regressions**

Assert processing the same valid target with physical mouse already at its destination does not warp again. Moving to a different focus target warps once. Hidden, disabled, freed, and off-tree targets clear safely without warping.

- [ ] **Step 3: Add hub/modal integration regressions**

Drive a real keyboard navigation event in the hub, move focus to a new skill node, process the navigation cursor, and assert the physical-warp seam receives that node's rendered center while input family remains keyboard/mouse. Repeat with a controller event. Pop a modal and assert restored screen focus synchronizes to its restored control.

- [ ] **Step 4: Run focused tests and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_cursor -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_ux_layer -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect hub_progression -gexit
```

- [ ] **Step 5: Implement snapped/free positioning and mouse synchronization**

Replace input-family positioning with cursor-behavior positioning:

```gdscript
func _process(_delta: float) -> void:
	update_position_for_behavior(InputManager.get_cursor_behavior(), get_viewport().get_mouse_position())

func update_position_for_behavior(behavior: InputManager.CursorBehavior, mouse_position: Vector2, immediate := false) -> void:
	if behavior == InputManager.CursorBehavior.FREE:
		_move_to(mouse_position, true)
		show()
		return
	if not _is_valid_target():
		clear_target()
		return
	var destination := _target_position()
	_move_to(destination, immediate)
	if mouse_position.distance_to(destination) > InputManager.WARP_POSITION_TOLERANCE:
		InputManager.expect_mouse_warp(destination)
		_warp_mouse(destination)
	show()

func _warp_mouse(position: Vector2) -> void:
	Input.warp_mouse(position)
```

Do not warp continuously: after a warp, the physical mouse position equals the destination, and unchanged processing falls within tolerance. Preserve cursor target tweening; physical synchronization occurs immediately so later real motion begins at the target.

- [ ] **Step 6: Run focused tests and commit**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_cursor -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_ux_layer -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect hub_progression -gexit
git diff --check
git add src/ui/navigation/navigation_cursor.gd test/unit/test_navigation_cursor.gd test/integration/test_navigation_ux_layer.gd test/integration/test_hub_progression.gd
git commit -m "feat: synchronize snapped cursor and mouse"
```

### Task 3: Keep Map and Combat Cursor Appearance Default

**Files:**
- Modify: `src/map/dungeon_map.gd`
- Modify: `src/battle/battle_scene.gd`
- Modify: `src/ui/navigation/navigation_cursor.gd`
- Modify: `test/integration/test_dungeon_restore.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `test/unit/test_navigation_cursor.gd`

**Interfaces:**
- Keeps: map/combat target selection and adapter APIs.
- Changes only cursor appearance state for map/combat targets and cleared transitions.

- [ ] **Step 1: Change existing expectations to default and observe RED**

Update dungeon tests that currently assert `CursorState.TARGET` to assert `CursorState.DEFAULT`. Add battle assertions after target changes and modal restoration:

```gdscript
assert_eq(navigation.cursor._state, NavigationCursor.CursorState.DEFAULT)
assert_eq(navigation.cursor.texture.resource_path.get_file(), "pointer_c.svg")
```

Add a transition regression that first sets `TARGET`, clears/exits the adapter, enters/restores map or battle focus, and asserts the appearance resets to default.

- [ ] **Step 2: Run focused tests and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
```

Expected: production map/battle code still assigns `CursorState.TARGET`.

- [ ] **Step 3: Make default appearance authoritative for map/combat**

Change every map `set_world_target(..., CursorState.TARGET)` and battle `set_focus_target(..., CursorState.TARGET)` call to `CursorState.DEFAULT`. Make `NavigationCursor.clear_target()` reset state to `DEFAULT` before hiding:

```gdscript
func clear_target() -> void:
	_target = null
	set_cursor_state(CursorState.DEFAULT)
	hide()
```

This prevents any specialized appearance from leaking across adapter/phase transitions. Direct-manipulation controls will set their specialized state again when targeted.

- [ ] **Step 4: Run focused and full verification**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_cursor -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: editor import exits 0, full GUT passes, cursor crosshair does not persist through map/combat transitions.

- [ ] **Step 5: Commit**

```bash
git add src/map/dungeon_map.gd src/battle/battle_scene.gd src/ui/navigation/navigation_cursor.gd test/integration/test_dungeon_restore.gd test/integration/test_battle_controller_navigation.gd test/unit/test_navigation_cursor.gd
git commit -m "fix: keep map and combat cursor default"
```
