# Continuous Dungeon Controller Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Replace the dungeon map's one-shot stick gate with stable continuous controller aiming that returns to center on release and supports rapid confirmed movement while the stick remains held.

**Architecture:** DungeonNavigation remains the pure geometry boundary and gains a hysteresis-aware selector. DungeonMap reconciles its preview every frame from the active controller vector, current node, and map state; reticle tweens remain presentation-only and mouse hover keeps its independent path. Keyboard-and-mouse mode no longer drives dungeon node preview or confirmation.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6.1, Godot Input Map, PS5 DualSense manual verification.

## Global Constraints

- Run Godot 4.6.3 with vendored GUT 9.6.1 and HOME=/tmp/mars-godot-home.
- Left-stick angle chooses a node; magnitude determines only engaged versus neutral.
- The reticle always lands on a node and keeps the existing approximately 0.15-second movement animation.
- Releasing the stick clears confirmation, returns the reticle to the current node, briefly holds it there, and fades it.
- A held direction is reevaluated whenever current_node changes.
- Controller D-pad remains a digital fallback through the same actions.
- Mouse hover/click remain authoritative in keyboard-and-mouse mode; WASD and arrows do not preview or move between dungeon nodes.
- Preserve traversal, completed-node backtracking, revisit alert reduction, scanning, locking, camera, and save behavior.
- Do not add pathfinding, automatic travel, new artwork, proportional analog positioning, or a project-wide input refactor.
- Preserve unrelated user/editor changes and commit required Godot sidecars for task files.

## File Structure

- src/map/dungeon_navigation.gd — pure angle scoring and hysteresis.
- src/map/dungeon_map.gd — controller reconciliation, reticle lifecycle, confirmation, and mouse handoff.
- src/ui/navigation/navigation_ux_layer.gd — public read-only modal-presence query used to suppress map polling.
- test/unit/test_dungeon_navigation.gd — deterministic geometry tests.
- test/integration/test_dungeon_restore.gd — state, traversal, input-mode, scan, and reticle tests.
- test/integration/test_navigation_ux_layer.gd — modal-presence query regression.
- docs/testing/controller-manual-checklist.md — physical-controller feel checks.

---

### Task 1: Add Stable Analog Candidate Selection

**Files:**
- Modify: src/map/dungeon_navigation.gd
- Modify: test/unit/test_dungeon_navigation.gd

**Interfaces:**
- Consumes: DungeonNavigation.closest_by_angle(origin, direction, candidates).
- Produces: DungeonNavigation.closest_by_angle_stable(origin: Vector2, direction: Vector2, candidates: Array[MapNode], current: MapNode, switch_margin: float = 0.05) -> MapNode.

- [ ] **Step 1: Write failing hysteresis tests**

Append:

~~~gdscript
func test_stable_angle_selection_retains_current_candidate_near_boundary() -> void:
	var lower := _node(Vector2.RIGHT.rotated(deg_to_rad(-30.0)) * 100.0)
	var upper := _node(Vector2.RIGHT.rotated(deg_to_rad(30.0)) * 100.0)
	var near_boundary := Vector2.RIGHT.rotated(deg_to_rad(2.0))
	assert_same(
		DungeonNavigation.closest_by_angle_stable(
			Vector2.ZERO, near_boundary, [lower, upper], lower, 0.05
		),
		lower,
	)


func test_stable_angle_selection_switches_for_clear_intent() -> void:
	var lower := _node(Vector2.RIGHT.rotated(deg_to_rad(-30.0)) * 100.0)
	var upper := _node(Vector2.RIGHT.rotated(deg_to_rad(30.0)) * 100.0)
	var clear_upper := Vector2.RIGHT.rotated(deg_to_rad(15.0))
	assert_same(
		DungeonNavigation.closest_by_angle_stable(
			Vector2.ZERO, clear_upper, [lower, upper], lower, 0.05
		),
		upper,
	)


func test_stable_angle_selection_does_not_retain_invalid_current() -> void:
	var behind := _node(Vector2.LEFT * 100.0)
	var ahead := _node(Vector2.RIGHT * 100.0)
	assert_same(
		DungeonNavigation.closest_by_angle_stable(
			Vector2.ZERO, Vector2.RIGHT, [behind, ahead], behind, 0.05
		),
		ahead,
	)
	behind.navigation_eligible = false
	assert_same(
		DungeonNavigation.closest_by_angle_stable(
			Vector2.ZERO, Vector2.RIGHT, [behind, ahead], behind, 0.05
		),
		ahead,
	)
