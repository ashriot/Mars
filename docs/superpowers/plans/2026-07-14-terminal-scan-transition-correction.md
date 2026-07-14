# Terminal-to-Scan Transition Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make terminal protocols shortcut-only for controller/keyboard use, remove the terminal modal before scanning begins, and keep the dedicated controller scan cursor and snapped reticle synchronized during camera movement without warping the OS mouse.

**Architecture:** Terminal rows retain mouse hover/click presentation but leave the GUI focus graph; semantic shortcuts remain the sole controller/keyboard protocol path. `GameManager` synchronously removes the terminal before starting targeting. `DungeonMap` drives a controller-owned screen-space pointer, presents it through `NavigationCursor`, and resolves the `MapNode` beneath it through real `Area2D` collision geometry after pointer or camera movement. `InputManager` changes to keyboard-and-mouse mode on a physical mouse-button click, not mouse motion.

**Tech Stack:** Godot 4.6.3, typed GDScript, GUT 9.6.1, `PhysicsDirectSpaceState2D`, existing `InputManager`, `NavigationCursor`, and isolated-HOME test commands.

## Global Constraints

- Work in the current normal checkout and feature branch; do not create a worktree.
- Protocol rows are mouse-clickable and show hover presentation, but never receive normal keyboard/controller GUI focus.
- Each displayed semantic shortcut invokes only its assigned protocol; Cross/A never activates a separately hovered row.
- Protocol and extraction input during the short typing animation is consumed without skipping or committing; Circle/B may still close.
- Remove the terminal overlay/modal synchronously before calling `DungeonMap.start_targeting_mode()`.
- Left-stick analog magnitude and D-pad input drive one continuous screen-space pointer, not hex-to-hex selection.
- The stored controller pointer and custom navigation cursor use the same screen coordinates; controller input never warps the OS mouse.
- Mouse motion alone does not change input mode. A physical mouse-button click activates keyboard-and-mouse mode, hides the custom cursor, and reveals the OS cursor at its physical position.
- Mouse hover signals and controller collision resolution call one shared scan-selection method.
- After controller pointer or camera movement, resolve the node beneath the pointer from real `Area2D` collision shapes; do not infer selection from nearest-node geometry.
- Preserve scan effects, radius, costs, confirmation, cancellation, reveal timing, alert behavior, return-to-party behavior, and ordinary dungeon traversal.
- Keep the OS cursor hidden during controller-owned cursor interaction and visible in keyboard-and-mouse mode; broader release cursor policy remains deferred.
- Automated Godot runs must use `HOME=/tmp/mars-godot-home`.

**Design:** [`docs/superpowers/specs/2026-07-14-terminal-scan-transition-correction-design.md`](../specs/2026-07-14-terminal-scan-transition-correction-design.md)

---

### Task 1: Make terminal protocols shortcut-only with mouse hover presentation

**Files:**

- Modify: `src/map/terminal_protocol_row.gd`
- Modify: `src/map/terminal.gd`
- Test: `test/unit/test_terminal_protocol_row.gd`
- Test: `test/unit/test_terminal.gd`

**Interfaces:**

- Consumes: existing `TerminalProtocolRow.activated(choice_id)`, `Terminal.handle_semantic_action(action)`, and extraction confirmation controls.
- Produces: non-focusable clickable rows whose caret reflects mouse hover; `Terminal` consumes but ignores protocol shortcuts while `TerminalState.TYPING`.

- [ ] **Step 1: Write failing row hover/focus tests**

Replace the focus-oriented row tests with public behavior tests:

```gdscript
func test_enabled_row_is_mouse_clickable_but_never_gui_focusable() -> void:
	var row := _row()
	row.set_interactable(true)
	assert_false(row.disabled)
	assert_eq(row.focus_mode, Control.FOCUS_NONE)
	assert_eq(row.mouse_filter, Control.MOUSE_FILTER_STOP)
	watch_signals(row)
	row.emit_signal(&"pressed")
	assert_signal_emit_count(row, "activated", 1)


func test_mouse_hover_controls_caret_without_assigning_focus() -> void:
	var row := _row()
	row.mouse_entered.emit()
	assert_true(row.caret_label.visible)
	assert_false(row.has_focus())
	row.mouse_exited.emit()
	assert_false(row.caret_label.visible)
```

