# Free Dungeon Scan Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore movement into adjacent unrevealed hexes, then replace angle-and-confirm scan targeting with a continuous world-space scanner, snapped hex target, hidden-hex eligibility, and proportional smart camera following.

**Architecture:** DungeonMap's shared traversal predicate once again treats every adjacent generated hex as reachable, preserving mouse/controller parity and zero-visibility exploration. A new DungeonScanController owns pure cursor geometry, nearest-hex selection, bounds, and dead-zone camera targets. DungeonMap owns semantic input, scene visuals, map state, reveal timing, and applying smoothed camera positions. Ordinary traversal keeps the reviewed continuous aim-and-confirm input model.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6.1, Camera2D, semantic Input Map actions, PS5 DualSense manual verification.

## Global Constraints

- Run every Godot command with HOME=/tmp/mars-godot-home.
- Scanner movement is 600 screen pixels per second, delta-scaled and divided by camera zoom.
- The proportional camera dead zone is the central 60 percent of the viewport on both axes.
- Camera follow uses an exponential response of 8.0 per second and does not create per-frame tweens.
- Scan confirmation locks scanner, traversal, and camera input for exactly 0.25 seconds while the existing 0.5-second reveal continues.
- Every generated hex is a valid scan center, including HIDDEN, REVEALED, COMPLETED, and the party's current hex.
- Every adjacent generated hex is a valid traversal destination, including HIDDEN, REVEALED, and COMPLETED; current and non-adjacent hexes remain invalid.
- Moving into a hidden hex uses the normal first-visit alert cost, updates vision from the destination, and requests its interaction exactly as the pre-controller implementation did.
- A free scanner cursor moves continuously while the existing hex reticle snaps to the deterministic nearest hex.
- Semantic confirm/cancel/navigation actions remain controller-family independent; do not inspect physical button indices.
- Right-stick camera pan works only while left-stick scanner input is neutral.
- The camera remains at the scanned region after confirmation.
- Preserve traversal aim-and-confirm, backtracking discounts, alert formulas, scan radius/cost/content, saves, map generation, and general zoom/background behavior.
- Preserve unrelated work and commit required Godot .uid/.import sidecars for task files.

## File Structure

- Create src/map/dungeon_scan_controller.gd — pure scan cursor state, movement, bounds, nearest target, and dead-zone camera target.
- Create test/unit/test_dungeon_scan_controller.gd — deterministic unit coverage for the extracted controller.
- Modify src/map/dungeon_map.gd — scan lifecycle, semantic routing, visual synchronization, hidden targeting, camera smoothing, and reveal lockout.
- Modify src/map/dungeon_map.tscn — dedicated ScannerCursor visual using the existing cross_small.svg.
- Modify test/integration/test_dungeon_restore.gd — scan integration, state, camera, input-family, and regression coverage.
- Modify docs/superpowers/specs/2026-07-12-dungeon-backtracking-design.md — correct the superseded hidden-traversal assumption.
- Modify docs/superpowers/specs/2026-07-13-free-dungeon-scan-navigation-design.md — record hidden traversal as restored prerequisite behavior.
- Modify docs/testing/controller-manual-checklist.md — free scanner and smart-camera physical checks.
- Modify docs/refactor.md — record the new scan boundary and future DungeonMap decomposition.

---

### Task 1: Restore Traversal into Adjacent Hidden Hexes

**Files:**
- Modify: src/map/dungeon_map.gd
- Modify: test/integration/test_dungeon_restore.gd
- Modify: docs/superpowers/specs/2026-07-12-dungeon-backtracking-design.md
- Modify: docs/superpowers/specs/2026-07-13-free-dungeon-scan-navigation-design.md

**Interfaces:**
- Corrects: DungeonMap._is_normal_traversal_destination(node: MapNode) -> bool.
- Preserves: DungeonMap._is_controller_candidate delegation and _on_node_clicked mouse/controller parity.

- [ ] **Step 1: Replace the regression expectations and add a zero-visibility movement test**

In test/integration/test_dungeon_restore.gd, rename `test_controller_candidates_allow_adjacent_completed_and_filter_invalid_destinations` to `test_controller_candidates_allow_adjacent_hidden_revealed_and_completed_destinations`. Keep the completed-node assertion, then replace its hidden assertions with:

