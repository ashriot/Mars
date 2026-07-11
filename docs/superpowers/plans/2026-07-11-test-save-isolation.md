# Test Save Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guarantee that GUT processes cannot resolve, read, overwrite, or delete production save-slot files.

**Architecture:** `SaveSystem` selects one of two save roots from the Godot command line: the existing production root or a GUT-only root. Every slot operation continues flowing through `_get_slot_path()`, making the isolation automatic for production methods and imperfect future tests alike.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1

## Global Constraints

- Production paths remain `user://saves/slot_<n>.json`.
- GUT paths are `user://test_saves/slot_<n>.json`.
- Test isolation must never fall back to the production save directory.
- No gameplay save format or progression behavior changes.
- Preserve the user's unrelated dirty `.tres` and `.tscn` files.

---

### Task 1: Enforce Save-Path Isolation in SaveSystem

**Files:**
- Modify: `src/singletons/save_system.gd`
- Test: `test/unit/test_save_system_isolation.gd`

**Interfaces:**
- Consumes: `OS.get_cmdline_args() -> PackedStringArray`
- Produces: `SaveSystem._is_gut_process(args: PackedStringArray) -> bool`, `SaveSystem._get_save_dir() -> String`, and the existing `SaveSystem._get_slot_path(index: int) -> String`

- [ ] **Step 1: Write the failing path-isolation tests**

Create `test/unit/test_save_system_isolation.gd`:

```gdscript
extends GutTest


func test_gut_runner_argument_is_detected() -> void:
	assert_true(SaveSystem._is_gut_process(PackedStringArray([
		"-s",
		"res://addons/gut/gut_cmdln.gd",
		"-gexit",
	])))


func test_unrelated_script_argument_is_not_detected_as_gut() -> void:
	assert_false(SaveSystem._is_gut_process(PackedStringArray([
		"-s",
		"res://tools/export_data.gd",
	])))


func test_current_gut_process_resolves_slot_under_test_save_root() -> void:
	assert_true(SaveSystem._is_gut_process(OS.get_cmdline_args()))
	assert_eq(SaveSystem._get_save_dir(), "user://test_saves/")
	assert_eq(SaveSystem._get_slot_path(1), "user://test_saves/slot_1.json")
	assert_ne(SaveSystem._get_slot_path(1), "user://saves/slot_1.json")
```

- [ ] **Step 2: Run the suite and verify RED**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
```

Expected: the new script fails because `_is_gut_process()` and `_get_save_dir()` do not exist, and `_get_slot_path(1)` still resolves beneath `user://saves/`.

- [ ] **Step 3: Implement the minimal hard boundary**

Update the constants and directory initialization in `src/singletons/save_system.gd`:

```gdscript
const SAVE_DIR = "user://saves/"
const TEST_SAVE_DIR = "user://test_saves/"
const GUT_RUNNER_PATH = "addons/gut/gut_cmdln.gd"


func _ready():
	var save_dir := _get_save_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_absolute(save_dir)


func _is_gut_process(args: PackedStringArray) -> bool:
	for argument in args:
		if GUT_RUNNER_PATH in argument:
			return true
	return false


func _get_save_dir() -> String:
	if _is_gut_process(OS.get_cmdline_args()):
		return TEST_SAVE_DIR
	return SAVE_DIR
```

Replace `_get_slot_path()` with:

```gdscript
func _get_slot_path(index: int) -> String:
	return _get_save_dir() + SLOT_PREFIX + str(index) + SLOT_EXT
```

Do not add a fallback from `TEST_SAVE_DIR` to `SAVE_DIR`.

- [ ] **Step 4: Run the full suite and verify GREEN**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
```

Expected: 78/78 tests pass (the existing 75 plus three isolation tests), with no unexpected errors or orphan/leak warnings.

- [ ] **Step 5: Verify the real slot cannot change during an unsandboxed-home test run**

First record the checksum:

```bash
shasum "$HOME/Library/Application Support/Godot/app_userdata/Redshift/saves/slot_1.json"
```

Run GUT without overriding `HOME`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
```

Record the checksum again with the same `shasum` command. Expected: both checksums are identical, while test files appear only under `user://test_saves/`. If Godot cannot run because another editor/game process owns its log, stop that process or repeat after it exits; do not weaken the save-isolation assertions.

- [ ] **Step 6: Verify project parsing and repository hygiene**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
git diff --check
git status --short
```

Expected: Godot exits 0 without parse failures; `git diff --check` emits nothing; status contains only the two task files plus the user's pre-existing dirty scene/audio-layout files.

- [ ] **Step 7: Commit the isolation boundary**

```bash
git add src/singletons/save_system.gd test/unit/test_save_system_isolation.gd
git commit -m "test: isolate automated save data"
```