Keep the disabled-row inert assertion and glyph/color hierarchy tests.

- [ ] **Step 2: Write failing terminal typing and focus tests**

Replace `test_first_protocol_input_during_typing_only_finishes_animation` with:

```gdscript
func test_protocol_input_during_typing_is_consumed_without_skip_or_choice() -> void:
	var terminal := await _terminal()
	watch_signals(terminal)
	assert_eq(terminal.interaction_state, terminal.TerminalState.TYPING)
	for action: StringName in TERMINAL_PROTOCOL_ACTIONS:
		assert_true(terminal.handle_semantic_action(action))
		assert_eq(terminal.interaction_state, terminal.TerminalState.TYPING)
		assert_signal_not_emitted(terminal, "option_selected")
	terminal.get_protocol_row(3).emit_signal(&"pressed")
	assert_eq(terminal.interaction_state, terminal.TerminalState.TYPING)
	assert_signal_not_emitted(terminal, "option_selected")
```

Add a setup assertion that every protocol row has `FOCUS_NONE` and no row owns focus after deferred setup. Retain the test that Circle/B can close while typing and extraction confirmation can focus Confirm/Cancel.

- [ ] **Step 3: Run focused tests and verify RED**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal_protocol_row -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect terminal -gexit
```

Expected: the row remains focusable, hover does not show the caret, and a protocol action changes `TYPING` to `READY`.

- [ ] **Step 4: Implement hover-only row presentation**

In `TerminalProtocolRow`, replace focus signal wiring and focus-based presentation with hover state:

```gdscript
var _mouse_hovered := false


func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_mode = Control.FOCUS_NONE
	_refresh_hover_presentation()


func set_interactable(enabled: bool) -> void:
	disabled = not enabled
	focus_mode = Control.FOCUS_NONE
	if not enabled:
		_mouse_hovered = false
	_refresh_hover_presentation()


func _on_mouse_entered() -> void:
	_mouse_hovered = true
	_refresh_hover_presentation()


func _on_mouse_exited() -> void:
	_mouse_hovered = false
	_refresh_hover_presentation()


func _refresh_hover_presentation() -> void:
	if is_node_ready():
		caret_label.visible = _mouse_hovered and not disabled
```

Do not use `grab_focus()`, `has_focus()`, or toggle state for protocol presentation.

- [ ] **Step 5: Remove normal row focus and typing skip from Terminal**

In `Terminal.setup()`, remove the deferred `_grab_focus_if_valid(_rows[0])` call. Keep deferred focus only for extraction confirmation controls.

Change the typing branch of `handle_semantic_action()` to:

```gdscript
if interaction_state == TerminalState.TYPING:
	if action == &"cancel":
		_begin_close()
		return true
	return action in PROTOCOL_ACTIONS or action in [EXTRACTION_ACTION, &"confirm"]
```

Change `_on_protocol_activated()` so `TYPING` returns without calling `finish_typing()`. Do not change the normal `READY`, confirmation, or one-shot closing paths.

- [ ] **Step 6: Run focused tests and verify GREEN**

Run the two commands from Step 3.

Expected: both scripts pass; expected-error fixtures remain documented and there are no parser errors or crashes.

- [ ] **Step 7: Commit terminal input behavior**

```sh
git add src/map/terminal_protocol_row.gd src/map/terminal.gd test/unit/test_terminal_protocol_row.gd test/unit/test_terminal.gd
git commit -m "fix: make terminal protocols shortcut only"
```

---

### Task 2: Remove the terminal modal before scan targeting starts

**Files:**

- Modify: `src/battle/game_manager.gd`
- Test: `test/integration/test_game_manager_interactions.gd`

**Interfaces:**

- Consumes: `GameManager._clear_transient_overlay()` synchronous `remove_child()` behavior and `DungeonMap.start_targeting_mode(radius)`.
- Produces: Scan startup with zero transient overlay children and no terminal modal still in the tree.

- [ ] **Step 1: Write the failing transition-order test**

Add focused doubles:

```gdscript
class ScanTransitionDungeonMap extends FakeDungeonMap:
	var overlay_to_check: Node
	var overlay_children_when_targeting_started := -1
	var targeting_start_count := 0

	func start_targeting_mode(_radius: int) -> void:
		overlay_children_when_targeting_started = overlay_to_check.get_child_count()
		targeting_start_count += 1
		current_map_state = MapState.TARGETING