~~~gdscript
nodes[2].set_state(MapNode.NodeState.HIDDEN)
assert_true(dungeon_map._is_controller_candidate(nodes[2]))
assert_false(dungeon_map._is_controller_candidate(nodes[1]), "current node is not a destination")
assert_false(dungeon_map._is_controller_candidate(nodes[3]), "non-adjacent node is not a destination")
~~~

In `test_mouse_and_controller_normal_traversal_destinations_match`, change the hidden case to:

~~~gdscript
{state = MapNode.NodeState.HIDDEN, expected = true},
~~~

Add this regression test:

~~~gdscript
func test_zero_visibility_can_move_into_hidden_adjacent_hex_and_continue_exploring() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	var hidden: MapNode = nodes[2]
	hidden.set_state(MapNode.NodeState.HIDDEN)
	hidden.is_aware = false
	dungeon_map.vision_range = 0
	dungeon_map.current_alert = DungeonMap.ALERT_MED_THRESHOLD
	watch_signals(dungeon_map)

	assert_true(dungeon_map._is_controller_candidate(hidden))
	dungeon_map._on_node_clicked(hidden)

	assert_same(dungeon_map.current_node, hidden)
	assert_true(hidden.has_been_visited)
	assert_eq(hidden.state, MapNode.NodeState.REVEALED)
	assert_signal_emitted_with_parameters(dungeon_map, &"interaction_requested", [hidden])
~~~

- [ ] **Step 2: Run dungeon_restore and observe RED**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
~~~

Expected: hidden destination assertions fail and the current node does not advance.

- [ ] **Step 3: Restore the original adjacent-hex traversal rule**

Replace `_is_normal_traversal_destination` with:

~~~gdscript
func _is_normal_traversal_destination(node: MapNode) -> bool:
	if node == null or current_node == null or node == current_node or current_map_state != MapState.PLAYING:
		return false
	return _get_hex_distance(current_node.grid_coords, node.grid_coords) == 1
~~~

Do not add state filtering elsewhere. `_move_player_to` already applies the normal first-visit alert cost, calls `_update_vision()` from the destination, and emits `interaction_requested` for any non-completed destination.

- [ ] **Step 4: Correct the superseded design notes**

In the backtracking design, replace the claim that HIDDEN is invalid with a dated correction that adjacent HIDDEN, REVEALED, and COMPLETED nodes are valid, while current/non-adjacent nodes remain invalid. In the free-scan design, add hidden traversal restoration as a prerequisite distinct from hidden scan targeting.

- [ ] **Step 5: Verify and commit the softlock fix**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
git diff --check
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd docs/superpowers/specs/2026-07-12-dungeon-backtracking-design.md docs/superpowers/specs/2026-07-13-free-dungeon-scan-navigation-design.md
git commit -m "fix: restore hidden hex exploration"
~~~

Expected: focused integration tests pass; zero visibility no longer prevents entering an adjacent hidden hex.

---

### Task 2: Extract Pure Dungeon Scan Geometry

**Files:**
- Create: src/map/dungeon_scan_controller.gd
- Create: test/unit/test_dungeon_scan_controller.gd
- Add after import when present: src/map/dungeon_scan_controller.gd.uid
- Add after import when present: test/unit/test_dungeon_scan_controller.gd.uid

**Interfaces:**
- Produces: DungeonScanController.begin(origin: Vector2, bounds: Rect2) -> void.
- Produces: stop() -> void, set_position(value: Vector2) -> Vector2, move(direction: Vector2, delta: float, zoom: Vector2) -> Vector2.
- Produces: select_nearest(nodes: Array[MapNode]) -> MapNode.
- Produces: desired_camera_position(camera_position: Vector2, viewport_size: Vector2, zoom: Vector2) -> Vector2.
- Produces: static bounds_for_nodes(nodes: Array[MapNode]) -> Rect2.

- [ ] **Step 1: Write movement, bounds, and selection tests**

Create test/unit/test_dungeon_scan_controller.gd:

~~~gdscript
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


