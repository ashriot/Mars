# Local 3D Battle Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first asset-backed 3D battle presentation: a reusable industrial room, five-position W/M enemy staging, projected enemy HUDs, and one EyeDrone model reused for every ordinary enemy while all Quaternius binaries remain local and Git-ignored.

**Architecture:** A tracked `BattleWorld3D` sits behind the existing Canvas UI and places generic enemy presentation roots at authored formation transforms. Tracked scenes refer to ignored Quaternius resources only through an optional runtime/editor loader, so clean clones use placeholders without missing-resource errors. `EnemyDronePresentation` adapts the existing authoritative `EnemyCombatant` and cancellation-safe presentation contract to the real model, projected HUD, animation player, camera rig, and 2D first-person effects.

**Tech Stack:** Godot 4.7.1, GDScript, Godot scenes/resources, GUT 9.6.1, POSIX shell for the curated local-asset installer.

## Global Constraints

- Preserve the unrelated user edit in `src/dev/endgame_battle_lab.tscn`; never edit, stage, restore, or commit it.
- Work in the primary checkout on the current ordinary feature branch; do not create a Git worktree.
- Use Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot` and the isolated `HOME` commands in `docs/testing/README.md` for every automated Godot run.
- Do not change GUT or another dependency version.
- Keep every file under `assets/graphics/models/quaternius_local/` ignored and untracked; do not use Git LFS and do not force-add vendor files.
- Copy only the exact EyeDrone and eight-module environment whitelist from the approved design; do not copy FBX, OBJ, previews, or unused kit content.
- All ordinary enemies use the same EyeDrone presentation in this slice; additional models, palettes, and profile infrastructure are out of scope.
- Support at most five ordinary enemies. Preserve authored W/M depth instead of collapsing surviving enemies into an even row.
- Keep combatant models authoritative. The 3D room, models, animations, HUDs, camera, projectiles, and shake are presentation only.
- Preserve face-button skill selection, directional target navigation, and CTB right-stick ownership. Battle camera motion must not consume controller axes.
- A clean clone without local kit assets must import, parse, and pass the complete suite using tracked placeholders.
- Commit required `.uid` and `.import` sidecars for tracked files. Never commit `.godot/`.
- Run focused tests while iterating, then the complete suite because the final integration crosses battle runtime, input, navigation, scenes, and settings persistence.

---

## File Structure

### Asset policy and setup

- Modify `.gitignore` — ignore only the local Quaternius vendor root.
- Create `tools/setup_quaternius_local_assets.sh` — validate and copy the exact whitelist while enforcing Git-ignore safety.
- Create `test/tools/test_setup_quaternius_local_assets.sh` — isolated shell coverage for exact copying and missing-dependency failure.
- Create `docs/assets/quaternius-local-assets.md` — tracked manifest, license/source notes, local paths, and recovery instructions.
- Modify `docs/README.md` — index the local-asset manifest.

### Optional local model boundary

- Create `src/battle/presentation/optional_local_model_3d.gd` — editor/runtime loader with placeholder fallback and warning deduplication.
- Create `test/fixtures/presentation/optional_model_fixture.tscn` — tracked loadable fixture.
- Create `test/unit/test_optional_local_model_3d.gd` — existing/missing/reload/teardown coverage.

### Motion preference

- Create `src/singletons/combat_presentation_settings.gd` — clamped persistent shake intensity.
- Modify `project.godot` — register the `CombatPresentationSettings` autoload.
- Create `src/hub/options_panel.gd` and `src/hub/options_panel.tscn` — controller-focusable combat-motion slider.
- Modify `src/hub/party_menu.gd` and `src/hub/party_menu.tscn` — replace the Options placeholder and preserve hub navigation ownership.
- Create `test/unit/test_combat_presentation_settings.gd` — isolated storage coverage.
- Modify `test/integration/test_hub_progression.gd` — options-tab focus, slider, and controller regression coverage.

### 3D world and formations

- Create `src/battle/presentation/battle_formation_layout.gd` — pure W/M and boss transform policy.
- Create `src/battle/presentation/battle_world_3d.gd` and `src/battle/presentation/battle_world_3d.tscn` — world, room, camera, view root, and placement boundary.
- Create `src/battle/presentation/industrial_room_3d.tscn` — eight optional local model instances plus tracked fallback geometry and lights.
- Modify `src/scripts/enemies/encounter.gd` — authored W/M presentation selection.
- Create `test/unit/test_battle_formation_layout.gd` — exact transforms, count rejection, and boss reservations.
- Create `test/integration/test_battle_world_3d.gd` — placement and placeholder room coverage.

### Enemy HUD and presentation

- Create `src/battle/presentation/enemy_intent_formatter.gd` — shared intent text/tooltip formatting extracted from `EnemyCard`.
- Create `src/battle/presentation/enemy_hud_layout.gd` — pure, deterministic safe-area and overlap resolution for up to five projected HUDs.
- Create `src/battle/presentation/enemy_world_hud.gd` and `src/battle/presentation/enemy_world_hud.tscn` — compact projected HUD and expanded details.
- Modify `src/battle/enemy_card.gd` — consume the shared formatter while the legacy card remains available as a fallback.
- Create `test/unit/test_enemy_intent_formatter.gd`, `test/unit/test_enemy_hud_layout.gd`, and `test/unit/test_enemy_world_hud.gd` — formatting, safe-area/overlap, binding, reveal, and compact-layout coverage.
- Create `src/battle/presentation/enemy_drone_presentation.gd` and `src/battle/presentation/enemy_drone_presentation.tscn` — model, animation, projection, selection, and presentation-operation adapter.
- Create `test/integration/test_enemy_drone_presentation.gd` — model reuse, animation mapping, projected target position, teardown, and material isolation coverage.

### Battle integration and feedback

- Modify `src/battle/battle_manager.gd` — presentation-oriented exports, exact view-root registry, formation placement, and projectile routing.
- Modify `src/battle/battle_scene.gd` and `src/battle/battle_scene.tscn` — instantiate the 3D world, switch the enemy parent, retain hero UI, and apply responsive layout.
- Modify `test/integration/test_card_combatant_binding.gd`, `test/integration/test_battle_controller_navigation.gd`, `test/integration/test_battle_responsive_layout.gd`, and `test/integration/test_controller_playable_loop.gd` — generic root cleanup, 3D targeting, responsive projection, and full-loop regressions.
- Create `src/battle/presentation/battle_camera_rig.gd` — mouse edge-look, idle drift, and settings-scaled trauma shake.
- Create `src/battle/presentation/battle_projectile_layer.gd` and `src/battle/presentation/battle_projectile_layer.tscn` — simple screen-space laser from projected enemy to hero UI.
- Modify `src/battle/presentation/combatant_presentation.gd` — typed projectile request signal.
- Modify `src/battle/actor_card.gd` and `src/battle/fx_manager.gd` — shared shake scaling and camera-shake routing.
- Create `test/unit/test_battle_camera_rig.gd` and `test/unit/test_battle_projectile_layer.gd` — deterministic motion and effect coverage.

### Acceptance records

- Modify `docs/testing/ctb-combat-checklist.md` — add the first-person 3D manual acceptance section and final automated evidence.

---

### Task 1: Guard and Install the Curated Local Asset Slice

**Files:**
- Modify: `.gitignore`
- Create: `tools/setup_quaternius_local_assets.sh`
- Create: `test/tools/test_setup_quaternius_local_assets.sh`
- Create: `docs/assets/quaternius-local-assets.md`
- Modify: `docs/README.md`
- Local ignored output: `assets/graphics/models/quaternius_local/`

**Interfaces:**
- Consumes: Essentials root containing `glTF/Enemy_EyeDrone.*`; MegaKit root containing categorized `glTF` models and root `Textures`; optional third destination argument.
- Produces: `tools/setup_quaternius_local_assets.sh ESSENTIALS_ROOT MEGAKIT_ROOT [DEST_ROOT]`; fixed paths `res://assets/graphics/models/quaternius_local/enemies/eye_drone/Enemy_EyeDrone.gltf` and `res://assets/graphics/models/quaternius_local/environment/industrial/*.gltf`.

- [ ] **Step 1: Write the failing isolated shell test**

Create a temporary fake pair of kit roots, populate all whitelisted files with distinct small contents, invoke the not-yet-existing setup utility, and assert these exact behaviors:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/mars-quaternius-test.XXXXXX")
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

ESSENTIALS_ROOT="$FIXTURE_ROOT/essentials"
MEGAKIT_ROOT="$FIXTURE_ROOT/megakit"
DEST_ROOT="$FIXTURE_ROOT/output"

