# Controller-Driven Scan Cursor Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task by task, with review checkpoints after each task.

**Goal:** Replace controller scan hex-stepping with a visible screen-space cursor that shares mouse hover selection, while preserving scan rules and providing pressure-gated camera edge scrolling.

**Architecture:** `DungeonScanController` becomes a small pointer-state object: it owns screen position, speed, viewport clamping, active state, and the last node supplied by hover. `DungeonMap` moves and warps that pointer, uses `_on_node_hovered()` as the only selection boundary, and invokes either right-stick pan or cursor edge-follow. `DungeonCameraController` retains camera smoothing, safe-area math, zoom ownership, and map clamping.

**Tech Stack:** Godot 4.6.3, typed GDScript, GUT 9.6.1, existing `InputManager` expected-warp suppression.

**Design:** [`docs/superpowers/specs/2026-07-14-controller-driven-scan-cursor-design.md`](../specs/2026-07-14-controller-driven-scan-cursor-design.md)

---

## Task 1: Replace scan node-stepping with screen-pointer state

**Files:**

- Modify: `src/map/dungeon_scan_controller.gd`
- Modify: `test/unit/test_dungeon_scan_controller.gd`

### Step 1: Write failing pointer-state tests

Replace the neighbor-selection and repeat-timing tests in `test/unit/test_dungeon_scan_controller.gd` with tests for the controller's new public behavior:

```gdscript
func test_begin_initializes_pointer_and_selection_and_stop_clears_state() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i.ZERO)
	var controller := DungeonScanController.new()
	controller.begin(Vector2(320, 180), Vector2(640, 360), origin)
	assert_true(controller.active)
	assert_eq(controller.pointer_position, Vector2(320, 180))
	assert_same(controller.selected_node, origin)
	controller.stop()
	assert_false(controller.active)
	assert_null(controller.selected_node)


func test_pointer_motion_is_delta_scaled_and_speed_limited() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i.ZERO)
	var controller := DungeonScanController.new()
	controller.cursor_speed = 600.0
	controller.begin(Vector2(100, 100), Vector2(1000, 800), origin)
	assert_eq(
		controller.move_pointer(Vector2.RIGHT, 0.5, Vector2(1000, 800)),
		Vector2(400, 100),
	)
	controller.sync_pointer(Vector2(100, 100), Vector2(1000, 800))
	var diagonal := controller.move_pointer(Vector2.ONE, 0.5, Vector2(1000, 800))
	assert_almost_eq(diagonal.distance_to(Vector2(100, 100)), 300.0, 0.001)
```

Also cover these boundaries:

- `begin()` clamps an out-of-range initial position;
- `move_pointer()` clamps at `viewport_size - Vector2.ONE`, so it never requests an out-of-bounds warp;
- neutral input and non-positive delta preserve position;
- `sync_pointer()` clamps a physical-mouse position, and the next controller move continues from it;
- `set_selected()` stores hidden, revealed, and completed nodes without directional scoring;
- `stop()` clears active selection but leaves no repeat or direction state behind.

### Step 2: Run the focused test and confirm it fails

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller -gexit
```

Expected: failures because `begin()` does not accept a screen position and viewport, and pointer APIs do not exist.

### Step 3: Implement the pointer-state controller

Replace repeat constants and neighbor scoring in `src/map/dungeon_scan_controller.gd` with this responsibility:

```gdscript
class_name DungeonScanController
extends RefCounted

var cursor_speed := 600.0
var active := false
var pointer_position := Vector2.ZERO
var selected_node: MapNode


func begin(origin_position: Vector2, viewport_size: Vector2, origin: MapNode) -> void:
	active = true
	pointer_position = _clamp_to_viewport(origin_position, viewport_size)
	selected_node = origin


func stop() -> void:
	active = false
	selected_node = null


func set_selected(node: MapNode) -> MapNode:
	selected_node = node
	return selected_node