class ScanTransitionManager extends GameManager:
	func _ready() -> void:
		pass
```

Add the regression:

```gdscript
func test_scan_choice_removes_terminal_before_targeting_begins() -> void:
	var manager := ScanTransitionManager.new()
	var dungeon_map := ScanTransitionDungeonMap.new()
	var overlay := Node.new()
	manager.dungeon_map = dungeon_map
	manager.overlay_layer = overlay
	dungeon_map.overlay_to_check = overlay
	manager.add_child(dungeon_map)
	manager.add_child(overlay)
	var terminal := Control.new()
	overlay.add_child(terminal)

	manager._on_terminal_choice("opt_scan", _terminal_payload())

	assert_eq(dungeon_map.targeting_start_count, 1)
	assert_eq(dungeon_map.overlay_children_when_targeting_started, 0)
	assert_eq(overlay.get_child_count(), 0)
	assert_true(terminal.is_queued_for_deletion())
	manager.free()
	await get_tree().process_frame
```

- [ ] **Step 2: Run focused integration and verify RED**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect game_manager_interactions -gexit
```

Expected: the new test reports one overlay child when targeting starts and one child still attached afterward.

- [ ] **Step 3: Use the synchronous overlay cleanup seam**

Replace the scan branch's manual `queue_free()` loop with:

```gdscript
# Remove the terminal from the tree before targeting starts so its modal
# registration cannot cancel the scan on the map's next frame.
_clear_transient_overlay()
```

Keep signal connection and `start_targeting_mode()` ordering unchanged after cleanup.

- [ ] **Step 4: Run focused integration and verify GREEN**

Run the Step 2 command.

Expected: all `test_game_manager_interactions.gd` tests pass.

- [ ] **Step 5: Commit the transition correction**

```sh
git add src/battle/game_manager.gd test/integration/test_game_manager_interactions.gd
git commit -m "fix: remove terminal before scan targeting"
```

---

### Task 3: Separate the controller scan cursor from the OS mouse

**Files:**

- Modify: `src/ui/navigation/navigation_cursor.gd`
- Modify: `src/singletons/input_manager.gd`
- Modify: `src/map/dungeon_map.gd`
- Test: `test/unit/test_navigation_cursor.gd`
- Test: `test/unit/test_input_manager.gd`
- Test: `test/integration/test_dungeon_restore.gd`

**Interfaces:**

- Consumes: `DungeonScanController.pointer_position`, global input-mode events, and the global `NavigationUXLayer.cursor`.
- Produces: `NavigationCursor.show_at_screen_position(screen_position: Vector2, state := CursorState.DEFAULT) -> void`; `clear_target()` exits explicit screen-position mode; physical mouse motion preserves controller mode and a mouse-button click activates keyboard-and-mouse mode.

- [ ] **Step 1: Write failing click-only mouse activation tests**

Extend `test/unit/test_input_manager.gd` to prove that real `InputEventMouseMotion` leaves `InputMode.CONTROLLER` unchanged, while a pressed physical `InputEventMouseButton` changes it to `InputMode.KEYBOARD_MOUSE`. Retain keyboard activation and controller-button activation coverage. Remove or update obsolete tests whose intended behavior was deliberate mouse-motion takeover; expected-warp suppression is no longer part of controller scan movement.

- [ ] **Step 2: Write failing NavigationCursor screen-position tests**

Add:

```gdscript
func test_explicit_screen_position_stays_visible_without_focus_target() -> void:
	var cursor := TestCursor.new()
	add_child_autofree(cursor)
	cursor.show_at_screen_position(Vector2(320, 180))
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO)
	assert_true(cursor.visible)
	assert_eq(cursor.position, Vector2(320, 180))
	assert_null(cursor._target)


func test_clear_target_exits_explicit_screen_position_mode() -> void:
	var cursor := TestCursor.new()
	add_child_autofree(cursor)
	cursor.show_at_screen_position(Vector2(50, 60))
	cursor.clear_target()
	assert_false(cursor.visible)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO)
	assert_false(cursor.visible)
```

