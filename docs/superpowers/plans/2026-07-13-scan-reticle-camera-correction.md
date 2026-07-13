# Scan Reticle and Camera Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dungeon scan's free blue-X cursor with stable reticle-only hex navigation, concurrent right-stick camera control, safe-area smart-follow, and automatic party return after scan completion or cancellation.

**Architecture:** `DungeonScanController` becomes a small directional-selection state machine that owns the current scan hex and held-stick repeat timing. `DungeonMap` routes semantic input and updates the one existing reticle, while `DungeonCameraController` remains the sole owner of pan, safe-area follow, clamping, and smooth party motion.

**Tech Stack:** Godot 4.6.3, typed GDScript, Camera2D, Tween, GUT 9.6.1

## Global Constraints

- The existing hex reticle is the only visible scan target; remove the blue-X `ScannerCursor` presentation and runtime path.
- Scan targeting includes every generated hex regardless of `HIDDEN`, `REVEALED`, or `COMPLETED` state.
- Left-stick and D-pad input move between neighboring generated hexes with held-input repeat; map edges never wrap, reverse, or warp.
- Right-stick pan always wins while non-zero and is never counteracted by smart-follow in the same frame.
- Releasing right-stick input preserves the manually chosen camera position.
- Smart-follow runs only after later reticle movement places the selected hex outside the proportional safe area.
- Confirmation keeps the existing `0.25` second reveal lock, then smoothly returns the camera to the party; cancellation returns it immediately.
- Use semantic input actions only; do not inspect physical controller button indices.
- Do not change scan radius, cost, reveal content, availability, ordinary traversal, alert rules, or save behavior.
- Use `HOME=/tmp/mars-godot-home` for every automated Godot command.
- Preserve unrelated dirty-worktree files and commit required Godot sidecars.

---

## File Structure

- Modify `src/map/dungeon_scan_controller.gd`: replace free-position movement, rectangular clamping, and nearest-node lookup with selected-node state, adjacent-hex directional scoring, and held-input repeat.
- Modify `test/unit/test_dungeon_scan_controller.gd`: replace free-cursor geometry tests with directional, repeat, hidden-node, tie-break, and stable-edge coverage.
- Modify `src/map/dungeon_map.gd`: route scan input through selected nodes, keep pan concurrent, invoke safe-area follow only after reticle movement, preserve mouse continuity, and recenter after confirm/cancel.
- Modify `test/integration/test_dungeon_restore.gd`: replace two-cursor and camera-retention expectations with reticle-only, simultaneous pan, manual override, smart reacquisition, modal, and return behavior.
- Modify `src/map/dungeon_map.tscn`: remove the obsolete `ScannerCursor` node and texture resource.
- Modify `docs/testing/controller-manual-checklist.md`: record the physical-controller acceptance checks for scan aiming and camera behavior.

### Task 1: Reticle-Only Directional Scan Selection

**Files:**
- Modify: `src/map/dungeon_scan_controller.gd`
- Modify: `test/unit/test_dungeon_scan_controller.gd`

**Interfaces:**
- Consumes: generated `MapNode` instances with `position` and odd-row-offset `grid_coords`.
- Produces: `begin(origin: MapNode) -> void`, `stop() -> void`, `set_selected(node: MapNode) -> MapNode`, and `process_direction(direction: Vector2, nodes: Array[MapNode], delta: float) -> MapNode`.
- Preserves: public `active: bool` and `selected_node: MapNode` state used by `DungeonMap`.

- [ ] **Step 1: Replace free-cursor tests with failing directional-selection tests**

Replace `test/unit/test_dungeon_scan_controller.gd` with:

```gdscript
extends GutTest

const MAP_NODE_SCENE := preload("res://src/map/map_node.tscn")


func _node(position: Vector2, coords: Vector2i, state := MapNode.NodeState.HIDDEN) -> MapNode:
	var node := MAP_NODE_SCENE.instantiate() as MapNode
	node.position = position
	node.grid_coords = coords
	add_child_autofree(node)
	await get_tree().process_frame
	node.set_state(state)
	return node


func test_begin_selects_origin_and_stop_clears_transient_state() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i.ZERO)
	var controller := DungeonScanController.new()
	controller.begin(origin)
	assert_true(controller.active)
	assert_same(controller.selected_node, origin)
	controller.stop()
	assert_false(controller.active)
	assert_null(controller.selected_node)


func test_direction_selects_adjacent_hidden_hex_without_jumping_over_it() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i(0, 0))
	var adjacent := await _node(Vector2(100, 0), Vector2i(1, 0), MapNode.NodeState.HIDDEN)
	var distant := await _node(Vector2(200, 0), Vector2i(2, 0), MapNode.NodeState.REVEALED)
	var controller := DungeonScanController.new()
	controller.begin(origin)
	assert_same(controller.process_direction(Vector2.RIGHT, [origin, distant, adjacent], 0.0), adjacent)
	assert_eq(adjacent.state, MapNode.NodeState.HIDDEN)


func test_direction_prefers_alignment_then_coordinates_for_neighbor_tie() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i(0, 0))
	var upper := await _node(Vector2(80, -50), Vector2i(0, -1))
	var lower := await _node(Vector2(80, 50), Vector2i(0, 1))
	var controller := DungeonScanController.new()
	controller.begin(origin)
	assert_same(controller.process_direction(Vector2.RIGHT, [lower, origin, upper], 0.0), upper)


func test_held_direction_repeats_after_delay() -> void:
	var first := await _node(Vector2.ZERO, Vector2i(0, 0))
	var second := await _node(Vector2(100, 0), Vector2i(1, 0))
	var third := await _node(Vector2(200, 0), Vector2i(2, 0))
	var controller := DungeonScanController.new()
	controller.begin(first)
	assert_same(controller.process_direction(Vector2.RIGHT, [first, second, third], 0.0), second)
	assert_same(controller.process_direction(Vector2.RIGHT, [first, second, third], 0.1), second)
	assert_same(
		controller.process_direction(Vector2.RIGHT, [first, second, third], DungeonScanController.REPEAT_DELAY),
		third,
	)


func test_changed_direction_steps_immediately_without_waiting_for_repeat() -> void:
	var center := await _node(Vector2.ZERO, Vector2i(0, 0))
	var right := await _node(Vector2(100, 0), Vector2i(1, 0))
	var above_right := await _node(Vector2(50, -100), Vector2i(1, -1))
	var controller := DungeonScanController.new()
	controller.begin(center)
	assert_same(controller.process_direction(Vector2.RIGHT, [center, right, above_right], 0.0), right)
	assert_same(controller.process_direction(Vector2.UP, [center, right, above_right], 0.0), above_right)


func test_map_edge_holds_last_hex_without_wrap_or_warp() -> void:
	var left := await _node(Vector2.ZERO, Vector2i(0, 0))
	var right := await _node(Vector2(100, 0), Vector2i(1, 0))
	var controller := DungeonScanController.new()
	controller.begin(left)
	assert_same(controller.process_direction(Vector2.RIGHT, [left, right], 0.0), right)
	for repeat in range(5):
		assert_same(
			controller.process_direction(Vector2.RIGHT, [left, right], DungeonScanController.REPEAT_DELAY),
			right,
		)


func test_neutral_input_resets_repeat_and_mouse_selection_becomes_controller_origin() -> void:
	var left := await _node(Vector2.ZERO, Vector2i(0, 0))
	var right := await _node(Vector2(100, 0), Vector2i(1, 0))
	var controller := DungeonScanController.new()
	controller.begin(left)
	assert_same(controller.set_selected(right), right)
	assert_same(controller.process_direction(Vector2.ZERO, [left, right], 1.0), right)
	assert_same(controller.process_direction(Vector2.LEFT, [left, right], 0.0), left)
```

- [ ] **Step 2: Run the focused test and verify the old free-position API fails**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller -gexit
```

Expected: FAIL because `begin(MapNode)`, `process_direction(...)`, and `set_selected(...)` do not exist with these signatures.

- [ ] **Step 3: Replace the free-position controller with directional adjacent-hex selection**

Replace `src/map/dungeon_scan_controller.gd` with:

```gdscript
class_name DungeonScanController
extends RefCounted

const REPEAT_DELAY := 0.32
const REPEAT_INTERVAL := 0.12
const DIRECTION_CHANGE_DOT := 0.99

var active := false
var selected_node: MapNode
var _last_direction := Vector2.ZERO
var _direction_hold_time := 0.0


func begin(origin: MapNode) -> void:
	active = true
	selected_node = origin
	_reset_repeat()


func stop() -> void:
	active = false
	selected_node = null
	_reset_repeat()