func sync_pointer(position: Vector2, viewport_size: Vector2) -> Vector2:
	pointer_position = _clamp_to_viewport(position, viewport_size)
	return pointer_position


func move_pointer(direction: Vector2, delta: float, viewport_size: Vector2) -> Vector2:
	if not active or direction.is_zero_approx() or delta <= 0.0:
		return pointer_position
	var limited_direction := direction.limit_length(1.0)
	pointer_position = _clamp_to_viewport(
		pointer_position + limited_direction * cursor_speed * delta,
		viewport_size,
	)
	return pointer_position


func _clamp_to_viewport(position: Vector2, viewport_size: Vector2) -> Vector2:
	var maximum := Vector2(
		maxf(viewport_size.x - 1.0, 0.0),
		maxf(viewport_size.y - 1.0, 0.0),
	)
	return position.clamp(Vector2.ZERO, maximum)
```

Do not retain `REPEAT_DELAY`, `REPEAT_INTERVAL`, `_step()`, hex-distance helpers, or neighbor tie-breaking. Ordinary traversal still owns its separate directional selection logic in `DungeonMap`.

### Step 4: Run the focused test and confirm it passes

Run the command from Step 2.

Expected: all `test_dungeon_scan_controller.gd` cases pass with no parser errors or crashes.

### Step 5: Commit the pointer-state change

```sh
git add src/map/dungeon_scan_controller.gd test/unit/test_dungeon_scan_controller.gd
git commit -m "refactor: model scan input as screen pointer"
```

---

## Task 2: Unify controller and mouse scan selection through hover

**Files:**

- Modify: `src/map/dungeon_map.gd`
- Modify: `test/integration/test_dungeon_restore.gd`

### Step 1: Replace obsolete integration expectations with failing pointer-routing tests

Remove or rewrite integration cases that require controller neighbor stepping, repeat timing, or selection restoration, especially:

- `test_scan_reticle_repeats_through_hidden_hexes_without_moving_party`
- controller portions of `test_mouse_hover_becomes_controller_reticle_origin`
- any assertion that `_process_scan_navigation()` directly replaces `selected_node`.

Add tests that establish the new ownership boundary:

```gdscript
func test_scan_start_initializes_pointer_at_party_screen_position() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	var expected := dungeon_map.current_node.get_global_transform_with_canvas().origin
	assert_eq(dungeon_map.scan_controller.pointer_position, expected)
	assert_same(dungeon_map.scan_controller.selected_node, dungeon_map.current_node)


func test_controller_pointer_motion_does_not_select_until_node_hover() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var hovered: MapNode = setup.nodes[2]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	var original := dungeon_map.scan_controller.selected_node
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.1)
	assert_same(dungeon_map.scan_controller.selected_node, original)
	dungeon_map._on_node_hovered(hovered)
	assert_same(dungeon_map.scan_controller.selected_node, hovered)
	assert_eq(dungeon_map.player_reticle.position, hovered.position)
```

Also add or retain coverage that:

- hover selects hidden, revealed, and completed hexes while targeting;
- a controller-generated expected mouse motion does not switch `InputManager` out of controller mode;
- physical mouse mode synchronizes `scan_controller.pointer_position` from the actual viewport mouse position;
- after physical mouse takeover, the next controller motion starts from that synchronized position;
- moving the camera so another hex fires hover intentionally changes selection, and the next neutral process frame does not restore the old node;
- scan confirmation still targets the last hovered node and does not move the party or change alert.

For expected-warp suppression, after processing controller movement, construct an `InputEventMouseMotion` at `scan_controller.pointer_position`, send it through `InputManager._input(event)`, and assert the active mode remains controller. Keep the existing dedicated `test_input_manager.gd` tolerance tests unchanged.

### Step 2: Run the focused integration test and confirm it fails

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: failures because scan start still passes a `MapNode` only and `_process_scan_navigation()` still performs node stepping.

### Step 3: Initialize and warp the shared pointer

In `DungeonMap.start_targeting_mode()`:

1. compute the party node's viewport position with `current_node.get_global_transform_with_canvas().origin`;
2. call `scan_controller.begin(origin_screen_position, get_viewport_rect().size, current_node)`;
3. if the active mode is controller, call a new `_warp_scan_pointer()` seam so the visible system cursor starts over the party hex;
4. keep `_sync_scan_selection(false)`, reticle pulsing, hints, and camera focus behavior unchanged.

Add the small wrapper:

```gdscript
func _warp_scan_pointer(screen_position: Vector2) -> void:
	InputManager.expect_mouse_warp(screen_position)
	get_viewport().warp_mouse(screen_position)