mkdir -p "$ESSENTIALS_ROOT/glTF" "$MEGAKIT_ROOT/glTF/Walls" \
  "$MEGAKIT_ROOT/glTF/Platforms" "$MEGAKIT_ROOT/glTF/Columns" \
  "$MEGAKIT_ROOT/glTF/Props" "$MEGAKIT_ROOT/Textures"

while IFS= read -r relative_path; do
  mkdir -p "$(dirname "$ESSENTIALS_ROOT/$relative_path")"
  printf '%s\n' "$relative_path" > "$ESSENTIALS_ROOT/$relative_path"
done < <("$REPO_ROOT/tools/setup_quaternius_local_assets.sh" --print-essentials-manifest)

while IFS= read -r relative_path; do
  mkdir -p "$(dirname "$MEGAKIT_ROOT/$relative_path")"
  printf '%s\n' "$relative_path" > "$MEGAKIT_ROOT/$relative_path"
done < <("$REPO_ROOT/tools/setup_quaternius_local_assets.sh" --print-megakit-manifest)

"$REPO_ROOT/tools/setup_quaternius_local_assets.sh" \
  "$ESSENTIALS_ROOT" "$MEGAKIT_ROOT" "$DEST_ROOT"

test "$(find "$DEST_ROOT" -type f | wc -l | tr -d ' ')" = "33"
test -f "$DEST_ROOT/enemies/eye_drone/Enemy_EyeDrone.gltf"
test -f "$DEST_ROOT/environment/industrial/Prop_Cable_1.gltf"
test -f "$DEST_ROOT/LICENSE_SCI_FI_ESSENTIALS.txt"
test -f "$DEST_ROOT/LICENSE_MODULAR_SCI_FI_MEGAKIT.txt"
test ! -e "$DEST_ROOT/Preview_1.png"

rm "$MEGAKIT_ROOT/Textures/T_Trim_03_ORM.png"
if "$REPO_ROOT/tools/setup_quaternius_local_assets.sh" \
  "$ESSENTIALS_ROOT" "$MEGAKIT_ROOT" "$FIXTURE_ROOT/missing-output"; then
  exit 1
fi
test ! -e "$FIXTURE_ROOT/missing-output"
```

The count is exactly 33: 5 EyeDrone files, 16 environment model files, 10 environment textures, and 2 distinctly named license files.

- [ ] **Step 2: Run the shell test to verify RED**

Run:

```bash
bash test/tools/test_setup_quaternius_local_assets.sh
```

Expected: FAIL because `tools/setup_quaternius_local_assets.sh` does not exist.

- [ ] **Step 3: Add the narrow ignore rule before any copy**

Append exactly:

```gitignore
# Local CC0 Quaternius source assets; installed by tools/setup_quaternius_local_assets.sh
/assets/graphics/models/quaternius_local/
```

Verify the intended path and a representative nested binary are ignored:

```bash
git check-ignore -v assets/graphics/models/quaternius_local/
git check-ignore -v assets/graphics/models/quaternius_local/enemies/eye_drone/Enemy_EyeDrone.bin
```

- [ ] **Step 4: Implement the explicit-whitelist setup utility**

The script must use constant arrays rather than directory-wide copies. Its public shape is:

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly DEFAULT_DEST_ROOT="assets/graphics/models/quaternius_local"
readonly ESSENTIALS_FILES=(
  "License_Standard.txt"
  "glTF/Enemy_EyeDrone.gltf"
  "glTF/Enemy_EyeDrone.bin"
  "glTF/T_Enemies_BaseColor_png.png"
  "glTF/T_Enemies_Normal.png"
  "glTF/T_Enemies_ORM.png"
)
readonly MEGAKIT_MODELS=(
  "License_Standard.txt"
  "glTF/Walls/WallAstra_Straight_Flat.gltf"
  "glTF/Walls/WallAstra_Straight_Flat.bin"
  "glTF/Walls/TopAstra_Straight.gltf"
  "glTF/Walls/TopAstra_Straight.bin"
  "glTF/Walls/BottomMetal_Straight.gltf"
  "glTF/Walls/BottomMetal_Straight.bin"
  "glTF/Platforms/Platform_Metal.gltf"
  "glTF/Platforms/Platform_Metal.bin"
  "glTF/Columns/Column_Astra.gltf"
  "glTF/Columns/Column_Astra.bin"
  "glTF/Props/Prop_Light_Wide.gltf"
  "glTF/Props/Prop_Light_Wide.bin"
  "glTF/Props/Prop_Vent_Wide.gltf"
  "glTF/Props/Prop_Vent_Wide.bin"
  "glTF/Props/Prop_Cable_1.gltf"
  "glTF/Props/Prop_Cable_1.bin"
)
readonly MEGAKIT_TEXTURES=(
  "Textures/T_Trim_01_BaseColor_Red.png"
  "Textures/T_Trim_01_Normal.png"
  "Textures/T_Trim_01_ORM.png"
  "Textures/T_Trim_02_BaseColor_Red.png"
  "Textures/T_Trim_02_Normal.png"
  "Textures/T_Trim_02_ORM.png"
  "Textures/T_Trim_03_BaseColor.png"
  "Textures/T_Trim_03_Cables.png"
  "Textures/T_Trim_03_Normal.png"
  "Textures/T_Trim_03_ORM.png"
)
```

Required behavior:

1. `--print-essentials-manifest` and `--print-megakit-manifest` print the complete source-relative whitelist, including each kit's `License_Standard.txt`, and exit.
2. Validate all arguments and every source file before creating the destination.
3. When the destination is inside a Git worktree, require `git check-ignore -q "$DEST_ROOT"` before copying.
4. Copy each model pair into a flattened destination so glTF sibling URI references resolve.
5. Copy the two `License_Standard.txt` files as `LICENSE_SCI_FI_ESSENTIALS.txt` and `LICENSE_MODULAR_SCI_FI_MEGAKIT.txt`.
6. Print the installed file count and destination.
7. When the destination is in this worktree, re-check every installed file with `git check-ignore` and fail if `git ls-files "$DEST_ROOT"` returns any path.

- [ ] **Step 5: Run the isolated setup test to verify GREEN**

Run:

```bash
bash test/tools/test_setup_quaternius_local_assets.sh
```

Expected: PASS with exact whitelist output and missing-dependency rejection.

- [ ] **Step 6: Install the real local slice**

Run with the user-provided sources:

```bash
tools/setup_quaternius_local_assets.sh \
  '/Users/adam/Downloads/Sci-Fi Essentials Kit[Standard]' \
  '/Users/adam/Downloads/Modular SciFi MegaKit[Standard]'
```

Then prove nothing under the vendor root is tracked or staged:

```bash
git check-ignore -v assets/graphics/models/quaternius_local/enemies/eye_drone/Enemy_EyeDrone.gltf
git ls-files assets/graphics/models/quaternius_local
git diff --cached --name-only | rg '^assets/graphics/models/quaternius_local/'
```

Expected: `git check-ignore` names the new rule; both later commands print nothing.

- [ ] **Step 7: Write the tracked manifest and index it**

Document the exact source paths, destination tree, CC0 license, setup command, warning that Git LFS is intentionally unused, and recovery steps. Add one link under `docs/README.md` Design and Engineering or Development and Testing.

- [ ] **Step 8: Commit only policy, installer, test, and documentation**

```bash
git add .gitignore tools/setup_quaternius_local_assets.sh \
  test/tools/test_setup_quaternius_local_assets.sh \
  docs/assets/quaternius-local-assets.md docs/README.md
git diff --cached --name-only
git commit -m "build: guard curated local battle assets"
```

Expected staged list: exactly the five tracked paths above; no vendor binary.

---

### Task 2: Add the Optional Local Model Loader

**Files:**
- Create: `src/battle/presentation/optional_local_model_3d.gd`
- Create: `src/battle/presentation/optional_local_model_3d.gd.uid`
- Create: `test/fixtures/presentation/optional_model_fixture.tscn`
- Create: `test/unit/test_optional_local_model_3d.gd`
- Create: `test/unit/test_optional_local_model_3d.gd.uid`

**Interfaces:**
- Consumes: a string `local_resource_path`, a `Node3D` `model_parent`, and a tracked `Node3D` placeholder.
- Produces: `class_name OptionalLocalModel3D`, `signal model_loaded(instance: Node3D)`, `signal model_unavailable(path: String)`, `try_load() -> bool`, `clear_loaded_model() -> void`, `loaded_model: Node3D`, and `using_placeholder: bool`.

- [ ] **Step 1: Write failing loader tests**

Cover an existing tracked fixture and a missing ignored-style path:

```gdscript
extends GutTest

func _loader(path: String) -> OptionalLocalModel3D:
	var loader := OptionalLocalModel3D.new()
	loader.local_resource_path = path
	loader.model_parent = Node3D.new()
	loader.placeholder = Node3D.new()
	loader.add_child(loader.model_parent)
	loader.add_child(loader.placeholder)
	add_child_autofree(loader)
	return loader

func test_existing_packed_scene_replaces_placeholder() -> void:
	var loader := _loader(
		"res://test/fixtures/presentation/optional_model_fixture.tscn",
	)
	assert_true(loader.try_load())
	assert_not_null(loader.loaded_model)
	assert_false(loader.placeholder.visible)
	assert_false(loader.using_placeholder)

func test_missing_scene_keeps_placeholder_without_partial_child() -> void:
	var loader := _loader(
		"res://assets/graphics/models/quaternius_local/missing.gltf",
	)
	assert_false(loader.try_load())
	assert_null(loader.loaded_model)
	assert_true(loader.placeholder.visible)
	assert_true(loader.using_placeholder)
	assert_eq(loader.model_parent.get_child_count(), 0)

func test_reload_clears_the_prior_instance_exactly_once() -> void:
	var loader := _loader(
		"res://test/fixtures/presentation/optional_model_fixture.tscn",
	)
	assert_true(loader.try_load())
	var first := loader.loaded_model
	assert_true(loader.try_load())
	assert_false(is_instance_valid(first))
	assert_eq(loader.model_parent.get_child_count(), 1)
```

- [ ] **Step 2: Run focused tests to verify RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" -s addons/gut/gut_cmdln.gd \
  -gselect optional_local_model_3d -gexit
```

Expected: parse/test failure because `OptionalLocalModel3D` is undefined.

- [ ] **Step 3: Implement the loader without hard resource references**

Use the approved string boundary:

```gdscript
@tool
extends Node3D
class_name OptionalLocalModel3D

signal model_loaded(instance: Node3D)
signal model_unavailable(path: String)

@export_file("*.tscn,*.gltf,*.glb,*.fbx") var local_resource_path := ""
@export var model_parent: Node3D
@export var placeholder: Node3D

var loaded_model: Node3D
var using_placeholder := true
static var _warned_paths: Dictionary = {}

func try_load() -> bool:
	clear_loaded_model()
	if local_resource_path.is_empty() or not ResourceLoader.exists(local_resource_path):
		_show_placeholder()
		_warn_once(local_resource_path)
		model_unavailable.emit(local_resource_path)
		return false
	var packed := load(local_resource_path) as PackedScene
	if packed == null:
		_show_placeholder()
		_warn_once(local_resource_path)
		model_unavailable.emit(local_resource_path)
		return false
	var instance := packed.instantiate() as Node3D
	if instance == null:
		_show_placeholder()
		_warn_once(local_resource_path)
		model_unavailable.emit(local_resource_path)
		return false
	model_parent.add_child(instance)
	loaded_model = instance
	using_placeholder = false
	placeholder.visible = false
	model_loaded.emit(instance)
	return true

func clear_loaded_model() -> void:
	if is_instance_valid(loaded_model):
		loaded_model.free()
	loaded_model = null

func _show_placeholder() -> void:
	using_placeholder = true
	if is_instance_valid(placeholder):
		placeholder.visible = true
```

Add null-node guards that return `false` and warn clearly rather than asserting. `_warn_once()` uses the static dictionary to suppress duplicate warnings for five instances of the same missing model.

- [ ] **Step 4: Run loader tests and import to verify GREEN**

Run the commands from Step 2. Expected: all loader tests pass; import exits 0 without parser errors.

- [ ] **Step 5: Commit the loader boundary**

```bash
git add src/battle/presentation/optional_local_model_3d.gd \
  src/battle/presentation/optional_local_model_3d.gd.uid \
  test/fixtures/presentation/optional_model_fixture.tscn \
  test/unit/test_optional_local_model_3d.gd \
  test/unit/test_optional_local_model_3d.gd.uid
git commit -m "feat: add optional local model loader"
```

---

### Task 3: Persist Combat Motion Intensity and Expose the Options Slider

**Files:**
- Create: `src/singletons/combat_presentation_settings.gd`
- Create: `src/singletons/combat_presentation_settings.gd.uid`
- Modify: `project.godot`
- Create: `src/hub/options_panel.gd`
- Create: `src/hub/options_panel.gd.uid`
- Create: `src/hub/options_panel.tscn`
- Modify: `src/hub/party_menu.gd`
- Modify: `src/hub/party_menu.tscn`
- Create: `test/unit/test_combat_presentation_settings.gd`
- Create: `test/unit/test_combat_presentation_settings.gd.uid`
- Modify: `test/integration/test_hub_progression.gd`

**Interfaces:**
- Produces: autoload `CombatPresentationSettings`, `signal shake_intensity_changed(value: float)`, `shake_intensity: float`, `set_shake_intensity(value: float, persist := true)`, `load_settings()`, and `configure_storage_path_for_tests(path: String)`.
- Produces: `OptionsPanel.focus_default() -> Control` and controller-focusable `HSlider` range `0.0..1.0` with step `0.05`.
- Consumes later: `CombatPresentationSettings.shake_intensity` from camera and UI feedback.

- [ ] **Step 1: Write failing settings tests with isolated storage**

```gdscript
extends GutTest

var _settings: CombatPresentationSettingsService
var _storage_path: String

func before_each() -> void:
	_storage_path = "user://test-combat-settings-%s.cfg" % get_instance_id()
	_settings = CombatPresentationSettingsService.new()
	_settings.configure_storage_path_for_tests(_storage_path)

func after_each() -> void:
	if FileAccess.file_exists(_storage_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_storage_path))
	_settings.free()

func test_intensity_clamps_and_emits_normalized_value() -> void:
	watch_signals(_settings)
	_settings.set_shake_intensity(1.7, false)
	assert_eq(_settings.shake_intensity, 1.0)
	assert_signal_emitted_with_parameters(
		_settings, "shake_intensity_changed", [1.0],
	)

func test_zero_persists_and_reloads_as_off() -> void:
	_settings.set_shake_intensity(0.0)
	var restored := CombatPresentationSettingsService.new()
	restored.configure_storage_path_for_tests(_storage_path)
	restored.load_settings()
	assert_eq(restored.shake_intensity, 0.0)
	restored.free()
```

- [ ] **Step 2: Run settings tests to verify RED**

Run import, then:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" -s addons/gut/gut_cmdln.gd \
  -gselect combat_presentation_settings -gexit
```

Expected: FAIL because the service class does not exist.

- [ ] **Step 3: Implement clamped ConfigFile persistence**

Use a named service class so unit tests do not mutate the autoload:

```gdscript
extends Node
class_name CombatPresentationSettingsService

signal shake_intensity_changed(value: float)

const DEFAULT_SHAKE_INTENSITY := 0.35
const SECTION := "combat_presentation"
const KEY := "shake_intensity"

var shake_intensity := DEFAULT_SHAKE_INTENSITY
var _storage_path := "user://presentation_settings.cfg"

func _ready() -> void:
	load_settings()

func set_shake_intensity(value: float, persist := true) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(shake_intensity, clamped):
		return
	shake_intensity = clamped
	shake_intensity_changed.emit(shake_intensity)
	if persist:
		_save_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(_storage_path) == OK:
		shake_intensity = clampf(
			float(config.get_value(SECTION, KEY, DEFAULT_SHAKE_INTENSITY)),
			0.0,
			1.0,
		)

func configure_storage_path_for_tests(path: String) -> void:
	_storage_path = path
```

Register it as `CombatPresentationSettings` in `project.godot`.

- [ ] **Step 4: Run settings tests to verify GREEN**

Run the focused command from Step 2. Expected: all tests pass and test files are removed during teardown.

- [ ] **Step 5: Write failing Options-panel integration tests**

Add tests that enter the Options tab, assert the slider is the enabled default content control, move it through its public handler, and verify controller hints/focus stay owned by `PartyMenu`:

```gdscript
func test_options_tab_focuses_shake_slider_and_updates_setting() -> void:
	var menu := _ready_party_menu()
	menu._show_tab(PartyMenu.Tab.OPTIONS)
	var slider := menu.options_view.shake_slider
	assert_true(slider.visible)
	assert_eq(menu._content_default_focus(), slider)
	slider.value = 0.0
	slider.value_changed.emit(0.0)
	assert_eq(CombatPresentationSettings.shake_intensity, 0.0)
```

Use the test's existing autoload-state save/restore pattern so the real user setting is restored in teardown.

