# Industrial Battle Room Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the barren model-test stage with a compact three-bay mechanical battle chamber that remains readable behind five enemies and the existing first-person UI.

**Architecture:** Extract one reusable tracked bay scene and instance it three times inside `IndustrialRoom3D`. Each bay owns paired side-wall/support modules, a ceiling beam, and an emissive practical; the room scene owns the floor and layered back-wall bulkhead. `BattleWorld3D` discovers `OptionalLocalModel3D` recursively so nested bay assets load while tracked placeholders preserve the complete shell without local Quaternius files.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, Forward Mobile renderer, GUT 9.6.1, ignored local Quaternius glTF assets.

## Global Constraints

- Use Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot`.
- Use an isolated `HOME` for every automated Godot command.
- Do not change the battle camera, `EnemyViews` elevation, five-enemy W/M transforms, projected HUD contract, hero/action UI, controller behavior, or combat rules.
- Keep the camera-facing side open and build the other five room surfaces.
- Keep the central enemy and reserved boss volume free of props.
- Preserve one shadowed key, one non-shadowed local fill, one diffuse-only bounce, and color-sourced ambient illumination.
- Keep Quaternius source assets ignored; never stage their `.gltf`, `.bin`, textures, `.import` files, or directory symlinks.
- Do not edit the primary checkout's unrelated `src/dev/endgame_battle_lab.tscn` change.

---

## File Structure

- Create `src/battle/presentation/industrial_room_bay_3d.tscn` — one reusable structural bay with paired wall/support assemblies, a ceiling beam, and a practical light.
- Modify `src/battle/presentation/industrial_room_3d.tscn` — compose three bay instances, the continuous floor, layered back wall, sealed bulkhead, edge dressing, and room lights.
- Modify `src/battle/presentation/battle_world_3d.gd` — load nested `OptionalLocalModel3D` nodes recursively.
- Modify `test/integration/test_battle_world_3d.gd` — protect recursive loading, the five-surface shell, three-bay composition, local fallback contract, lighting hierarchy, and unchanged battle staging.
- Modify `docs/testing/ctb-combat-checklist.md` — record the room-composition acceptance criteria without marking unperformed checks complete.
- Local-only under `assets/graphics/models/quaternius_local/environment/industrial/` — add the door frame, metal door, and only the texture files referenced by those two models; these files remain ignored.

---

### Task 1: Build the tracked three-bay room shell

**Files:**
- Create: `src/battle/presentation/industrial_room_bay_3d.tscn`
- Modify: `src/battle/presentation/industrial_room_3d.tscn`
- Modify: `src/battle/presentation/battle_world_3d.gd`
- Modify: `test/integration/test_battle_world_3d.gd`

**Interfaces:**
- Consumes: `OptionalLocalModel3D.try_load() -> bool`; existing `IndustrialRoom3D` instance at `BattleWorld3D/IndustrialRoom3D`.
- Produces: `BattleWorld3D._load_optional_local_models(room: Node) -> void`; room nodes `RoomShell`, `BayNear`, `BayMiddle`, `BayRear`, and `BackWall`; nested optional-model wrappers with valid `model_parent` and `placeholder` references.

- [ ] **Step 1: Replace the obsolete backdrop/module assertions with failing shell assertions**

In `test/integration/test_battle_world_3d.gd`, delete `test_room_keeps_a_tracked_backdrop_behind_optional_local_modules()` and `test_room_uses_eight_optional_local_modules_with_tracked_placeholders()`. Add:

```gdscript
func test_room_builds_a_closed_three_bay_shell_without_backdrop() -> void:
	var world := _world()
	var room := world.get_node("IndustrialRoom3D")
	assert_null(room.get_node_or_null("BattleBackdrop"))
	var shell := room.get_node("RoomShell")
	assert_not_null(shell.get_node("Floor"))
	assert_not_null(shell.get_node("BackWall/LeftPanel"))
	assert_not_null(shell.get_node("BackWall/CenterBulkhead"))
	assert_not_null(shell.get_node("BackWall/RightPanel"))
	var expected_bays := {
		"BayNear": Vector3(0.0, 0.0, 2.5),
		"BayMiddle": Vector3(0.0, 0.0, -1.5),
		"BayRear": Vector3(0.0, 0.0, -5.5),
	}
	for bay_name: String in expected_bays:
		var bay := shell.get_node(bay_name) as Node3D
		assert_not_null(bay)
		assert_eq(bay.position, expected_bays[bay_name])
		assert_not_null(bay.get_node("LeftWall"))
		assert_not_null(bay.get_node("RightWall"))
		assert_not_null(bay.get_node("LeftSupport"))
		assert_not_null(bay.get_node("RightSupport"))
		assert_not_null(bay.get_node("CeilingPanel"))
		assert_not_null(bay.get_node("CeilingBeam"))
		assert_not_null(bay.get_node("PracticalLight"))