```

The expected warp must be registered before the physical warp call.

### Step 4: Route pointer movement without direct selection

Rewrite the input-mode portion of `_process_scan_navigation()`:

```gdscript
var viewport_size := get_viewport_rect().size
if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
	var before := scan_controller.pointer_position
	var after := scan_controller.move_pointer(direction, delta, viewport_size)
	if not after.is_equal_approx(before):
		_warp_scan_pointer(after)
else:
	scan_controller.sync_pointer(get_viewport().get_mouse_position(), viewport_size)
```

Do not call `set_selected()` here. Leave `DungeonMap._on_node_hovered()` as the sole selection writer during `MapState.TARGETING`; it should continue to call `scan_controller.set_selected(hovered_node)` followed by `_sync_scan_selection(false)`.

Remove the scan-specific use of `_map_nodes()` if it becomes unused. Preserve `_map_nodes()` only if another caller still needs it.

### Step 5: Remove competing selection restoration

Remove `_scan_camera_reacquiring` and all assignments/assertions tied to it. A neutral frame must not move the pointer, move the camera, or restore a prior selected node.

Keep `_controller_preview_node` as reticle/hint presentation state for now; removing it would broaden the refactor beyond this behavior change.

### Step 6: Run focused unit and integration tests

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: both focused scripts pass. Headless execution does not need to prove the OS cursor's visual position; it must prove stored pointer position, expected-warp mode suppression, and hover-owned selection.

### Step 7: Commit unified pointer/hover selection

```sh
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd
git commit -m "fix: unify scan selection under cursor hover"
```

---

## Task 3: Gate scan edge scrolling by active pointer pressure

**Files:**

- Modify: `src/map/dungeon_map.gd`
- Modify: `test/integration/test_dungeon_restore.gd`

### Step 1: Write failing edge-scroll policy tests

Replace the old reacquisition tests, including `test_scan_reticle_movement_reacquires_only_after_manual_pan_release` and `test_scan_camera_continues_reacquiring_over_neutral_frames`, with tests for the approved policy:

- cursor inside the proportional safe area + active left-stick direction leaves the camera still;
- cursor outside the safe area + active direction moves the camera smoothly;
- releasing direction immediately stops camera motion even while the cursor remains outside the safe area;
- holding outward direction after the pointer clamps to the viewport edge continues camera motion;
- non-zero right-stick pan wins over edge-follow in the same frame;
- releasing right stick does not cause edge-follow unless left-stick/D-pad direction is also active;
- zoom tween and camera clamping still leave `DungeonCameraController` as the only camera-position authority.

Use a small `scan_dead_zone_ratio` and high zoom in integration fixtures where needed so the safe-area boundary is deterministic. Set `scan_controller.pointer_position` directly to an inside/outside screen position; selection does not need to change for camera-policy tests.

### Step 2: Run the focused integration test and confirm it fails

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: new active-pressure tests fail until camera follow uses the pointer instead of the selected node.

### Step 3: Convert the screen pointer to camera/world space

Add a focused helper in `DungeonMap`:

```gdscript
func _scan_pointer_world_position() -> Vector2:
	return get_canvas_transform().affine_inverse() * scan_controller.pointer_position