- [ ] **Step 6: Replace only the Options placeholder**

Create this focus structure:

```text
OptionsPanel (Control)
└── CenterContainer
    └── VBoxContainer
        ├── Title (Label: "COMBAT MOTION")
        ├── ShakeRow (HBoxContainer)
        │   ├── Label ("SHAKE INTENSITY")
        │   ├── ShakeSlider (HSlider, 0..1, step 0.05)
        │   └── Value (Label, "35%")
        └── Help (Label: "Set to 0% to disable camera and panel shake.")
```

`OptionsPanel` initializes from the autoload, updates the percent label, and calls `set_shake_intensity(value)`. Modify `PartyMenu` so Options participates in its existing content-depth focus and back behavior. Leave Journal as Coming Soon.

- [ ] **Step 7: Run hub and settings tests**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" -s addons/gut/gut_cmdln.gd \
  -gselect combat_presentation_settings -gselect hub_progression -gexit
```

Expected: settings and existing hub navigation tests all pass.

- [ ] **Step 8: Commit settings and Options UI**

```bash
git add project.godot src/singletons/combat_presentation_settings.gd \
  src/singletons/combat_presentation_settings.gd.uid \
  src/hub/options_panel.gd src/hub/options_panel.gd.uid \
  src/hub/options_panel.tscn src/hub/party_menu.gd src/hub/party_menu.tscn \
  test/unit/test_combat_presentation_settings.gd \
  test/unit/test_combat_presentation_settings.gd.uid \
  test/integration/test_hub_progression.gd
git commit -m "feat: add combat motion preference"
```

---

### Task 4: Build Deterministic W/M Formations and the Battle World

**Files:**
- Create: `src/battle/presentation/battle_formation_layout.gd`
- Create: `src/battle/presentation/battle_formation_layout.gd.uid`
- Create: `src/battle/presentation/battle_world_3d.gd`
- Create: `src/battle/presentation/battle_world_3d.gd.uid`
- Create: `src/battle/presentation/battle_world_3d.tscn`
- Create: `src/battle/presentation/industrial_room_3d.tscn`
- Modify: `src/scripts/enemies/encounter.gd`
- Create: `test/unit/test_battle_formation_layout.gd`
- Create: `test/unit/test_battle_formation_layout.gd.uid`
- Create: `test/integration/test_battle_world_3d.gd`
- Create: `test/integration/test_battle_world_3d.gd.uid`

**Interfaces:**
- Produces: `BattleFormationLayout.Layout { W, M }`, `ordinary_transforms(count: int, layout: Layout) -> Array[Transform3D]`, and `boss_transforms(ally_count: int) -> Dictionary`.
- Produces: `BattleWorld3D.enemy_views: Node3D`, `camera: Camera3D`, `hud_layer: Control`, `place_ordinary_view(view_root: Node3D, index: int, total: int, layout: BattleFormationLayout.Layout) -> bool`, and `place_boss_view(view_root: Node3D, ally_index := -1) -> bool`.
- Adds: `Encounter.enemy_formation: BattleFormationLayout.Layout = BattleFormationLayout.Layout.W`.

- [ ] **Step 1: Write failing pure formation tests**

Define exact expected positions in camera-facing coordinates:

```gdscript
extends GutTest

func _positions(transforms: Array[Transform3D]) -> Array[Vector3]:
	var values: Array[Vector3] = []
	for value: Transform3D in transforms:
		values.append(value.origin)
	return values

func test_five_unit_w_uses_three_back_and_two_front() -> void:
	assert_eq(_positions(BattleFormationLayout.ordinary_transforms(
		5, BattleFormationLayout.Layout.W,
	)), [
		Vector3(-3.6, 0.0, -1.0), Vector3(0.0, 0.0, -1.4),
		Vector3(3.6, 0.0, -1.0), Vector3(-1.8, 0.0, 1.0),
		Vector3(1.8, 0.0, 1.0),
	])

func test_five_unit_m_uses_two_back_and_three_front() -> void:
	assert_eq(_positions(BattleFormationLayout.ordinary_transforms(
		5, BattleFormationLayout.Layout.M,
	)), [
		Vector3(-1.8, 0.0, -1.0), Vector3(1.8, 0.0, -1.0),
		Vector3(-3.6, 0.0, 1.0), Vector3(0.0, 0.0, 1.4),
		Vector3(3.6, 0.0, 1.0),
	])

func test_counts_keep_authored_depth_and_reject_six() -> void:
	assert_eq(BattleFormationLayout.ordinary_transforms(3, BattleFormationLayout.Layout.W).size(), 3)
	assert_eq(BattleFormationLayout.ordinary_transforms(3, BattleFormationLayout.Layout.M).size(), 3)
	assert_push_error("supports at most five ordinary enemies")
	assert_true(BattleFormationLayout.ordinary_transforms(6, BattleFormationLayout.Layout.W).is_empty())

func test_boss_reserves_center_volume_and_two_outer_allies() -> void:
	var layout := BattleFormationLayout.boss_transforms(2)
	assert_eq(layout.boss.origin, Vector3(0.0, 0.0, 0.0))
	assert_eq(layout.left_ally.origin.x, -4.4)
	assert_eq(layout.right_ally.origin.x, 4.4)
```

Also assert authored one-through-four slot choices explicitly; do not implement them as `five_slots.slice(0, count)` because that creates unbalanced subsets.

- [ ] **Step 2: Run formation tests to verify RED**

Run import and `-gselect battle_formation_layout`. Expected: FAIL because the class is undefined.

- [ ] **Step 3: Implement the pure layout table**

Use explicit arrays for every count and layout:

```gdscript
extends RefCounted
class_name BattleFormationLayout

enum Layout { W, M }

const W_POSITIONS := {
	1: [Vector3(0.0, 0.0, -1.4)],
	2: [Vector3(-1.8, 0.0, 1.0), Vector3(1.8, 0.0, 1.0)],
	3: [Vector3(-3.6, 0.0, -1.0), Vector3(0.0, 0.0, -1.4), Vector3(3.6, 0.0, -1.0)],
	4: [Vector3(-3.6, 0.0, -1.0), Vector3(3.6, 0.0, -1.0), Vector3(-1.8, 0.0, 1.0), Vector3(1.8, 0.0, 1.0)],
	5: [Vector3(-3.6, 0.0, -1.0), Vector3(0.0, 0.0, -1.4), Vector3(3.6, 0.0, -1.0), Vector3(-1.8, 0.0, 1.0), Vector3(1.8, 0.0, 1.0)],
}
```

Define the corresponding M table and convert each position to `Transform3D(Basis.IDENTITY, position)`.

- [ ] **Step 4: Run formation tests to verify GREEN**

Expected: every count, both layouts, count rejection, and boss reservations pass.

- [ ] **Step 5: Write failing BattleWorld placement tests**

Instantiate the world scene with placeholders, add five plain Node3D roots, and assert the world places them at the pure transforms without reparenting them outside `EnemyViews`. Assert a sixth returns `false` without moving or adopting it.

- [ ] **Step 6: Create the world and room scenes**

Use this stable tree:

```text
BattleWorld3D (Node3D, BattleWorld3D script)
├── WorldEnvironment
├── CameraRig (Node3D)
│   └── BattleCamera (Camera3D, current=true)
├── IndustrialRoom3D (Node3D instance)
├── EnemyViews (Node3D)
└── EnemyHUDCanvas (CanvasLayer)
    └── EnemyHUDLayer (Control, full viewport, mouse_filter=IGNORE)
```

`IndustrialRoom3D` contains eight `OptionalLocalModel3D` nodes with exact local string paths. Each has simple tracked BoxMesh/CylinderMesh fallback geometry. Use Godot DirectionalLight3D/OmniLight3D nodes for lighting; do not require a local light mesh to illuminate the room.

- [ ] **Step 7: Add encounter formation data and run world tests**

Add the exported enum with a default preserving existing encounters:

```gdscript
@export_group("Presentation")
@export var enemy_formation: BattleFormationLayout.Layout = BattleFormationLayout.Layout.W
```

Run `-gselect battle_formation_layout -gselect battle_world_3d -gselect enemy_content`. Expected: all focused tests pass and existing encounter resources parse without edits.

- [ ] **Step 8: Commit formation and world**

```bash
git add src/battle/presentation/battle_formation_layout.gd \
  src/battle/presentation/battle_formation_layout.gd.uid \
  src/battle/presentation/battle_world_3d.gd \
  src/battle/presentation/battle_world_3d.gd.uid \
  src/battle/presentation/battle_world_3d.tscn \
  src/battle/presentation/industrial_room_3d.tscn \
  src/scripts/enemies/encounter.gd \
  test/unit/test_battle_formation_layout.gd \
  test/unit/test_battle_formation_layout.gd.uid \
  test/integration/test_battle_world_3d.gd \
  test/integration/test_battle_world_3d.gd.uid