func test_move_is_delta_scaled_screen_speed_and_zoom_adjusted() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2.ZERO, Rect2(-1000, -1000, 2000, 2000))
	assert_eq(controller.move(Vector2.RIGHT, 0.5, Vector2(2, 2)), Vector2(150, 0))
	var before := controller.position
	controller.move(Vector2(1, 1), 0.5, Vector2.ONE)
	assert_almost_eq(controller.position.distance_to(before), 300.0, 0.001)


func test_position_clamps_to_generated_bounds() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2.ZERO, Rect2(-100, -50, 200, 100))
	assert_eq(controller.set_position(Vector2(500, -500)), Vector2(100, -50))
	controller.move(Vector2.LEFT, 10.0, Vector2.ONE)
	assert_eq(controller.position, Vector2(-100, -50))


func test_bounds_for_nodes_uses_all_generated_centers() -> void:
	var left := await _node(Vector2(-80, 20), Vector2i(0, 0))
	var right := await _node(Vector2(120, -40), Vector2i(1, 0))
	assert_eq(
		DungeonScanController.bounds_for_nodes([right, left]),
		Rect2(Vector2(-80, -40), Vector2(200, 60)),
	)


func test_nearest_selection_includes_hidden_and_breaks_ties_by_coordinates() -> void:
	var controller := DungeonScanController.new()
	var high := await _node(Vector2(10, 0), Vector2i(2, 0), MapNode.NodeState.REVEALED)
	var low_hidden := await _node(Vector2(-10, 0), Vector2i(1, 0), MapNode.NodeState.HIDDEN)
	controller.begin(Vector2.ZERO, DungeonScanController.bounds_for_nodes([high, low_hidden]))
	assert_same(controller.select_nearest([high, low_hidden]), low_hidden)
	assert_eq(low_hidden.state, MapNode.NodeState.HIDDEN)


func test_empty_selection_returns_null() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2.ZERO, Rect2(Vector2.ZERO, Vector2.ZERO))
	assert_null(controller.select_nearest([]))
~~~

- [ ] **Step 2: Write dead-zone camera target tests**

Append:

~~~gdscript
func test_camera_stays_still_inside_proportional_dead_zone() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2(250, 200), Rect2(-1000, -1000, 2000, 2000))
	assert_eq(
		controller.desired_camera_position(Vector2.ZERO, Vector2(1000, 800), Vector2.ONE),
		Vector2.ZERO,
	)


func test_camera_moves_minimum_distance_to_dead_zone_boundary() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2(400, -300), Rect2(-1000, -1000, 2000, 2000))
	assert_eq(
		controller.desired_camera_position(Vector2.ZERO, Vector2(1000, 800), Vector2.ONE),
		Vector2(100, -60),
	)


func test_camera_dead_zone_scales_with_zoom_and_viewport() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2(200, 0), Rect2(-1000, -1000, 2000, 2000))
	assert_eq(
		controller.desired_camera_position(Vector2.ZERO, Vector2(1000, 800), Vector2(2, 2)),
		Vector2(50, 0),
	)
	controller.set_position(Vector2(350, 0))
	assert_eq(
		controller.desired_camera_position(Vector2.ZERO, Vector2(2000, 800), Vector2.ONE),
		Vector2.ZERO,
	)
~~~

- [ ] **Step 3: Run the unit test and observe RED**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller -gexit
~~~

Expected: collection fails because DungeonScanController does not exist.

- [ ] **Step 4: Implement DungeonScanController**

Create src/map/dungeon_scan_controller.gd:

~~~gdscript
class_name DungeonScanController
extends RefCounted

const MIN_ZOOM := 0.001

var cursor_speed := 600.0
var dead_zone_ratio := Vector2(0.6, 0.6)
var active := false
var position := Vector2.ZERO
var selected_node: MapNode
var _bounds := Rect2()


func begin(origin: Vector2, bounds: Rect2) -> void:
	active = true
	_bounds = bounds
	set_position(origin)


func stop() -> void:
	active = false
	selected_node = null


func set_position(value: Vector2) -> Vector2:
	var end := _bounds.position + _bounds.size
	position = Vector2(
		clampf(value.x, _bounds.position.x, end.x),
		clampf(value.y, _bounds.position.y, end.y),
	)
	return position


