# Dungeon Crawl Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make dungeon runs deterministic, recoverable, and safe across generation, node interactions, terminals, all run endings, and save/resume.

**Architecture:** Preserve the current `GameManager`/`DungeonMap`/`RunManager` ownership. Add only two pure, stateless seams (`DungeonRules` and `DungeonSaveCodec`) for deterministic testing, then centralize interaction completion and run-ending transitions inside `GameManager`. Record broader restructuring opportunities in `docs/refactor.md` without implementing them during stabilization.

**Tech Stack:** Godot project metadata 4.6, GDScript, official GUT `godot_4_7` snapshot `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605` (runtime 9.7.1), and the Godot 4.7 test binary. See `addons/gut/VENDORED.md` for the pinned source and current harness command.

---

## File map

**Create:**

- `addons/gut/` — vendored official GUT `godot_4_7` snapshot at `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`, runtime 9.7.1.
- `.gutconfig.json` — headless test discovery and exit settings.
- `docs/refactor.md` — evidence-backed backlog for the later refactor pass.
- `src/map/dungeon_rules.gd` — pure tier, node-count, progress-total, and medical-effect rules.
- `src/map/dungeon_save_codec.gd` — active-run/map shape validation and saved node-type extraction.
- `test/unit/test_dungeon_rules.gd` — generation, tier, and medical rule tests.
- `test/unit/test_dungeon_save_codec.gd` — save validation and node-type extraction tests.
- `test/unit/test_run_rewards.gd` — reward multiplier and idempotency tests.
- `test/integration/test_game_manager_interactions.gd` — node outcome and run-ending regression tests.
- `test/integration/test_dungeon_restore.gd` — authoritative map restoration tests.
- `docs/testing/dungeon-manual-checklist.md` — repeatable in-editor crawl verification.

**Modify:**

- `project.godot` — enable the GUT editor plugin only if its install requires the editor entry.
- `src/hub/hub.gd` — initialize new runs at tier 1.
- `src/map/dungeon_map.gd` — use pure count rules, authoritative saved types, correct restore order, and explicit completion totals.
- `src/battle/game_manager.gd` — validate payloads, centralize interaction outcomes, and guard run endings.
- `src/map/terminal.gd` — fix protocol numbering and make close/selection emission single-shot.
- `src/singletons/run_manager.gd` — validate active-run data, clamp tier, and guard reward commitment.
- `src/core/main.gd` — reject an invalid active run before entering the dungeon scene.
- `src/map/dungeon_end_screen.gd` — prevent duplicate confirmation.

Do not touch Event behavior or add a 100%-Alert consequence in this plan.

---

### Task 1: Install the test harness and create the refactor backlog

**Files:**

- Create: `addons/gut/`
- Create: `.gutconfig.json`
- Create: `test/unit/test_test_harness.gd`
- Create: `docs/refactor.md`
- Modify: `project.godot`

- [ ] **Step 1: Verify the pinned GUT snapshot**

The harness is already vendored. Do not replace it with a release-tag download. From the repository root, verify the recorded source and executable entry point:

```sh
rg -n "godot_4_7|aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605|Runtime version: GUT 9.7.1" addons/gut/VENDORED.md
test -f addons/gut/gut_cmdln.gd
```

Expected: all three pinned identifiers are present and `addons/gut/gut_cmdln.gd` exists. `addons/gut/VENDORED.md` is authoritative for retrieval and local-normalization details.

- [ ] **Step 2: Add deterministic CLI configuration**

Create `.gutconfig.json`:

```json
{
  "dirs": ["res://test/unit", "res://test/integration"],
  "double_strategy": "partial",
  "include_subdirs": true,
  "log_level": 1,
  "prefix": "test_",
  "should_exit": true,
  "suffix": ".gd"
}
```

If GUT does not add its plugin entry automatically, add this exact section to `project.godot`:

```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")
```

- [ ] **Step 3: Write the first test**

Create `test/unit/test_test_harness.gd`:

```gdscript
extends GutTest

func test_gut_runs_under_supported_godot_4() -> void:
	assert_eq(Engine.get_version_info().major, 4)
	assert_true(Engine.get_version_info().minor >= 6)
```

- [ ] **Step 4: Run the harness**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_test_harness.gd -gexit
```

Expected: `1 passed`, exit code 0.

- [ ] **Step 5: Create the deferred-refactor log**

Create `docs/refactor.md`:

```markdown
# Refactor Research Backlog

This file records architectural evidence discovered during stabilization. Items here are not part of the stabilization scope. Each candidate must cite tests that preserve its behavior before it is scheduled.