git commit -m "feat: add 3d battle world formations"
```

---

### Task 5: Extract Intent Formatting and Build the Projected Enemy HUD

**Files:**
- Create: `src/battle/presentation/enemy_intent_formatter.gd`
- Create: `src/battle/presentation/enemy_intent_formatter.gd.uid`
- Create: `src/battle/presentation/enemy_hud_layout.gd`
- Create: `src/battle/presentation/enemy_hud_layout.gd.uid`
- Create: `src/battle/presentation/enemy_world_hud.gd`
- Create: `src/battle/presentation/enemy_world_hud.gd.uid`
- Create: `src/battle/presentation/enemy_world_hud.tscn`
- Modify: `src/battle/presentation/battle_world_3d.gd`
- Modify: `src/battle/presentation/battle_world_3d.tscn`
- Modify: `src/battle/enemy_card.gd`
- Create: `test/unit/test_enemy_intent_formatter.gd`
- Create: `test/unit/test_enemy_intent_formatter.gd.uid`
- Create: `test/unit/test_enemy_hud_layout.gd`
- Create: `test/unit/test_enemy_hud_layout.gd.uid`
- Create: `test/unit/test_enemy_world_hud.gd`
- Create: `test/unit/test_enemy_world_hud.gd.uid`
- Modify: `test/integration/test_enemy_ai_intents.gd`

**Interfaces:**
- Produces: `EnemyIntentFormatter.format(enemy: EnemyCombatant, manager: BattleManager) -> Dictionary` with keys `text: String` and `tooltip: String`.
- Produces: `EnemyHUDLayout.resolve(desired_rects: Array[Rect2], safe_rect: Rect2, gap := 6.0) -> Array[Rect2]`.
- Produces: `EnemyWorldHUD.bind_combatant(enemy: EnemyCombatant) -> bool`, `set_target_state(state: CombatantPresentation.TargetState)`, `set_details_visible(visible: bool)`, `set_projected_head_position(position: Vector2)`, `refresh_intent()`, `get_target_rect() -> Rect2`, and signals `hovered`, `unhovered`, `pressed`.
- Consumes: existing combatant signals and `Condition.icon`; it does not mutate combatant data.

- [ ] **Step 1: Write intent-formatter characterization tests**

Move representative current expectations behind the new API before changing `EnemyCard`:

```gdscript
func test_single_target_damage_preserves_amount_type_hits_and_target() -> void:
	var enemy := _enemy_with_locked_damage_intent()
	var result := EnemyIntentFormatter.format(enemy, _manager)
	assert_string_contains(result.text, "25")
	assert_string_contains(result.text, "ASHE")
	assert_string_contains(result.tooltip, enemy.intended_action.action_name)

func test_non_damage_intent_preserves_action_and_everyone_suffix() -> void:
	var enemy := _enemy_with_support_intent(Action.TargetType.ALL_ALLIES)
	var result := EnemyIntentFormatter.format(enemy, _manager)
	assert_eq(result.text, "%s EVERYONE" % enemy.intended_action.action_name)
```

Cover random multi-hit, everyone, single named target, and missing intent.

- [ ] **Step 2: Run formatter tests to verify RED**

Run `-gselect enemy_intent_formatter -gselect enemy_ai_intents`. Expected: new tests fail because the formatter does not exist; existing intent tests still pass.

- [ ] **Step 3: Extract the formatter and make EnemyCard consume it**

The public method returns data only:

```gdscript
extends RefCounted
class_name EnemyIntentFormatter

static func format(enemy: EnemyCombatant, manager: BattleManager) -> Dictionary:
	if enemy == null or enemy.intended_action == null:
		return {"text": "", "tooltip": ""}
	var targets: Array[BattleCombatant] = []
	targets.assign(enemy.intended_targets)
	var text := _format_text(enemy, targets, manager)
	var tooltip_target: BattleCombatant = targets[0] if targets.size() == 1 else null
	return {
		"text": text,
		"tooltip": enemy.intended_action.get_rich_description(
			enemy, tooltip_target, targets, manager,
		),
	}
```

Move the existing damage-preview and suffix logic without altering math or wording. `EnemyCard._update_intent_ui()` becomes an assignment from this result.

- [ ] **Step 4: Run formatter and AI intent tests to verify GREEN**

Expected: characterization and all existing AI intent tests pass with unchanged text.

- [ ] **Step 5: Write failing deterministic layout tests**

Cover one HUD at each safe-area edge and five deliberately overlapping HUDs. The resolver must preserve input order, keep every result inside the safe rectangle, return the same output for the same input, and leave already non-overlapping rectangles unchanged. Its algorithm is fixed: clamp desired rectangles; process them in ascending desired-center Y, then X, then original index; shift each collision upward by `prior.position.y - current.size.y - gap`; if the resolved group crosses the safe top, translate the complete group downward just enough to fit, then clamp once more. Five compact HUDs must fit the supported `1280x800` safe area; an impossible input returns an empty array and pushes one clear error.

- [ ] **Step 6: Implement the pure safe-area and overlap resolver**

Keep `EnemyHUDLayout` stateless and independent of scene nodes. Return results in original input order even though collision processing uses the documented stable sort. Add exact expected-rectangle assertions rather than only intersection checks.

- [ ] **Step 7: Write failing HUD binding and reveal tests**

```gdscript
func test_compact_stack_orders_intent_guard_hp_and_conditions() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(80, 3)
	assert_true(hud.bind_combatant(enemy))
	assert_true(hud.intent_row.get_index() < hud.vitals_row.get_index())
	assert_true(hud.vitals_row.get_index() < hud.conditions_row.get_index())
	assert_eq(hud.guard_value.text, "3")
	assert_eq(hud.hp_bar.value, 80.0)

func test_details_reveal_does_not_reflow_compact_stack() -> void:
	var hud := _hud()
	hud.bind_combatant(_enemy_with_state(80, 3))
	var compact_position := hud.compact_stack.position
	hud.set_details_visible(true)
	assert_true(hud.details.visible)
	assert_eq(hud.compact_stack.position, compact_position)

func test_rebinding_is_rejected_and_teardown_disconnects_model() -> void:
	var hud := _hud()
	var first := _enemy_with_state(80, 3)
	var second := _enemy_with_state(50, 0)
	assert_true(hud.bind_combatant(first))
	assert_false(hud.bind_combatant(second))
	hud.free()
	first.hp_changed.emit(first, 10)
```

- [ ] **Step 8: Build the compact HUD scene and model-only rendering**

Use this node order:

```text
EnemyWorldHUD (Control)
├── TargetRegion (Control, mouse_filter=STOP)
├── Details (MarginContainer, initially transparent/hidden)
│   └── VBoxContainer
│       ├── Name (Label)
│       └── Defenses (HBoxContainer: Kinetic, Energy)
└── CompactStack (VBoxContainer)
    ├── IntentRow (RichTextLabel)
    ├── VitalsRow (HBoxContainer)
    │   ├── GuardIcon (TextureRect)
    │   ├── GuardValue (Label)
    │   └── HP (TextureProgressBar)
    └── ConditionsRow (HBoxContainer)
```

Use condition icons directly in small TextureRects with existing tooltip behavior where practical. All signal handlers read from the bound `EnemyCombatant`; no HP, Guard, defense, Intent, or condition state is stored independently beyond current rendered values.

`BattleWorld3D.hud_layer` runs one layout pass after all visible presentations update their desired head positions. It feeds compact desired rectangles to `EnemyHUDLayout.resolve()`, applies the resolved positions in stable combatant spawn order, and hides overlays whose projection is behind the camera. Expanded details use a fading overlay that does not change the compact rectangle supplied to the resolver. The projected head/foot pair also sizes a padded `TargetRegion`, allowing mouse targeting across the visible model instead of only over the text.

- [ ] **Step 9: Run HUD, card, and intent tests**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" -s addons/gut/gut_cmdln.gd \
  -gselect enemy_hud_layout -gselect enemy_world_hud \
  -gselect actor_card_target_presentation \
  -gselect card_combatant_binding -gselect enemy_ai_intents -gexit
```

Expected: all focused tests pass; the existing card remains a valid fallback.

- [ ] **Step 10: Commit intent extraction and HUD**