- [ ] **Step 3: Write failing DungeonMap pointer-separation test**

Create a `NavigationUXLayer` before preparing the map, record the viewport's physical mouse position, start controller targeting, and assert:

```gdscript
var expected := dungeon_map.scan_controller.pointer_position
var physical_mouse := dungeon_map.get_viewport().get_mouse_position()
assert_true(navigation.cursor.visible)
assert_eq(navigation.cursor.position, expected)

dungeon_map._process_scan_navigation(Vector2.RIGHT * 0.5, Vector2.ZERO, 0.1)
var moved := dungeon_map.scan_controller.pointer_position
assert_eq(moved, expected + Vector2.RIGHT * dungeon_map.scan_controller.cursor_speed * 0.05)
assert_eq(dungeon_map.get_viewport().get_mouse_position(), physical_mouse)
assert_eq(navigation.cursor.position, moved)
```

Use an origin and viewport size that avoid clamping. Add a D-pad/full-magnitude assertion using `Vector2.RIGHT` and the same API. Add a mode-handoff assertion: mouse motion leaves controller mode and the custom cursor intact; a mouse-button click activates keyboard-and-mouse mode, clears the custom cursor, and does not first warp the physical pointer to the controller position.

- [ ] **Step 4: Run focused tests and verify RED**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_cursor -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect input_manager -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: `show_at_screen_position()` is missing, mouse motion still activates keyboard-and-mouse mode, and controller scan still warps the viewport mouse.

- [ ] **Step 5: Implement click-only mouse activation**

In `InputManager`, stop treating `InputEventMouseMotion` as a keyboard-and-mouse activation event. A pressed, non-synthetic `InputEventMouseButton` activates keyboard-and-mouse mode. Keep keyboard events in keyboard-and-mouse mode and controller events in controller mode. Remove controller-scan warp expectations only after all callers are gone; do not delete a still-used compatibility seam speculatively.

- [ ] **Step 6: Implement explicit screen-position cursor mode**

Add `_screen_position_active := false`. In `NavigationCursor._process()`, return without focus/free reconciliation while explicit mode is active.

Add:

```gdscript
func show_at_screen_position(
	screen_position: Vector2,
	state: CursorState = CursorState.DEFAULT,
) -> void:
	_screen_position_active = true
	_target = null
	_reset_warp_dedupe()
	set_cursor_state(state)
	_move_to(screen_position, true)
	show()
```

At the beginning of `set_focus_target()` and `set_world_target()`, set `_screen_position_active = false`. At the beginning of `clear_target()`, set it to false before clearing and hiding.

- [ ] **Step 7: Present the controller scan cursor without warping the OS mouse**

Add:

```gdscript
func _show_scan_cursor() -> void:
	var navigation := _navigation_ux_layer()
	if navigation and InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
		navigation.cursor.show_at_screen_position(scan_controller.pointer_position)
```

Replace the controller scan warp path with a controller-pointer update that calls `_show_scan_cursor()` after initial placement and each controller movement. Do not call `Input.warp_mouse()` or `InputManager.expect_mouse_warp()` for controller scan movement. In keyboard-and-mouse mode, clear the custom navigation cursor and synchronize scan selection from the physical mouse only after a mouse-button click has activated that mode. Existing cancel, confirm, modal takeover, and teardown paths must still call `_clear_navigation_cursor()` and restore the correct OS/custom cursor visibility.

- [ ] **Step 8: Run focused tests and verify GREEN**

Run the commands from Step 4.

Expected: all focused scripts pass; controller pointer and custom cursor share coordinates, the OS mouse is not warped, mouse motion cannot steal controller mode, and a mouse-button click performs the handoff.

- [ ] **Step 9: Commit cursor separation**

```sh
git add src/ui/navigation/navigation_cursor.gd src/singletons/input_manager.gd src/map/dungeon_map.gd test/unit/test_navigation_cursor.gd test/unit/test_input_manager.gd test/integration/test_dungeon_restore.gd
git commit -m "fix: separate controller scan cursor"
```

---