func move(direction: Vector2, delta: float, zoom: Vector2) -> Vector2:
	if not active or direction.is_zero_approx() or delta <= 0.0:
		return position
	var limited := direction.limit_length(1.0)
	var safe_zoom := Vector2(
		maxf(absf(zoom.x), MIN_ZOOM),
		maxf(absf(zoom.y), MIN_ZOOM),
	)
	return set_position(position + limited * cursor_speed * delta / safe_zoom)


func select_nearest(nodes: Array[MapNode]) -> MapNode:
	var best: MapNode
	var best_distance := INF
	for node: MapNode in nodes:
		if node == null:
			continue
		var distance := position.distance_squared_to(node.position)
		if best == null or distance < best_distance or (
			is_equal_approx(distance, best_distance) and _coordinates_before(node, best)
		):
			best = node
			best_distance = distance
	selected_node = best
	return best


func desired_camera_position(
	camera_position: Vector2,
	viewport_size: Vector2,
	zoom: Vector2,
) -> Vector2:
	var safe_zoom := Vector2(
		maxf(absf(zoom.x), MIN_ZOOM),
		maxf(absf(zoom.y), MIN_ZOOM),
	)
	var half_dead_world := viewport_size * dead_zone_ratio * 0.5 / safe_zoom
	var offset := position - camera_position
	var target := camera_position
	if offset.x < -half_dead_world.x:
		target.x = position.x + half_dead_world.x
	elif offset.x > half_dead_world.x:
		target.x = position.x - half_dead_world.x
	if offset.y < -half_dead_world.y:
		target.y = position.y + half_dead_world.y
	elif offset.y > half_dead_world.y:
		target.y = position.y - half_dead_world.y
	return target


static func bounds_for_nodes(nodes: Array[MapNode]) -> Rect2:
	if nodes.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var minimum := nodes[0].position
	var maximum := nodes[0].position
	for node: MapNode in nodes:
		minimum = minimum.min(node.position)
		maximum = maximum.max(node.position)
	return Rect2(minimum, maximum - minimum)


static func _coordinates_before(a: MapNode, b: MapNode) -> bool:
	return a.grid_coords.x < b.grid_coords.x or (
		a.grid_coords.x == b.grid_coords.x and a.grid_coords.y < b.grid_coords.y
	)
~~~

- [ ] **Step 5: Run focused tests and commit**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller -gexit
git diff --check
git add src/map/dungeon_scan_controller.gd test/unit/test_dungeon_scan_controller.gd
test -f src/map/dungeon_scan_controller.gd.uid && git add src/map/dungeon_scan_controller.gd.uid
test -f test/unit/test_dungeon_scan_controller.gd.uid && git add test/unit/test_dungeon_scan_controller.gd.uid
git commit -m "feat: extract dungeon scan navigation geometry"
~~~

Expected: the new unit suite passes; stage only sidecars that actually exist.

---

### Task 3: Integrate Free Scanner Visuals and Hidden-Hex Targeting

**Files:**
- Modify: src/map/dungeon_map.gd
- Modify: src/map/dungeon_map.tscn
- Modify: test/integration/test_dungeon_restore.gd

**Interfaces:**
- Consumes: DungeonScanController from Task 2.
- Produces: DungeonMap._process_scan_navigation(direction: Vector2, pan_direction: Vector2, delta: float) -> void.
- Produces: _sync_scan_selection() -> void, _map_nodes() -> Array[MapNode], and _finish_scan_target(target_node: MapNode) -> void.
- Keeps: execute_camera_scan(center_node, radius), scan_performed, scan_canceled, and ordinary traversal methods.

- [ ] **Step 1: Write failing scan lifecycle and hidden-target tests**

Replace the old angle-based scan tests in test_dungeon_restore.gd with:

~~~gdscript
func test_scan_starts_at_current_node_with_free_cursor_and_snapped_reticle() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	assert_true(dungeon_map.scan_controller.active)
	assert_eq(dungeon_map.scan_controller.position, dungeon_map.current_node.position)
	assert_true(dungeon_map.scanner_cursor.visible)
	assert_same(dungeon_map._controller_preview_node, dungeon_map.current_node)
	assert_eq(dungeon_map.player_reticle.position, dungeon_map.current_node.position)


func test_scan_cursor_moves_continuously_without_confirming() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	var start := dungeon_map.scan_controller.position
	var current := dungeon_map.current_node
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.1)
	assert_gt(dungeon_map.scan_controller.position.x, start.x)
	assert_same(dungeon_map.current_node, current)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.TARGETING)