## Candidate: Extract procedural map generation

**Current location:** `src/map/dungeon_map.gd`, especially `_distribute_node_types()` and `generate_hex_grid()`
**Observed while:** Reviewing node-count and restore defects
**Problem:** Random layout generation, live scene creation, HUD progress, and serialized run state share one script.
**Proposed boundary:** A `DungeonGenerator` that accepts dimensions, profile multipliers, endpoint rules, and a seed, then returns plain map data.
**Why defer:** Pure count helpers are enough to stabilize current generation without moving scene construction.
**Tests protecting behavior:** Seed determinism, node-count invariants, payload/type correspondence.
**Likely files affected:** `src/map/dungeon_map.gd`, a future generator script, dungeon generation tests.
**Risks/open questions:** Decide whether generated map data should be a typed Resource or immutable dictionaries.

## Candidate: Separate run presentation from run lifecycle

**Current location:** `src/battle/game_manager.gd`, `src/map/dungeon_end_screen.gd`, `src/singletons/run_manager.gd`
**Observed while:** Reviewing duplicate cleanup and reward-commit paths
**Problem:** Screen lifecycle, map locking, outcome selection, and reward commitment are coordinated through callbacks across three scripts.
**Proposed boundary:** A non-autoload run lifecycle object with explicit `begin_end(result)` and `confirm_end()` transitions.
**Why defer:** A guarded `GameManager` transition fixes correctness with a smaller change.
**Tests protecting behavior:** One-shot Success, Retreat, Defeat, and reward commitment tests.
**Likely files affected:** The three current scripts plus a future lifecycle script.
**Risks/open questions:** Decide whether confirmation belongs to the controller or remains a screen signal.
```

- [ ] **Step 6: Commit the harness**

```bash
git add addons/gut .gutconfig.json project.godot test/unit/test_test_harness.gd docs/refactor.md
git commit -m "test: add Godot dungeon test harness"
```

---

### Task 2: Stabilize tier and node-count rules

**Files:**

- Create: `src/map/dungeon_rules.gd`
- Create: `test/unit/test_dungeon_rules.gd`
- Modify: `src/map/dungeon_map.gd:15-35,1064-1236`
- Modify: `src/hub/hub.gd:16-25`
- Modify: `src/singletons/run_manager.gd:8-12,63-70,95-126`
- Modify: `docs/refactor.md`

- [ ] **Step 1: Write failing rule tests**

Create `test/unit/test_dungeon_rules.gd`:

```gdscript
extends GutTest

const DungeonRulesScript = preload("res://src/map/dungeon_rules.gd")

func test_profile_multiplier_is_applied_once() -> void:
	assert_eq(DungeonRulesScript.calculate_count(300, 2.0, 1.5), 9)

func test_terminal_minimum_is_two_without_adding_an_extra_terminal() -> void:
	assert_eq(DungeonRulesScript.apply_minimum(0, 2), 2)
	assert_eq(DungeonRulesScript.apply_minimum(6, 2), 6)

func test_actionable_total_includes_boss_but_not_exit_or_entrance() -> void:
	var counts := {
		"terminal": 2,
		"combat": 4,
		"elite": 1,
		"reward_common": 2,
		"reward_uncommon": 1,
		"reward_rare": 0,
		"reward_epic": 0,
		"event": 0,
	}
	assert_eq(DungeonRulesScript.actionable_total(counts, false), 10)
	assert_eq(DungeonRulesScript.actionable_total(counts, true), 11)

func test_tier_and_loot_scalar_start_at_one() -> void:
	assert_eq(DungeonRulesScript.normalized_tier(0), 1)
	assert_eq(DungeonRulesScript.loot_scalar(1), 1.0)
	assert_eq(DungeonRulesScript.loot_scalar(3), 1.5)
```

- [ ] **Step 2: Run the rule test and confirm the missing-script failure**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_dungeon_rules.gd -gexit
```

Expected: FAIL because `res://src/map/dungeon_rules.gd` does not exist.

- [ ] **Step 3: Add the pure rule seam**

Create `src/map/dungeon_rules.gd`:

```gdscript
class_name DungeonRules
extends RefCounted

const MIN_DUNGEON_TIER := 1
const MIN_TERMINALS := 2

static func normalized_tier(tier: int) -> int:
	return max(MIN_DUNGEON_TIER, tier)

static func loot_scalar(tier: int) -> float:
	return 1.0 + float(normalized_tier(tier) - 1) * 0.25

static func calculate_count(map_size: int, density_percent: float, multiplier: float) -> int:
	return max(0, int(float(map_size) * density_percent / 100.0 * multiplier))

static func apply_minimum(value: int, minimum: int) -> int:
	return max(minimum, value)

static func actionable_total(counts: Dictionary, has_boss: bool) -> int:
	var total := 1 if has_boss else 0
	for value in counts.values():
		total += int(value)
	return total
```