### Task 4: Resolve the real map node beneath the controller pointer

**Files:**

- Modify: `src/map/dungeon_map.gd`
- Test: `test/integration/test_dungeon_restore.gd`

**Interfaces:**

- Consumes: `DungeonMap._scan_pointer_world_position()`, real `MapNode` `Area2D` collision shapes, and Task 3's synchronized pointer.
- Produces: `_scan_node_under_pointer() -> MapNode`, `_apply_scan_selection(node: MapNode) -> void`, and `_refresh_scan_selection_under_pointer() -> void`.

- [ ] **Step 1: Replace the synthetic camera-hover test with a failing real collision test**

Replace `test_camera_hover_changes_scan_selection_without_neutral_frame_restoration` with:

```gdscript
func test_camera_motion_retargets_real_node_under_stationary_pointer() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var first: MapNode = setup.nodes[1]
	var second: MapNode = setup.nodes[2]
	for node: MapNode in [first, second]:
		var collision := node.get_node("CollisionPolygon2D") as CollisionPolygon2D
		assert_false(collision.polygon.is_empty())
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	await get_tree().physics_frame
	var stationary_pointer := first.get_global_transform_with_canvas().origin
	dungeon_map.scan_controller.sync_pointer(
		stationary_pointer,
		dungeon_map.get_viewport_rect().size,
	)
	dungeon_map._refresh_scan_selection_under_pointer()
	assert_same(dungeon_map.scan_controller.selected_node, first)

	dungeon_map.camera.position += second.position - first.position
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.016)

	assert_eq(dungeon_map.scan_controller.pointer_position, stationary_pointer)
	assert_same(dungeon_map.scan_controller.selected_node, second)
	assert_eq(dungeon_map.player_reticle.position, second.position)
```

This test must not call `_on_node_hovered()` or inject a fake physics result.

- [ ] **Step 2: Add a failing gap-preservation test**

Add:

```gdscript
func test_pointer_gap_preserves_last_valid_scan_selection() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var selected: MapNode = setup.nodes[1]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	await get_tree().physics_frame
	dungeon_map._apply_scan_selection(selected)
	var previous_reticle := dungeon_map.player_reticle.position
	var gap_position := selected.get_global_transform_with_canvas().origin + Vector2(0, 100)
	dungeon_map.scan_controller.sync_pointer(gap_position, dungeon_map.get_viewport_rect().size)

	dungeon_map._refresh_scan_selection_under_pointer()

	assert_null(dungeon_map._scan_node_under_pointer())
	assert_same(dungeon_map.scan_controller.selected_node, selected)
	assert_eq(dungeon_map.player_reticle.position, previous_reticle)
```

- [ ] **Step 3: Run focused integration and verify RED**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: the under-pointer resolver methods are missing or camera movement leaves the old node selected.

- [ ] **Step 4: Extract one shared selection method**

Add:

```gdscript
func _apply_scan_selection(node: MapNode) -> void:
	if current_map_state != MapState.TARGETING or node == null:
		return
	scan_controller.set_selected(node)
	_sync_scan_selection(false)
```

Change the targeting branch of `_on_node_hovered()` to call `_apply_scan_selection(hovered_node)` and return. No other method may directly assign scan selection presentation.

- [ ] **Step 5: Query real Area2D collision shapes beneath the pointer**

Add:

```gdscript
func _scan_node_under_pointer() -> MapNode:
	var parameters := PhysicsPointQueryParameters2D.new()
	parameters.position = _scan_pointer_world_position()
	parameters.collide_with_areas = true
	parameters.collide_with_bodies = false
	var matches: Array[MapNode] = []
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_point(parameters, 16):
		var collider := hit.get("collider") as MapNode
		if collider != null:
			matches.append(collider)
	if matches.is_empty():
		return null
	matches.sort_custom(func(a: MapNode, b: MapNode) -> bool:
		return a.grid_coords.x < b.grid_coords.x or (
			a.grid_coords.x == b.grid_coords.x and a.grid_coords.y < b.grid_coords.y
		)
	)
	return matches[0]


func _refresh_scan_selection_under_pointer() -> void:
	var node := _scan_node_under_pointer()
	if node != null:
		_apply_scan_selection(node)
```