func test_controller_can_scan_hidden_hex_without_changing_party_or_alert() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	var hidden: MapNode = nodes[2]
	hidden.set_state(MapNode.NodeState.HIDDEN)
	var party_node := dungeon_map.current_node
	var alert := dungeon_map.current_alert
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_position(hidden.position)
	dungeon_map._sync_scan_selection()
	assert_same(dungeon_map._controller_preview_node, hidden)
	watch_signals(dungeon_map)
	dungeon_map._unhandled_input(_action_event(&"confirm"))
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	await get_tree().create_timer(0.3).timeout
	assert_signal_emitted(dungeon_map, &"scan_performed")
	assert_eq(hidden.state, MapNode.NodeState.REVEALED)
	assert_same(dungeon_map.current_node, party_node)
	assert_eq(dungeon_map.current_alert, alert)


func test_mouse_can_hover_and_click_hidden_scan_center() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var hidden: MapNode = setup.nodes[2]
	hidden.set_state(MapNode.NodeState.HIDDEN)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	dungeon_map.start_targeting_mode(1)
	dungeon_map._on_node_hovered(hidden)
	assert_same(dungeon_map._controller_preview_node, hidden)
	assert_eq(dungeon_map.player_reticle.position, hidden.position)
	dungeon_map._on_node_clicked(hidden)
	await get_tree().create_timer(0.3).timeout
	assert_eq(hidden.state, MapNode.NodeState.REVEALED)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
~~~

- [ ] **Step 2: Run dungeon_restore and observe RED**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
~~~

Expected: scanner_cursor, scan_controller, and free scan methods are missing; hidden clicks remain rejected.

- [ ] **Step 3: Add the scanner visual to the scene**

In dungeon_map.tscn, add an ext_resource for:

~~~text
res://assets/graphics/glyphs/cursors/outline/cross_small.svg
~~~

Increase load_steps by one and add under Player:

~~~text
[node name="ScannerCursor" type="Node2D" parent="Player"]
visible = false
z_index = 12

[node name="Sprite" type="Sprite2D" parent="Player/ScannerCursor"]
modulate = Color(0.117647, 0.564706, 1, 1)
scale = Vector2(0.6, 0.6)
texture = ExtResource("scanner_cursor")
~~~

Use the exact ext_resource ID scanner_cursor.

- [ ] **Step 4: Add scan fields and process routing**

In DungeonMap add:

~~~gdscript
const SCAN_REVEAL_LOCK_SECONDS := 0.25

@export_group("Scanner")
@export var scan_cursor_speed := 600.0
@export_range(0.1, 0.9, 0.05) var scan_dead_zone_ratio := 0.6
@export var scan_camera_follow_response := 8.0

@onready var scanner_cursor: Node2D = $Player/ScannerCursor

var scan_controller := DungeonScanController.new()
~~~

Replace _process with this routing while preserving its existing modal guard:

~~~gdscript
func _process(delta: float) -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED:
		_clear_controller_navigation(true)
		scanner_cursor.visible = false
		return
	var navigation := _navigation_ux_layer()
	if navigation and navigation.has_open_modal():
		_clear_controller_navigation(false)
		scanner_cursor.visible = false
		return
	var direction := Input.get_vector(&"nav_left", &"nav_right", &"nav_up", &"nav_down")
	var pan_direction := Input.get_vector(
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_up", &"camera_pan_down"
	)
	if current_map_state == MapState.TARGETING:
		_process_scan_navigation(direction, pan_direction, delta)
		return
	if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
		_reconcile_controller_navigation(direction)
	else:
		_clear_controller_navigation(
			InputManager.get_cursor_behavior() == InputManager.CursorBehavior.SNAPPED
		)
	process_controller_camera(pan_direction, delta)
~~~

Add:

~~~gdscript
func _map_nodes() -> Array[MapNode]:
	var nodes: Array[MapNode] = []
	for value in grid_nodes.values():
		nodes.append(value as MapNode)
	return nodes


