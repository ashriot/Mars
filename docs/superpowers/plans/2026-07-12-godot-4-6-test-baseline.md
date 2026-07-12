# Godot 4.6.3 Test Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Godot 4.6.3 and official GUT 9.6.1 the single reproducible development and automated-test baseline, with a zero-failure suite.

**Architecture:** Replace the entire vendored GUT 4.7 harness at its dependency boundary rather than patching individual framework files. Pin the engine contract in one harness test and current testing guide, then repair the one confirmed Godot 4.6 typed-array incompatibility without changing progression behavior.

**Tech Stack:** Godot 4.6.3, GDScript, official GUT v9.6.1 at commit `c80954f47bed74a0a2c471d472c0389f98e0a8f6`.

## Global Constraints

- Godot 4.6.3 is the exact supported development and automated-test runtime.
- GUT is the complete official `v9.6.1` release at commit `c80954f47bed74a0a2c471d472c0389f98e0a8f6`; do not create a mixed 9.6/9.7 harness.
- Do not add local GUT compatibility patches unless the unmodified official release cannot run under Godot 4.6.3.
- The canonical full suite must finish with zero failing tests and without the `AccessibilityServer` or `stub_params.gd` parser errors.
- Invalid role trees remain fail-closed and return empty typed arrays through their public collection properties.
- Valid role-tree defensive copies and ordering remain unchanged.
- Do not change gameplay, UI, balance, saves, or historical plans/specifications.
- Preserve unrelated local changes to `project.godot` and `data/heroes/asher/actions/aimed_shot.tres`; never stage them.

---

### Task 1: Pin the Godot and GUT Harness

**Files:**
- Replace: `addons/gut/**`
- Modify after replacement: `addons/gut/VENDORED.md`
- Modify: `test/unit/test_test_harness.gd`
- Create: `docs/testing/README.md`
- Modify: `docs/testing/dungeon-manual-checklist.md`

**Interfaces:**
- Consumes: `/Applications/Godot.app/Contents/MacOS/Godot`, which must report `4.6.3`.
- Produces: a complete GUT 9.6.1 harness and canonical test commands for later tasks.

- [ ] **Step 1: Tighten the engine contract test**

Change `test/unit/test_test_harness.gd` to assert all three components independently:

```gdscript
extends GutTest


func test_gut_runs_under_supported_godot_version() -> void:
	var version := Engine.get_version_info()
	assert_eq(version.major, 4)
	assert_eq(version.minor, 6)
	assert_eq(version.patch, 3)
```

- [ ] **Step 2: Run the harness test and observe RED with the mismatched dependency**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect test_test_harness -gexit
```

Expected before replacement: Godot reports 4.6.3 and the version assertions pass, but the command output contains GUT 9.7.1 compatibility parser errors for `AccessibilityServer` and `stub_params.gd`. This is a failing harness contract even if GUT returns exit 0 for the selected assertion.

- [ ] **Step 3: Download and verify the exact official dependency revision**

```bash
git ls-remote --tags https://github.com/bitwes/Gut.git refs/tags/v9.6.1
curl -L https://github.com/bitwes/Gut/archive/refs/tags/v9.6.1.zip -o /tmp/gut-v9.6.1.zip
rm -rf /tmp/Gut-9.6.1
unzip -q /tmp/gut-v9.6.1.zip -d /tmp
```

The tag lookup must return `c80954f47bed74a0a2c471d472c0389f98e0a8f6`, and `/tmp/Gut-9.6.1/addons/gut/plugin.cfg` must exist after extraction. GitHub source archives do not contain a `.git` directory; provenance comes from the verified tag lookup and archive URL.

- [ ] **Step 4: Replace the complete vendored harness**

```bash
rsync -a --delete /tmp/Gut-9.6.1/addons/gut/ addons/gut/
```

Do not copy the upstream repository's tests, examples, or project settings. Confirm the runtime version:

```bash
rg -n 'version="9\.6\.1"|"9\.6\.1"' addons/gut/plugin.cfg addons/gut/versions.json
```

Expected: `addons/gut/plugin.cfg` declares version `9.6.1` and the vendored compatibility data associates it with Godot 4.6.x.

- [ ] **Step 5: Restore repository provenance documentation**

Create `addons/gut/VENDORED.md` with:

```markdown
# Vendored GUT

- Source: https://github.com/bitwes/Gut
- Tag: `v9.6.1`
- Upstream commit: `c80954f47bed74a0a2c471d472c0389f98e0a8f6`
- Runtime version: GUT 9.6.1
- Retrieved from: `https://github.com/bitwes/Gut/archive/refs/tags/v9.6.1.zip`
- Local modifications: none.

The project and automated test baseline is Godot 4.6.3. This version has been verified on iPhone; Godot 4.7 is deferred because of iOS visual issues.