func test_room_nested_local_modules_all_keep_tracked_placeholders() -> void:
	var world := _world()
	var room := world.get_node("IndustrialRoom3D")
	var nodes: Array[Node] = []
	for node: Node in room.find_children("*", "", true, false):
		if node is OptionalLocalModel3D:
			nodes.append(node)
	assert_gte(nodes.size(), 20)
	for node: Node in nodes:
		var loader := node as OptionalLocalModel3D
		assert_not_null(loader.model_parent)
		assert_not_null(loader.placeholder)
		assert_true(loader.placeholder is GeometryInstance3D)
		assert_false(loader.local_resource_path.is_empty())


func test_world_loads_optional_models_nested_below_room_root() -> void:
	var world := _world()
	var branch := Node3D.new()
	var loader := OptionalLocalModel3D.new()
	loader.local_resource_path = \
		"res://test/fixtures/presentation/optional_model_fixture.tscn"
	loader.model_parent = Node3D.new()
	loader.placeholder = MeshInstance3D.new()
	loader.add_child(loader.model_parent)
	loader.add_child(loader.placeholder)
	branch.add_child(loader)
	add_child_autofree(branch)
	world._load_optional_local_models(branch)
	assert_false(loader.using_placeholder)
	assert_not_null(loader.loaded_model)
```

- [ ] **Step 2: Run the focused suite and verify RED**

Run:

```bash
env HOME=/private/tmp/mars-room-rebuild-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars/.worktrees/brighten-battle-world -s addons/gut/gut_cmdln.gd -gselect test_battle_world_3d -gexit
```

Expected: failures because `RoomShell`, the three bay instances, recursive loader method, and nested wrappers do not exist; no parser errors or crashes.

- [ ] **Step 3: Make optional local-model discovery recursive**

Replace the direct-child loop in `BattleWorld3D._ready()` and add the helper:

```gdscript
func _ready() -> void:
	process_priority = 100
	var room := get_node_or_null("IndustrialRoom3D")
	if room == null:
		return
	_load_optional_local_models(room)


func _load_optional_local_models(room: Node) -> void:
	for node: Node in room.find_children("*", "", true, false):
		if node is OptionalLocalModel3D:
			(node as OptionalLocalModel3D).try_load()