func _sync_scan_selection() -> void:
	scanner_cursor.position = scan_controller.position
	var selected := scan_controller.select_nearest(_map_nodes())
	if selected == _controller_preview_node:
		return
	_controller_preview_node = selected
	if selected:
		_animate_reticle_to(selected.position, false)
	else:
		_hide_reticle()
	_clear_navigation_cursor()
	_publish_controller_hints()


func _process_scan_navigation(
	direction: Vector2,
	pan_direction: Vector2,
	delta: float,
) -> void:
	if not scan_controller.active:
		return
	var controller_mode := InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER
	scanner_cursor.visible = controller_mode
	if not controller_mode:
		process_controller_camera(pan_direction, delta)
		return
	if direction.is_zero_approx():
		process_controller_camera(pan_direction, delta)
		return
	scan_controller.move(direction, delta, camera.zoom)
	_sync_scan_selection()
~~~

Task 4 adds camera following to the final moving branch.

- [ ] **Step 5: Replace angle-based scan start, cancel, hover, and confirm**

Replace start_targeting_mode:

~~~gdscript
func start_targeting_mode(radius: int) -> void:
	_controller_direction_engaged = false
	_controller_preview_node = null
	current_map_state = MapState.TARGETING
	pending_scan_radius = radius
	scan_controller.cursor_speed = scan_cursor_speed
	scan_controller.dead_zone_ratio = Vector2.ONE * scan_dead_zone_ratio
	var origin := current_node.position if current_node else Vector2.ZERO
	scan_controller.begin(origin, DungeonScanController.bounds_for_nodes(_map_nodes()))
	scanner_cursor.visible = InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER
	_sync_scan_selection()
	_start_reticle_scan_pulse()
	_clear_navigation_cursor()
	_publish_controller_hints()
~~~

In _cancel_targeting, before resetting visuals:

~~~gdscript
scan_controller.stop()
scanner_cursor.visible = false
~~~

Replace the TARGETING branch of _on_node_hovered:

~~~gdscript
if current_map_state == MapState.TARGETING:
	scan_controller.set_position(hovered_node.position)
	scanner_cursor.visible = false
	_controller_preview_node = hovered_node
	_animate_reticle_to(hovered_node.position, false)
	_publish_controller_hints()
	return
~~~

Move the current-node early return below the targeting branch and replace that branch:

~~~gdscript
func _on_node_clicked(target_node: MapNode) -> void:
	if current_map_state == MapState.TARGETING:
		_finish_scan_target(target_node)
		return
	if target_node == current_node:
		return
	if not _is_normal_traversal_destination(target_node):
		return
	_move_player_to(target_node)
~~~

Add the asynchronous scan resolution:

~~~gdscript
func _finish_scan_target(target_node: MapNode) -> void:
	if current_map_state != MapState.TARGETING or target_node == null:
		return
	var radius := pending_scan_radius
	current_map_state = MapState.LOCKED
	pending_scan_radius = 0
	_controller_preview_node = null
	scan_controller.stop()
	scanner_cursor.visible = false
	_reset_reticle_visuals()
	_clear_navigation_cursor()
	_publish_controller_hints()
	execute_camera_scan(target_node, radius)
	await get_tree().create_timer(SCAN_REVEAL_LOCK_SECONDS).timeout
	if not is_inside_tree():
		return
	current_map_state = MapState.PLAYING
	scan_performed.emit()
	_publish_controller_hints()
~~~

Remove the TARGETING branch from _is_controller_candidate so traversal candidates remain governed only by _is_normal_traversal_destination.

- [ ] **Step 6: Run focused suites and commit**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
git diff --check
git add src/map/dungeon_map.gd src/map/dungeon_map.tscn test/integration/test_dungeon_restore.gd
git commit -m "feat: add free dungeon scan targeting"
~~~

Expected: hidden scans succeed through controller and mouse, free cursor moves without confirm, ordinary traversal tests remain green.

---

### Task 4: Add Smart Camera Following, Input Arbitration, and Refactor Record

**Files:**
- Modify: src/map/dungeon_map.gd
- Modify: test/integration/test_dungeon_restore.gd
- Modify: docs/testing/controller-manual-checklist.md
- Modify: docs/refactor.md

**Interfaces:**
- Consumes: DungeonScanController.desired_camera_position from Task 2 and _process_scan_navigation from Task 3.
- Produces: DungeonMap._approach_scan_camera(delta: float) -> void.
- Keeps: process_controller_camera for neutral scanner input and ordinary map states.