The deterministic sort handles accidental overlapping collision shapes without introducing nearest-node selection.

- [ ] **Step 6: Refresh after pointer and camera policy finish**

Restructure `_process_scan_navigation()` so right-stick precedence and active-pressure camera behavior remain unchanged, but controller mode always ends the frame with:

```gdscript
_show_scan_cursor()
_refresh_scan_selection_under_pointer()
```

Do this after right-stick pan or edge-follow has updated the camera transform. Avoid early returns that skip the refresh in controller mode. Mouse mode continues to rely on physical hover signals and must not run the controller collision query.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_camera_controller -gexit
```

Expected: both scripts pass; no direct handler call remains in the camera-under-pointer regression.

- [ ] **Step 8: Commit under-pointer selection**

```sh
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd
git commit -m "fix: keep scan reticle beneath cursor"
```

---

### Task 5: Update acceptance documentation and verify the complete correction

**Files:**

- Modify: `docs/testing/controller-manual-checklist.md`
- Verify: `docs/superpowers/specs/2026-07-14-terminal-scan-transition-correction-design.md`

**Interfaces:**

- Consumes: completed Tasks 1-4.
- Produces: current manual acceptance instructions and final automated evidence.

- [ ] **Step 1: Update terminal and scan manual checks**

Replace the terminal acceptance bullets with these exact checks:

```markdown
- [ ] On the normal protocol list, Up/Down and WASD do not highlight or move among rows; no protocol row owns GUI focus.
- [ ] Hover each protocol with the mouse: its caret appears only while hovered, and clicking it activates that row exactly once.
- [ ] On DualSense, Cross, Square, Triangle, L1, and R1 activate only their displayed protocols regardless of prior mouse hover; Circle closes.
- [ ] Press a protocol shortcut during the brief typing animation: it is ignored without skipping or committing; after typing completes, one press activates it.
```

Replace the scan-cursor bullets with:

```markdown
- [ ] Move the left stick partially and fully: pointer speed follows analog magnitude; D-pad moves the same pointer at full digital speed.
- [ ] During controller scanning, the visible custom cursor follows the controller pointer while the hidden OS mouse remains at its independent physical position.
- [ ] Move the physical mouse without clicking: controller mode, controller cursor, and reticle remain authoritative. Click a mouse button: keyboard-and-mouse mode activates, the custom cursor hides, and the OS cursor appears at the physical click position without inheriting the controller position.
- [ ] Hold toward a viewport edge: the cursor clamps, camera edge-scroll continues, and the reticle advances through real hexes beneath the stationary edge cursor.
- [ ] No stale reticle scrolls offscreen; releasing the stick stops pointer and camera immediately.
```

- [ ] **Step 2: Run isolated Godot import**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
```

Expected: exit 0 with no parser errors or crashes. The documented macOS CA warning is acceptable.

- [ ] **Step 3: Run the complete GUT suite**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: every test passes. Record exact test and assertion totals; documented expected-error and shutdown diagnostics are acceptable only with exit 0.

- [ ] **Step 4: Check scope and stale behavior**

Run:

```sh
git diff --check
rg -n "first_protocol_input_during_typing_only_finishes|focus_presentation_uses_terminal_caret|_on_node_hovered\(hovered_after_camera_move\)|for child in overlay_layer.get_children\(\)" src test docs/testing
git status --short
```

Expected: no whitespace errors, no obsolete typing/focus/camera-hover regression language, and only intentional task files or required Godot sidecars are present.

- [ ] **Step 5: Commit documentation**

```sh
git add docs/testing/controller-manual-checklist.md
git commit -m "docs: update terminal scan acceptance checks"
```

No sidecars are expected for Markdown-only Task 5. If the final import changes a task-related `.uid` or `.import`, inspect it and commit it in a separate sidecar-only commit using its exact path; never stage `.godot/`.

- [ ] **Step 6: Record remaining manual acceptance**

Do not claim the physical behavior is verified until DualSense USB and Bluetooth passes confirm shortcut exclusivity, hover presentation, analog speed, D-pad parity, visible controller-cursor alignment, click-only mouse takeover without pointer inheritance, edge-scroll reticle tracking, confirm, and cancel.