func set_selected(node: MapNode) -> MapNode:
	selected_node = node
	_reset_repeat()
	return selected_node


func process_direction(
	direction: Vector2,
	nodes: Array[MapNode],
	delta: float,
) -> MapNode:
	if not active or selected_node == null:
		return selected_node
	if direction.is_zero_approx():
		_reset_repeat()
		return selected_node
	var normalized := direction.normalized()
	var changed := (
		_last_direction.is_zero_approx()
		or normalized.dot(_last_direction.normalized()) < DIRECTION_CHANGE_DOT
	)
	if changed:
		_step(normalized, nodes)
		_direction_hold_time = 0.0
	else:
		_direction_hold_time += maxf(delta, 0.0)
		if _direction_hold_time >= REPEAT_DELAY:
			_step(normalized, nodes)
			_direction_hold_time = REPEAT_DELAY - REPEAT_INTERVAL
	_last_direction = normalized
	return selected_node


func _step(direction: Vector2, nodes: Array[MapNode]) -> void:
	var best: MapNode
	var best_alignment := -INF
	for candidate: MapNode in nodes:
		if candidate == null or candidate == selected_node:
			continue
		if _hex_distance(selected_node.grid_coords, candidate.grid_coords) != 1:
			continue
		var offset := candidate.position - selected_node.position
		if offset.is_zero_approx():
			continue
		var alignment := offset.normalized().dot(direction)
		if alignment <= 0.0:
			continue
		if best == null or alignment > best_alignment or (
			is_equal_approx(alignment, best_alignment) and _coordinates_before(candidate, best)
		):
			best = candidate
			best_alignment = alignment
	if best != null:
		selected_node = best


func _reset_repeat() -> void:
	_last_direction = Vector2.ZERO
	_direction_hold_time = 0.0


static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac := _offset_to_cube(a)
	var bc := _offset_to_cube(b)
	return maxi(abs(ac.x - bc.x), maxi(abs(ac.y - bc.y), abs(ac.z - bc.z)))


static func _offset_to_cube(hex: Vector2i) -> Vector3i:
	var q := hex.x - (hex.y + (hex.y & 1)) / 2
	var r := hex.y
	return Vector3i(q, r, -q - r)


static func _coordinates_before(a: MapNode, b: MapNode) -> bool:
	return a.grid_coords.x < b.grid_coords.x or (
		a.grid_coords.x == b.grid_coords.x and a.grid_coords.y < b.grid_coords.y
	)
```

- [ ] **Step 4: Run focused tests and verify directional selection passes**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller -gexit
```

Expected: all `test_dungeon_scan_controller.gd` tests pass with no parser errors.

- [ ] **Step 5: Commit the scan-selection policy**

```bash
git add src/map/dungeon_scan_controller.gd test/unit/test_dungeon_scan_controller.gd
git commit -m "fix: replace free dungeon scan cursor"
```

### Task 2: Concurrent Scan Reticle and Camera Behavior

**Files:**
- Modify: `src/map/dungeon_map.gd`
- Modify: `test/integration/test_dungeon_restore.gd`

**Interfaces:**
- Consumes: Task 1's `DungeonScanController.selected_node`, `begin`, `set_selected`, and `process_direction` methods.
- Consumes: `DungeonCameraController.pan(...)`, `follow_scanner(...)`, `move_to_party(...)`, `set_focus_mode(...)`, and `zoom_by(...)`.
- Produces: `_sync_scan_selection(animate := true) -> bool`, with `true` only when the authoritative selected hex changes.

- [ ] **Step 1: Replace integration expectations for scan startup, directional movement, and mouse continuity**

In `test/integration/test_dungeon_restore.gd`, replace the tests that reference free cursor position or `scanner_cursor` with:

```gdscript
func test_scan_starts_on_party_with_single_reticle() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	assert_true(dungeon_map.scan_controller.active)
	assert_same(dungeon_map.scan_controller.selected_node, dungeon_map.current_node)
	assert_same(dungeon_map._controller_preview_node, dungeon_map.current_node)
	assert_true(dungeon_map.player_reticle.visible)
	assert_eq(dungeon_map.player_reticle.position, dungeon_map.current_node.position)


func test_scan_reticle_repeats_through_hidden_hexes_without_moving_party() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	var party := dungeon_map.current_node
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.0)
	assert_same(dungeon_map._controller_preview_node, nodes[2])
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, DungeonScanController.REPEAT_DELAY)
	assert_same(dungeon_map._controller_preview_node, nodes[3])
	assert_same(dungeon_map.current_node, party)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.TARGETING)


func test_mouse_hover_becomes_controller_reticle_origin_without_extra_cursor() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var hovered: MapNode = setup.nodes[2]
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	dungeon_map.start_targeting_mode(1)
	dungeon_map._on_node_hovered(hovered)
	assert_same(dungeon_map.scan_controller.selected_node, hovered)
	assert_same(dungeon_map._controller_preview_node, hovered)
	assert_eq(dungeon_map.player_reticle.position, hovered.position)
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.016)
	assert_same(dungeon_map.scan_controller.selected_node, hovered)
	assert_eq(dungeon_map.player_reticle.position, hovered.position)
```

- [ ] **Step 2: Replace integration expectations for manual override, smart-follow, and camera return**

Replace the old tests named `test_scan_neutral_allows_manual_pan_but_scanner_motion_suppresses_it`, `test_scanner_keeps_moving_while_camera_reacquires_after_manual_pan`, and `test_scan_confirmation_briefly_locks_input_and_keeps_camera_at_scan_region` with:

```gdscript
func test_scan_right_stick_pan_wins_over_same_frame_reticle_follow() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.scan_dead_zone_ratio = 0.1
	dungeon_map.start_targeting_mode(1)
	var before := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.RIGHT, 0.1)
	assert_gt(dungeon_map.camera.position.x, before.x)
	var manually_panned := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.1)
	assert_eq(dungeon_map.camera.position, manually_panned)


func test_scan_reticle_movement_reacquires_only_after_manual_pan_release() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.scan_dead_zone_ratio = 0.1
	dungeon_map.start_targeting_mode(1)
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.RIGHT, 0.2)
	var manually_panned := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.1)
	assert_eq(dungeon_map.camera.position, manually_panned)
	dungeon_map._process_scan_navigation(Vector2.LEFT, Vector2.ZERO, 0.1)
	assert_ne(dungeon_map.camera.position, manually_panned)


func test_scan_confirmation_locks_briefly_then_returns_camera_to_party() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var target: MapNode = setup.nodes[3]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_selected(target)
	dungeon_map._sync_scan_selection(false)
	dungeon_map.camera.position = target.position
	var expected := dungeon_map._calculate_hybrid_position(dungeon_map.camera.zoom)
	dungeon_map.confirm_preview()
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	await get_tree().create_timer(0.15).timeout
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	await get_tree().create_timer(0.15).timeout
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	await get_tree().create_timer(dungeon_map.camera_smooth_speed + 0.05).timeout
	assert_almost_eq(dungeon_map.camera.position.x, expected.x, 0.01)
	assert_almost_eq(dungeon_map.camera.position.y, expected.y, 0.01)


func test_scan_cancel_returns_camera_to_party_without_consuming_scan() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.camera.position = setup.nodes[3].position
	var expected := dungeon_map._calculate_hybrid_position(dungeon_map.camera.zoom)
	watch_signals(dungeon_map)
	dungeon_map.cancel_preview()
	assert_signal_emitted(dungeon_map, &"scan_canceled")
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	await get_tree().create_timer(dungeon_map.camera_smooth_speed + 0.05).timeout
	assert_almost_eq(dungeon_map.camera.position.x, expected.x, 0.01)
	assert_almost_eq(dungeon_map.camera.position.y, expected.y, 0.01)
```

- [ ] **Step 3: Run the dungeon integration tests and verify the old runtime fails the new contract**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: FAIL because `DungeonMap` still reads free cursor position, suppresses pan during scan movement, and leaves the camera at the scan region.

- [ ] **Step 4: Rewire `DungeonMap` to selected-node state and one reticle**

Make these exact structural changes in `src/map/dungeon_map.gd`:

1. Remove `@onready var scanner_cursor` and the exported `scan_cursor_speed`.
2. Remove every assignment to `scanner_cursor.position` or `scanner_cursor.visible`.
3. Replace `_sync_scan_selection`, `_process_scan_navigation`, and `_approach_scan_camera` with:

```gdscript
func _sync_scan_selection(animate := true) -> bool:
	var selected := scan_controller.selected_node
	if selected == _controller_preview_node:
		return false
	_controller_preview_node = selected
	if selected:
		_animate_reticle_to(selected.position, animate)
	else:
		_hide_reticle()
	_clear_navigation_cursor()
	_publish_controller_hints()
	return true


func _process_scan_navigation(
	direction: Vector2,
	pan_direction: Vector2,
	delta: float,
) -> void:
	if not scan_controller.active:
		return
	if _controller_preview_node == null:
		_sync_scan_selection(false)
	var selection_moved := false
	if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
		var before := scan_controller.selected_node
		scan_controller.process_direction(direction, _map_nodes(), delta)
		selection_moved = scan_controller.selected_node != before
		if selection_moved:
			_sync_scan_selection()
	process_controller_camera(pan_direction, delta)
	if selection_moved and pan_direction.is_zero_approx():
		_approach_scan_camera(delta)


func _approach_scan_camera(delta: float) -> void:
	if scan_controller.selected_node == null:
		return
	_sync_camera_tuning()
	camera_controller.follow_scanner(
		scan_controller.selected_node.position,
		delta,
		get_viewport_rect().size,
	)
```

4. Replace scan startup with:

```gdscript
func start_targeting_mode(radius: int) -> void:
	_controller_direction_engaged = false
	_controller_preview_node = null
	current_map_state = MapState.TARGETING
	pending_scan_radius = radius
	_sync_camera_tuning()
	camera_controller.set_focus_mode(DungeonCameraController.FocusMode.SCANNER)
	scan_controller.begin(current_node)
	_sync_scan_selection(false)
	_start_reticle_scan_pulse()
	_clear_navigation_cursor()
	_publish_controller_hints()
```

5. In `_on_node_hovered`, replace the targeting branch with:

```gdscript
	if current_map_state == MapState.TARGETING:
		scan_controller.set_selected(hovered_node)
		_sync_scan_selection(false)
		return
```

6. In `_zoom_camera`, derive scanner position without a free cursor:

```gdscript
	var scanner_position := party_position
	if scan_controller.selected_node != null:
		scanner_position = scan_controller.selected_node.position
	camera_controller.zoom_by(
		step,
		party_position,
		scanner_position,
		get_viewport_rect().size,
	)
```

- [ ] **Step 5: Return the camera after cancel and confirmation**

In `_cancel_targeting`, after `camera_controller.set_focus_mode(...)`, add:

```gdscript
	camera_controller.move_to_party(
		current_node.position,
		false,
		get_viewport_rect().size,
	)
```

In `_finish_scan_target`, keep the state `LOCKED` through the reveal timer. After the timer and `is_inside_tree()` guard, use this ordering:

```gdscript
	camera_controller.move_to_party(
		current_node.position,
		false,
		get_viewport_rect().size,
	)
	current_map_state = MapState.PLAYING
	scan_performed.emit()
	_publish_controller_hints()
```

This deliberately starts the smooth return only after the `0.25` second reveal lock.

- [ ] **Step 6: Update remaining integration setup to selected-node state**

Across `test/integration/test_dungeon_restore.gd`, make these mechanical substitutions where the test still describes valid behavior:

```gdscript
dungeon_map.scan_controller.set_position(node.position)
dungeon_map._sync_scan_selection()
```

becomes:

```gdscript
dungeon_map.scan_controller.set_selected(node)
dungeon_map._sync_scan_selection(false)
```

Replace `scan_controller.position` camera expectations with `scan_controller.selected_node.position`. Delete assertions about continuous world-space cursor distance, rectangular cursor bounds, or `scanner_cursor`; those behaviors are intentionally removed. Retain assertions for hidden-hex eligibility, modal suppression, semantic confirm/cancel, zoom framing, unchanged party node, unchanged alert, and one-shot scan consumption.