- [ ] **Step 1: Add camera arbitration and reacquisition tests**

Append to test_dungeon_restore.gd:

~~~gdscript
func test_scan_neutral_allows_manual_pan_but_scanner_motion_suppresses_it() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(10, 10)
	dungeon_map.camera.position = dungeon_map._get_clamped_camera_pos(Vector2.ZERO, dungeon_map.camera.zoom)
	dungeon_map.start_targeting_mode(1)
	var before_pan := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.RIGHT, 0.1)
	assert_gt(dungeon_map.camera.position.x, before_pan.x)
	var after_pan := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.LEFT, Vector2.RIGHT, 0.001)
	assert_le(dungeon_map.camera.position.x, after_pan.x, "right-stick pan cannot fight scanner follow")


func test_scanner_keeps_moving_while_camera_reacquires_after_manual_pan() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.scan_dead_zone_ratio = 0.1
	dungeon_map.start_targeting_mode(1)
	dungeon_map.camera.position = dungeon_map._get_clamped_camera_pos(
		dungeon_map.camera.position + Vector2(200, 0),
		dungeon_map.camera.zoom,
	)
	var cursor_before := dungeon_map.scan_controller.position
	var desired := dungeon_map.scan_controller.desired_camera_position(
		dungeon_map.camera.position,
		dungeon_map.get_viewport_rect().size,
		dungeon_map.camera.zoom,
	)
	var distance_before := dungeon_map.camera.position.distance_to(desired)
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.016)
	assert_gt(dungeon_map.scan_controller.position.x, cursor_before.x)
	assert_lt(dungeon_map.camera.position.distance_to(desired), distance_before)
~~~

- [ ] **Step 2: Add reveal lockout, camera retention, and modal tests**

Append:

~~~gdscript
func test_scan_confirmation_briefly_locks_input_and_keeps_camera_at_scan_region() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var target: MapNode = setup.nodes[2]
	target.set_state(MapNode.NodeState.HIDDEN)
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_position(target.position)
	dungeon_map._sync_scan_selection()
	var camera_at_scan := dungeon_map.camera.position
	dungeon_map.confirm_preview()
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	dungeon_map.process_controller_camera(Vector2.RIGHT, 1.0)
	assert_eq(dungeon_map.camera.position, camera_at_scan)
	await get_tree().create_timer(0.15).timeout
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	await get_tree().create_timer(0.15).timeout
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	assert_eq(dungeon_map.camera.position, camera_at_scan)


func test_modal_hides_and_suppresses_active_scan_cursor() -> void:
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.start_targeting_mode(1)
	var position := dungeon_map.scan_controller.position
	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	dungeon_map._process(0.1)
	assert_true(navigation.has_open_modal())
	assert_false(dungeon_map.scanner_cursor.visible)
	assert_eq(dungeon_map.scan_controller.position, position)
	terminal.queue_free()
	await get_tree().process_frame
~~~

- [ ] **Step 3: Run dungeon_restore and observe RED**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
~~~

Expected: scanner movement does not yet move/reacquire the camera and arbitration assertions fail.

- [ ] **Step 4: Implement smooth dead-zone camera approach**

Add:

~~~gdscript
func _approach_scan_camera(delta: float) -> void:
	var desired := scan_controller.desired_camera_position(
		camera.position,
		get_viewport_rect().size,
		camera.zoom,
	)
	var weight := 1.0 - exp(-scan_camera_follow_response * maxf(delta, 0.0))
	camera.position = _get_clamped_camera_pos(
		camera.position.lerp(desired, weight),
		camera.zoom,
	)
~~~

At the end of _process_scan_navigation's moving branch, after _sync_scan_selection:

~~~gdscript
_approach_scan_camera(delta)
~~~

Do not call process_controller_camera in that branch. Its existing call remains only in the neutral branch.

- [ ] **Step 5: Update manual checks and refactor research**

Replace the scan-targeting dungeon checklist item with:

