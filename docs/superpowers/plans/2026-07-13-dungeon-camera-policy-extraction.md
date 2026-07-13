# Dungeon Camera Policy Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract all stable dungeon camera calculations and camera-owned motion into a focused `DungeonCameraController` without intentionally changing camera behavior.

**Architecture:** `DungeonMap` remains the input, gameplay-state, modal, scan-lifecycle, battle-presentation, and scene-presentation authority. A runtime `DungeonCameraController` receives already-authorized commands, owns camera math and compatible tweens, and explicitly switches between party and scanner focus; `DungeonScanController` retains only scanner movement and selection.

**Tech Stack:** Godot 4.6.3, typed GDScript, Camera2D, Tween, GUT 9.6.1

## Global Constraints

- Preserve current numerical tuning, input gates, camera destinations, animation timing, background behavior, scan behavior, traversal behavior, and input mappings.
- Keep `zoom_step`, `min_zoom`, `max_zoom`, `camera_smooth_speed`, `camera_edge_margin`, `camera_pan_speed`, `scan_dead_zone_ratio`, and `scan_camera_follow_response` exported on `DungeonMap`.
- Do not activate the currently unused `camera_edge_margin` setting.
- Keep map state, modal gating, raw input, traversal, scan legality, battle fades, HUD, grid, shader, parallax, background sizing, and save/restore orchestration in `DungeonMap`.
- Keep scanner activity, virtual movement, positional bounds, and deterministic nearest-node selection in `DungeonScanController`.
- Use semantic input actions only; do not add physical controller-button handling.
- Use the isolated `HOME=/tmp/mars-godot-home` for every automated Godot command.
- Preserve and commit any required `.uid` sidecar Godot generates for the new script.

---

## File Structure

- Create `src/map/dungeon_camera_controller.gd`: live camera policy, focus mode, geometry, manual pan/recenter, party/scanner follow, zoom, and camera-owned tween cancellation.
- Create `test/unit/test_dungeon_camera_controller.gd`: focused protection for pure camera math, focus behavior, and tween ownership.
- Modify `src/map/dungeon_scan_controller.gd`: remove camera dead-zone configuration and calculation, leaving scanner-only responsibilities.
- Modify `test/unit/test_dungeon_scan_controller.gd`: remove camera-policy tests; retain movement, bounds, and selection coverage.
- Modify `src/map/dungeon_map.gd`: create/configure the camera controller, preserve current input/state gates, and convert existing camera entry points into delegates.
- Modify `test/integration/test_dungeon_restore.gd`: use the new controller seam for expected camera calculations while continuing to protect end-to-end dungeon behavior.
- Modify `docs/refactor.md`: record general camera policy as an extracted boundary after implementation passes.

### Task 1: Camera Geometry and Manual Movement

**Files:**
- Create: `src/map/dungeon_camera_controller.gd`
- Create: `test/unit/test_dungeon_camera_controller.gd`
- Generate if Godot requires it: `src/map/dungeon_camera_controller.gd.uid`

**Interfaces:**
- Consumes: live `Camera2D`, `Sprite2D`, and `Parallax2D` references supplied by `DungeonMap`.
- Produces: `configure(camera_node: Camera2D, background_node: Sprite2D, parallax_node: Parallax2D) -> void`, `clamp_position(target_position: Vector2, zoom_level: Vector2, viewport_size: Vector2) -> Vector2`, `pan(direction: Vector2, delta: float, viewport_size: Vector2) -> Vector2`, and `recenter(party_position: Vector2, viewport_size: Vector2) -> Vector2`.

- [ ] **Step 1: Write failing geometry and movement tests**

Create `test/unit/test_dungeon_camera_controller.gd` with a fixture that uses real Godot nodes and an in-memory texture:

```gdscript
extends GutTest


func _fixture() -> Dictionary:
	var controller := DungeonCameraController.new()
	var camera := Camera2D.new()
	var background := Sprite2D.new()
	var parallax := Parallax2D.new()
	background.texture = ImageTexture.create_from_image(
		Image.create(1200, 900, false, Image.FORMAT_RGBA8)
	)
	background.scale = Vector2(2.0, 2.0)
	parallax.scroll_scale = Vector2(0.5, 0.5)
	add_child_autofree(controller)
	add_child_autofree(camera)
	add_child_autofree(background)
	add_child_autofree(parallax)
	controller.configure(camera, background, parallax)
	return {
		"controller": controller,
		"camera": camera,
		"background": background,
		"parallax": parallax,
	}


func test_clamp_position_preserves_inside_position_and_clamps_each_edge() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var viewport := Vector2(900, 600)
	assert_eq(controller.clamp_position(Vector2.ZERO, Vector2.ONE, viewport), Vector2.ZERO)
	var positive := controller.clamp_position(Vector2(100000, 100000), Vector2.ONE, viewport)
	var negative := controller.clamp_position(Vector2(-100000, -100000), Vector2.ONE, viewport)
	assert_gt(positive.x, 0.0)
	assert_gt(positive.y, 0.0)
	assert_eq(negative, -positive)


func test_clamp_position_centers_axis_when_viewport_exceeds_background() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	assert_eq(
		controller.clamp_position(Vector2(500, 500), Vector2(0.01, 0.01), Vector2(900, 600)),
		Vector2.ZERO,
	)


func test_pan_is_delta_scaled_zoom_adjusted_normalized_and_clamped() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.pan_speed = 100.0
	camera.zoom = Vector2(2.0, 2.0)
	camera.position = Vector2.ZERO
	var diagonal := controller.pan(Vector2(1, 1), 0.5, Vector2(900, 600))
	assert_almost_eq(diagonal.x, 70.71068, 0.001)
	assert_almost_eq(diagonal.y, 70.71068, 0.001)
	assert_eq(camera.position, diagonal)
	camera.position = Vector2(100000, 100000)
	var clamped := controller.pan(Vector2.RIGHT, 0.5, Vector2(900, 600))
	assert_eq(clamped, controller.clamp_position(clamped, camera.zoom, Vector2(900, 600)))


func test_recenter_clamps_party_position_at_current_zoom() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	camera.zoom = Vector2(1.5, 1.5)
	var expected := controller.clamp_position(Vector2(100000, -100000), camera.zoom, Vector2(900, 600))
	assert_eq(controller.recenter(Vector2(100000, -100000), Vector2(900, 600)), expected)
	assert_eq(camera.position, expected)
```

- [ ] **Step 2: Run the focused test and verify it fails for the missing class**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_camera_controller -gexit
```

Expected: FAIL with a parser error that `DungeonCameraController` is not declared.

- [ ] **Step 3: Implement the minimal geometry and movement controller**

Create `src/map/dungeon_camera_controller.gd`:

```gdscript
class_name DungeonCameraController
extends Node

const MIN_ZOOM := 0.001

var pan_speed := 600.0

var _camera: Camera2D
var _background: Sprite2D
var _parallax: Parallax2D


func configure(
	camera_node: Camera2D,
	background_node: Sprite2D,
	parallax_node: Parallax2D,
) -> void:
	_camera = camera_node
	_background = background_node
	_parallax = parallax_node


func clamp_position(
	target_position: Vector2,
	zoom_level: Vector2,
	viewport_size: Vector2,
) -> Vector2:
	var safe_zoom := Vector2(
		maxf(absf(zoom_level.x), MIN_ZOOM),
		maxf(absf(zoom_level.y), MIN_ZOOM),
	)
	var visible_world_size := viewport_size / safe_zoom
	var background_size := _background.texture.get_size() * _background.scale
	var parallax_scale := Vector2.ONE
	if _parallax and _parallax.scroll_scale != Vector2.ZERO:
		parallax_scale = _parallax.scroll_scale
	var half_background := background_size / parallax_scale / 3.0
	var half_view := visible_world_size / 3.0
	var minimum := -half_background + half_view
	var maximum := half_background - half_view
	if minimum.x > maximum.x:
		minimum.x = 0.0
		maximum.x = 0.0
	if minimum.y > maximum.y:
		minimum.y = 0.0
		maximum.y = 0.0
	return Vector2(
		clampf(target_position.x, minimum.x, maximum.x),
		clampf(target_position.y, minimum.y, maximum.y),
	)


func pan(direction: Vector2, delta: float, viewport_size: Vector2) -> Vector2:
	if direction.is_zero_approx() or delta <= 0.0:
		return _camera.position
	var target := _camera.position + direction.normalized() * pan_speed * delta * _camera.zoom.x
	_camera.position = clamp_position(target, _camera.zoom, viewport_size)
	return _camera.position