```

Use the canvas transform rather than `selected_node.position`; camera movement must follow the visible screen cursor, not a stale hex selection.

### Step 4: Enforce input precedence and pressure gating

After pointer synchronization in `_process_scan_navigation()`:

1. if `pan_direction` is non-zero, call `process_controller_camera(pan_direction, delta)` and return;
2. if input mode is not controller, return—mouse edge scrolling is outside this change;
3. if `direction` is zero, return immediately;
4. calculate the pointer's world position;
5. if it is already inside `DungeonCameraController`'s safe area, return;
6. otherwise call `camera_controller.follow_scanner(pointer_world_position, delta, viewport_size)` after `_sync_camera_tuning()`.

This ordering ensures right-stick precedence and makes stick release stop scrolling on the same frame. Because the screen pointer remains clamped at an edge while its derived world position changes with the camera transform, continued directional pressure keeps producing edge scroll without cursor warping.

Rename `_approach_scan_camera()` to `_follow_scan_pointer()` or inline the short call; do not keep any selected-node or reacquisition semantics in its name or implementation.

### Step 5: Run focused tests

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_camera_controller -gexit
```

Expected: scan integration and camera-controller unit tests pass without parser errors or crashes.

### Step 6: Commit camera behavior

```sh
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd
git commit -m "fix: edge scroll with active scan pointer"
```

---

## Task 4: Update manual acceptance and verify the complete change

**Files:**

- Modify: `docs/testing/controller-manual-checklist.md`
- Verify: `docs/superpowers/specs/2026-07-14-controller-driven-scan-cursor-design.md`

### Step 1: Rewrite the DualSense scan checks

Replace the obsolete “reticle only” and neighbor-stepping bullets in both scan sections of `docs/testing/controller-manual-checklist.md` with the authoritative behavior:

- entering scan shows the visible system cursor centered over the party hex and the existing reticle on that hex;
- left stick moves the cursor smoothly at analog speed; D-pad provides continuous digital motion;
- the reticle snaps to hidden, revealed, and completed hexes crossed by the cursor;
- cursor and reticle never warp backward when camera edge scrolling begins;
- cursor clamps at the viewport boundary while held pressure continues scrolling the camera;
- releasing the stick stops pointer and edge scrolling immediately;
- right-stick pan wins while held and does not pull the cursor or selection;
- physical mouse takes over from the cursor's current position, and controller movement resumes from that same position;
- confirm scans the last hovered hex; cancel consumes nothing and returns the camera to the party.

Keep the existing USB/Bluetooth evidence table and hardware sign-off requirements.

### Step 2: Import and parse with the required isolated HOME

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
```

Expected: exit code 0 with no parser errors or crashes. The documented macOS certificate warning and shutdown leak diagnostics are acceptable.

### Step 3: Run the complete GUT suite

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: all tests pass. Record the exact test and assertion totals in the handoff; do not treat the current totals as fixed targets.

### Step 4: Review the final diff for scope and stale concepts

Run:

```sh
git diff --check
git diff --stat HEAD~3..HEAD
rg -n "REPEAT_DELAY|REPEAT_INTERVAL|process_direction|_scan_camera_reacquiring|only the existing hex reticle|reticle advances smoothly through neighboring" src/map test docs/testing
```

Expected: no whitespace errors and no remaining scan node-step/reacquisition implementation or obsolete manual language. If a searched phrase is used by ordinary traversal rather than scanning, retain it and document why.

### Step 5: Commit documentation and any required Godot sidecars

```sh
git add docs/testing/controller-manual-checklist.md
git add <required .uid or .import sidecars generated for task files, if any>
git commit -m "docs: update scan cursor acceptance checks"
```

Do not stage unrelated user files or `.godot/` cache contents.

### Step 6: Perform manual acceptance when hardware is available

On a DualSense, verify both USB and Bluetooth rows in the checklist. This remains an explicit manual check after automated verification; lack of immediate hardware access does not justify claiming the controller feel or visual cursor placement is verified.

