# Keyboard Navigation Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make arrows and WASD move standard UI focus and the snapped cursor identically while keeping WASD for semantic gameplay navigation and arrows for dungeon camera panning.

**Architecture:** Extend Godot's built-in `ui_*` actions with WASD while retaining their arrow, D-pad, and left-stick defaults. Classify `ui_*` as snapped cursor input in `InputManager`, keep arrow keys out of custom `nav_*`, and repair the two incorrect horizontal dungeon-camera key codes.

**Tech Stack:** Godot 4.6.3 Input Map, GDScript, GUT 9.6.1.

## Global Constraints

- Standard UI treats WASD and arrow keys identically: one focus change and one snapped-cursor destination per event.
- Keyboard navigation keeps `InputMode.KEYBOARD_MOUSE`; it does not display controller-only presentation.
- Custom `nav_*` actions retain WASD and controller bindings; arrow keys are not added to `nav_*`.
- Dungeon WASD continues to select nodes, while dungeon arrows pan the camera and do not select nodes.
- `camera_pan_left/right/up/down` use `KEY_LEFT/RIGHT/UP/DOWN`; right-stick camera bindings remain unchanged.
- Do not synthesize, translate, or re-dispatch input events.
- Do not add screen-specific navigation code.
- Preserve all unrelated working-tree edits and any unrelated `project.godot` content; never stage them.

---

### Task 1: Unify Keyboard Actions and Snapped Classification

**Files:**
- Modify: `project.godot`
- Modify: `src/singletons/input_manager.gd`
- Test: `test/unit/test_input_manager.gd`

**Interfaces:**
- Produces: built-in `ui_left/right/up/down` mappings containing arrow, WASD, D-pad, and left-stick events.
- Preserves: custom `nav_left/right/up/down` as WASD plus controller only.
- Extends: `InputManager.NAVIGATION_ACTIONS` to recognize the four built-in `ui_*` directions.

- [ ] **Step 1: Add failing Input Map and cursor-classification regressions**

Add these tests to `test/unit/test_input_manager.gd`:

```gdscript
func test_standard_ui_directions_include_arrows_wasd_and_controller_defaults() -> void:
	var expected := {
		&"ui_left": [KEY_LEFT, KEY_A, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0],
		&"ui_right": [KEY_RIGHT, KEY_D, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0],
		&"ui_up": [KEY_UP, KEY_W, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0],
		&"ui_down": [KEY_DOWN, KEY_S, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0],
	}
	for action: StringName in expected:
		var values: Array = expected[action]
		assert_true(_has_logical_key(action, values[0]), "%s arrow" % action)
		assert_true(_has_physical_key(action, values[1]), "%s WASD" % action)
		assert_true(_has_joy_button(action, values[2]), "%s D-pad" % action)
		assert_true(_has_joy_axis(action, values[3], values[4]), "%s stick" % action)


func test_custom_navigation_keeps_arrows_out_and_wasd_in() -> void:
	var expected := {
		&"nav_left": [KEY_LEFT, KEY_A],
		&"nav_right": [KEY_RIGHT, KEY_D],
		&"nav_up": [KEY_UP, KEY_W],
		&"nav_down": [KEY_DOWN, KEY_S],
	}
	for action: StringName in expected:
		assert_false(_has_logical_key(action, expected[action][0]), "%s excludes arrow" % action)
		assert_true(_has_physical_key(action, expected[action][1]), "%s keeps WASD" % action)


func test_arrow_and_wasd_navigation_select_snapped_keyboard_mouse() -> void:
	for event: InputEventKey in [_key(KEY_RIGHT), _physical_key(KEY_D)]:
		manager._set_cursor_behavior(manager.CursorBehavior.FREE)
		manager._input(event)
		assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
		assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)
```

Add helpers:

```gdscript
func _has_logical_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false


func _has_physical_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _physical_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event
```

Keep the existing `_has_joy_button` and `_has_joy_axis` helpers. Replace the old single-W `test_navigation_key_selects_snapped_without_changing_input_family` with the comprehensive parity test above.

- [ ] **Step 2: Add failing dungeon camera binding assertions**