func recenter(party_position: Vector2, viewport_size: Vector2) -> Vector2:
	_camera.position = clamp_position(party_position, _camera.zoom, viewport_size)
	return _camera.position
```

- [ ] **Step 4: Import, run the focused test, and verify it passes**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_camera_controller -gexit
```

Expected: import exits 0; all `test_dungeon_camera_controller.gd` tests pass. If Godot creates `src/map/dungeon_camera_controller.gd.uid`, include it rather than deleting it.

- [ ] **Step 5: Commit the geometry seam**

```bash
git add src/map/dungeon_camera_controller.gd src/map/dungeon_camera_controller.gd.uid test/unit/test_dungeon_camera_controller.gd
git commit -m "refactor: add dungeon camera geometry controller"
```

### Task 2: Scanner Camera Policy and Explicit Focus

**Files:**
- Modify: `src/map/dungeon_camera_controller.gd`
- Modify: `test/unit/test_dungeon_camera_controller.gd`
- Modify: `src/map/dungeon_scan_controller.gd`
- Modify: `test/unit/test_dungeon_scan_controller.gd`

**Interfaces:**
- Consumes: Task 1 `clamp_position(...)` and configured live camera.
- Produces: `FocusMode { PARTY, SCANNER }`, `set_focus_mode(mode: FocusMode) -> void`, `desired_scanner_position(scanner_position: Vector2, camera_position: Vector2, viewport_size: Vector2, zoom_level: Vector2) -> Vector2`, and `follow_scanner(scanner_position: Vector2, delta: float, viewport_size: Vector2) -> Vector2`.

- [ ] **Step 1: Add failing scanner-policy tests to the camera controller test**

Append:

```gdscript
func test_scanner_dead_zone_scales_with_viewport_and_zoom() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	controller.scanner_dead_zone_ratio = Vector2(0.6, 0.6)
	assert_eq(
		controller.desired_scanner_position(Vector2(250, 200), Vector2.ZERO, Vector2(1000, 800), Vector2.ONE),
		Vector2.ZERO,
	)
	assert_eq(
		controller.desired_scanner_position(Vector2(200, 0), Vector2.ZERO, Vector2(1000, 800), Vector2(2, 2)),
		Vector2(50, 0),
	)
	assert_eq(
		controller.desired_scanner_position(Vector2(350, 0), Vector2.ZERO, Vector2(2000, 800), Vector2.ONE),
		Vector2.ZERO,
	)


func test_follow_scanner_uses_exponential_response_without_overshoot() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.scanner_dead_zone_ratio = Vector2(0.1, 0.1)
	controller.scanner_follow_response = 8.0
	controller.set_focus_mode(DungeonCameraController.FocusMode.SCANNER)
	var scanner := Vector2(400, 300)
	var desired := controller.desired_scanner_position(
		scanner, camera.position, Vector2(1000, 800), camera.zoom
	)
	var expected := controller.clamp_position(
		camera.position.lerp(desired, 1.0 - exp(-8.0 * 0.125)),
		camera.zoom,
		Vector2(1000, 800),
	)
	assert_eq(controller.follow_scanner(scanner, 0.125, Vector2(1000, 800)), expected)
	assert_gt(camera.position.distance_to(desired), 0.0)


func test_party_focus_does_not_follow_scanner() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.set_focus_mode(DungeonCameraController.FocusMode.PARTY)
	assert_eq(controller.follow_scanner(Vector2(400, 300), 1.0, Vector2(1000, 800)), Vector2.ZERO)
	assert_eq(camera.position, Vector2.ZERO)
```

- [ ] **Step 2: Run focused tests and verify the new interface is missing**

Run the camera-controller command from Task 1.

Expected: FAIL because `FocusMode`, `desired_scanner_position`, or `follow_scanner` is not defined.

- [ ] **Step 3: Add scanner policy and focus mode to `DungeonCameraController`**

Add:

```gdscript
enum FocusMode { PARTY, SCANNER }

var scanner_dead_zone_ratio := Vector2(0.6, 0.6)
var scanner_follow_response := 8.0
var focus_mode := FocusMode.PARTY


func set_focus_mode(mode: FocusMode) -> void:
	focus_mode = mode


func desired_scanner_position(
	scanner_position: Vector2,
	camera_position: Vector2,
	viewport_size: Vector2,
	zoom_level: Vector2,
) -> Vector2:
	var safe_zoom := Vector2(
		maxf(absf(zoom_level.x), MIN_ZOOM),
		maxf(absf(zoom_level.y), MIN_ZOOM),
	)
	var half_dead_world := viewport_size * scanner_dead_zone_ratio * 0.5 / safe_zoom
	var offset := scanner_position - camera_position
	var target := camera_position
	if offset.x < -half_dead_world.x:
		target.x = scanner_position.x + half_dead_world.x
	elif offset.x > half_dead_world.x:
		target.x = scanner_position.x - half_dead_world.x
	if offset.y < -half_dead_world.y:
		target.y = scanner_position.y + half_dead_world.y
	elif offset.y > half_dead_world.y:
		target.y = scanner_position.y - half_dead_world.y
	return target


func follow_scanner(scanner_position: Vector2, delta: float, viewport_size: Vector2) -> Vector2:
	if focus_mode != FocusMode.SCANNER:
		return _camera.position
	var desired := desired_scanner_position(
		scanner_position, _camera.position, viewport_size, _camera.zoom
	)
	var weight := 1.0 - exp(-scanner_follow_response * maxf(delta, 0.0))
	_camera.position = clamp_position(
		_camera.position.lerp(desired, weight), _camera.zoom, viewport_size
	)
	return _camera.position
```

- [ ] **Step 4: Remove camera policy from `DungeonScanController` and its unit tests**

Keep `MIN_ZOOM`, because zoom-safe scanner movement still uses it. Delete:

```gdscript
var dead_zone_ratio := Vector2(0.6, 0.6)
```

Delete the complete `desired_camera_position(...)` method from `src/map/dungeon_scan_controller.gd`. Delete these four tests from `test/unit/test_dungeon_scan_controller.gd` because their behavior now lives in the camera-controller tests:

```text
test_camera_stays_still_inside_proportional_dead_zone
test_camera_moves_minimum_distance_to_dead_zone_boundary
test_camera_dead_zone_scales_with_zoom_and_viewport
test_camera_fractional_dead_zone_preserves_inside_and_outside_boundary
```

- [ ] **Step 5: Run both focused unit scripts and verify they pass**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_camera_controller -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller -gexit
```

Expected: both focused scripts pass; `DungeonScanController` still protects movement, zoom adjustment, bounds, hidden-node selection, deterministic ties, and empty selection.

- [ ] **Step 6: Commit scanner camera ownership**

```bash
git add src/map/dungeon_camera_controller.gd src/map/dungeon_scan_controller.gd test/unit/test_dungeon_camera_controller.gd test/unit/test_dungeon_scan_controller.gd
git commit -m "refactor: move scan following into camera controller"
```

### Task 3: Party Follow, Zoom, and Camera-Owned Tweens

**Files:**
- Modify: `src/map/dungeon_camera_controller.gd`
- Modify: `test/unit/test_dungeon_camera_controller.gd`

**Interfaces:**
- Consumes: Task 1 geometry and Task 2 focus/scanner policy.
- Produces: `cover_zoom(viewport_size: Vector2) -> Vector2`, `hybrid_position(party_position: Vector2, at_zoom: Vector2, viewport_size: Vector2) -> Vector2`, `move_to_party(party_position: Vector2, force_center: bool, viewport_size: Vector2) -> void`, `zoom_by(step: float, party_position: Vector2, scanner_position: Vector2, viewport_size: Vector2) -> Vector2`, and `cancel_motion() -> void`.

- [ ] **Step 1: Add failing party/zoom/tween tests**

Append:

```gdscript
func test_cover_zoom_and_hybrid_position_preserve_existing_formula() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var cover := controller.cover_zoom(Vector2(900, 600))
	assert_eq(cover, Vector2.ONE * maxf(900.0 / 2400.0, 600.0 / 1800.0) * 1.02)
	assert_eq(controller.hybrid_position(Vector2(300, 150), cover, Vector2(900, 600)), Vector2.ZERO)
	assert_eq(controller.hybrid_position(Vector2(300, 150), Vector2.ONE, Vector2(900, 600)), Vector2(300, 150))