~~~markdown
- [ ] Enter scan targeting with a controller; the free scanner cursor starts at the party while the hex reticle independently marks the nearest scan center.
- [ ] Hold and rotate the left stick through cardinal and diagonal directions; cursor speed is smooth, continuous, zoom-consistent, and requires no confirm presses.
- [ ] Scan a distant hidden hex; confirm uses the displayed family glyph, reveals around that hidden center, briefly locks input, and leaves the camera at the scanned region.
- [ ] Keep the scanner inside the central camera box, then cross each boundary; the camera stays still inside and smoothly follows outside without cutting off scanner input.
- [ ] Manually pan with the right stick while the scanner is neutral; resume left-stick motion and verify the camera smoothly reacquires while right-stick pan cannot fight it.
- [ ] Hover/click hidden scan centers with the mouse, switch back to controller, and verify the free cursor resumes from the last hovered hex without a jump.
- [ ] Verify semantic confirm/cancel and D-pad fallback on the connected controller family.
~~~

Add this candidate to docs/refactor.md:

~~~markdown
## Candidate: Decompose dungeon exploration orchestration

**Current location:** src/map/dungeon_map.gd, with scan geometry extracted to src/map/dungeon_scan_controller.gd

**Observed while:** Restoring free scan movement and proportional smart-camera following

**Problem:** DungeonMap still owns generation, traversal, scan lifecycle, camera/zoom policy, reveal animation, interactions, HUD updates, alert rules, and save restoration in one large script.

**Proposed boundary:** Continue extracting independently tested exploration components after DungeonScanController: general camera policy, traversal state, reveal/vision, and map generation/geometry. DungeonMap should orchestrate those components and scene presentation rather than implement every rule.

**Why defer:** Free scanning needs only the scan-specific seam; reorganizing unrelated stable systems would mix refactoring with behavior repair.

**Tests protecting behavior:** test_dungeon_scan_controller.gd protects scan geometry; test_dungeon_navigation.gd protects traversal direction; test_dungeon_restore.gd protects live map state, camera, scan, backtracking, and restoration.

**Likely files affected:** src/map/dungeon_map.gd, future focused helpers under src/map/, dungeon unit/integration tests, and map scene wiring.

**Risks/open questions:** Preserve asynchronous interaction ownership, camera clamping across zoom/background modes, exact save geometry, modal precedence, and authoritative current-node state while extracting responsibilities.
~~~

- [ ] **Step 6: Run full verification and commit**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_scan_controller -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd docs/testing/controller-manual-checklist.md docs/refactor.md
git commit -m "feat: add smart dungeon scan camera"
~~~

Expected: import exits 0 and all focused and full tests pass.

---

### Task 5: Physical DualSense Acceptance and Final Automation

**Files:**
- Update results: docs/testing/controller-manual-checklist.md
- Modify tuning only if physical evidence requires it: src/map/dungeon_map.gd
- Modify deterministic expectations with tuning: test/unit/test_dungeon_scan_controller.gd or test/integration/test_dungeon_restore.gd

**Interfaces:**
- Consumes: completed Tasks 1–4.
- Produces: recorded physical acceptance and a final verified commit.

- [ ] **Step 1: Run the new scan checklist on PS5 DualSense**

Record date, macOS version, USB/Bluetooth connection, and tested commit. Verify free motion, diagonals, zoom consistency, hidden scans, semantic Cross/Circle glyphs, D-pad fallback, proportional camera boundaries, manual pan/reacquisition, mouse switching, brief lockout, and camera retention.

- [ ] **Step 2: Tune only named values if physical evidence requires it**

Allowed tuning values:

~~~gdscript
scan_cursor_speed
scan_dead_zone_ratio
scan_camera_follow_response
~~~

Do not change the 0.25-second lockout without explicit user approval. Add or update a deterministic test before committing changed tuning.

- [ ] **Step 3: Commit recorded physical results or tested tuning**

Checklist only:

~~~bash
git add docs/testing/controller-manual-checklist.md
git commit -m "test: record DualSense scan navigation pass"
~~~

With tuning:

~~~bash
git add src/map/dungeon_map.gd test/unit/test_dungeon_scan_controller.gd test/integration/test_dungeon_restore.gd docs/testing/controller-manual-checklist.md
git commit -m "tune: refine dungeon scan navigation feel"
~~~

- [ ] **Step 4: Re-run final automation**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
git status --short
~~~

Expected: import and full suite exit 0, no whitespace errors remain, and only explicitly deferred user work is uncommitted.