Add:

```gdscript
func test_dungeon_camera_uses_matching_arrow_keys_without_nav_overlap() -> void:
	var expected := {
		&"camera_pan_left": KEY_LEFT,
		&"camera_pan_right": KEY_RIGHT,
		&"camera_pan_up": KEY_UP,
		&"camera_pan_down": KEY_DOWN,
	}
	for action: StringName in expected:
		assert_true(_has_physical_key(action, expected[action]), str(action))
		var arrow := _physical_key(expected[action])
		for nav_action: StringName in [&"nav_left", &"nav_right", &"nav_up", &"nav_down"]:
			assert_false(arrow.is_action(nav_action), "%s does not trigger %s" % [action, nav_action])
```

- [ ] **Step 3: Run the unit script and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
```

Expected: the four `ui_*` actions lack WASD; arrow events do not select snapped behavior; `camera_pan_left` and `camera_pan_right` lack the matching arrow constants.

- [ ] **Step 4: Define complete standard UI mappings in `project.godot`**

Add explicit `ui_left`, `ui_right`, `ui_up`, and `ui_down` actions under `[input]`. Each action must retain its existing logical arrow, D-pad, and left-stick events and add one physical WASD event:

```text
ui_left:  KEY_LEFT + physical KEY_A + D-pad Left + left-stick X -1
ui_right: KEY_RIGHT + physical KEY_D + D-pad Right + left-stick X +1
ui_up:    KEY_UP + physical KEY_W + D-pad Up + left-stick Y -1
ui_down:  KEY_DOWN + physical KEY_S + D-pad Down + left-stick Y +1
```

Use the same serialized `InputEventKey`, `InputEventJoypadButton`, and `InputEventJoypadMotion` forms already present in `project.godot`. The verified Godot 4.6.3 key values are:

```text
KEY_LEFT=4194319
KEY_RIGHT=4194321
KEY_UP=4194320
KEY_DOWN=4194322
KEY_A=65
KEY_D=68
KEY_W=87
KEY_S=83
```

Keep the default controller values:

```text
ui_left:  button 13, axis 0 value -1.0
ui_right: button 14, axis 0 value 1.0
ui_up:    button 11, axis 1 value -1.0
ui_down:  button 12, axis 1 value 1.0
```

Do not alter `nav_*` events.

- [ ] **Step 5: Correct only the horizontal camera key events**

In `project.godot`, change the physical key code for `camera_pan_left` from `4194311` to `4194319` and `camera_pan_right` from `4194313` to `4194321`. Leave vertical and joypad-axis events unchanged.

- [ ] **Step 6: Classify standard UI directions as snapped navigation**

Change `InputManager.NAVIGATION_ACTIONS` to:

```gdscript
const NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_left", &"ui_right", &"ui_up", &"ui_down",
	&"nav_left", &"nav_right", &"nav_up", &"nav_down",
	&"confirm", &"cancel", &"page_left", &"page_right",
	&"role_left", &"role_right",
]
```

Do not synthesize another event or change active input mode.

- [ ] **Step 7: Run unit tests and confirm GREEN**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
```

Expected: every mapping and classification assertion passes with no unexpected script errors.

- [ ] **Step 8: Commit the action contract**

```bash
git diff --check
git add project.godot src/singletons/input_manager.gd test/unit/test_input_manager.gd
git commit -m "fix: unify keyboard UI navigation"
```

Before staging `project.godot`, inspect its complete diff and preserve any user/editor-owned content that predates the task. Stage the file only when the diff contains the scoped Input Map edits plus known pre-existing content the user has explicitly retained.

---

### Task 2: Verify Hub Cursor and Dungeon Camera Integration

**Files:**
- Modify: `test/integration/test_standard_focus_navigation.gd`
- Modify: `test/integration/test_dungeon_restore.gd`

**Interfaces:**
- Consumes: the `ui_*`, `nav_*`, camera, and snapped-cursor contracts from Task 1.
- Verifies: one-event hub focus/cursor parity and four-direction arrow camera input without dungeon selection overlap.

- [ ] **Step 1: Add a hub parity integration test**