func test_party_zoom_tweens_zoom_and_hybrid_position() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.min_zoom = 0.5
	controller.max_zoom = 1.5
	controller.set_focus_mode(DungeonCameraController.FocusMode.PARTY)
	var final_zoom := controller.zoom_by(0.25, Vector2(300, 150), Vector2.ZERO, Vector2(900, 600))
	assert_eq(final_zoom, Vector2(1.25, 1.25))
	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout
	assert_eq(camera.zoom, final_zoom)
	assert_eq(camera.position, controller.hybrid_position(Vector2(300, 150), final_zoom, Vector2(900, 600)))


func test_scanner_zoom_reframes_immediately_and_tweens_only_zoom() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.max_zoom = 5.0
	camera.zoom = Vector2(4.0, 4.0)
	controller.set_focus_mode(DungeonCameraController.FocusMode.SCANNER)
	var scanner := Vector2(400, 300)
	var final_zoom := controller.zoom_by(1.0, Vector2(-300, -150), scanner, Vector2(900, 600))
	var expected_position := controller.clamp_position(
		controller.desired_scanner_position(scanner, Vector2.ZERO, Vector2(900, 600), final_zoom),
		final_zoom,
		Vector2(900, 600),
	)
	assert_eq(camera.position, expected_position)
	controller.follow_scanner(Vector2(450, 300), 0.5, Vector2(900, 600))
	var followed_position := camera.position
	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout
	assert_eq(camera.zoom, final_zoom)
	assert_eq(camera.position, followed_position)


func test_new_motion_cancels_previous_camera_owned_tween() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	controller.zoom_by(0.25, Vector2(300, 150), Vector2.ZERO, Vector2(900, 600))
	assert_true(controller.has_active_motion())
	controller.cancel_motion()
	assert_false(controller.has_active_motion())
```

- [ ] **Step 2: Run focused tests and verify the party/zoom API is missing**

Run the camera-controller command from Task 1.

Expected: FAIL because `cover_zoom`, `hybrid_position`, `zoom_by`, or motion methods are missing.

- [ ] **Step 3: Implement party calculations and centralized camera motion**

Add these constants, tuning fields, and methods to `DungeonCameraController`:

```gdscript
const ZOOM_TWEEN_DURATION := 0.3

var min_zoom := 0.5
var max_zoom := 1.5
var smooth_speed := 0.3
var _motion_tween: Tween


func cover_zoom(viewport_size: Vector2) -> Vector2:
	var background_size := _background.texture.get_size() * _background.scale
	var zoom_value := maxf(
		viewport_size.x / background_size.x,
		viewport_size.y / background_size.y,
	)
	return Vector2.ONE * zoom_value * 1.02


func hybrid_position(
	party_position: Vector2,
	at_zoom: Vector2,
	viewport_size: Vector2,
) -> Vector2:
	var limit_zoom := cover_zoom(viewport_size).x
	var influence := clampf(remap(at_zoom.x, limit_zoom, 1.0, 0.0, 1.0), 0.0, 1.0)
	return Vector2.ZERO.lerp(party_position, influence)


func move_to_party(
	party_position: Vector2,
	force_center: bool,
	viewport_size: Vector2,
) -> void:
	cancel_motion()
	set_focus_mode(FocusMode.PARTY)
	var target := hybrid_position(party_position, _camera.zoom, viewport_size)
	if force_center:
		_camera.position = target
		return
	_motion_tween = create_tween()
	_motion_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(_camera, "position", target, smooth_speed)


func zoom_by(
	step: float,
	party_position: Vector2,
	scanner_position: Vector2,
	viewport_size: Vector2,
) -> Vector2:
	cancel_motion()
	var minimum_allowed := maxf(min_zoom, cover_zoom(viewport_size).x)
	var next_value := clampf(_camera.zoom.x + step, minimum_allowed, max_zoom)
	var final_zoom := Vector2.ONE * next_value
	if focus_mode == FocusMode.SCANNER:
		_camera.position = clamp_position(
			desired_scanner_position(scanner_position, _camera.position, viewport_size, final_zoom),
			final_zoom,
			viewport_size,
		)
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(_camera, "zoom", final_zoom, ZOOM_TWEEN_DURATION)
	if focus_mode == FocusMode.PARTY:
		_motion_tween.tween_property(
			_camera,
			"position",
			hybrid_position(party_position, final_zoom, viewport_size),
			ZOOM_TWEEN_DURATION,
		)
	return final_zoom