~~~

- [ ] **Step 2: Run the unit test and observe RED**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_navigation -gexit
~~~

Expected: the new tests fail because closest_by_angle_stable does not exist; existing closest_by_angle tests remain green.

- [ ] **Step 3: Implement the stable selector**

Add without changing closest_by_angle:

~~~gdscript
static func closest_by_angle_stable(
	origin: Vector2,
	direction: Vector2,
	candidates: Array[MapNode],
	current: MapNode,
	switch_margin: float = 0.05,
) -> MapNode:
	var best := closest_by_angle(origin, direction, candidates)
	if best == null or current == null or best == current or not current.navigation_eligible:
		return best
	var normalized_direction := direction.normalized()
	var current_offset := current.position - origin
	var best_offset := best.position - origin
	if current_offset.is_zero_approx() or best_offset.is_zero_approx():
		return best
	var current_alignment := current_offset.normalized().dot(normalized_direction)
	if current_alignment <= 0.0:
		return best
	var best_alignment := best_offset.normalized().dot(normalized_direction)
	if best_alignment < current_alignment + switch_margin:
		return current
	return best
~~~

- [ ] **Step 4: Run the unit test and observe GREEN**

Run the Step 2 command. Expected: every dungeon-navigation unit test passes.

- [ ] **Step 5: Commit the geometry boundary**

~~~bash
git diff --check
git add src/map/dungeon_navigation.gd test/unit/test_dungeon_navigation.gd
git commit -m "feat: stabilize dungeon stick direction selection"
~~~

---

### Task 2: Reconcile Held Stick State and Reticle Presentation

**Files:**
- Modify: src/map/dungeon_map.gd
- Modify: test/integration/test_dungeon_restore.gd

**Interfaces:**
- Consumes: DungeonNavigation.closest_by_angle_stable, InputManager.get_active_mode(), and existing _controller_candidates().
- Produces: _reconcile_controller_navigation(direction: Vector2), _clear_controller_navigation(return_to_current: bool), and _return_reticle_to_current().
- Keeps: confirm_preview(), _on_node_clicked(), and _move_player_to() as the validated movement path.

- [ ] **Step 1: Replace the obsolete neutral-retention test**

Replace test_controller_preview_retains_on_neutral_and_confirm_uses_validated_move:

~~~gdscript
func test_controller_neutral_clears_preview_and_returns_reticle_to_current_node() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_not_null(dungeon_map._controller_preview_node)
	dungeon_map._reconcile_controller_navigation(Vector2.ZERO)
	assert_null(dungeon_map._controller_preview_node)
	assert_true(dungeon_map.player_reticle.visible)
	await get_tree().create_timer(0.2).timeout
	assert_eq(dungeon_map.player_reticle.position, dungeon_map.current_node.position)
	await get_tree().create_timer(0.5).timeout
	assert_false(dungeon_map.player_reticle.visible)
~~~

- [ ] **Step 2: Add held-direction traversal tests**

~~~gdscript
func test_held_direction_is_reevaluated_after_completed_node_movement() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	for index in [2, 3]:
		nodes[index].set_state(MapNode.NodeState.COMPLETED)
		nodes[index].has_been_visited = true
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_same(dungeon_map._controller_preview_node, nodes[2])
	dungeon_map.confirm_preview()
	assert_same(dungeon_map.current_node, nodes[2])
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_same(dungeon_map._controller_preview_node, nodes[3])
	dungeon_map.confirm_preview()
	assert_same(dungeon_map.current_node, nodes[3])


func test_locked_interaction_reselects_after_unlock_without_stick_reset() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	dungeon_map.confirm_preview()
	assert_same(dungeon_map.current_node, nodes[2])
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	assert_null(dungeon_map._controller_preview_node)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_null(dungeon_map._controller_preview_node)
	dungeon_map.unlock_input()
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_same(dungeon_map._controller_preview_node, nodes[3])
~~~

In test_locked_state_suppresses_selection_camera_and_confirmation, replace:

~~~gdscript
	assert_same(dungeon_map._controller_preview_node, preview)
~~~

with:

~~~gdscript
	assert_null(dungeon_map._controller_preview_node)
~~~

Keep its assertions that current node, camera position, and zoom do not change.

In test_arrow_keys_drive_all_camera_directions_without_selecting_nodes, keyboard input now intentionally clears controller preview. Replace:

~~~gdscript
assert_same(dungeon_map._controller_preview_node, start_preview, "arrow does not change controller preview")
~~~

with:

~~~gdscript
assert_null(dungeon_map._controller_preview_node, "keyboard mode clears controller preview")
~~~

Remove the now-unused declaration of start_preview from that test.

In test_map_registers_global_adapter_preserves_preview_without_world_cursor_and_publishes_state_hints, replace the direct selection setup with a genuinely held controller action:

~~~gdscript
Input.action_press(&"nav_right")
dungeon_map._process(0.016)
var preview: MapNode = dungeon_map._controller_preview_node
assert_not_null(preview)
~~~

Keep nav_right pressed through the outsider-focus frame and its retained-preview assertion, then release it:

~~~gdscript
Input.action_release(&"nav_right")
~~~

For Task 2 only, replace the terminal-modal test's direct select_direction setup with:

~~~gdscript
Input.action_press(&"nav_right")
dungeon_map._process(0.016)
var preview: MapNode = dungeon_map._controller_preview_node
assert_not_null(preview)
~~~

After its existing preview-restoration assertions, release the action:

~~~gdscript
Input.action_release(&"nav_right")
~~~

Task 3 replaces those retained-preview assertions with explicit modal suppression.

- [ ] **Step 3: Run the integration test and observe RED**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
~~~

Expected: tests fail because continuous reconciliation and return-to-center do not exist.

- [ ] **Step 4: Replace the stale direction gate**

Replace _last_controller_direction with:

~~~gdscript
const CONTROLLER_CANDIDATE_SWITCH_MARGIN := 0.05
const RETICLE_CENTER_HOLD_SECONDS := 0.25

var _controller_preview_node: MapNode = null
var _controller_direction_engaged := false
~~~

Replace the navigation portion of _process while preserving camera pan:

~~~gdscript
func _process(delta: float) -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED:
		_clear_controller_navigation(true)
		return
	var direction := Input.get_vector(&"nav_left", &"nav_right", &"nav_up", &"nav_down")
	if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
		_reconcile_controller_navigation(direction)
	else:
		_clear_controller_navigation(
			InputManager.get_cursor_behavior() == InputManager.CursorBehavior.SNAPPED
		)
	var pan_direction := Input.get_vector(
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_up", &"camera_pan_down"
	)
	process_controller_camera(pan_direction, delta)
~~~

Add:

~~~gdscript
func select_direction(direction: Vector2) -> void:
	_reconcile_controller_navigation(direction)


func _reconcile_controller_navigation(direction: Vector2) -> void:
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED or current_node == null:
		_clear_controller_navigation(true)
		return
	if direction.is_zero_approx():
		_clear_controller_navigation(true)
		return
	_controller_direction_engaged = true
	var selected := DungeonNavigation.closest_by_angle_stable(
		current_node.position,
		direction,
		_controller_candidates(),
		_controller_preview_node,
		CONTROLLER_CANDIDATE_SWITCH_MARGIN,
	)
	if selected == _controller_preview_node:
		return
	_controller_preview_node = selected
	if selected == null:
		_return_reticle_to_current()
	else:
		if current_map_state == MapState.TARGETING:
			_start_reticle_scan_pulse()
		_animate_reticle_to(selected.position)
	_clear_navigation_cursor()
	_publish_controller_hints()


func _clear_controller_navigation(return_to_current: bool) -> void:
	var had_state := _controller_direction_engaged or _controller_preview_node != null
	_controller_direction_engaged = false
	_controller_preview_node = null
	if not had_state:
		return
	if return_to_current:
		_return_reticle_to_current()
	else:
		_hide_reticle()
	_clear_navigation_cursor()
	_publish_controller_hints()
~~~

The selected-equality guard prevents the tween restarting every frame. When current_node changes, the old preview becomes ineligible and the same held vector selects from the new origin.