```bash
git add src/battle/presentation/enemy_intent_formatter.gd \
  src/battle/presentation/enemy_intent_formatter.gd.uid \
  src/battle/presentation/enemy_hud_layout.gd \
  src/battle/presentation/enemy_hud_layout.gd.uid \
  src/battle/presentation/enemy_world_hud.gd \
  src/battle/presentation/enemy_world_hud.gd.uid \
  src/battle/presentation/enemy_world_hud.tscn \
  src/battle/presentation/battle_world_3d.gd \
  src/battle/presentation/battle_world_3d.tscn \
  src/battle/enemy_card.gd \
  test/unit/test_enemy_intent_formatter.gd \
  test/unit/test_enemy_intent_formatter.gd.uid \
  test/unit/test_enemy_hud_layout.gd \
  test/unit/test_enemy_hud_layout.gd.uid \
  test/unit/test_enemy_world_hud.gd \
  test/unit/test_enemy_world_hud.gd.uid \
  test/integration/test_enemy_ai_intents.gd
git commit -m "feat: add projected enemy hud"
```

---

### Task 6: Implement the Reusable EyeDrone Presentation

**Files:**
- Create: `src/battle/presentation/enemy_drone_presentation.gd`
- Create: `src/battle/presentation/enemy_drone_presentation.gd.uid`
- Create: `src/battle/presentation/enemy_drone_presentation.tscn`
- Create: `test/integration/test_enemy_drone_presentation.gd`
- Create: `test/integration/test_enemy_drone_presentation.gd.uid`

**Interfaces:**
- Consumes: `EnemyCombatant`, active viewport `Camera3D`, `BattleWorld3D.hud_layer`, `OptionalLocalModel3D`, and `EnemyWorldHUD`.
- Produces: exactly one nested `CombatantPresentation` per view; `setup_view(value) -> bool`; projected target position/visibility; target input forwarding; Idle/Attack/Hit/Charging animation routing; cancellation-safe defeat and action transitions.

- [ ] **Step 1: Write failing setup and model-reuse tests**

```gdscript
func test_drone_view_binds_enemy_and_adds_one_hud_to_world_layer() -> void:
	var world := _world()
	var view := _drone_view(world)
	var enemy := _enemy()
	assert_true(view.presentation.setup_view(enemy))
	assert_same(view.presentation.combatant, enemy)
	assert_eq(world.hud_layer.get_child_count(), 1)
	assert_same(view.presentation.hud.combatant, enemy)

func test_two_drones_do_not_share_material_or_animation_state() -> void:
	var first := _bound_drone(_world(), _enemy())
	var second := _bound_drone(_world(), _enemy())
	first.presentation.set_instance_tint(Color.CYAN)
	assert_ne(first.presentation.instance_material, second.presentation.instance_material)
	assert_ne(first.presentation.instance_material.albedo_color, second.presentation.instance_material.albedo_color)

func test_wrong_model_and_second_setup_are_rejected() -> void:
	var view := _drone_view(_world())
	assert_false(view.presentation.setup_view(HeroCombatant.new()))
	var enemy := _enemy()
	assert_true(view.presentation.setup_view(enemy))
	assert_false(view.presentation.setup_view(enemy))
```

- [ ] **Step 2: Write failing projection and teardown tests**

Use a real Camera3D with non-default transform and a `1280x800` viewport. Assert `get_target_screen_position()` equals `camera.unproject_position(head_anchor.global_position)`, `is_target_visible()` is false behind the camera, freeing the view removes its HUD, and pending animation operations complete after registry-safe teardown.

- [ ] **Step 3: Run focused tests to verify RED**

Run import and `-gselect enemy_drone_presentation`. Expected: FAIL because the scene and class do not exist.

- [ ] **Step 4: Create the generic Node3D view with exactly one presentation child**

```text
EnemyDroneView (Node3D)
├── ModelPivot (Node3D)
│   ├── OptionalLocalModel3D
│   │   ├── LoadedModel (Node3D)
│   │   └── Placeholder (MeshInstance3D, tracked SphereMesh)
│   ├── HeadAnchor (Marker3D)
│   └── FootAnchor (Marker3D)
└── CombatantPresentation (Node, EnemyDronePresentation script)
```

Set the loader path string to:

```text
res://assets/graphics/models/quaternius_local/enemies/eye_drone/Enemy_EyeDrone.gltf
```

Do not declare it as an ext_resource.

- [ ] **Step 5: Implement binding, HUD ownership, projection, and input forwarding**

The presentation setup must validate the model type, bind through `super`, find the active camera and grouped HUD layer, instantiate one HUD, and connect model signals exactly once:

```gdscript
extends CombatantPresentation
class_name EnemyDronePresentation

const HUD_SCENE := preload("res://src/battle/presentation/enemy_world_hud.tscn")

@export var view_root: Node3D
@export var model_loader: OptionalLocalModel3D
@export var head_anchor: Marker3D
@export var foot_anchor: Marker3D

var camera: Camera3D
var hud: EnemyWorldHUD
var animation_player: AnimationPlayer

func setup_view(value: BattleCombatant) -> bool:
	if not (value is EnemyCombatant):
		push_error("EnemyDronePresentation requires an EnemyCombatant.")
		return false
	if not super.setup_view(value):
		return false
	camera = get_viewport().get_camera_3d()
	var hud_layer := get_tree().get_first_node_in_group(&"battle_enemy_hud_layer") as Control
	if not is_instance_valid(camera) or not is_instance_valid(hud_layer):
		push_error("EnemyDronePresentation requires a battle camera and HUD layer.")
		return false
	hud = HUD_SCENE.instantiate() as EnemyWorldHUD
	hud_layer.add_child(hud)
	if not hud.bind_combatant(value as EnemyCombatant):
		hud.free()
		hud = null
		return false
	_connect_hud_input()
	_connect_combatant_events(value)
	model_loader.try_load()
	return true
```

If any post-bind dependency fails, undo HUD/model connections and leave the view safe for manager rollback; do not rebind the presentation.

- [ ] **Step 6: Implement animation discovery and mapping**

Recursively find the loaded model's AnimationPlayer. Duplicate mesh materials per instance before exposing tint. Use these event rules:

```gdscript
func set_acting(active: bool):
	acting = active
	_play_if_present(&"Charging" if active else &"Idle")
	hud.set_details_visible(active or target_state == TargetState.SELECTED)
	return PresentationOperation.already_completed()

func show_action(_action_name: String) -> void:
	_play_if_present(&"Attack")

func _on_presentation_event(
	_actor: BattleCombatant,
	event: StringName,
	_payload: Dictionary,
) -> void:
	match event:
		&"damage_received":
			_play_if_present(&"Hit")
		&"intent_changed":
			hud.refresh_intent()
		&"defeat_started":
			_begin_shutdown_fade()
```

Connect animation completion back to Idle unless the combatant is defeated. `_begin_shutdown_fade()` disables the target region immediately, fades the model and HUD through a tracked presentation operation, and leaves the view allocated for the encounter teardown path. Missing clips complete immediately and leave combat orchestration untouched. Teardown completes any pending hit, action, or shutdown operation exactly once.

- [ ] **Step 7: Run presentation, operation, and HUD tests**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" -s addons/gut/gut_cmdln.gd \
  -gselect enemy_drone_presentation -gselect enemy_world_hud \
  -gselect presentation_operation_cancellation -gexit
```

Expected: all tests pass with both the local EyeDrone and a forced-missing-path placeholder variant.

- [ ] **Step 8: Commit the reusable drone view**

```bash
git add src/battle/presentation/enemy_drone_presentation.gd \
  src/battle/presentation/enemy_drone_presentation.gd.uid \
  src/battle/presentation/enemy_drone_presentation.tscn \
  test/integration/test_enemy_drone_presentation.gd \
  test/integration/test_enemy_drone_presentation.gd.uid
git commit -m "feat: add reusable eye drone presentation"
```

---

### Task 7: Integrate the 3D World with Battle Spawning and Targeting

**Files:**
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/battle/battle_scene.gd`
- Modify: `src/battle/battle_scene.tscn`
- Modify: `test/integration/test_card_combatant_binding.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `test/integration/test_battle_responsive_layout.gd`
- Modify: `test/integration/test_controller_playable_loop.gd`

**Interfaces:**
- Renames: `hero_card_scene` → `hero_view_scene`, `enemy_card_scene` → `enemy_view_scene`.
- Adds: `BattleManager.battle_world: BattleWorld3D` and `_presentation_view_roots: Dictionary`.
- Produces: `presentation_view_root_for(combatant: BattleCombatant) -> Node` and exact view-root cleanup without parent-climbing assumptions.
- Consumes: `current_encounter.enemy_formation` and `BattleWorld3D.place_ordinary_view()`.

- [ ] **Step 1: Write failing exact-root registry tests**

Extend the generic presentation tests so the manager remembers a nested presentation's instantiated root and frees only that root during rollback/replacement:

```gdscript
func test_nested_presentation_registry_preserves_exact_view_root() -> void:
	var manager := _manager_with_world()
	var enemy := _enemy(manager)
	var presentation := manager._spawn_presentation_view(
		NestedNode3DPresentationScene,
		manager.battle_world.enemy_views,
		enemy,
	)
	var root := manager.presentation_view_root_for(enemy)
	assert_not_null(presentation)
	assert_same(root.get_parent(), manager.battle_world.enemy_views)
	manager.unregister_presentation(enemy)
	assert_null(manager.presentation_view_root_for(enemy))
	assert_true(is_instance_valid(root), "unregister detaches registry but caller owns free")