func cancel_motion() -> void:
	if _motion_tween and _motion_tween.is_running():
		_motion_tween.kill()
	_motion_tween = null


func has_active_motion() -> bool:
	return _motion_tween != null and _motion_tween.is_running()
```

- [ ] **Step 4: Run the focused controller tests and verify they pass**

Run the camera-controller command from Task 1.

Expected: all camera-controller tests pass, including asynchronous tween ownership tests.

- [ ] **Step 5: Commit party and tween policy**

```bash
git add src/map/dungeon_camera_controller.gd test/unit/test_dungeon_camera_controller.gd
git commit -m "refactor: centralize dungeon camera motion"
```

### Task 4: Wire `DungeonMap` Through the Camera Controller

**Files:**
- Modify: `src/map/dungeon_map.gd`
- Modify: `test/integration/test_dungeon_restore.gd`

**Interfaces:**
- Consumes: every `DungeonCameraController` interface produced by Tasks 1-3.
- Produces: behavior-compatible `DungeonMap.process_controller_camera(...)`, `recenter_camera()`, `_get_clamped_camera_pos(...)`, `_approach_scan_camera(...)`, `_zoom_camera(...)`, `_move_camera_to_player(...)`, `_calculate_hybrid_position(...)`, and `_get_cover_zoom_level()` delegates.

- [ ] **Step 1: Update integration expectations to use the controller seam**

In `test/integration/test_dungeon_restore.gd`, replace scan-camera expectations of this form:

```gdscript
dungeon_map.scan_controller.desired_camera_position(
	camera_position,
	dungeon_map.get_viewport_rect().size,
	zoom,
)
```

with:

```gdscript
dungeon_map.camera_controller.desired_scanner_position(
	dungeon_map.scan_controller.position,
	camera_position,
	dungeon_map.get_viewport_rect().size,
	zoom,
)
```

Add this ownership assertion to `test_scan_starts_at_current_node_with_free_cursor_and_snapped_reticle()`:

```gdscript
assert_eq(
	dungeon_map.camera_controller.focus_mode,
	DungeonCameraController.FocusMode.SCANNER,
)
```

Add this assertion immediately after the existing `dungeon_map.cancel_preview()` call in `test_map_registers_global_adapter_preserves_preview_without_world_cursor_and_publishes_state_hints()`:

```gdscript
assert_eq(
	dungeon_map.camera_controller.focus_mode,
	DungeonCameraController.FocusMode.PARTY,
)
```

Keep the existing integration assertions for exponential follow, clamping, scan zoom without party pull, scanner position ownership during zoom, pan/recenter, traversal follow, and scan-region retention.

- [ ] **Step 2: Run dungeon integration tests and verify they fail before wiring**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: FAIL because `DungeonMap.camera_controller` is not configured and the removed scan-controller method is no longer available.

- [ ] **Step 3: Create and configure the runtime controller in `DungeonMap`**

Beside `scan_controller`, add:

```gdscript
var camera_controller := DungeonCameraController.new()
```

Remove the obsolete map-owned field:

```gdscript
var _zoom_tween: Tween
```

Replace `_setup_camera()` with:

```gdscript
func _setup_camera() -> void:
	camera.make_current()
	add_child(camera_controller)
	camera_controller.configure(camera, bg_sprite, parallax_bg)
	_sync_camera_tuning()


func _sync_camera_tuning() -> void:
	camera_controller.pan_speed = camera_pan_speed
	camera_controller.min_zoom = min_zoom
	camera_controller.max_zoom = max_zoom
	camera_controller.smooth_speed = camera_smooth_speed
	camera_controller.scanner_dead_zone_ratio = Vector2.ONE * scan_dead_zone_ratio
	camera_controller.scanner_follow_response = scan_camera_follow_response