Add a test that instantiates `NavigationUXLayer`, a one-hero `Hub`, opens its `PartyMenu`, and compares Arrow Right with physical D from the Skills tab. Reset focus and cursor state before each case:

```gdscript
func test_party_tabs_arrow_and_wasd_move_focus_and_cursor_to_same_destination() -> void:
	var ux := _add_ux()
	var hero := load("res://data/heroes/asher/asher.tres").duplicate(true) as HeroData
	SaveSystem.party_roster.assign([hero])
	var hub := HubScene.instantiate() as Hub
	add_child_autofree(hub)
	await get_tree().process_frame
	hub.party_menu.open()
	await get_tree().process_frame
	var skills := hub.party_menu.get_node("Header/ModeTabs/Skills") as Button
	var inventory := hub.party_menu.get_node("Header/ModeTabs/Inventory") as Button

	var destinations: Array[Vector2] = []
	for event: InputEventKey in [_key(KEY_RIGHT), _physical_key(KEY_D)]:
		skills.grab_focus()
		InputManager._set_cursor_behavior(InputManager.CursorBehavior.FREE)
		get_viewport().push_input(event)
		await get_tree().process_frame
		assert_same(get_viewport().gui_get_focus_owner(), inventory)
		assert_same(ux.get_focus_target(), inventory)
		assert_same(ux.cursor._target, inventory)
		assert_eq(InputManager.get_active_mode(), InputManager.InputMode.KEYBOARD_MOUSE)
		assert_eq(InputManager.get_cursor_behavior(), InputManager.CursorBehavior.SNAPPED)
		destinations.append(ux.cursor._target_position())

	assert_eq(destinations.size(), 2)
	assert_eq(destinations[0], destinations[1])
```

Add local `_key` and `_physical_key` helpers matching Task 1. If the first input remains held in Godot's internal state, send the matching released event before resetting the second case.

- [ ] **Step 2: Add dungeon arrow-direction and non-selection integration coverage**

In `test/integration/test_dungeon_restore.gd`, add:

```gdscript
func test_arrow_keys_drive_all_camera_directions_without_selecting_nodes() -> void:
	var cases := [
		[KEY_LEFT, &"camera_pan_left", Vector2.LEFT],
		[KEY_RIGHT, &"camera_pan_right", Vector2.RIGHT],
		[KEY_UP, &"camera_pan_up", Vector2.UP],
		[KEY_DOWN, &"camera_pan_down", Vector2.DOWN],
	]
	for item: Array in cases:
		var arrow := _physical_key(item[0])
		assert_true(arrow.is_action(item[1]), str(item[1]))
		assert_eq(
			InputMap.event_is_action(arrow, &"nav_left")
			or InputMap.event_is_action(arrow, &"nav_right")
			or InputMap.event_is_action(arrow, &"nav_up")
			or InputMap.event_is_action(arrow, &"nav_down"),
			false,
			"camera arrows do not select nodes",
		)
		Input.parse_input_event(arrow)
		await get_tree().process_frame
		assert_eq(
			Input.get_vector(&"camera_pan_left", &"camera_pan_right", &"camera_pan_up", &"camera_pan_down"),
			item[2],
		)
		arrow.pressed = false
		Input.parse_input_event(arrow)
		await get_tree().process_frame
```

Add a local `_physical_key` helper if one does not already exist. Ensure every pressed event is released even after an assertion by keeping the release adjacent to the direction assertion.

- [ ] **Step 3: Run both focused integration scripts**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect standard_focus_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: Arrow Right and D select Inventory once and resolve the same cursor destination; all four arrows resolve the matching camera direction and no `nav_*` action.

- [ ] **Step 4: Run editor and full-suite verification**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
git status --short
```

Expected: editor exits 0; the full suite has zero failing tests; there are no parser errors or crashes; unrelated hero resources and GUT theme changes remain unstaged.

- [ ] **Step 5: Commit integration regressions**

```bash
git add test/integration/test_standard_focus_navigation.gd test/integration/test_dungeon_restore.gd
git commit -m "test: cover keyboard navigation parity"
```

Expected: only the two integration test files are committed.
