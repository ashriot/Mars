# Battle World Lighting and Framing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise enemy staging out of the hero-card band and make the first industrial battle room clearly readable without altering formation, camera, HUD, or combat behavior.

**Architecture:** Apply vertical staging once at the shared `EnemyViews` parent so all model and projection anchors move together while W/M transforms remain local and unchanged. Author background and ambient light in `BattleWorld3D`, author broad key/fill illumination in `IndustrialRoom3D`, and protect those tracked scene contracts with one focused integration suite.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` resources, GUT 9.6.1

## Global Constraints

- Use Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot` with an isolated test `HOME` for every automated run.
- Raise `EnemyViews` by exactly `1.0` world unit; do not change W/M or boss-local transforms.
- Keep the existing camera origin, field of view, parallax, and shake behavior unchanged.
- Keep the 2D hero UI and projected enemy HUD implementation unchanged.
- Keep Quaternius resources under `assets/graphics/models/quaternius_local/` ignored and unmodified.
- Preserve the unrelated working edit in `src/dev/endgame_battle_lab.tscn`; do not stage, restore, or rewrite it.
- Manual acceptance, not headless automation, is authoritative for final brightness and composition.

---

### Task 1: Protect the Readable World Composition Contract

**Files:**
- Modify: `test/integration/test_battle_world_3d.gd:12-46`

**Interfaces:**
- Consumes: `BattleWorldScene.instantiate()`, `BattleWorld3D.enemy_views`, `WorldEnvironment.environment`, `DirectionalLight3D`, and `OmniLight3D`.
- Produces: regression coverage for the shared vertical offset and exact tracked lighting baseline.

- [ ] **Step 1: Add failing staging and lighting tests**

Add these tests after `test_world_exposes_stable_camera_enemy_and_hud_nodes()`:

```gdscript
func test_world_raises_enemy_views_without_changing_local_formation_height() -> void:
	var world := _world()
	assert_eq(world.enemy_views.position, Vector3(0.0, 1.0, 0.0))
	var local_slots := BattleFormationLayout.ordinary_transforms(
		5,
		BattleFormationLayout.Layout.W,
	)
	for slot: Transform3D in local_slots:
		assert_eq(slot.origin.y, 0.0)


func test_world_environment_uses_readable_industrial_ambient_light() -> void:
	var world := _world()
	var world_environment := world.get_node("WorldEnvironment") as WorldEnvironment
	assert_not_null(world_environment)
	var environment := world_environment.environment
	assert_not_null(environment)
	assert_eq(environment.background_color, Color(0.035, 0.055, 0.085, 1.0))
	assert_eq(environment.ambient_light_color, Color(0.52, 0.58, 0.68, 1.0))
	assert_eq(environment.ambient_light_energy, 1.1)


func test_room_uses_broad_neutral_readability_lighting() -> void:
	var world := _world()
	var room := world.get_node("IndustrialRoom3D")
	var key := room.get_node("RoomKeyLight") as DirectionalLight3D
	var fill := room.get_node("RoomFillLight") as OmniLight3D
	assert_not_null(key)
	assert_not_null(fill)
	assert_eq(key.light_energy, 1.6)
	assert_true(key.shadow_enabled)
	assert_eq(fill.position, Vector3(0.0, 3.6, 4.0))
	assert_eq(fill.light_color, Color(0.82, 0.88, 1.0, 1.0))
	assert_eq(fill.light_energy, 5.0)
	assert_eq(fill.omni_range, 18.0)
	assert_false(fill.shadow_enabled)
```

- [ ] **Step 2: Run the focused test to verify RED**

Run:

```sh
env HOME=/private/tmp/mars-lighting-test-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_world_3d -gexit
```

Expected: the existing tests pass and the three new tests fail on the old enemy-layer and lighting values. Parser errors, crashes, or unrelated failures are not acceptable.

- [ ] **Step 3: Review the RED failures**

Confirm every failure is an expected mismatch for one of these authored values: `EnemyViews.position`, environment background/ambient values, key-light energy, or fill-light position/color/energy/range/shadow state. If any failure has another cause, stop and correct the test before changing the scenes.

---

### Task 2: Raise Enemies and Establish the Bright Industrial Baseline

**Files:**
- Modify: `src/battle/presentation/battle_world_3d.tscn:8-14,36-38`
- Modify: `src/battle/presentation/industrial_room_3d.tscn:158-169`
- Test: `test/integration/test_battle_world_3d.gd`

**Interfaces:**
- Consumes: the exact regression contract added in Task 1.
- Produces: a `BattleWorld3D` with `EnemyViews.position == Vector3(0.0, 1.0, 0.0)`, a brighter blue-gray environment, and neutral front/top room illumination.

- [ ] **Step 1: Raise the shared enemy layer and brighten the world environment**

Change the environment and enemy-layer sections of `battle_world_3d.tscn` to:

```ini
[sub_resource type="Environment" id="Environment_world"]
background_mode = 1
background_color = Color(0.035, 0.055, 0.085, 1)
ambient_light_source = 3
ambient_light_color = Color(0.52, 0.58, 0.68, 1)
ambient_light_energy = 1.1
tonemap_mode = 2
```

```ini
[node name="EnemyViews" type="Node3D" parent="."]
position = Vector3(0, 1, 0)
unique_name_in_owner = true
```

- [ ] **Step 2: Rebalance the tracked room lights**

Change the two room lights in `industrial_room_3d.tscn` to:

```ini
[node name="RoomKeyLight" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-42, -28, 0)
light_color = Color(0.72, 0.82, 1, 1)
light_energy = 1.6
shadow_enabled = true

[node name="RoomFillLight" type="OmniLight3D" parent="."]
position = Vector3(0, 3.6, 4)
light_color = Color(0.82, 0.88, 1, 1)
light_energy = 5.0
omni_range = 18.0
shadow_enabled = false
```

- [ ] **Step 3: Import and parse the edited scenes**

Run:

```sh
env HOME=/private/tmp/mars-lighting-test-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
```

Expected: exit `0`, with no script, parser, scene-resource, or load errors. The documented macOS certificate diagnostic is acceptable.

- [ ] **Step 4: Run the focused tests to verify GREEN**

Run:

```sh
env HOME=/private/tmp/mars-lighting-test-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_world_3d -gselect battle_formation_layout -gexit
```

Expected: all selected tests and assertions pass. This proves the parent offset changed while local formation heights remain `0.0`.

- [ ] **Step 5: Review the focused diff**

Run:

```sh
git diff --check
git diff -- src/battle/presentation/battle_world_3d.tscn src/battle/presentation/industrial_room_3d.tscn test/integration/test_battle_world_3d.gd
git status --short
```

Expected: only the three task files plus the already-protected `src/dev/endgame_battle_lab.tscn` edit are present. No file beneath `assets/graphics/models/quaternius_local/` is tracked or modified.

- [ ] **Step 6: Commit the scene correction and test**

```sh
git add src/battle/presentation/battle_world_3d.tscn src/battle/presentation/industrial_room_3d.tscn test/integration/test_battle_world_3d.gd
git commit -m "fix: brighten and raise 3d battle staging"
```

Do not stage `src/dev/endgame_battle_lab.tscn`.

---

### Task 3: Verify the Presentation Boundary and Hand Off Visual Acceptance

**Files:**
- Modify: `docs/testing/ctb-combat-checklist.md:45-51`

**Interfaces:**
- Consumes: the committed lighting/framing correction from Task 2 and the repository's existing battle-presentation suites.
- Produces: focused and full automated evidence plus explicit unchecked manual acceptance criteria for the user.

- [ ] **Step 1: Add explicit manual acceptance checks**

Under `### Room, formation, and projected HUD`, add these unchecked items after the two resolution checks:

```markdown
- [ ] Confirm every active EyeDrone body sits clearly above the hero-card band and remains visually connected to its overhead Intent/Guard/HP stack in both front and back rows.
- [ ] Confirm the center of the battlefield reads as a physical dark-metal room rather than a black void: drone surfaces, wall structure, and floor depth remain visible while blue practical lights retain contrast.
```

- [ ] **Step 2: Run the presentation-focused regression set**

Run:

```sh
env HOME=/private/tmp/mars-lighting-test-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect battle_world_3d -gselect battle_formation_layout -gselect enemy_drone_presentation -gselect card_combatant_binding -gselect responsive_battle_ui -gexit
```

Expected: every selected test and assertion passes with no parser errors, crashes, or unexpected failures.

- [ ] **Step 3: Run the complete working-checkout suite**

Run:

```sh
env HOME=/private/tmp/mars-lighting-test-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: the lighting/framing changes introduce no failure. The protected working edit in `src/dev/endgame_battle_lab.tscn` may retain its already-established single HP-multiplier failure; record it separately rather than changing or staging the file.

- [ ] **Step 4: Commit the checklist refinement**

```sh
git add docs/testing/ctb-combat-checklist.md
git commit -m "docs: add battle lighting acceptance checks"
```

- [ ] **Step 5: Perform the user-facing visual check**

Launch the ordinary playable battle with the installed local Quaternius assets. At `1920x1080`, capture the same encounter framing used for the reported screenshot. Repeat at `1280x800` if the desktop composition passes. Do not mark either checklist item complete unless the check is physically performed and its date, OS, input device, resolution, and tested commit are recorded.

- [ ] **Step 6: Evaluate the screenshot against the approved design**

Accept the pass only if all active drones sit above the hero-card band, their HUD ownership is clear, the central room surfaces are visible, blue accents retain contrast, and the 2D UI is not visually washed out. If illumination or height still misses the target, adjust only the authored values protected by Task 1, rerun Tasks 2 Steps 3-5 and Task 3 Steps 2-3, then request a new screenshot.