After importing the project once, run the suite with:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

On macOS this command may emit a nonfatal `get_system_ca_certificates` warning while the tests still run and report their results normally.
```

If diff-hygiene normalization is required after copying upstream files, list exactly that normalization instead of `none`.

- [ ] **Step 6: Establish one current testing guide**

Create `docs/testing/README.md`:

```markdown
# Testing

The supported development and automated-test runtime is Godot 4.6.3 with vendored GUT 9.6.1. Godot 4.6.3 has been verified on iPhone; Godot 4.7 is deferred because of iOS visual issues.

Import and parse the project:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
```

Run the complete automated suite:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Run a focused script by matching its filename:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect progression_definitions -gexit
```

The macOS `get_system_ca_certificates` warning and engine shutdown leak diagnostics may appear without failing the command. Test failures, script parser errors, and crashes are not acceptable.
```

In `docs/testing/dungeon-manual-checklist.md`, replace the stale paragraph beginning `Latest durable automated result:` with:

```markdown
The current automated-test baseline and canonical commands are documented in [Testing](README.md). Complete automated checks do not replace the interactive crawl below.
```

- [ ] **Step 7: Run focused harness verification and inspect output**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect test_test_harness -gexit
```

Expected: the selected test passes all three assertions, output reports Godot 4.6.3 and GUT 9.6.1, exit code is 0, and neither `AccessibilityServer` nor `stub_params.gd` appears as a parser error.

- [ ] **Step 8: Verify scope and commit the harness baseline**

```bash
git diff --check
git status --short
git add addons/gut test/unit/test_test_harness.gd docs/testing/README.md docs/testing/dungeon-manual-checklist.md
git commit -m "test: align harness with Godot 4.6"
```

Expected: `project.godot` and `data/heroes/asher/actions/aimed_shot.tres` remain unstaged.

---

### Task 2: Restore Godot 4.6 Typed-Array Compatibility

**Files:**
- Modify: `src/progression/role_tree_definition.gd`
- Test: `test/unit/test_progression_definitions.gd`

**Interfaces:**
- Consumes: the GUT 9.6.1/Godot 4.6.3 harness from Task 1.
- Preserves: `starting_node_ids: Array[String]`, `nodes: Array[ProgressionNodeDefinition]`, and `get_children(node_id: String) -> Array[ProgressionNodeDefinition]`.

- [ ] **Step 1: Strengthen the existing invalid-tree regression around typed returns**

In `test_invalid_trees_fail_closed_for_public_access`, retain the existing equality assertions and add type checks before them:

```gdscript
var starting_ids: Array[String] = duplicate_tree.starting_node_ids
var exposed_nodes: Array[ProgressionNodeDefinition] = duplicate_tree.nodes
var exposed_children: Array[ProgressionNodeDefinition] = duplicate_tree.get_children("gun.anchor")
assert_true(starting_ids.is_typed())
assert_true(exposed_nodes.is_typed())
assert_true(exposed_children.is_typed())
assert_eq(starting_ids, [])
assert_eq(exposed_nodes, [])
assert_eq(exposed_children, [])
```

Keep the existing root and `get_node()` fail-closed assertions. Remove only the now-duplicated direct property equality lines.

- [ ] **Step 2: Run the focused test and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect progression_definitions -gexit
```

Expected: `test_invalid_trees_fail_closed_for_public_access` fails with Godot 4.6 errors stating that untyped `Array` values cannot be returned as `Array[String]` and `Array[ProgressionNodeDefinition]` from the two property getters.

- [ ] **Step 3: Return typed empty arrays from invalid getters**

Replace the ternary getters in `src/progression/role_tree_definition.gd` with explicit typed branches:

```gdscript
var starting_node_ids: Array[String]:
	get:
		if not _is_valid:
			var empty: Array[String] = []
			return empty
		return _starting_node_ids.duplicate()

var nodes: Array[ProgressionNodeDefinition]:
	get:
		if not _is_valid:
			var empty: Array[ProgressionNodeDefinition] = []
			return empty
		return _nodes.duplicate()
```

Do not change construction, validation, sorting, or `get_children()`.

- [ ] **Step 4: Run focused tests and confirm GREEN**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect progression_definitions -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect progression_content -gexit
```

Expected: both focused scripts pass with no unexpected script errors.

- [ ] **Step 5: Run editor and complete-suite verification**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: editor import exits 0; the full GUT suite exits 0 with zero failing tests; output contains no GUT compatibility parser errors or crashes; diff hygiene passes.

- [ ] **Step 6: Commit the compatibility fix**

```bash
git add src/progression/role_tree_definition.gd test/unit/test_progression_definitions.gd
git commit -m "fix: support typed role tree arrays on Godot 4.6"
```

Expected: only the two task files are committed and the unrelated editor changes remain unstaged.