```

Call `_sync_camera_tuning()` at the start of each map delegate whose exported tuning tests may change after `_ready()`.

At the start of `_exit_tree()`, cancel camera-owned motion before the controller child is released:

```gdscript
camera_controller.cancel_motion()
```

- [ ] **Step 4: Replace direct pan, recenter, clamp, and gesture calculations with delegates**

Use:

```gdscript
func process_controller_camera(direction: Vector2, delta: float) -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED or direction.is_zero_approx():
		return
	_sync_camera_tuning()
	camera_controller.pan(direction, delta, get_viewport_rect().size)


func recenter_camera() -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED or current_node == null:
		return
	_sync_camera_tuning()
	camera_controller.recenter(current_node.position, get_viewport_rect().size)


func _get_clamped_camera_pos(target_pos: Vector2, zoom_level: Vector2) -> Vector2:
	return camera_controller.clamp_position(target_pos, zoom_level, get_viewport_rect().size)
```

For `InputEventPanGesture`, preserve the existing `event.delta * 20.0 * camera.zoom.x` calculation, then pass the resulting candidate through `_get_clamped_camera_pos(...)`. Do not route trackpad gesture velocity through `pan_speed`, because that would alter current behavior.

- [ ] **Step 5: Route scanner focus and following through the controller**

At scan entry, replace the deleted `scan_controller.dead_zone_ratio` assignment and set explicit focus:

```gdscript
_sync_camera_tuning()
camera_controller.set_focus_mode(DungeonCameraController.FocusMode.SCANNER)
scan_controller.begin(origin, DungeonScanController.bounds_for_nodes(_map_nodes()))
```

At both `_cancel_targeting()` and `_finish_scan_target(...)`, after stopping the scan controller, set:

```gdscript
camera_controller.set_focus_mode(DungeonCameraController.FocusMode.PARTY)
```

Replace `_approach_scan_camera(...)` with:

```gdscript
func _approach_scan_camera(delta: float) -> void:
	_sync_camera_tuning()
	camera_controller.follow_scanner(
		scan_controller.position,
		delta,
		get_viewport_rect().size,
	)
```

Do not automatically recenter when leaving scan mode; the current camera must remain at the scanned region until ordinary movement, explicit recenter, or another camera command changes it.

- [ ] **Step 6: Route zoom and party follow through the controller while keeping compatibility delegates**

Replace the map-owned implementations with:

```gdscript
func _zoom_camera(step: float) -> void:
	if not camera:
		return
	_sync_camera_tuning()
	var party_position := current_node.position if current_node else Vector2.ZERO
	camera_controller.zoom_by(
		step,
		party_position,
		scan_controller.position,
		get_viewport_rect().size,
	)


func _move_camera_to_player(force_center: bool) -> void:
	_sync_camera_tuning()
	var party_position := current_node.position if current_node else Vector2.ZERO
	camera_controller.move_to_party(
		party_position,
		force_center,
		get_viewport_rect().size,
	)


func _calculate_hybrid_position(at_zoom: Vector2) -> Vector2:
	if not current_node:
		return Vector2.ZERO
	return camera_controller.hybrid_position(
		current_node.position,
		at_zoom,
		get_viewport_rect().size,
	)


func _get_cover_zoom_level() -> Vector2:
	return camera_controller.cover_zoom(get_viewport_rect().size)
```

These wrappers remain during this refactor because current map callers and integration tests use them. The calculations themselves must exist only in `DungeonCameraController`.

- [ ] **Step 7: Run unit, scan, and dungeon integration tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_camera_controller -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: all three focused selections pass. Existing integration scenarios retain the same pan distances, zoom bounds, scanner framing, exponential follow, traversal target, scan retention, modal suppression, and locked-state behavior.

- [ ] **Step 8: Commit live map integration**

```bash
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd
git commit -m "refactor: delegate dungeon camera policy"
```

### Task 5: Battle Handoff, Documentation, and Full Verification

**Files:**
- Modify: `src/map/dungeon_map.gd`
- Modify: `test/integration/test_dungeon_restore.gd`
- Modify: `docs/refactor.md`

**Interfaces:**
- Consumes: Task 3 `cancel_motion()` and Task 4 configured controller/delegates.
- Produces: explicit cancellation before battle presentation takes camera ownership, restored party focus afterward, and an updated refactor record.

- [ ] **Step 1: Add failing battle-handoff integration coverage**

Add a test alongside existing battle visual coverage that starts a camera-owned tween, enters battle with zero duration, and verifies the camera controller relinquishes motion:

```gdscript
func test_battle_visuals_cancel_camera_motion_and_restore_party_focus() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map._zoom_camera(dungeon_map.zoom_step)
	assert_true(dungeon_map.camera_controller.has_active_motion())
	await dungeon_map.enter_battle_visuals(0.0)
	assert_false(dungeon_map.camera_controller.has_active_motion())
	dungeon_map.exit_battle_visuals(0.0)
	await get_tree().process_frame
	assert_eq(
		dungeon_map.camera_controller.focus_mode,
		DungeonCameraController.FocusMode.PARTY,
	)