```

Add rollback coverage proving formation anchors/world roots survive a failed later enemy view.

- [ ] **Step 2: Write failing 3D encounter-spawn tests**

Spawn five enemies with a test Node3D presentation, assert all roots are direct children of `EnemyViews`, and compare their transforms to the selected W or M layout. Assert every enemy still maps to its own combatant and projected target position.

- [ ] **Step 3: Run binding and controller tests to verify RED**

Run `-gselect card_combatant_binding -gselect battle_controller_navigation`. Expected: new exact-root/world placement tests fail under the old card-area spawning path.

- [ ] **Step 4: Replace parent-climbing cleanup with exact root ownership**

In `_spawn_presentation_view`, record the root only after setup and registration both succeed:

```gdscript
if not register_presentation(combatant, presentation):
	view_root.free()
	return null
_presentation_view_roots[combatant] = view_root
return presentation
```

`presentation_view_root_for()` prunes invalid values. `unregister_presentation()` removes the mapping only after registry state is stable. `_discard_encounter_spawn()` retrieves and frees the exact root; it never climbs into or frees `EnemyViews`, the room, or a formation anchor.

- [ ] **Step 5: Rename packed-scene exports and route enemies into the world**

Update scene links and spawn flow:

```gdscript
@export var battle_world: BattleWorld3D
@export var hero_view_scene: PackedScene
@export var enemy_view_scene: PackedScene
```

Heroes still spawn under the existing hero UI container. Create all enemy models first, then spawn each enemy view under `battle_world.enemy_views` and place its exact root using total count, index, and `current_encounter.enemy_formation`. This slice always uses ordinary W/M placement, including encounters whose existing encounter-wide `is_boss` flag is true. Keep the pure boss-reservation API tested but unused until a later data change provides one explicit boss-visual combatant; never infer one from spawn order.

- [ ] **Step 6: Replace the battle enemy-card area with BattleWorld3D**

In `battle_scene.tscn`:

1. Instance `BattleWorld3D` before `UI` so Canvas UI renders above it.
2. Set `enemy_view_scene` to `enemy_drone_presentation.tscn`.
3. Keep `hero_view_scene` as `hero_card.tscn`.
4. Hide/remove only `UI/Enemies/HBox`; retain the full-viewport HUD layer inside the world scene.
5. Keep the existing fallback Backdrop but hide it when `BattleWorld3D` is active.

- [ ] **Step 7: Update controller and responsive tests**

Assert directional selection uses each drone presentation's projected head position, wrapping still follows geometry, mouse/controller selection forwards the exact `EnemyCombatant`, and the `1280x800`/`1920x1080` safe rect keeps all five HUDs visible. Do not change face-button action selection or CTB right-stick tests.

- [ ] **Step 8: Run focused integration suites**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$PWD" -s addons/gut/gut_cmdln.gd \
  -gselect card_combatant_binding -gselect battle_controller_navigation \
  -gselect battle_responsive_layout -gselect controller_playable_loop -gexit
```

Expected: all suites pass with the installed local models. Missing-model behavior is covered by the forced-path loader/presentation tests; the asset-free clean-clone proof remains in Task 9 and does not rename the working checkout's ignored directory.

- [ ] **Step 9: Commit battle integration**

```bash
git add src/battle/battle_manager.gd src/battle/battle_scene.gd \
  src/battle/battle_scene.tscn \
  test/integration/test_card_combatant_binding.gd \
  test/integration/test_battle_controller_navigation.gd \
  test/integration/test_battle_responsive_layout.gd \
  test/integration/test_controller_playable_loop.gd
git commit -m "feat: present battle enemies in 3d"
```

---

### Task 8: Add Camera Motion, Lasers, and Shared Impact Feedback

**Files:**
- Create: `src/battle/presentation/battle_camera_rig.gd`
- Create: `src/battle/presentation/battle_camera_rig.gd.uid`
- Create: `src/battle/presentation/battle_projectile_layer.gd`
- Create: `src/battle/presentation/battle_projectile_layer.gd.uid`
- Create: `src/battle/presentation/battle_projectile_layer.tscn`
- Modify: `src/battle/presentation/battle_world_3d.gd`
- Modify: `src/battle/presentation/battle_world_3d.tscn`
- Modify: `src/battle/presentation/combatant_presentation.gd`
- Modify: `src/battle/presentation/enemy_drone_presentation.gd`
- Modify: `src/battle/actor_card.gd`
- Modify: `src/battle/fx_manager.gd`
- Modify: `src/battle/battle_manager.gd`
- Create: `test/unit/test_battle_camera_rig.gd`
- Create: `test/unit/test_battle_camera_rig.gd.uid`
- Create: `test/unit/test_battle_projectile_layer.gd`
- Create: `test/unit/test_battle_projectile_layer.gd.uid`
- Modify: `test/integration/test_card_combatant_binding.gd`

**Interfaces:**
- Produces: `BattleCameraRig.edge_rotation_for(pointer_screen: Vector2, viewport_size: Vector2) -> Vector2`, `request_shake(intensity: float)`, and `set_pointer_screen_position(position: Vector2)`.
- Produces: `BattleProjectileLayer.fire_laser(from_screen: Vector2, to_screen: Vector2, color: Color) -> PresentationOperation`.
- Adds: `CombatantPresentation.projectile_requested(from_screen: Vector2, to_screen: Vector2, effect_type: StringName)`.
- Adds: `FXManager.camera_rig: BattleCameraRig`; `BattleManager` assigns `BattleWorld3D.camera_rig` during setup and clears it during teardown.
- Consumes: `CombatPresentationSettings.shake_intensity`; never reads controller axes.

- [ ] **Step 1: Write failing pure edge-look and shake tests**

```gdscript
func test_edge_rotation_is_centered_clamped_and_symmetric() -> void:
	var rig := BattleCameraRig.new()
	var viewport_size := Vector2(1920, 1080)
	assert_eq(rig.edge_rotation_for(viewport_size * 0.5, viewport_size), Vector2.ZERO)
	var left := rig.edge_rotation_for(Vector2.ZERO, viewport_size)
	var right := rig.edge_rotation_for(Vector2(1920, 0), viewport_size)
	assert_almost_eq(left.y, -right.y, 0.0001)
	assert_true(absf(left.x) <= rig.max_pitch_radians)
	assert_true(absf(left.y) <= rig.max_yaw_radians)

func test_zero_motion_setting_disables_shake() -> void:
	var rig := BattleCameraRig.new()
	rig.shake_scale = 0.0
	rig.request_shake(1.0)
	assert_eq(rig.trauma, 0.0)
```

Add a test that controller ownership leaves the pointer-driven target at zero even when the physical pointer is at an edge.

- [ ] **Step 2: Run camera tests to verify RED**

Run `-gselect battle_camera_rig`. Expected: FAIL because the class does not exist.

- [ ] **Step 3: Implement bounded mouse-only camera motion**

`BattleCameraRig` owns a neutral transform and applies edge offset plus low-amplitude idle drift and trauma noise. Its public pure method normalizes the pointer around viewport center, applies a dead zone, and clamps to approximately 2 degrees pitch and 3 degrees yaw. `_process()` reads `get_viewport().get_mouse_position()` only when `InputManager` reports mouse ownership; otherwise it eases edge rotation to zero. It never reads `Input.get_joy_axis()` or CTB actions.

Multiply trauma and UI panel shake by `CombatPresentationSettings.shake_intensity`. Zero must avoid creating a tween or changing transforms.

- [ ] **Step 4: Write failing projectile tests**