```

- [ ] **Step 4: Author the reusable bay scene**

Create `industrial_room_bay_3d.tscn` with this exact public node contract and fallback placement:

| Node | Type | Position | Rotation | Fallback size |
|---|---|---:|---:|---:|
| `LeftWall` | `OptionalLocalModel3D` | `(-5.85, 2.5, 0)` | `(0, -90, 0)` | `(4.0, 5.0, 0.3)` |
| `RightWall` | `OptionalLocalModel3D` | `(5.85, 2.5, 0)` | `(0, 90, 0)` | `(4.0, 5.0, 0.3)` |
| `LeftSupport` | `OptionalLocalModel3D` | `(-5.55, 2.5, -1.8)` | `(0, 0, 0)` | `(0.65, 5.1, 0.65)` |
| `RightSupport` | `OptionalLocalModel3D` | `(5.55, 2.5, -1.8)` | `(0, 0, 0)` | `(0.65, 5.1, 0.65)` |
| `CeilingBeam` | `OptionalLocalModel3D` | `(0, 5.0, -1.8)` | `(0, 0, 0)` | `(11.7, 0.4, 0.65)` |
| `PracticalLight` | `OptionalLocalModel3D` | `(0, 4.78, -1.65)` | `(0, 0, 0)` | `(3.6, 0.14, 0.18)` |

Also add a permanent `CeilingPanel` `MeshInstance3D` at `(0, 5.2, 0)` with size `(12, 0.25, 4)`. It closes the upper surface even if a local trim model is missing or narrower than its bay.

Each wrapper contains `ModelPivot` and a `MeshInstance3D` named `Placeholder`; assign the existing WallAstra, ColumnAstra, TopAstra, and wide-light local paths. Use the existing dark, trim, and emissive material values from `industrial_room_3d.tscn`. Keep every `ModelPivot.scale` component between `0.5` and `2.0`; do not repeat the old `3x` wall/floor scaling.

The root and wrapper skeleton is:

```text
IndustrialRoomBay3D (Node3D)
├── LeftWall (OptionalLocalModel3D)
│   ├── ModelPivot (Node3D)
│   └── Placeholder (MeshInstance3D)
├── RightWall (OptionalLocalModel3D)
│   ├── ModelPivot (Node3D)
│   └── Placeholder (MeshInstance3D)
├── LeftSupport (OptionalLocalModel3D)
├── RightSupport (OptionalLocalModel3D)
├── CeilingPanel (MeshInstance3D)
├── CeilingBeam (OptionalLocalModel3D)
└── PracticalLight (OptionalLocalModel3D)
```

- [ ] **Step 5: Recompose `IndustrialRoom3D` around three bay instances**

Delete `BattleBackdrop` and the old single-instance catalog arrangement. Preserve `RoomKeyLight`, `RoomFillLight`, and `RoomBounceLight`. Create:

```text
IndustrialRoom3D
├── RoomShell
│   ├── Floor                         position (0, -0.3, -1.5), size (12, 0.3, 12)
│   ├── BayNear                       position (0, 0, 2.5)
│   ├── BayMiddle                     position (0, 0, -1.5)
│   ├── BayRear                       position (0, 0, -5.5)
│   └── BackWall                      position (0, 0, -7.5)
│       ├── LeftPanel                 position (-4, 2.5, 0), size (4, 5, 0.35)
│       ├── CenterBulkhead            position (0, 2.35, -0.08), size (3.6, 4.5, 0.45)
│       ├── RightPanel                position (4, 2.5, 0), size (4, 5, 0.35)
│       ├── BulkheadFrameLeft         position (-2.15, 2.5, 0.12), size (0.45, 5, 0.55)
│       ├── BulkheadFrameRight        position (2.15, 2.5, 0.12), size (0.45, 5, 0.55)
│       └── BulkheadLight             position (0, 4.25, 0.28), size (2.8, 0.16, 0.15)
├── EdgeDressing
│   ├── LeftVent
│   ├── RightVent
│   ├── LeftCable
│   └── RightCable
├── RoomKeyLight
├── RoomFillLight
└── RoomBounceLight
```

Make all four `EdgeDressing` children `OptionalLocalModel3D` wrappers with `ModelPivot` and tracked `MeshInstance3D` placeholders. `LeftVent` and `RightVent` use `Prop_Vent_Wide.gltf`; `LeftCable` and `RightCable` use `Prop_Cable_1.gltf`. Place them against the back corners at `x = ±4.6`, `z = -7.1`, never inside `x = -4.0..4.0` and `z = -2.5..2.5`, which is reserved for ordinary enemies and the boss volume.

- [ ] **Step 6: Run import and focused tests until GREEN**

Run:

```bash
env HOME=/private/tmp/mars-room-rebuild-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars/.worktrees/brighten-battle-world --editor --quit
env HOME=/private/tmp/mars-room-rebuild-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars/.worktrees/brighten-battle-world -s addons/gut/gut_cmdln.gd -gselect test_battle_world_3d -gexit
env HOME=/private/tmp/mars-room-rebuild-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars/.worktrees/brighten-battle-world -s addons/gut/gut_cmdln.gd -gselect test_battle_formation_layout -gexit
```

Expected: import exit `0`; both focused suites pass with no unexpected errors.

- [ ] **Step 7: Commit the tracked shell**

```bash
git add src/battle/presentation/industrial_room_bay_3d.tscn src/battle/presentation/industrial_room_bay_3d.tscn.uid src/battle/presentation/industrial_room_3d.tscn src/battle/presentation/battle_world_3d.gd test/integration/test_battle_world_3d.gd
git commit -m "feat: build three-bay battle room shell"
```

Include the `.uid` only if Godot creates it. Do not stage ignored Quaternius assets.

---

### Task 2: Fit the local kit, finish lighting, and record acceptance

**Files:**
- Modify: `src/battle/presentation/industrial_room_bay_3d.tscn`
- Modify: `src/battle/presentation/industrial_room_3d.tscn`
- Modify: `test/integration/test_battle_world_3d.gd`
- Modify: `docs/testing/ctb-combat-checklist.md`
- Local-only: `assets/graphics/models/quaternius_local/environment/industrial/`

**Interfaces:**
- Consumes: the three-bay node contract and recursive loader from Task 1.
- Produces: visually fitted local modules, sealed-door focal point, finalized Mobile lighting transforms, and recorded manual acceptance evidence.

- [ ] **Step 1: Copy only the two new focal models and their referenced files**

Copy `Door_Frame_A.gltf`, `Door_Frame_A.bin`, `Door_Metal.gltf`, and `Door_Metal.bin` from the kit's `glTF/Platforms` folder into the ignored industrial folder. Copy only referenced textures not already present, including `T_Decals.png` from the kit `Textures` folder. Do not copy FBX or OBJ variants.

```bash
cp '/Users/adam/Downloads/Modular SciFi MegaKit[Standard]/glTF/Platforms/Door_Frame_A.gltf' assets/graphics/models/quaternius_local/environment/industrial/Door_Frame_A.gltf
cp '/Users/adam/Downloads/Modular SciFi MegaKit[Standard]/glTF/Platforms/Door_Frame_A.bin' assets/graphics/models/quaternius_local/environment/industrial/Door_Frame_A.bin
cp '/Users/adam/Downloads/Modular SciFi MegaKit[Standard]/glTF/Platforms/Door_Metal.gltf' assets/graphics/models/quaternius_local/environment/industrial/Door_Metal.gltf
cp '/Users/adam/Downloads/Modular SciFi MegaKit[Standard]/glTF/Platforms/Door_Metal.bin' assets/graphics/models/quaternius_local/environment/industrial/Door_Metal.bin
cp '/Users/adam/Downloads/Modular SciFi MegaKit[Standard]/Textures/T_Decals.png' assets/graphics/models/quaternius_local/environment/industrial/T_Decals.png
```

Verify every local file remains ignored:

```bash
git check-ignore assets/graphics/models/quaternius_local/environment/industrial/Door_Frame_A.gltf assets/graphics/models/quaternius_local/environment/industrial/Door_Frame_A.bin assets/graphics/models/quaternius_local/environment/industrial/Door_Metal.gltf assets/graphics/models/quaternius_local/environment/industrial/Door_Metal.bin assets/graphics/models/quaternius_local/environment/industrial/T_Decals.png
```

Expected: all five paths are printed. If any path is not printed, stop without staging and correct `.gitignore` before continuing.

- [ ] **Step 2: Add optional local door dressing without weakening the tracked bulkhead**

Under `RoomShell/BackWall`, add `DoorFrameModel` and `DoorModel` wrappers with tracked mesh placeholders matching the bulkhead frame and door silhouette. Point them to:

```text
res://assets/graphics/models/quaternius_local/environment/industrial/Door_Frame_A.gltf
res://assets/graphics/models/quaternius_local/environment/industrial/Door_Metal.gltf
```

Keep their `ModelPivot` scale components within `0.5..2.0`. The permanent left/right back panels stay visible so loading a decorative model cannot reopen the room into a void.

- [ ] **Step 3: Protect the focal wrappers and bounded transforms**

Extend `test_room_nested_local_modules_all_keep_tracked_placeholders()`:

```gdscript
	var frame := room.get_node("RoomShell/BackWall/DoorFrameModel") \
		as OptionalLocalModel3D
	var door := room.get_node("RoomShell/BackWall/DoorModel") \
		as OptionalLocalModel3D
	assert_eq(frame.local_resource_path, \
		"res://assets/graphics/models/quaternius_local/environment/industrial/Door_Frame_A.gltf")
	assert_eq(door.local_resource_path, \
		"res://assets/graphics/models/quaternius_local/environment/industrial/Door_Metal.gltf")
	for loader: OptionalLocalModel3D in [frame, door]:
		var pivot_scale := loader.model_parent.scale
		assert_gte(pivot_scale.x, 0.5)
		assert_lte(pivot_scale.x, 2.0)
		assert_gte(pivot_scale.y, 0.5)
		assert_lte(pivot_scale.y, 2.0)
		assert_gte(pivot_scale.z, 0.5)
		assert_lte(pivot_scale.z, 2.0)