- [ ] **Step 4: Make generation consume the pure rules once**

In `DungeonMap._calculate_node_count()`, replace the body with:

```gdscript
var density := float(NODE_DENSITY[node_type])
var multiplier := RunManager.dungeon_profile.get_node_multiplier(node_type)
return DungeonRules.calculate_count(map_size, density, multiplier)
```

Delete the second multiplier application in `_distribute_node_types()`. Build a single count dictionary:

```gdscript
var counts := {
	"terminal": DungeonRules.apply_minimum(_calculate_node_count("terminal"), DungeonRules.MIN_TERMINALS),
	"combat": _calculate_node_count("combat"),
	"elite": _calculate_node_count("elite"),
	"reward_common": _calculate_node_count("reward_common"),
	"reward_uncommon": _calculate_node_count("reward_uncommon"),
	"reward_rare": _calculate_node_count("reward_rare"),
	"reward_epic": _calculate_node_count("reward_epic"),
	"event": _calculate_node_count("event"),
}
total_nodes = DungeonRules.actionable_total(counts, dungeon_has_boss)
```

Use those dictionary values for all placement batches and loader progress. Delete `NODE_MULT`, `_get_count`, and the later `num_terminals = max(1, num_terminals) + 1` mutation.

- [ ] **Step 5: Normalize tier at every entry point**

Change `RunManager.current_dungeon_tier` default and Hub initialization to `1`. Replace `RunManager.get_loot_scalar()` with:

```gdscript
func get_loot_scalar() -> float:
	return DungeonRules.loot_scalar(current_dungeon_tier)
```

During restore, use:

```gdscript
current_dungeon_tier = DungeonRules.normalized_tier(int(run_data.get("tier", 1)))
```

- [ ] **Step 6: Run focused and full tests**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_dungeon_rules.gd -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
```

Expected: all tests pass.

- [ ] **Step 7: Record the count-rule seam and commit**

Add a `docs/refactor.md` note that count rules were extracted but full map generation remains deferred, citing `test_dungeon_rules.gd`.

```bash
git add src/map/dungeon_rules.gd src/map/dungeon_map.gd src/hub/hub.gd src/singletons/run_manager.gd test/unit/test_dungeon_rules.gd docs/refactor.md
git commit -m "fix: stabilize dungeon tier and node counts"
```

---

### Task 3: Make saved map structure authoritative

**Files:**

- Create: `src/map/dungeon_save_codec.gd`
- Create: `test/unit/test_dungeon_save_codec.gd`
- Create: `test/integration/test_dungeon_restore.gd`
- Modify: `src/map/dungeon_map.gd:203-278,1335-1371`
- Modify: `src/singletons/run_manager.gd:95-126`
- Modify: `src/core/main.gd:91-103`

- [ ] **Step 1: Write failing codec tests**

Create `test/unit/test_dungeon_save_codec.gd`:

```gdscript
extends GutTest

const Codec = preload("res://src/map/dungeon_save_codec.gd")

func valid_map_data() -> Dictionary:
	return {
		"current_alert": 80.0,
		"total_nodes": 2,
		"nodes_done": 1,
		"current_coords": var_to_str(Vector2i(1, 0)),
		"width": 2,
		"height": 1,
		"node_data": {
			var_to_str(Vector2i(0, 0)): {"state": 2, "visited": true, "aware": true, "type": MapNode.NodeType.ENTRANCE},
			var_to_str(Vector2i(1, 0)): {"state": 1, "visited": true, "aware": false, "type": MapNode.NodeType.TERMINAL},
		},
		"terminal_memory": {var_to_str(Vector2i(1, 0)): {"facility_name": "TEST", "session_id": "1", "terminal_index": 0, "bits": 50, "alert": 50, "upgrade_key": "security"}},
		"encounter_memory": {},
		"reward_memory": {},
	}

func test_extracts_saved_node_types() -> void:
	var types := Codec.extract_node_types(valid_map_data())
	assert_eq(types[Vector2i(0, 0)], MapNode.NodeType.ENTRANCE)
	assert_eq(types[Vector2i(1, 0)], MapNode.NodeType.TERMINAL)

func test_rejects_missing_node_data() -> void:
	var data := valid_map_data()
	data.erase("node_data")
	assert_false(Codec.is_valid_map_data(data))