- [ ] **Step 5: Add cancellable center/hold/fade presentation**

Add beside _animate_reticle_to:

~~~gdscript
func _return_reticle_to_current() -> void:
	if current_node == null:
		_hide_reticle()
		return
	if reticle_move_tween and reticle_move_tween.is_running():
		reticle_move_tween.kill()
	if reticle_color_tween and reticle_color_tween.is_running():
		reticle_color_tween.kill()
	player_reticle.visible = true
	player_reticle.modulate.a = 1.0
	reticle_move_tween = create_tween()
	reticle_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reticle_move_tween.tween_property(player_reticle, "position", current_node.position, 0.15)
	reticle_move_tween.tween_interval(RETICLE_CENTER_HOLD_SECONDS)
	reticle_move_tween.tween_property(player_reticle, "modulate:a", 0.0, 0.2)
	reticle_move_tween.finished.connect(func() -> void:
		player_reticle.visible = false
		player_reticle.modulate = Color.ORANGE
	)
~~~

Replace _hide_reticle with:

~~~gdscript
func _hide_reticle() -> void:
	if not player_reticle.visible:
		return
	if reticle_move_tween and reticle_move_tween.is_running():
		reticle_move_tween.kill()
	if reticle_color_tween and reticle_color_tween.is_running():
		reticle_color_tween.kill()
	reticle_move_tween = create_tween()
	reticle_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reticle_move_tween.tween_property(player_reticle, "modulate:a", 0.0, 0.2)
	reticle_move_tween.finished.connect(func() -> void:
		player_reticle.visible = false
		player_reticle.modulate = Color.ORANGE
	)
~~~

In _animate_reticle_to, immediately after canceling the old movement tween, set:

~~~gdscript
player_reticle.visible = true
player_reticle.modulate.a = 1.0
~~~

In _reset_reticle_visuals, add before hiding:

~~~gdscript
if reticle_move_tween and reticle_move_tween.is_running():
	reticle_move_tween.kill()
~~~

These exact changes let new stick input, mouse hover, and scan completion cancel an old fade callback.

- [ ] **Step 6: Run focused tests and commit**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
git diff --check
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd
git commit -m "fix: make dungeon stick navigation continuous"
~~~

Expected: focused suites pass with zero failures and only the two task files are committed.

---

### Task 3: Enforce Controller-Only Preview, Modal Suppression, and Mouse Handoff

**Files:**
- Modify: src/map/dungeon_map.gd
- Modify: src/ui/navigation/navigation_ux_layer.gd
- Modify: test/integration/test_dungeon_restore.gd
- Modify: test/integration/test_navigation_ux_layer.gd
- Modify: docs/testing/controller-manual-checklist.md

**Interfaces:**
- Consumes: Task 2 reconciliation and InputManager input mode/cursor behavior.
- Produces: NavigationUXLayer.has_open_modal() -> bool, controller-only map confirmation, clean mouse reticle ownership, scan neutral behavior, and physical checks.

- [ ] **Step 1: Add keyboard exclusion and mouse takeover tests**

~~~gdscript
func test_keyboard_mode_does_not_preview_or_confirm_dungeon_nodes() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var start := dungeon_map.current_node
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_cursor_behavior(InputManager.CursorBehavior.SNAPPED)
	Input.action_press(&"nav_right")
	dungeon_map._process(0.016)
	Input.action_release(&"nav_right")
	assert_null(dungeon_map._controller_preview_node)
	dungeon_map._unhandled_input(_action_event(&"confirm"))
	assert_same(dungeon_map.current_node, start)


func test_mouse_hover_takes_reticle_ownership_after_controller_preview() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_not_null(dungeon_map._controller_preview_node)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_cursor_behavior(InputManager.CursorBehavior.FREE)
	dungeon_map._on_node_hovered(nodes[0])
	dungeon_map._process(0.016)
	assert_null(dungeon_map._controller_preview_node)
	assert_eq(dungeon_map.player_reticle.position, nodes[0].position)
~~~

In test_map_cursor_shows_for_free_mouse_then_hides_for_keyboard_navigation, replace its final retained-preview assertion with:

~~~gdscript
dungeon_map._process(0.016)
assert_null(dungeon_map._controller_preview_node)
~~~

- [ ] **Step 2: Extend controller confirm and scan tests**