- [ ] **Step 7: Run focused unit and integration tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller,dungeon_restore,dungeon_camera_controller -gexit
```

Expected: all selected tests pass; no parser errors, crashes, scan-position references, or unexpected failures.

- [ ] **Step 8: Commit runtime camera coordination**

```bash
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd
git commit -m "fix: coordinate scan reticle and camera"
```

### Task 3: Remove Obsolete Cursor Presentation and Verify the Playable Loop

**Files:**
- Modify: `src/map/dungeon_map.tscn`
- Modify: `docs/testing/controller-manual-checklist.md`
- Verify: `src/map/dungeon_map.gd`
- Verify: `test/integration/test_dungeon_restore.gd`

**Interfaces:**
- Consumes: the reticle-only runtime completed by Tasks 1 and 2.
- Produces: a map scene with no `ScannerCursor` node or cursor texture dependency and an updated physical-controller acceptance checklist.

- [ ] **Step 1: Add a failing scene regression assertion**

Add this test to `test/integration/test_dungeon_restore.gd`:

```gdscript
func test_dungeon_scene_has_no_secondary_scan_cursor() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	assert_null(dungeon_map.get_node_or_null("Player/ScannerCursor"))
```

- [ ] **Step 2: Run the focused test and verify the obsolete scene node is detected**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: the new scene assertion FAILS because `Player/ScannerCursor` still exists; any other failures must already be understood from Task 2 before proceeding.

- [ ] **Step 3: Remove the cursor resource and scene nodes**

In `src/map/dungeon_map.tscn`, remove:

```gdscript
[ext_resource type="Texture2D" path="res://assets/graphics/glyphs/cursors/outline/cross_small.svg" id="scanner_cursor"]
```

and:

```gdscript
[node name="ScannerCursor" type="Node2D" parent="Player"]
visible = false
z_index = 12

[node name="Sprite" type="Sprite2D" parent="Player/ScannerCursor"]
modulate = Color(0.117647, 0.564706, 1, 1)
scale = Vector2(0.6, 0.6)
texture = ExtResource("scanner_cursor")
```

Do not delete the shared `cross_small.svg` asset because other scenes or future cursor work may use it.

- [ ] **Step 4: Replace outdated physical-controller scan acceptance checks**

In `docs/testing/controller-manual-checklist.md`, preserve the DualSense run table but replace the checklist below it with:

```markdown
- Enter scan targeting: only the existing hex reticle appears; no blue X or second cursor is visible.
- Hold the left stick in each cardinal and diagonal direction: the reticle advances smoothly through neighboring valid hexes, including unrevealed hexes.
- Hold toward every map edge: the reticle stops on the last valid hex without wrapping, reversing, or warping.
- Pan with the right stick while moving the reticle: camera pan remains responsive and wins over smart-follow.
- Release the right stick: the camera remains where it was manually placed.
- Move the reticle inside the central safe area: the camera does not move.
- Move the reticle beyond the safe area after manual panning: the camera smoothly applies only enough correction to reacquire it.
- Confirm a distant scan: the reveal begins, input briefly locks, then the camera smoothly returns to the party.
- Cancel a distant scan: no scan is consumed and the camera smoothly returns to the party immediately.
- Switch between mouse and DualSense during targeting: the same reticle and selected hex persist without spawning another cursor.
```

In **Dungeon map and terminal**, replace the six bullets beginning with “Enter scan targeting with a controller” and ending with “Hover/click hidden scan centers” with the same reticle-only, edge-stability, simultaneous-pan, safe-area, camera-return, and input-family checks above. Keep the following semantic confirm/cancel, general pan, zoom, recenter, and terminal checks unchanged.

- [ ] **Step 5: Import and verify focused tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller,dungeon_restore,dungeon_camera_controller -gexit
```

Expected: import exits `0`; all selected tests pass. The documented macOS CA warning and shutdown diagnostics are acceptable only if the process exits successfully.

- [ ] **Step 6: Run the complete suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: every test and assertion passes with exit code `0`; no parser errors, crashes, or unexpected failures.

- [ ] **Step 7: Audit for obsolete runtime references and review the diff**

Run:

```bash
rg -n "scanner_cursor|scan_cursor_speed|scan_controller\.position|set_position\(|bounds_for_nodes|select_nearest" src/map test/unit/test_dungeon_scan_controller.gd test/integration/test_dungeon_restore.gd
git diff --check
git status --short
```

Expected: no obsolete scan-cursor references in the scoped runtime/tests, `git diff --check` is clean, and unrelated pre-existing battle/Godot changes remain unstaged.

- [ ] **Step 8: Commit scene cleanup and manual verification guidance**

```bash
git add src/map/dungeon_map.tscn docs/testing/controller-manual-checklist.md test/integration/test_dungeon_restore.gd
git commit -m "test: cover corrected dungeon scan controls"
```

- [ ] **Step 9: Perform the manual DualSense checklist before declaring the behavior complete**

Run the project in Godot 4.6.3 and complete the new **Scan targeting** subsection. Record any feel issue—especially repeat cadence, diagonal intent, or safe-area response—as a tuning follow-up rather than weakening deterministic state and edge tests.