func test_rejects_current_coordinate_outside_saved_nodes() -> void:
	var data := valid_map_data()
	data.current_coords = var_to_str(Vector2i(9, 9))
	assert_false(Codec.is_valid_map_data(data))
```

- [ ] **Step 2: Run and confirm the missing-codec failure**

Run the test file with the focused GUT command. Expected: FAIL because the codec script is missing.

- [ ] **Step 3: Implement strict prototype-save validation**

Create `src/map/dungeon_save_codec.gd`:

```gdscript
class_name DungeonSaveCodec
extends RefCounted

const REQUIRED_MAP_KEYS := [
	"current_alert", "total_nodes", "nodes_done", "current_coords",
	"width", "height", "node_data", "terminal_memory",
	"encounter_memory", "reward_memory"
]

static func is_valid_map_data(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in REQUIRED_MAP_KEYS:
		if not data.has(key):
			return false
	if not data.node_data is Dictionary or data.node_data.is_empty():
		return false
	if not data.node_data.has(data.current_coords):
		return false
	for saved_info in data.node_data.values():
		if not saved_info is Dictionary:
			return false
		for key in ["state", "visited", "aware", "type"]:
			if not saved_info.has(key):
				return false
	return true

static func is_valid_active_run(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in ["seed", "tier", "profile_path", "map_data"]:
		if not data.has(key):
			return false
	return ResourceLoader.exists(str(data.profile_path)) and is_valid_map_data(data.map_data)

static func extract_node_types(map_data: Dictionary) -> Dictionary:
	var result := {}
	for key in map_data.node_data:
		result[str_to_var(key)] = int(map_data.node_data[key].type)
	return result
```

- [ ] **Step 4: Restore Alert and types before visibility**

At the beginning of `DungeonMap.load_from_save_data()`:

```gdscript
if not DungeonSaveCodec.is_valid_map_data(data):
	push_error("DungeonMap: refusing invalid map save data")
	return false

map_length = int(data.width)
map_height = int(data.height)
current_alert = float(data.current_alert)
_update_alert_visuals()
var restored_types := DungeonSaveCodec.extract_node_types(data)
await generate_hex_grid(false, restored_types)
```

Delete the ineffective pre-generation loop. Restore node flags and payload memories after generation, set `current_node`, then call `_update_vision()` only after the saved Alert has established `vision_range`. Return `true` on success.

- [ ] **Step 5: Reject invalid active runs before scene creation**

Make `RunManager.restore_run()` return `bool`, validate before reading `profile_path`, and return false without indexing malformed data:

```gdscript
func restore_run() -> bool:
	var run_data = SaveSystem.data.get("active_run")
	if not DungeonSaveCodec.is_valid_active_run(run_data):
		push_error("RunManager: refusing invalid active run")
		is_run_active = false
		SaveSystem.data["active_run"] = null
		SaveSystem.save_current_slot()
		return false
	# Existing resource restoration follows.
	return await active_dungeon_map.load_from_save_data(run_data.map_data)
```

In `Main._on_continue_requested()`, check `DungeonSaveCodec.is_valid_active_run(SaveSystem.data.get("active_run"))`. If false, clear only `active_run`, save, and call `load_hub()` instead of creating `game_scene`.

- [ ] **Step 6: Add a round-trip integration test**

Create `test/integration/test_dungeon_restore.gd` that instantiates `res://src/map/dungeon_map.tscn`, builds a small saved map using the exact shape from the unit fixture, calls `load_from_save_data()`, and asserts:

```gdscript
assert_eq(map.current_alert, 80.0)
assert_eq(map.current_node.grid_coords, Vector2i(1, 0))
assert_eq(map.grid_nodes[Vector2i(1, 0)].type, MapNode.NodeType.TERMINAL)
assert_eq(map.terminal_memory[Vector2i(1, 0)].facility_name, "TEST")
assert_eq(map.vision_range, 0)
```

Use `add_child_autofree(map)` and await one process frame before loading data.

- [ ] **Step 7: Run focused and full tests, then commit**

Expected: codec tests, restore integration test, and full suite pass.

```bash
git add src/map/dungeon_save_codec.gd src/map/dungeon_map.gd src/singletons/run_manager.gd src/core/main.gd test/unit/test_dungeon_save_codec.gd test/integration/test_dungeon_restore.gd
git commit -m "fix: restore authoritative dungeon map state"
```

---

### Task 4: Make node payload failures recoverable

**Files:**

- Modify: `src/battle/game_manager.gd:17-83,168-227`
- Create: `test/integration/test_game_manager_interactions.gd`

- [ ] **Step 1: Write failing payload tests**

Create a test-only subclass inside `test_game_manager_interactions.gd`:

```gdscript
extends GutTest

class TestGameManager extends GameManager:
	var completed := 0
	var canceled := 0
	var errors: Array[String] = []

	func _complete_current_interaction() -> void:
		completed += 1

	func _cancel_current_interaction() -> void:
		canceled += 1

	func _report_interaction_error(message: String) -> void:
		errors.append(message)

func test_missing_terminal_payload_is_retryable() -> void:
	var manager := TestGameManager.new()
	manager._handle_terminal_payload(Vector2i(3, 2), null)
	assert_eq(manager.completed, 0)
	assert_eq(manager.canceled, 1)
	assert_eq(manager.errors.size(), 1)

func test_malformed_encounter_payload_is_retryable() -> void:
	var manager := TestGameManager.new()
	manager._handle_encounter_payload(Vector2i(1, 1), ["only-an-id"])
	assert_eq(manager.completed, 0)
	assert_eq(manager.canceled, 1)
	assert_eq(manager.errors.size(), 1)

func test_missing_reward_payload_is_retryable() -> void:
	var manager := TestGameManager.new()
	manager._handle_reward_payload(Vector2i(4, 4), {})
	assert_eq(manager.completed, 0)
	assert_eq(manager.canceled, 1)
```

- [ ] **Step 2: Run and confirm missing-handler failures**

Expected: FAIL because the three payload handler seams do not exist.

- [ ] **Step 3: Add explicit interaction outcomes**

In `GameManager`, add:

```gdscript
enum InteractionOutcome { COMPLETED, CANCELED, RUN_ENDED, ERROR }

func _finish_interaction(outcome: InteractionOutcome) -> void:
	match outcome:
		InteractionOutcome.COMPLETED:
			_complete_current_interaction()
		InteractionOutcome.CANCELED:
			_cancel_current_interaction()
		InteractionOutcome.RUN_ENDED:
			pass
		InteractionOutcome.ERROR:
			_cancel_current_interaction()

func _complete_current_interaction() -> void:
	_clear_transient_overlay()
	await dungeon_map.complete_current_node()
	RunManager.auto_save()
	dungeon_map.unlock_input()

func _cancel_current_interaction() -> void:
	_clear_transient_overlay()
	dungeon_map.unlock_input()

func _report_interaction_error(message: String) -> void:
	push_error(message)

func _clear_transient_overlay() -> void:
	for child in overlay_layer.get_children():
		child.queue_free()
```

Replace `_on_content_finished(bool)` call sites with the explicit outcome methods.

- [ ] **Step 4: Validate before indexing or duplicating**

Add handlers that enforce these shapes:

```gdscript
func _handle_encounter_payload(coords: Vector2i, payload: Variant) -> void:
	if not payload is Array or payload.size() != 3 or not payload[0] is String:
		_report_interaction_error("Invalid encounter payload at %s: %s" % [coords, payload])
		_finish_interaction(InteractionOutcome.ERROR)
		return
	var source := EncounterDatabase.get_encounter_by_id(payload[0])
	if source == null:
		_report_interaction_error("Unknown encounter '%s' at %s" % [payload[0], coords])
		_finish_interaction(InteractionOutcome.ERROR)
		return
	var encounter := source.duplicate()
	encounter.is_elite = bool(payload[1])
	encounter.is_boss = bool(payload[2])
	_start_encounter(encounter)
```

Terminal payloads must be dictionaries containing `facility_name`, `session_id`, `terminal_index`, `bits`, `alert`, and `upgrade_key`. Reward payloads must contain `type`, plus the fields required for that loot type. On failure, report and cancel; do not call `complete_current_node()`.

- [ ] **Step 5: Run tests and commit**

```bash
git add src/battle/game_manager.gd test/integration/test_game_manager_interactions.gd
git commit -m "fix: preserve dungeon nodes on invalid payloads"
```

---

### Task 5: Centralize and guard all run endings

**Files:**

- Modify: `src/battle/game_manager.gd:17-18,29-106,108-146,229-253`
- Modify: `src/map/dungeon_end_screen.gd:14-60`
- Modify: `test/integration/test_game_manager_interactions.gd`

- [ ] **Step 1: Add failing one-shot ending tests**

Extend the test-only manager:

```gdscript
class TestGameManager extends GameManager:
	var presented_results: Array[int] = []
	var overlay_clear_count := 0

	func _clear_transient_overlay() -> void:
		overlay_clear_count += 1

	func _present_end_screen(result: RunManager.RunResult) -> void:
		presented_results.append(result)
```

Add tests:

```gdscript
func test_terminal_extraction_starts_retreat_once() -> void:
	var manager := TestGameManager.new()
	manager._on_terminal_choice("opt_extract", {})
	manager._on_terminal_choice("opt_extract", {})
	assert_eq(manager.presented_results, [RunManager.RunResult.RETREAT])

func test_exit_starts_success_once() -> void:
	var manager := TestGameManager.new()
	manager._begin_run_end(RunManager.RunResult.SUCCESS)
	manager._begin_run_end(RunManager.RunResult.SUCCESS)
	assert_eq(manager.presented_results.size(), 1)

func test_boss_victory_maps_to_success() -> void:
	var manager := TestGameManager.new()
	var encounter := Encounter.new()
	encounter.is_boss = true
	manager.current_encounter = encounter
	assert_eq(manager._result_for_battle_end(true), RunManager.RunResult.SUCCESS)

func test_normal_victory_does_not_end_run() -> void:
	var manager := TestGameManager.new()
	manager.current_encounter = Encounter.new()
	assert_eq(manager._result_for_battle_end(true), -1)

func test_defeat_maps_to_defeat() -> void:
	var manager := TestGameManager.new()
	assert_eq(manager._result_for_battle_end(false), RunManager.RunResult.DEFEAT)
```

- [ ] **Step 2: Run and confirm failures**

Expected: duplicate result presentation and missing `_begin_run_end`, `current_encounter`, and `_result_for_battle_end` APIs.

- [ ] **Step 3: Add the guarded transition**

Add to `GameManager`:

```gdscript
var current_encounter: Encounter
var _run_end_started := false

func _begin_run_end(result: RunManager.RunResult) -> void:
	if _run_end_started:
		return
	_run_end_started = true
	dungeon_map.current_map_state = DungeonMap.MapState.LOCKED
	_clear_transient_overlay()
	_present_end_screen(result)

func _present_end_screen(result: RunManager.RunResult) -> void:
	var screen := dungeon_end_screen_scene.instantiate() as DungeonEndScreen
	overlay_layer.add_child(screen)
	screen.setup(result)
	screen.finished.connect(_on_end_screen_finished, CONNECT_ONE_SHOT)

func _on_end_screen_finished() -> void:
	dungeon_exited.emit(true)

func _result_for_battle_end(won: bool) -> int:
	if not won:
		return RunManager.RunResult.DEFEAT
	if current_encounter != null and current_encounter.is_boss:
		return RunManager.RunResult.SUCCESS
	return -1
```

Set `current_encounter` in `_start_encounter()`. In `end_encounter()`, route Defeat and boss Success to `_begin_run_end`; only normal victories complete the node and restore map control.

- [ ] **Step 4: Route every ending and stop fallthrough**

- Entrance calls `_begin_run_end(RETREAT)`.
- Exit calls `_begin_run_end(SUCCESS)`.
- Terminal `opt_extract` calls `_begin_run_end(RETREAT)` and immediately `return`.
- Party defeat calls `_begin_run_end(DEFEAT)`.
- Delete `_handle_extraction()`, `_show_end_screen()`, and the unused `_on_party_wipe()` duplicate if all defeat calls now use the guarded transition.

- [ ] **Step 5: Make result confirmation single-shot**

In `DungeonEndScreen`:

```gdscript
var _result: RunManager.RunResult
var _confirmed := false

func _on_continue_pressed() -> void:
	if _confirmed:
		return
	_confirmed = true
	continue_button.disabled = true
	RunManager.commit_rewards(_result)
	finished.emit()
```

- [ ] **Step 6: Run focused and full tests, then commit**

```bash
git add src/battle/game_manager.gd src/map/dungeon_end_screen.gd test/integration/test_game_manager_interactions.gd
git commit -m "fix: make dungeon endings one-shot"
```

---

### Task 6: Stabilize terminal selection and medical effects

**Files:**

- Modify: `src/map/dungeon_rules.gd`
- Modify: `src/map/terminal.gd:14-127`
- Modify: `src/battle/game_manager.gd:108-166`
- Modify: `test/unit/test_dungeon_rules.gd`
- Modify: `test/integration/test_game_manager_interactions.gd`

- [ ] **Step 1: Add failing deterministic medical tests**

Append to `test_dungeon_rules.gd`:

```gdscript
func hero(injuries: int) -> HeroData:
	var value := HeroData.new()
	value.injuries = injuries
	return value

func test_standard_medical_clears_injury_without_boon() -> void:
	var value := hero(1)
	DungeonRulesScript.apply_medical([value], false, 0.9)
	assert_eq(value.injuries, 0)
	assert_false(value.boon_focused)
	assert_false(value.boon_armored)

func test_standard_medical_grants_one_boon_to_healthy_hero() -> void:
	var value := hero(0)
	DungeonRulesScript.apply_medical([value], false, 0.9)
	assert_true(value.boon_focused)
	assert_false(value.boon_armored)

func test_upgraded_medical_heals_and_grants_one_boon() -> void:
	var value := hero(2)
	DungeonRulesScript.apply_medical([value], true, 0.1)
	assert_eq(value.injuries, 0)
	assert_false(value.boon_focused)
	assert_true(value.boon_armored)

func test_upgraded_medical_grants_both_boons_to_healthy_hero() -> void:
	var value := hero(0)
	DungeonRulesScript.apply_medical([value], true, 0.1)
	assert_true(value.boon_focused)
	assert_true(value.boon_armored)
```

- [ ] **Step 2: Add the pure medical rule**

Append to `DungeonRules`:

```gdscript
static func apply_medical(roster: Array, upgraded: bool, boon_roll: float) -> void:
	for hero in roster:
		var was_injured := hero.injuries > 0
		if was_injured:
			hero.injuries = 0
		if upgraded and not was_injured:
			hero.boon_focused = true
			hero.boon_armored = true
		elif upgraded or not was_injured:
			if boon_roll > 0.5:
				hero.boon_focused = true
			else:
				hero.boon_armored = true
```

Replace `_handle_medical_logic()` with one RNG draw passed into this rule, then refresh the team HUD.

- [ ] **Step 3: Add terminal single-shot and numbering tests**

Instantiate `res://src/map/terminal.tscn`, call `setup()` with a complete test payload, and assert its rendered text contains these unique prefixes:

```gdscript
assert_string(terminal.final_text_content).contains("1 ->")
assert_string(terminal.final_text_content).contains("2 ->")
assert_string(terminal.final_text_content).contains("3 ->")
assert_string(terminal.final_text_content).contains("4 ->")
assert_string(terminal.final_text_content).contains("5 -> SIGNAL EXTRACTION")
```

Connect a counter to `option_selected`, call `_on_text_link_clicked("opt_sec")` twice, and assert the counter is 1.

- [ ] **Step 4: Correct terminal behavior**

Add `_choice_made := false` and guard `_on_text_link_clicked()` and `_on_close_button_pressed()`. Disable `close_button` as soon as either path starts. Number Security 1, Scan 2, Medical 3, Finance 4, and Extraction 5; update `ENTER CHOICE [1-5]`.

Ensure scan cancel calls the terminal-opening helper without completing the node, while scan success calls `_finish_interaction(COMPLETED)` exactly once.

- [ ] **Step 5: Run tests and commit**

```bash
git add src/map/dungeon_rules.gd src/map/terminal.gd src/battle/game_manager.gd test/unit/test_dungeon_rules.gd test/integration/test_game_manager_interactions.gd
git commit -m "fix: stabilize dungeon terminal behavior"
```

---

### Task 7: Make reward commitment deterministic and idempotent

**Files:**

- Create: `test/unit/test_run_rewards.gd`
- Modify: `src/singletons/run_manager.gd:8-17,142-186`
- Modify: `src/core/main.gd:130-135`

- [ ] **Step 1: Write failing multiplier and one-shot tests**

Create `test/unit/test_run_rewards.gd`:

```gdscript
extends GutTest

const RunManagerScript = preload("res://src/singletons/run_manager.gd")

func test_reward_multipliers() -> void:
	assert_eq(RunManagerScript.reward_multiplier(RunManagerScript.RunResult.SUCCESS), 1.0)
	assert_eq(RunManagerScript.reward_multiplier(RunManagerScript.RunResult.RETREAT), 0.5)
	assert_eq(RunManagerScript.reward_multiplier(RunManagerScript.RunResult.DEFEAT), 0.0)

func test_reward_commit_guard_only_opens_once() -> void:
	var manager := RunManagerScript.new()
	assert_true(manager.begin_reward_commit())
	assert_false(manager.begin_reward_commit())
```

- [ ] **Step 2: Run and confirm missing-method failures**

Expected: FAIL because `reward_multiplier()` and `begin_reward_commit()` do not exist.

- [ ] **Step 3: Add pure multiplier and commitment guard**

Add to `RunManager`:

```gdscript
var _rewards_committed := false

static func reward_multiplier(result: RunResult) -> float:
	match result:
		RunResult.SUCCESS: return 1.0
		RunResult.RETREAT: return 0.5
		_: return 0.0

func begin_reward_commit() -> bool:
	if _rewards_committed:
		return false
	_rewards_committed = true
	return true
```

At the start of `commit_rewards()`:

```gdscript
if not begin_reward_commit():
	return
var multiplier := reward_multiplier(result)
```

Reset `_rewards_committed = false` when a new run starts or successfully restores. At the end of every result, clear `run_equipment_loot` and `run_mods_loot` as well as Bits, XP, and inventory. Set `is_run_active = false` before saving so `active_run` is cleared immediately.

- [ ] **Step 4: Keep hub return presentation-only**

In `Main.return_to_hub_with_rewards()`, retain injury cleanup and scene transition, but do not repeat reward commitment or mutate run rewards. Save once after injury cleanup.

- [ ] **Step 5: Run tests and commit**

```bash
git add src/singletons/run_manager.gd src/core/main.gd test/unit/test_run_rewards.gd
git commit -m "fix: make run rewards idempotent"
```

---

### Task 8: Complete automated and manual stabilization verification

**Files:**

- Create: `docs/testing/dungeon-manual-checklist.md`
- Modify: `docs/refactor.md`
- Modify: `docs/superpowers/specs/2026-07-10-dungeon-stabilization-design.md` only if verified behavior differs from the approved wording

- [ ] **Step 1: Write the manual verification checklist**

Create `docs/testing/dungeon-manual-checklist.md`:

```markdown
# Dungeon Stabilization Manual Checklist

Record the commit tested and mark every item before declaring stabilization complete.

- [ ] Start a fresh run at tier 1; confirm the first movement cost and loot scalar are not tier-0 values.
- [ ] Confirm HUD total agrees with the number of completable generated nodes.
- [ ] Close a terminal; reopen it and confirm it remains unused.
- [ ] Enter scan targeting, cancel, and confirm the same terminal reopens.
- [ ] Complete a scan and confirm the terminal cannot be reused.
- [ ] Use Security, Medical, and Finance once each and confirm their displayed values match their effects.
- [ ] Extract from a terminal and receive one Tactical Retreat screen.
- [ ] Return to the Entrance and receive one Tactical Retreat screen.
- [ ] Reach an Exit and receive one Mission Complete screen.
- [ ] Win a boss fight and receive one Mission Complete screen immediately.
- [ ] Lose a fight and receive one Critical Failure screen.
- [ ] Double-click the result confirmation and confirm rewards are committed once.
- [ ] Save at Safe Alert, resume, and confirm position, types, payloads, and visibility.
- [ ] Save at 75% or greater Alert, resume, and confirm no additional ring is revealed.
- [ ] Temporarily corrupt `active_run.map_data.node_data`, continue, and confirm the run is rejected without losing permanent inventory, heroes, or Bits.
- [ ] Complete one uninterrupted crawl while monitoring the debugger for parse errors, invalid accesses, and orphan-node warnings.
```

- [ ] **Step 2: Run every automated test headlessly**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
```

Expected: exit code 0, no failed or pending tests.

- [ ] **Step 3: Run a project parse/runtime smoke check**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
```

Expected: exit code 0 and no `SCRIPT ERROR`, `Parse Error`, or invalid resource errors.

- [ ] **Step 4: Execute the manual checklist in Godot**

Run the project, complete every checklist item, and record the tested commit at the top of the document. If an item fails, add a focused failing GUT test before changing production code.

- [ ] **Step 5: Finalize refactor research**

Review every file touched during stabilization. Add only concrete deferred candidates to `docs/refactor.md`, each with current symbols, proposed boundary, reason for deferral, protecting tests, likely files, and open questions. Do not implement those candidates in this task.

- [ ] **Step 6: Commit verification artifacts**

```bash
git add docs/testing/dungeon-manual-checklist.md docs/refactor.md docs/superpowers/specs/2026-07-10-dungeon-stabilization-design.md
git commit -m "docs: record dungeon stabilization verification"
```

- [ ] **Step 7: Final clean-state verification**

Run the full GUT command and headless editor command again after the documentation commit. Confirm `git status --short` contains only the user's pre-existing unrelated local changes, if they are still present.

---

## Deferred until the refactor pass

- Moving procedural generation out of `DungeonMap`.
- Splitting Alert/visibility logic from HUD and animation code.
- Introducing typed terminal, reward, or encounter payload resources.
- Moving run lifecycle into its own controller.
- Implementing Event nodes.
- Adding a mechanical consequence at 100% Alert.

The next project after this plan should begin by reviewing `docs/refactor.md` against the passing stabilization suite, then producing a separate refactor design.