Add:

~~~gdscript
func test_controller_confirm_event_moves_to_previewed_node() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	var preview := dungeon_map._controller_preview_node
	assert_not_null(preview)
	dungeon_map._unhandled_input(_action_event(&"confirm"))
	assert_same(dungeon_map.current_node, preview)


func test_keyboard_confirm_event_cannot_consume_controller_preview() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	var preview := dungeon_map._controller_preview_node
	var start := dungeon_map.current_node
	assert_not_null(preview)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	dungeon_map._unhandled_input(_action_event(&"confirm"))
	assert_same(dungeon_map.current_node, start)
	assert_same(dungeon_map._controller_preview_node, preview)
~~~

In both existing scan tests, set controller mode and add:

~~~gdscript
InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
assert_not_null(dungeon_map._controller_preview_node)
dungeon_map._reconcile_controller_navigation(Vector2.ZERO)
assert_null(dungeon_map._controller_preview_node)
assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.TARGETING)
~~~

Reselect before the existing confirm/cancel assertions. Neutral must clear the pending target without consuming or exiting the scan.

Add this Input Map regression for the D-pad fallback:

~~~gdscript
func test_dungeon_navigation_actions_keep_controller_dpad_fallback() -> void:
	var expected := {
		&"nav_up": JOY_BUTTON_DPAD_UP,
		&"nav_down": JOY_BUTTON_DPAD_DOWN,
		&"nav_left": JOY_BUTTON_DPAD_LEFT,
		&"nav_right": JOY_BUTTON_DPAD_RIGHT,
	}
	for action: StringName in expected:
		var found := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == expected[action]:
				found = true
				break
		assert_true(found, "%s keeps its controller D-pad event" % action)
~~~

In test/integration/test_navigation_ux_layer.gd, add:

~~~gdscript
func test_open_modal_query_tracks_stack_presence() -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var modal := Control.new()
	var button := Button.new()
	modal.add_child(button)
	add_child_autofree(modal)
	assert_false(ux.has_open_modal())
	ux.push_modal(modal, button)
	assert_true(ux.has_open_modal())
	ux.pop_modal(modal)
	assert_false(ux.has_open_modal())
~~~

Replace the old terminal-preview retention setup and assertions in test_terminal_modal_temporarily_owns_cursor_then_restores_live_map_adapter with:

~~~gdscript
InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
Input.action_press(&"nav_right")
dungeon_map._process(0.016)
assert_not_null(dungeon_map._controller_preview_node)
var terminal := TERMINAL_SCENE.instantiate()
add_child(terminal)
await get_tree().process_frame
dungeon_map._process(0.016)
assert_true(navigation.is_top_modal(terminal))
assert_null(dungeon_map._controller_preview_node)
dungeon_map._process(0.016)
assert_null(dungeon_map._controller_preview_node, "held input cannot navigate behind modal")
terminal.queue_free()
await get_tree().process_frame
dungeon_map._process(0.016)
assert_not_null(dungeon_map._controller_preview_node, "held input resumes after modal closes")
Input.action_release(&"nav_right")
~~~

Retain that test's focus, cursor, adapter, and hint restoration assertions, but remove assertions that the pre-modal preview object itself survives.

- [ ] **Step 3: Run dungeon_restore and observe RED**

Run:

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_ux_layer -gexit
~~~

Expected: keyboard confirm can still consume a directly established preview, mouse hover leaves controller preview state stale, and has_open_modal is missing.

- [ ] **Step 4: Gate confirm and transfer mouse ownership**

Add this public read-only query beside is_top_modal in NavigationUXLayer:

~~~gdscript
func has_open_modal() -> bool:
	_prune_state()
	return not _modal_stack.is_empty()
~~~

In DungeonMap._process, after the LOADING/LOCKED guard and before reading direction, suppress both node and camera polling while a modal owns input:

~~~gdscript
var navigation := _navigation_ux_layer()
if navigation and navigation.has_open_modal():
	_clear_controller_navigation(false)
	return
~~~

Replace the confirm branch in _unhandled_input:

~~~gdscript
if event.is_action_pressed(&"confirm"):
	if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
		confirm_preview()
		get_viewport().set_input_as_handled()
	return
~~~

At the start of _on_node_hovered add:

~~~gdscript
if InputManager.get_active_mode() == InputManager.InputMode.KEYBOARD_MOUSE:
	var had_preview := _controller_direction_engaged or _controller_preview_node != null
	_controller_direction_engaged = false
	_controller_preview_node = null
	if had_preview:
		_clear_navigation_cursor()
		_publish_controller_hints()
~~~

Leave mouse targeting and adjacent-node animation immediately after this block. Do not gate camera controls, mouse clicks, or existing ui_cancel/right-click scan cancellation.

- [ ] **Step 5: Update the controller checklist**

Replace the first three dungeon-map checks with:

~~~markdown
- [ ] Slowly rotate the left stick around the current node; the reticle snaps only to eligible adjacent revealed/completed nodes, changes once per clear directional choice, and does not flicker at boundaries.
- [ ] Release the stick; confirmation disables immediately, the reticle returns to the current node, briefly remains visible, and fades out.
- [ ] Hold a direction and tap confirm repeatedly across completed nodes; each move reevaluates from the new node without requiring stick recentering, while new interactions still lock input.
- [ ] Use the controller D-pad as a digital fallback and verify it selects the same eligible destinations.
- [ ] Switch to keyboard-and-mouse mode; WASD/arrows do not preview or move between nodes, while mouse hover/click immediately owns the reticle and traversal.
- [ ] Enter scan targeting, rotate among non-hidden targets, release to clear the pending target without consuming the scan, then confirm and cancel through their existing paths.
~~~

Keep camera, zoom, recenter, terminal, and modal checks unchanged.

- [ ] **Step 6: Run focused tests and commit**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_navigation -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect navigation_ux_layer -gexit
git diff --check
git add src/map/dungeon_map.gd src/ui/navigation/navigation_ux_layer.gd test/integration/test_dungeon_restore.gd test/integration/test_navigation_ux_layer.gd docs/testing/controller-manual-checklist.md
git commit -m "fix: separate controller and mouse dungeon navigation"
~~~

---

### Task 4: Full Verification and PS5 Feel Check

**Files:**
- Verify: src/map/dungeon_navigation.gd
- Verify: src/map/dungeon_map.gd
- Verify: test/unit/test_dungeon_navigation.gd
- Verify: test/integration/test_dungeon_restore.gd
- Verify/update results: docs/testing/controller-manual-checklist.md

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: a verified implementation ready for user acceptance.

- [ ] **Step 1: Import and run the full suite**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
~~~

Expected: import exits 0; every GUT test passes; there are no parser errors, crashes, or whitespace errors. Documented macOS certificate/shutdown diagnostics are acceptable only with successful exits.

- [ ] **Step 2: Audit repository scope**

~~~bash
git status --short
git log --oneline -4
~~~

Expected: only intentional task files or required task sidecars remain changed, and the three implementation commits follow the design/plan history.

- [ ] **Step 3: Perform the PS5 DualSense map checks**

Run the new unchecked dungeon-map checklist items on macOS with the connected PS5 controller:

1. slowly rotate across every adjacent-node boundary;
2. release at several angles and observe center/hold/fade;
3. rapidly tap Cross through at least three completed nodes;
4. enter a new interaction while holding, resolve it, and verify selection resumes;
5. switch controller → mouse → controller and verify no stale target returns;
6. verify D-pad fallback and scan targeting.

Record date, macOS version, connection type, tested commit, and pass/fail notes in the checklist. If feel tuning is needed, first adjust the deterministic boundary test, then change only CONTROLLER_CANDIDATE_SWITCH_MARGIN or RETICLE_CENTER_HOLD_SECONDS.

- [ ] **Step 4: Commit any checklist result or tested tuning**

When no tuning is needed:

~~~bash
git add docs/testing/controller-manual-checklist.md
git commit -m "test: record PS5 dungeon navigation pass"
~~~

When a tested constant changes:

~~~bash
git add src/map/dungeon_map.gd test/unit/test_dungeon_navigation.gd docs/testing/controller-manual-checklist.md
git commit -m "tune: refine dungeon controller navigation feel"
~~~

- [ ] **Step 5: Re-run final automation after physical testing**

~~~bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
~~~

Expected: import and full suite succeed and the physically tested commit has no whitespace errors.