```

- [ ] **Step 2: Run the dungeon integration selection and verify the new assertion fails**

Run the `dungeon_restore` command from Task 4.

Expected: FAIL because battle entry has not canceled controller-owned motion or restored explicit focus.

- [ ] **Step 3: Add explicit battle camera handoff**

At the start of `enter_battle_visuals(...)`, before saving or tweening camera state:

```gdscript
camera_controller.cancel_motion()
```

At the start of `exit_battle_visuals(...)`:

```gdscript
camera_controller.cancel_motion()
camera_controller.set_focus_mode(DungeonCameraController.FocusMode.PARTY)
```

Keep battle fade, camera presentation tween, parallax transition, shader blur, HUD, grid, and background ownership in `DungeonMap` exactly as they are.

- [ ] **Step 4: Run focused dungeon integration tests**

Run the `dungeon_restore` command from Task 4.

Expected: all dungeon restore/integration tests pass, including battle handoff.

- [ ] **Step 5: Update the refactor research record**

In `docs/refactor.md`, add a completed boundary before the remaining dungeon candidate:

```markdown
## Completed boundary: Dungeon camera policy

`DungeonCameraController` now owns dungeon camera clamping, manual pan and recenter, party and scanner follow calculations, bounded zoom, explicit focus mode, and camera-owned tween cancellation. `DungeonMap` retains input and modal gates, gameplay authority, battle/background presentation, and thin compatibility delegates. `DungeonScanController` now contains scanner movement and selection only.

The broader dungeon decomposition remains open. Traversal state, reveal/vision, and shared map geometry are the next evidence-backed candidates; they should not be combined without their own approved scope.
```

Edit the existing `Candidate: Decompose dungeon exploration orchestration` entry so its current location mentions both focused controllers and its proposed next boundaries no longer list general camera policy.

- [ ] **Step 6: Parse/import the project and run the complete suite**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: import exits 0 with no parser errors; the complete GUT suite exits 0 with every test and assertion passing. Record the exact totals in the handoff rather than copying historical totals into the plan.

- [ ] **Step 7: Review the final diff for scope and generated sidecars**

Run:

```bash
git diff --check
git status --short
git diff --stat
git diff -- src/map/dungeon_camera_controller.gd src/map/dungeon_scan_controller.gd src/map/dungeon_map.gd test/unit/test_dungeon_camera_controller.gd test/unit/test_dungeon_scan_controller.gd test/integration/test_dungeon_restore.gd docs/refactor.md
```

Expected: no whitespace errors; only the planned source, tests, documentation, and required `dungeon_camera_controller.gd.uid` sidecar are present. Confirm `camera_edge_margin` remains exported but unused and no numerical tuning changed.

- [ ] **Step 8: Perform the manual camera regression checklist**

In a local build, verify:

1. mouse/trackpad pan, wheel zoom, pinch zoom, and recenter feel unchanged;
2. controller manual pan and recenter feel unchanged;
3. ordinary movement follows the party with the same animation;
4. scan movement uses the same proportional dead zone and smooth reacquisition;
5. zooming during scan reframes the scanner without pulling toward the party;
6. confirming a scan leaves the camera at the scanned region;
7. entering and leaving combat does not fight a prior camera tween;
8. modal and locked states still suppress dungeon camera input.

Expected: no intentional visual or control-feel difference from the pre-refactor build.

- [ ] **Step 9: Commit battle handoff and completed documentation**

```bash
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd docs/refactor.md
git commit -m "docs: record dungeon camera boundary"
```

Do not close GitHub issue #3 until automated verification passes and the manual camera regression checklist is accepted.