```

- [ ] **Step 4: Fit models and light the completed shell in the Godot editor**

Open the isolated project and inspect `industrial_room_3d.tscn` through the battle camera preview. Adjust only `ModelPivot` transforms, edge-dressing transforms, and the existing three light transforms/energies. Preserve the exact node names and structural positions protected by Task 1.

Acceptance boundaries:

- no imported mesh crosses the camera near plane or extends beyond the room shell;
- left/right supports are mirrored within `0.05` world units;
- all three bays remain visible as repeated depth lines;
- the back bulkhead is readable but darker than enemy health bars;
- ordinary enemy positions `x = ±3.6`, `z = -1.4..1.4` remain unobstructed;
- boss and ally positions `x = 0, ±4.4`, `z = 0` remain unobstructed;
- no light energy exceeds `4.0` and exposure remains `1.15`.

- [ ] **Step 5: Run focused and complete automated verification**

Run:

```bash
env HOME=/private/tmp/mars-room-rebuild-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars/.worktrees/brighten-battle-world --editor --quit
env HOME=/private/tmp/mars-room-rebuild-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars/.worktrees/brighten-battle-world -s addons/gut/gut_cmdln.gd -gselect test_battle_world_3d -gexit
env HOME=/private/tmp/mars-room-rebuild-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars/.worktrees/brighten-battle-world -s addons/gut/gut_cmdln.gd -gselect test_battle_formation_layout -gexit
env HOME=/private/tmp/mars-room-rebuild-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars/.worktrees/brighten-battle-world -s addons/gut/gut_cmdln.gd -gexit
```

Expected: import exit `0`; focused and complete suites pass with zero failures.

- [ ] **Step 6: Commit the verified visual candidate**

```bash
git add src/battle/presentation/industrial_room_bay_3d.tscn src/battle/presentation/industrial_room_3d.tscn test/integration/test_battle_world_3d.gd
git commit -m "fix: finish industrial battle room presentation"
```

Before committing, run `git status --short --ignored assets/graphics/models/quaternius_local` and confirm every local kit file remains ignored and unstaged.

- [ ] **Step 7: Perform the two-resolution manual acceptance gate**

Launch `src/dev/endgame_battle_lab.tscn` at `1920x1080`, then `1280x800`. At both sizes verify the room is enclosed, repeated bays produce depth, no module clips, the bulkhead anchors the composition, five enemies remain readable, projected HUDs remain attached, and hero/action UI remains legible. Capture screenshots before marking acceptance complete.

- [ ] **Step 8: Record evidence and commit the acceptance record**

Add a dated entry to `docs/testing/ctb-combat-checklist.md` containing Godot `4.7.1`, macOS, input method, both resolutions, tested commit, exact test/assertion totals, and screenshot paths. Leave any unperformed controller or hardware items unchecked.

```bash
git add docs/testing/ctb-combat-checklist.md
git commit -m "docs: record industrial room acceptance"
```
