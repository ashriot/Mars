# Dungeon Backtracking Restoration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore adjacent completed-node backtracking for mouse and controller while preserving reduced revisit alert cost and preventing interaction replay.

**Architecture:** `DungeonMap` gains one normal-traversal eligibility predicate shared by controller candidate generation and mouse click validation. The existing `_move_player_to()` revisit calculation and completed-node interaction suppression remain unchanged, with integration tests pinning their behavior.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

## Global Constraints

- Normal traversal permits adjacent `REVEALED` and `COMPLETED` nodes and rejects `HIDDEN` nodes.
- Mouse and keyboard/controller movement use the same eligibility rule.
- The current node and nodes beyond hex distance 1 remain invalid.
- Revisiting an already visited node adds exactly half the normal movement alert cost.
- Completed nodes do not emit `interaction_requested` again.
- Scanning/targeting eligibility remains unchanged.
- Do not add pathfinding or multi-node automatic movement.
- Preserve unrelated local changes to `project.godot` and `data/heroes/asher/actions/aimed_shot.tres`; never stage them.

---

### Task 1: Restore Shared Completed-Node Traversal

**Files:**
- Modify: `src/map/dungeon_map.gd`
- Modify: `test/integration/test_dungeon_restore.gd`

**Interfaces:**
- Produces: `DungeonMap._is_normal_traversal_destination(node: MapNode) -> bool`.
- Keeps: `_is_controller_candidate`, `_on_node_clicked`, `_move_player_to`, and all movement signals.

- [ ] **Step 1: Replace the incorrect completed-node filter regression**

Rename `test_controller_candidates_filter_hidden_completed_unreachable_and_cancel_clears` to describe the restored rule. With the adjacent right-hand node completed:

```gdscript
nodes[2].set_state(MapNode.NodeState.COMPLETED)
nodes[2].has_been_visited = true
dungeon_map.select_direction(Vector2.RIGHT)
assert_same(dungeon_map._controller_preview_node, nodes[2])
dungeon_map.cancel_preview()
assert_null(dungeon_map._controller_preview_node)
```

Keep independent assertions that a hidden adjacent node, the current node, and a non-adjacent revealed node are excluded.

- [ ] **Step 2: Add mouse/controller parity tests**

For each `REVEALED`, `COMPLETED`, and `HIDDEN` adjacent state, compare the controller predicate and click outcome. Use a movement spy or await-free bounded map fixture so the test observes whether `_move_player_to()` receives the target without relying on animation completion.

```gdscript
assert_eq(
	dungeon_map._is_controller_candidate(target),
	dungeon_map._is_normal_traversal_destination(target),
)
```

Assert revealed/completed are true and hidden is false in `PLAYING`; targeting-mode candidate behavior remains separately covered by the existing scan tests.

- [ ] **Step 3: Add revisit alert and interaction regressions**

Prepare an adjacent completed node with `has_been_visited = true`, set `current_alert` to a known baseline, and observe `interaction_requested`:

```gdscript
var baseline := dungeon_map.current_alert
watch_signals(dungeon_map)
dungeon_map._on_node_clicked(completed)
await get_tree().process_frame
assert_almost_eq(dungeon_map.current_alert, baseline + dungeon_map.current_move_cost / 2.0, 0.001)
assert_signal_not_emitted(dungeon_map, "interaction_requested")
```

Add a revealed unvisited control case that adds the full movement cost and emits `interaction_requested` once. Stub/disable cursor and camera animation as the existing fixture pattern requires; do not change production timing to accommodate tests.

- [ ] **Step 4: Run the focused test and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
```

Expected: completed controller preview is null, completed click is rejected, and the shared predicate is missing.

- [ ] **Step 5: Implement one shared normal-traversal predicate**

Add:

```gdscript
func _is_normal_traversal_destination(node: MapNode) -> bool:
	if node == null or current_node == null or node == current_node or current_map_state != MapState.PLAYING:
		return false
	if node.state != MapNode.NodeState.REVEALED and node.state != MapNode.NodeState.COMPLETED:
		return false
	return _get_hex_distance(current_node.grid_coords, node.grid_coords) == 1
```

Use it from `_is_controller_candidate()` only when not targeting:

```gdscript
if current_map_state == MapState.TARGETING:
	return node != null and node != current_node and node.state != MapNode.NodeState.HIDDEN
return _is_normal_traversal_destination(node)
```

Use the same predicate in `_on_node_clicked()` after the unchanged targeting branch:

```gdscript
if not _is_normal_traversal_destination(target_node):
	return
_move_player_to(target_node)
```

Remove the duplicated revealed-state and distance checks. Do not modify `_move_player_to()`; its `has_been_visited` half-cost calculation and completed-state signal suppression are the desired behavior.

- [ ] **Step 6: Run focused/full verification and commit**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect dungeon_restore -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
git diff --check
git add src/map/dungeon_map.gd test/integration/test_dungeon_restore.gd
git commit -m "fix: restore dungeon backtracking"
```

Expected: editor import exits 0, full suite passes, and only the two task files are committed.