```gdscript
func test_laser_starts_and_ends_at_requested_screen_positions() -> void:
	var layer := _projectile_layer()
	var operation := layer.fire_laser(Vector2(300, 200), Vector2(900, 700), Color.CYAN)
	assert_eq(layer.active_lasers.size(), 1)
	assert_eq(layer.active_lasers[0].points[0], Vector2(300, 200))
	assert_eq(layer.active_lasers[0].points[1], Vector2(900, 700))
	await operation.completed
	assert_true(layer.active_lasers.is_empty())

func test_freeing_layer_completes_pending_laser_operation() -> void:
	var layer := _projectile_layer(60.0)
	var operation := layer.fire_laser(Vector2.ZERO, Vector2.ONE, Color.RED)
	layer.free()
	await get_tree().process_frame
	assert_true(operation.is_completed)
```

- [ ] **Step 5: Implement the screen-space laser and typed routing signal**

Create a full-viewport, mouse-ignoring CanvasLayer/Control using temporary Line2D nodes. Add the typed signal to `CombatantPresentation`. `EnemyDronePresentation.show_action()` computes its own projected head position and the intended hero presentation's target screen position, emits one laser request per visible intended target, and plays Attack.

`BattleManager` connects/disconnects the projectile signal alongside existing presentation signals and forwards it to `BattleWorld3D.projectile_layer`. The layer's operation completes on tween finish or layer teardown.

- [ ] **Step 6: Route hit feedback through the shared setting**

`ActorCard.shake_panel()` computes effective intensity as:

```gdscript
var effective_intensity := clampf(intensity, 0.0, 1.0) \
	* CombatPresentationSettings.shake_intensity
if is_zero_approx(effective_intensity):
	return
```

`FXManager.trigger_shake()` forwards to its assigned `camera_rig.request_shake()` when that valid rig exists. `BattleManager` owns the reference wiring, so `FXManager` does not search the tree or depend on a scene path. Extend the manager's existing combatant signal connection lifecycle with one presentation-event callback: on `impact`, call `trigger_shake()` only when the impacted combatant is a `HeroCombatant`; enemy impacts retain local model feedback without moving the player's camera. Enemy attacks still damage model state through the existing action pipeline; laser, panel flash, and camera shake are consumers only.

- [ ] **Step 7: Run camera, projectile, card, and controller tests**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' \
  --headless --path "$PWD" -s addons/gut/gut_cmdln.gd \
  -gselect battle_camera_rig -gselect battle_projectile_layer \
  -gselect card_combatant_binding -gselect battle_controller_navigation \
  -gselect turn_queue -gexit
```

Expected: effects and cancellation pass; right-stick CTB scrolling and controller target navigation remain unchanged.

- [ ] **Step 8: Commit motion and impact feedback**

```bash
git add src/battle/presentation/battle_camera_rig.gd \
  src/battle/presentation/battle_camera_rig.gd.uid \
  src/battle/presentation/battle_projectile_layer.gd \
  src/battle/presentation/battle_projectile_layer.gd.uid \
  src/battle/presentation/battle_projectile_layer.tscn \
  src/battle/presentation/battle_world_3d.gd \
  src/battle/presentation/battle_world_3d.tscn \
  src/battle/presentation/combatant_presentation.gd \
  src/battle/presentation/enemy_drone_presentation.gd \
  src/battle/actor_card.gd src/battle/fx_manager.gd src/battle/battle_manager.gd \
  test/unit/test_battle_camera_rig.gd test/unit/test_battle_camera_rig.gd.uid \
  test/unit/test_battle_projectile_layer.gd \
  test/unit/test_battle_projectile_layer.gd.uid \
  test/integration/test_card_combatant_binding.gd
git commit -m "feat: add first person battle feedback"
```

---

### Task 9: Final Verification, Clean-Clone Proof, and Manual Acceptance Record

**Files:**
- Modify: `docs/testing/ctb-combat-checklist.md`

**Interfaces:**
- Consumes: completed local 3D slice and source commit hash.
- Produces: exact automated evidence, explicit local-asset status, and unchecked/manual results that distinguish automation from hands-on acceptance.

- [ ] **Step 1: Run project import and all focused risk suites in the working checkout**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' \
  --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' \
  --headless --path "$PWD" -s addons/gut/gut_cmdln.gd \
  -gselect optional_local_model_3d -gselect combat_presentation_settings \
  -gselect battle_formation_layout -gselect battle_world_3d \
  -gselect enemy_world_hud -gselect enemy_drone_presentation \
  -gselect card_combatant_binding -gselect battle_controller_navigation \
  -gselect battle_responsive_layout -gselect controller_playable_loop \
  -gselect presentation_operation_cancellation -gselect turn_queue -gexit
```

Expected: import exits 0 without parser errors; every focused suite passes. The known user-modified battle-lab fixture may affect only its existing full-suite assertion and must not be changed.

- [ ] **Step 2: Run the complete suite with exact totals**

```bash
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' \
  --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Expected: all task-related tests pass. Record exact tests/assertions. If the sole failure is still the protected dirty `endgame_battle_lab.tscn` multiplier mismatch, report it separately and do not alter the scene.

- [ ] **Step 3: Commit source before exact clean verification**

If verification fixes changed tracked source/tests, stage only task files and create a source commit. Record its full SHA. Do not include checklist evidence in that source commit.

- [ ] **Step 4: Prove a clean exact-source clone works without vendor assets**

Create a temporary shared clone at the exact source SHA. Confirm `assets/graphics/models/quaternius_local/` does not exist. Run the headless import twice so the first pass may build asset caches, then run the complete suite with a fresh isolated HOME:

```bash
VERIFY_ROOT=$(mktemp -d /private/tmp/mars-3d-clean-XXXXXX)
VERIFY_HOME=$(mktemp -d /private/tmp/mars-3d-home-XXXXXX)
git clone --shared --no-checkout /Users/adam/github/mars "$VERIFY_ROOT/repo"
git -C "$VERIFY_ROOT/repo" checkout --detach SOURCE_SHA
test ! -e "$VERIFY_ROOT/repo/assets/graphics/models/quaternius_local"
env HOME="$VERIFY_HOME" '/Applications/Godot 4.7.app/Contents/MacOS/Godot' \
  --headless --path "$VERIFY_ROOT/repo" --editor --quit
env HOME="$VERIFY_HOME" '/Applications/Godot 4.7.app/Contents/MacOS/Godot' \
  --headless --path "$VERIFY_ROOT/repo" --editor --quit
env HOME="$VERIFY_HOME" '/Applications/Godot 4.7.app/Contents/MacOS/Godot' \
  --headless --path "$VERIFY_ROOT/repo" -s addons/gut/gut_cmdln.gd -gexit
```

Replace `SOURCE_SHA` with the actual full hash in the executed command and checklist record. Expected: clean import and complete suite exit 0 using placeholders with no missing-resource parser errors.

- [ ] **Step 5: Audit Git safety after local import**

```bash
git check-ignore -v assets/graphics/models/quaternius_local/enemies/eye_drone/Enemy_EyeDrone.gltf
git ls-files assets/graphics/models/quaternius_local
git status --short
git diff --check
```

Expected: ignore rule is reported, no vendor files are tracked, status contains only task changes plus the preserved user battle-lab edit, and diff check passes.

- [ ] **Step 6: Perform manual visual and physical-input acceptance**

Run the current battle at physical `1280x800` and `1920x1080` with local assets installed. Record pass/fail notes for:

1. room scale, camera height, full background coverage, and lighting;
2. one through five enemies in both W and M layouts;
3. projected HUD order, safe-area clamping, overlap, hover reveal, and controller reveal;
4. controller-only action selection and directional targeting;
5. EyeDrone Idle, Charging, Attack, Hit, defeat, and return to Idle;
6. mouse edge-look center return and lack of target drift;
7. shake at `0%`, the default, and `100%`;
8. laser origin/destination and hero-panel impact feedback;
9. CTB right-stick scrolling without camera movement.

Leave any unperformed item unchecked and state the missing device/path explicitly.

- [ ] **Step 7: Update and commit the acceptance record**

Add a dedicated “First-person 3D battle slice” section to `docs/testing/ctb-combat-checklist.md`, naming the exact source SHA, Godot version, focused/full totals, clean-clone result, local asset state, resolutions, and manual input devices.

```bash
git add docs/testing/ctb-combat-checklist.md
git commit -m "docs: record 3d battle slice verification"
```

- [ ] **Step 8: Request final independent review**

Ask the reviewer to inspect the entire implementation range against both the 2026-08-01 foundation design and 2026-08-02 local slice design, with explicit attention to:

- ignored-asset leakage and clean-clone parsing;
- combatant authority and presentation-only effects;
- exact view-root and HUD teardown;
- five-slot/boss formation semantics;
- controller/CTB input ownership;
- animation/projectile cancellation;
- persistence isolation and shake-off behavior;
- manual claims matching performed checks.
